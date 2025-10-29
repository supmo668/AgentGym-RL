# AgentGym-RL

AgentGym-RL is a framework for evaluating and training reinforcement learning agents in various environments.

## Quick Start

### Prerequisites

- Docker and Docker Compose (for containerized setup)
- Conda (for local setup)
- Python 3.10+
- OpenAI API key

### Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd AgentGym-RL
   ```

2. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env and add your OPENAI_API_KEY
   ```

## Usage

### Using Docker (Recommended)

#### Start SearchQA Environment Server

```bash
# Start the SearchQA environment server
make docker-up

# Check logs
make docker-logs

# Stop services
make docker-down
```

#### Run Evaluation

```bash
# Run evaluation with Docker
docker compose --profile eval up

# Or with custom parameters
INFERENCE_FILE=searchqa_eval_sample.json MODEL_NAME=gpt-4o-mini make docker-up
```

### Using Local Setup

#### Install Dependencies

```bash
# Install core agentenv package
make install

# Setup SearchQA environment
make setup-searchqa
```

#### Start SearchQA Server

```bash
# Start the environment server
make start-searchqa
```

In another terminal:

```bash
# Run evaluation
make eval-searchqa INFERENCE_FILE=searchqa/searchqa_eval_sample.json
```

#### Advanced Usage

```bash
# Custom evaluation with parameters
make eval-searchqa \
  INFERENCE_FILE=path/to/test.json \
  MODEL=gpt-4o-mini \
  MAX_ROUND=15 \
  OUTPUT_DIR=./custom_results
```

## Makefile Targets

- `make help` - Show all available commands
- `make install` - Install agentenv core package
- `make setup-searchqa` - Setup SearchQA environment
- `make start-searchqa` - Start SearchQA server locally
- `make stop-searchqa` - Stop SearchQA server
- `make eval-searchqa` - Run SearchQA evaluation
- `make docker-up` - Start Docker services
- `make docker-down` - Stop Docker services
- `make docker-logs` - View Docker logs
- `make clean` - Clean up generated files

## Project Structure

```
AgentGym-RL/
├── AgentGym/                    # Core AgentGym framework
│   ├── agentenv/                # Core environment package
│   ├── agentenv-searchqa/       # SearchQA environment
│   └── ...                      # Other environments
├── searchqa/                    # SearchQA evaluation scripts
│   ├── eval_searchqa.py         # Main evaluation script
│   ├── searchqa_eval_sample.json # Sample test data
│   └── README.md                # SearchQA documentation
├── docker-compose.yml           # Docker Compose configuration
├── Dockerfile.eval              # Evaluation container
├── Makefile                     # Build and run commands
└── .env.example                 # Environment variables template
```

## Environment Configuration

Key environment variables (see `.env.example`):

- `OPENAI_API_KEY` - Your OpenAI API key (required)
- `OPENAI_BASE_URL` - OpenAI API endpoint
- `MODEL_NAME` - Model to use for evaluation (default: gpt-4o-mini)
- `MAX_ROUND` - Maximum interaction rounds (default: 10)
- `ENV_SERVER_BASE` - Environment server URL

## SearchQA Environment

SearchQA is a question-answering environment that tests agents' ability to:
- Search for information
- Retrieve relevant context
- Answer questions accurately

### Dataset Ranges

| Item ID Range   | Dataset             | Split |
|-----------------|---------------------|-------|
| 0 - 3609        | nq                  | Test  |
| 3610 - 14922    | triviaqa            | Test  |
| 14923 - 29189   | popqa               | Test  |
| 29190 - 36594   | hotpotqa            | Test  |
| 36595 - 49170   | 2wikimultihopqa     | Test  |
| 49171 - 51587   | musique             | Test  |
| 51588 - 51712   | bamboogle           | Test  |
| 51713 - 130880  | nq                  | Train |
| 130881 - 221328 | hotpotqa            | Train |

## Troubleshooting

### SearchQA Server Issues

If the server fails to start:
1. Check if port 36001 is available
2. Verify environment variables are set correctly
3. Check Docker logs: `make docker-logs`

### Evaluation Issues

If evaluation fails:
1. Ensure SearchQA server is running
2. Verify OPENAI_API_KEY is set
3. Check inference file path is correct

## Development

### Adding New Environments

1. Create environment package in `AgentGym/agentenv-<name>/`
2. Add Dockerfile for the environment
3. Update `docker-compose.yml` with new service
4. Add Makefile targets for setup and evaluation

### Running Tests

```bash
# Run tests for specific environment
cd AgentGym/agentenv-searchqa
pytest
```

## License

See LICENSE file for details.
