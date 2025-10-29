.PHONY: help venv install setup-env start-env stop-env eval-env docker-up docker-down docker-logs docker-rebuild docker-eval clean

# Default target
help:
	@echo "AgentGym-RL Makefile (uv-based)"
	@echo ""
	@echo "Available targets:"
	@echo "  venv              - Create virtual environment with uv"
	@echo "  install           - Install agentenv core package with uv"
	@echo "  setup-env         - Setup environment specified by ENV variable"
	@echo "  start-env         - Start environment server"
	@echo "  stop-env          - Stop environment server"
	@echo "  eval-env          - Run environment evaluation"
	@echo "  docker-up         - Start environment service with Docker"
	@echo "  docker-down       - Stop Docker services"
	@echo "  docker-rebuild    - Rebuild and restart Docker services"
	@echo "  docker-eval       - Run evaluation in Docker"
	@echo "  docker-logs       - View Docker logs"
	@echo "  clean             - Clean up generated files"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENV               - Environment name (default: searchqa)"
	@echo "  MODEL             - Model name (default: gpt-4o-mini)"
	@echo "  ENV_PORT          - Environment server port (default: 36001)"
	@echo "  INFERENCE_FILE    - Test dataset file (default: <ENV>_eval_sample.json)"
	@echo "  OUTPUT_DIR        - Output directory (default: ./<ENV>/eval_results_<ENV>)"

# Create virtual environment
venv:
	@if [ ! -d ".venv" ]; then \
		echo "Creating virtual environment with uv..."; \
		uv venv; \
	else \
		echo "Virtual environment already exists"; \
	fi

# Install core agentenv package with uv
install: venv
	@echo "Installing agentenv core package..."
	uv pip install -e AgentGym/agentenv

# Setup environment with uv (uses ENV variable)
setup-env: install
	@echo "Setting up $(ENV) environment with uv..."
	uv pip install -e AgentGym/agentenv-$(ENV)
	@echo "Running $(ENV) setup script..."
	cd AgentGym/agentenv-$(ENV) && ([ -f setup.sh ] && bash ./setup.sh || true)
	@echo "$(ENV) setup complete!"

# Start environment server
start-env: venv
	@echo "Starting $(ENV) server on http://0.0.0.0:$(ENV_PORT)"
	uv run $(ENV) --host 0.0.0.0 --port $(ENV_PORT)

# Stop environment server
stop-env:
	@pkill -f "$(ENV) --host" || echo "No $(ENV) server running"

# Run environment evaluation
eval-env: venv
	@echo "Running $(ENV) evaluation..."
	@if [ -z "$(OPENAI_API_KEY)" ]; then \
		echo "Error: OPENAI_API_KEY environment variable is required"; \
		exit 1; \
	fi
	cd $(ENV) && uv run python eval_$(ENV).py \
		--inference_file $(INFERENCE_FILE) \
		--output_dir $(OUTPUT_DIR) \
		--model $(MODEL) \
		--max_round $(MAX_ROUND) \
		--api_key $(OPENAI_API_KEY) \
		--base_url $(OPENAI_BASE_URL) \
		--env_server_base http://localhost:$(ENV_PORT)

# Docker Compose targets
docker-up:
	docker compose --profile $(ENV) up -d

docker-down:
	docker compose --profile $(ENV) down

docker-logs:
	docker compose --profile $(ENV) logs -f

docker-rebuild:
	docker compose --profile $(ENV) up -d --build --no-cache

docker-eval:
	docker compose --profile eval up --abort-on-container-exit

# Clean up
clean:
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf $(ENV)/eval_results_$(ENV)

# Environment variables with defaults
ENV ?= searchqa
MODEL ?= gpt-4o-mini
MAX_ROUND ?= 10
ENV_PORT ?= 36001
INFERENCE_FILE ?= $(ENV)_eval_sample.json
OUTPUT_DIR ?= ./$(ENV)/eval_results_$(ENV)
OPENAI_API_KEY ?= $(shell echo $$OPENAI_API_KEY)
OPENAI_BASE_URL ?= https://api.openai.com/v1
