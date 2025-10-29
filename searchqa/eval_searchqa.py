"""
SearchQA Evaluation Script
Based on AgentGym framework for evaluating agents on SearchQA tasks
"""

import json
import time
import os
from dataclasses import dataclass, field

import jsonlines
import transformers
from tqdm import tqdm

from agentenv.controller import APIAgent, Evaluator
from agentenv.envs import SearchQATask


@dataclass
class EvalArguments:
    api_key: str = field(default_factory=lambda: os.getenv("OPENAI_API_KEY", ""))
    base_url: str = field(default_factory=lambda: os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"))
    model: str = field(default="gpt-4")
    inference_file: str = field(metadata={"help": "Test dataset JSON file"})
    output_dir: str = field(default="./eval_results_searchqa")
    max_tokens: int = field(default=4096)
    temperature: float = field(default=0.7)
    top_p: float = field(default=1)
    task_name: str = field(default="searchqa")

    # conversation rounds
    max_round: int = field(
        default=10,
        metadata={"help": "Interaction rounds between agents and environment"},
    )

    # environment parameters
    env_server_base: str = field(default="http://localhost:36001")
    data_len: int = field(default=100)
    timeout: int = field(default=2400)


def main(args):

    DATA_PATH = args["inference_file"]

    # set environment parameters
    env_args = {
        "env_server_base": args["env_server_base"],
        "data_len": args["data_len"],
        "timeout": args["timeout"],
    }

    # set env client
    evaluator = Evaluator(
        APIAgent(
            api_key=args["api_key"],
            base_url=args["base_url"],
            model=args["model"],
            max_tokens=args["max_tokens"],
            temperature=args["temperature"],
            top_p=args["top_p"],
        ),
        [SearchQATask(client_args=env_args, n_clients=1)],
    )

    with open(DATA_PATH, "r") as file:
        test_data = json.load(file)

    data_idxs = [int(item["item_id"].split("_")[-1]) for item in test_data]

    total_score = 0.0
    total_success = 0.0
    start_time = time.time()
    os.makedirs(args["output_dir"], exist_ok=True)

    for data_idx in tqdm(data_idxs, total=len(data_idxs), desc="[Evaluation Loop]"):
        # Check if already evaluated
        output_file = os.path.join(args["output_dir"], f"{args['task_name']}_{data_idx}.json")
        try:
            with open(output_file, 'r') as f:
                item = json.load(f)
                total_score += item["reward"]
                total_success += item["success"]
            print(f"Skipping {data_idx} (already evaluated)")
            continue
        except:
            pass

        # Run evaluation
        while True:
            try:
                exps = evaluator.eval(
                    max_rounds=args["max_round"],
                    idxs=[data_idx],
                )
                break
            except Exception as e:
                print(f"Error evaluating {data_idx}: {e}")
                print("Retrying...")
                continue

        total_score += exps.score
        total_success += exps.success

        cur_experiences = exps.experiences
        # write inference results to file
        with open(output_file, 'w') as f:
            for exp in cur_experiences:
                conversation = exp.conversation
                cur_reward = exp.reward
                cur_success = 1 if exp.reward == 1 else 0
                item_id = f"{args['task_name']}_{data_idx}"
                json.dump({
                    "conversations": conversation,
                    "item_id": item_id,
                    "reward": cur_reward,
                    "success": cur_success,
                }, f, ensure_ascii=False, indent=4)

        # Print progress
        avg_score = total_score / (data_idxs.index(data_idx) + 1)
        avg_success = total_success / (data_idxs.index(data_idx) + 1)
        print(f"\nProgress: {data_idxs.index(data_idx) + 1}/{len(data_idxs)}")
        print(f"Current Avg Score: {avg_score:.4f}")
        print(f"Current Avg Success: {avg_success:.4f}\n")

    process_time = time.time() - start_time

    Score = total_score / len(data_idxs)
    Success = total_success / len(data_idxs)
    print("\n\n==== EVALUATION ====\n")
    print(f"Score: {Score}")
    print(f"Success: {Success}")
    print(f"Time: {process_time} seconds")
    print(f"Results saved to: {args['output_dir']}")


if __name__ == "__main__":
    parser = transformers.HfArgumentParser(EvalArguments)
    (args,) = parser.parse_args_into_dataclasses()
    args = vars(args)
    print(json.dumps(args, indent=2, ensure_ascii=False))
    main(args)
