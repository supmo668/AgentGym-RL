#!/usr/bin/env bash
set -euo pipefail
set -x

# UV-based evaluation script for SearchQA environment.
# Mirrors original conda + merger flow but uses uv virtual environment.

export VLLM_USE_MODELSCOPE=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ATTENTION_BACKEND=XFORMERS

TASK_NAME="searchqa"
PORT="36005"  # override if needed
ENV_SERVER_URL="http://127.0.0.1:${PORT}"  # server must already be running

SAMPLE_NUM="1"
MAX_ROUNDS="30"
CKPT_PATH="global_step_150/actor"
MODEL_PATH="${CKPT_PATH}/huggingface"

SCRIPT_ROOT="$(git rev-parse --show-toplevel)"
cd "${SCRIPT_ROOT}" || { echo "Failed to cd to repo root"; exit 1; }

# Ensure uv environment exists
if [ ! -d .uv ]; then
  echo "uv environment missing: run 'make agentenv-searchqa-setup' first" >&2
  exit 2
fi

MERGER_SCRIPT="AgentGym-RL/scripts/model_merger.py"

# Merge model shards (idempotent)
uv run --python python3 "${MERGER_SCRIPT}" --local_dir "${CKPT_PATH}" || true

HYDRA_FULL_ERROR=1 uv run --python python3 -m verl.agent_trainer.main_generation \
  data.path=AgentEval/${TASK_NAME} \
  data.max_prompt_length=750 \
  data.max_response_length=14098 \
  data.n_samples=${SAMPLE_NUM} \
  data.batch_size=32 \
  agentgym.task_name=${TASK_NAME} \
  agentgym.env_addr=${ENV_SERVER_URL} \
  agentgym.max_rounds=${MAX_ROUNDS} \
  agentgym.timeout=500 \
  model.path=${MODEL_PATH} \
  rollout.gpu_memory_utilization=0.95 \
  rollout.temperature=1 \
  rollout.max_model_len=32768 \
  rollout.max_tokens=512 \
  rollout.tensor_model_parallel_size=1 \
  rollout.rollout_log_dir=executer_logs

exit $?
