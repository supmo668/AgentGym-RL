################################################################################
# Makefile for agentenv-searchqa using uv (Python package manager)
# Requires: curl installed (for bootstrap), or manually install uv first.
# See: https://github.com/astral-sh/uv
################################################################################

# CONFIG ----------------------------------------------------------------------
UV := uv
PYTHON := python3
SEARCHQA_ENV_NAME := agentenv-searchqa
SEARCHQA_PORT ?= 36001
SEARCHQA_HOST ?= 0.0.0.0
SEARCHQA_WORKERS ?= 1
MERGE_CKPT ?= global_step_150/actor
MODEL_PATH := $(MERGE_CKPT)/huggingface
EVAL_EPISODES ?= 1
MAX_ROUNDS ?= 30
ENV_SERVER_URL ?= http://127.0.0.1:$(SEARCHQA_PORT)

# DATA / PATHS ---------------------------------------------------------------
SEARCHQA_DIR := AgentGym/agentenv-searchqa
MERGER_SCRIPT := AgentGym-RL/scripts/model_merger.py
GEN_SCRIPT := verl.agent_trainer.main_generation

.PHONY: help agentenv-searchqa-bootstrap agentenv-searchqa-setup \
        agentenv-searchqa-lock agentenv-searchqa-server agentenv-searchqa-merge \
        agentenv-searchqa-eval agentenv-searchqa-clean

help:
	@echo "Available targets:"
	@echo "  agentenv-searchqa-bootstrap  - Install uv if missing"
	@echo "  agentenv-searchqa-setup      - Create virtual env & install deps for SearchQA"
	@echo "  agentenv-searchqa-lock       - Recreate lockfile (uv) from pyproject"
	@echo "  agentenv-searchqa-server     - Launch SearchQA FastAPI server via uvicorn"
	@echo "  agentenv-searchqa-merge      - Merge model shards into $(MODEL_PATH)"
	@echo "  agentenv-searchqa-eval       - Run generation/eval against running server"
	@echo "  agentenv-searchqa-clean      - Remove .uv and build artifacts"

# Install uv locally if not present
agentenv-searchqa-bootstrap:
	@if ! command -v uv >/dev/null 2>&1; then \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	else \
		echo "uv already installed"; \
	fi

# Create environment & install (editable) packages
agentenv-searchqa-setup: agentenv-searchqa-bootstrap
	@echo "[SETUP] Installing base dependencies with uv"
	$(UV) venv .uv
	$(UV) pip install -e AgentGym/agentenv
	$(UV) pip install -e $(SEARCHQA_DIR)
	@if [ -f $(SEARCHQA_DIR)/requirements.txt ]; then $(UV) pip install -r $(SEARCHQA_DIR)/requirements.txt; fi
	@if [ -f $(SEARCHQA_DIR)/environment.yml ]; then echo 'NOTE: environment.yml ignored (conda format).'; fi
	@echo "[SETUP] Running setup.sh if present"
	@if [ -f $(SEARCHQA_DIR)/setup.sh ]; then bash $(SEARCHQA_DIR)/setup.sh; fi
	@echo "[SETUP] Done"

# Re-lock (optional) when pyproject updated
agentenv-searchqa-lock:
	$(UV) lock --project $(SEARCHQA_DIR)

# Launch FastAPI server
agentenv-searchqa-server:
	@echo "[SERVER] Starting SearchQA server on $(SEARCHQA_HOST):$(SEARCHQA_PORT)"
	$(UV) run --python $(PYTHON) $(SEARCHQA_DIR)/agentenv_searchqa/launch.py --host $(SEARCHQA_HOST) --port $(SEARCHQA_PORT) --workers $(SEARCHQA_WORKERS)

# Merge model shards (expects MERGE_CKPT set to directory containing pieces)
agentenv-searchqa-merge:
	@echo "[MERGE] Merging model shards in $(MERGE_CKPT) -> $(MODEL_PATH)"
	$(UV) run --python $(PYTHON) $(MERGER_SCRIPT) --local_dir $(MERGE_CKPT)

# Run evaluation (requires server already running)
agentenv-searchqa-eval:
	@echo "[EVAL] Running SearchQA evaluation episodes=$(EVAL_EPISODES) rounds=$(MAX_ROUNDS)"
	HYDRA_FULL_ERROR=1 $(UV) run --python $(PYTHON) -m $(GEN_SCRIPT) \
		data.path=AgentEval/searchqa \
		data.max_prompt_length=750 \
		data.max_response_length=14098 \
		data.n_samples=$(EVAL_EPISODES) \
		data.batch_size=32 \
		agentgym.task_name=searchqa \
		agentgym.env_addr=$(ENV_SERVER_URL) \
		agentgym.max_rounds=$(MAX_ROUNDS) \
		agentgym.timeout=500 \
		model.path=$(MODEL_PATH) \
		rollout.gpu_memory_utilization=0.95 \
		rollout.temperature=1 \
		rollout.max_model_len=32768 \
		rollout.max_tokens=512 \
		rollout.tensor_model_parallel_size=1 \
		rollout.rollout_log_dir=executer_logs

agentenv-searchqa-clean:
	@echo "[CLEAN] Removing .uv virtual environment and executer logs"
	rm -rf .uv executer_logs
	@echo "[CLEAN] Done"
