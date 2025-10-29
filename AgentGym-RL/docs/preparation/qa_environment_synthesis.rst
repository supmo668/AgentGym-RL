Synthesize a Tool-Augmented QA Environment
=========================================

This guide shows how to turn synthesized JSON traces from large language models (LLMs) into a
question-answering environment that runs inside ``agentenv``. The recipe assumes you already
collected dialogues where the assistant invokes tools and receives tool outputs before delivering
final answers.

.. contents::
   :local:
   :depth: 2

Prerequisites
-------------

- A JSON file containing one list item per QA episode. Each item should include a unique
  ``dialogue_id``, the user-facing ``question``, and the full ``messages`` exchange between
  human, assistant, and tool calls.
- Tool call metadata that captures the ``id``, ``name``, and serialized ``arguments`` payload for
  each invocation, plus a matching tool response message.
- A recent checkout of this repository with the ``agentenv`` package installed in editable mode::

    pip install -e AgentGym/agentenv

1. Model the Trace Schema
-------------------------

Normalize your synthesized traces so every message follows the OpenAI-compatible schema we use in
``agentenv.controller.types``:

- ``role``: ``"user"``, ``"assistant"``, or ``"tool"``
- ``content``: human-readable text returned to the agent at that step
- ``tool_calls`` *(assistant messages only, optional)*: list of objects with ``id``, ``type`` and a
  ``function`` payload containing ``name`` and JSON ``arguments`` string
- ``tool_call_id`` *(tool messages only)*: used to associate the tool response with the triggering
  assistant call

Example snippet::

    {
      "dialogue_id": "qa-synth-00042",
      "question": "Who discovered radium and in which year?",
      "messages": [
        {"role": "user", "content": "Who discovered radium and when?"},
        {"role": "assistant", "content": "<think>Need historical lookup</think>",
         "tool_calls": [{
           "id": "call_01",
           "type": "function",
           "function": {"name": "science_search", "arguments": "{\"query\": \"radium discovery\"}"}
         }]},
        {"role": "tool", "tool_call_id": "call_01", "content": "Radium was discovered by Marie and Pierre Curie in 1898."},
        {"role": "assistant", "content": "Radium was discovered by Marie and Pierre Curie in 1898."}
      ]
    }

Keep the tool response in plain text; ``agentenv`` handles optional structured attachments through
``ConversationMessage`` if needed.

2. Build a Static Environment Payload
-------------------------------------

Transform the normalized traces into the payload consumed by your environment server. For tractable
QA environments we recommend packaging each dialogue as::

    {
      "id": 42,
      "question": "...",
      "tool_contract": {
        "science_search": {
          "description": "Domain-specific search API",
          "parameters": {...}
        }
      },
      "golden_answer": "...",
      "messages": [... as above ...]
    }

Store the artifacts in ``AgentGym/albert_qa`` or a new subdirectory under ``AgentGym`` that matches
your environment name. We commonly ship both a compact ``train.json`` for experience generation and
an ``eval.json`` for deterministic scoring.

- ``tool_contract`` documents the tools exposed to the agent during rollouts; mirror the schema used
  by ``agentenv_tool`` environments so controllers can auto-populate OpenAI-style function schemas.
- The ``messages`` list keeps the exact order of interactions and will be replayed when the agent
  calls ``reset`` or ``step``.

3. Author the Environment Server
--------------------------------

Follow the pattern from ``AgentGym/agentenv_searchqa`` to scaffold a lightweight FastAPI (or Flask)
server that streams observations and scores completions. Core handlers:

- ``POST /create``: accept dataset metadata, allocate an environment ID, and prime any caches.
- ``GET /observation``: return the initial question and tool schema for the current dialogue ID.
- ``POST /step``: accept the agent's response, append it to the transcript, evaluate tool calls,
  and emit the next observation plus a reward. When the assistant submits a final answer, compute
  the episode reward using string match, fuzzy score, or a custom verifier.
- ``POST /reset``: select the next dialogue and return its starting observation.
- ``POST /close``: clean up server-side resources.

Wrap dataset-level configuration (paths, scoring knobs, maximum tool invocations) inside a Pydantic
``Settings`` model to keep deployment reproducible.

4. Implement the ``agentenv`` Client
------------------------------------

Create a new client in ``AgentGym/agentenv/agentenv/envs`` by extending ``BaseEnvClient`` and
``BaseTask``. Mirror ``searchqa.py`` but adapt the REST endpoints you defined above and plug in your
trace length for ``__len__``::

.. code-block:: python

   class SynthQAEnvClient(BaseEnvClient):
       conversation_start = (
           ConversationMessage({"from": "human", "loss": None, "value": "Answer using tools when needed."}),
           ConversationMessage({"from": "gpt", "loss": False, "value": "Understood."}),
       )

       def __init__(self, env_server_base: str, data_len: int, timeout: int = 120, **kwargs):
           super().__init__(**kwargs)
           self.env_server_base = env_server_base
           self.timeout = timeout
           self.data_len = data_len
           self.env_id = self._post_create()

       # reuse _get/_post helpers from searchqa.py and return StepOutput

   class SynthQATask(BaseTask):
       env_client_cls = SynthQAEnvClient
       env_name = "SynthQA"

Update ``AgentGym/agentenv/agentenv/envs/__init__.py`` so ``SynthQATask`` can be imported via
``agentenv.make_task("SynthQA")``.

5. Hook Up Evaluation Logic
---------------------------

Design a score function that leverages your synthesized tool traces:

- Validate that assistant tool invocations match the ground-truth sequence. You can enforce
  ``tool_name`` and ``arguments`` equality or allow semantically equivalent calls via custom
  validators.
- Compare the final assistant answer with ``golden_answer`` using exact match, regex rules, or LLM-based
  grading.
- Aggregate any dense feedback (e.g., intermediate reward for correct tool usage) into the float
  you return in ``StepOutput``.

Embed the scorer either inside the environment server's ``/step`` handler or inside a dedicated
``RewardModule`` if the environment will be used for RL training.

6. Verify the Environment
-------------------------

Run a local smoke test to ensure the new environment wires into ``agentenv`` correctly::

    python -m agentenv.examples.basic.run_eval \
        --task SynthQA \
        --env-server-base http://127.0.0.1:8001 \
        --num-episodes 2

Confirm that the controller can invoke tools, receive the stub responses from your dataset, and that
rewards match the output of your scoring logic. Once validated, package the dataset and server code
with a short README describing tool schemas and trace provenance.
