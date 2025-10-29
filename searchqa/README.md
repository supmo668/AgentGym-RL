# SearchQA Evaluation Setup Guide

This guide documents the setup and evaluation process for SearchQA using the AgentGym framework.

## Setup Summary

### 1. Environment Setup ✓

Created a Python 3.10 virtual environment using `uv` with all dependencies:

```bash
cd AgentGym/agentenv-searchqa
uv venv --python 3.10
source .venv/bin/activate
```

### Installed Packages:
- PyTorch 2.9.0 (macOS version)
- faiss-cpu (for vector similarity search)
- transformers, datasets
- pyserini (information retrieval)
- FastAPI + uvicorn (for server)
- agentenv-searchqa package
- agentenv core package

### 2. Data Download (In Progress)

Running `setup.sh` which downloads:
- **FAISS indices**: `part_aa`, `part_ab` → merged to `e5_Flat.index`
- **Wikipedia corpus**: `wiki-18.jsonl.gz` → decompressed to `wiki-18.jsonl`
- **E5 model**: `intfloat/e5-base-v2` for embedding generation
- **QA datasets**: Multiple QA benchmarks (NQ, TriviaQA, HotpotQA, etc.)

**Current Status**: Downloading (~3.4GB so far)

### 3. Evaluation Files Created ✓

#### eval_searchqa.py
Main evaluation script supporting:
- API-based agents (OpenAI, compatible APIs)
- SearchQA task evaluation through AgentGym framework
- Automatic result caching
- Progress tracking

#### searchqa_eval_sample.json
Sample evaluation dataset with 3 test items:
- searchqa_0 (NQ dataset)
- searchqa_1 (NQ dataset)
- searchqa_2 (NQ dataset)

## SearchQA Environment Details

### Dataset Ranges

**Test Split** (0-51,713):
- NQ: 0-3,609
- TriviaQA: 3,610-14,922
- PopQA: 14,923-29,189
- HotpotQA: 29,190-36,594
- 2WikiMultihopQA: 36,595-49,170
- Musique: 49,171-51,587
- Bamboogle: 51,588-51,712

**Train Split** (51,713-221,328):
- NQ: 51,713-130,880
- HotpotQA: 130,881-221,328

### Environment Interaction Format

The agent interacts with SearchQA using XML-style tags:

1. **Think**: `<think>reasoning process</think>`
2. **Search**: `<search>query</search>` - retrieves relevant documents
3. **Information**: `<information>retrieved docs</information>` - returned by environment
4. **Answer**: `<answer>final answer</answer>` - submit final answer

## Usage Instructions

### Step 1: Wait for Data Download to Complete

Monitor progress:
```bash
cd AgentGym/agentenv-searchqa
du -sh retrieve_data/
```

Once complete, you should see:
- `retrieve_data/e5_Flat.index` (~3-4GB FAISS index)
- `retrieve_data/wiki-18.jsonl` (Wikipedia corpus)
- `retrieve_data/e5-base-v2/` (embedding model)
- `agentenv_searchqa/queries/train.parquet`
- `agentenv_searchqa/queries/test.parquet`

### Step 2: Launch SearchQA Server

```bash
source .venv/bin/activate
searchqa --host 0.0.0.0 --port 36001
```

The server provides HTTP APIs:
- `/create` - create environment
- `/observation` - get current observation
- `/step` - perform action
- `/reset` - reset environment
- `/close` - close environment

### Step 3: Run Evaluation

Set up your API credentials:
```bash
export OPENAI_API_KEY="your-api-key"
export OPENAI_BASE_URL="https://api.openai.com/v1"  # or your endpoint
```

Run evaluation:
```bash
source .venv/bin/activate

python eval_searchqa.py \
    --model gpt-4 \
    --inference_file searchqa_eval_sample.json \
    --output_dir ./eval_results_searchqa \
    --max_round 10 \
    --env_server_base http://localhost:36001 \
    --data_len 100
```

### Step 4: View Results

Results are saved to `eval_results_searchqa/`:
- Individual files: `searchqa_{id}.json`
- Each contains: conversations, reward, success

Final metrics printed:
- Score: Average reward (0-1)
- Success: Success rate
- Time: Evaluation duration

## Environment Variables

Optional configurations for SearchQA server:

```bash
export SEARCHQA_FAISS_GPU=False              # Use GPU for FAISS (default: False)
export SEARCHQA_RETRIEVAL_METHOD=e5          # Retrieval method
export SEARCHQA_RETRIEVAL_TOPK=3             # Top-k documents
export SEARCHQA_RETRIEVAL_USE_FP16=True      # Use FP16 for model
export SEARCHQA_RETRIEVAL_BATCH_SIZE=512     # Batch size
```

## Files Created

```
AgentGym-RL/
├── eval_searchqa.py                    # Evaluation script
├── searchqa_eval_sample.json           # Sample eval dataset
├── SEARCHQA_EVAL_README.md            # This file
└── AgentGym/
    └── agentenv-searchqa/
        ├── .venv/                     # Python environment
        ├── retrieve_data/             # Downloaded data
        │   ├── e5_Flat.index
        │   ├── wiki-18.jsonl
        │   └── e5-base-v2/
        └── agentenv_searchqa/
            └── queries/
                ├── train.parquet
                └── test.parquet
```

## Troubleshooting

### Server won't start
- Check data files are downloaded: `ls retrieve_data/`
- Check query files exist: `ls agentenv_searchqa/queries/`
- Verify port 36001 is available: `lsof -i :36001`

### Evaluation fails
- Ensure server is running: `curl http://localhost:36001`
- Check API credentials are set
- Verify inference file format matches sample

### Memory issues
- SearchQA loads large indices into memory
- Reduce `SEARCHQA_RETRIEVAL_BATCH_SIZE`
- Use `SEARCHQA_RETRIEVAL_USE_FP16=True`

## Next Steps

1. ✓ Environment setup complete
2. ⏳ Waiting for data download
3. ⏹ Launch SearchQA server
4. ⏹ Run evaluation
5. ⏹ Analyze results

## References

- [AgentGym Paper](https://arxiv.org/abs/2406.04151)
- [AgentGym GitHub](https://github.com/WooooDyy/AgentGym)
- [E5 Model](https://huggingface.co/intfloat/e5-base-v2)
