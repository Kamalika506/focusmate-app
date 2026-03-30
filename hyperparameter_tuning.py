from __future__ import annotations

import argparse
import json
import random
from dataclasses import asdict
from pathlib import Path

from train_gnn import GnnHyperParams
from train_gnn import train_model as train_gnn_model
from train_lstm import LstmHyperParams
from train_lstm import train_model as train_lstm_model


LSTM_SEARCH_SPACE = {
    "conv_filters": [32, 64, 96],
    "kernel_size": [3, 5],
    "lstm_units": [32, 64, 96],
    "dense_units": [16, 32, 64],
    "dropout": [0.2, 0.3, 0.4],
    "learning_rate": [1e-3, 5e-4],
    "batch_size": [16, 32],
    "epochs": [8, 10, 12],
    "patience": [2, 3],
}

GNN_SEARCH_SPACE = {
    "hidden_units": [16, 32, 48, 64],
    "dense_units": [16, 24, 32],
    "dropout": [0.15, 0.25, 0.35],
    "learning_rate": [1e-3, 5e-4],
    "batch_size": [32, 64],
    "epochs": [8, 10, 12],
    "patience": [2, 3],
}


def sample_params(space: dict[str, list], trials: int, seed: int) -> list[dict[str, object]]:
    random.seed(seed)
    sampled: list[dict[str, object]] = []
    seen: set[tuple] = set()
    attempts = 0

    while len(sampled) < trials and attempts < trials * 20:
        attempts += 1
        params = {key: random.choice(values) for key, values in space.items()}
        signature = tuple(sorted(params.items()))
        if signature in seen:
            continue
        seen.add(signature)
        sampled.append(params)

    return sampled


def tune_lstm(features_csv: Path, trials: int, seed: int) -> list[dict[str, object]]:
    results = []
    for trial_index, params_dict in enumerate(sample_params(LSTM_SEARCH_SPACE, trials, seed), start=1):
        params = LstmHyperParams(**params_dict)
        metrics = train_lstm_model(
            features_csv,
            Path("assets/models"),
            params,
            export_artifacts=False,
            verbose=0,
        )
        results.append(
            {
                "trial": trial_index,
                "model": "cnn_lstm",
                "score": metrics["f1"],
                "metrics": metrics,
                "hyperparameters": asdict(params),
            }
        )
        print(f"LSTM trial {trial_index}/{trials}: F1={metrics['f1']:.4f}, accuracy={metrics['accuracy']:.4f}")
    return results


def tune_gnn(features_csv: Path, trials: int, seed: int) -> list[dict[str, object]]:
    results = []
    for trial_index, params_dict in enumerate(sample_params(GNN_SEARCH_SPACE, trials, seed), start=1):
        params = GnnHyperParams(**params_dict)
        metrics = train_gnn_model(
            features_csv,
            Path("assets/models"),
            params,
            export_artifacts=False,
            verbose=0,
        )
        results.append(
            {
                "trial": trial_index,
                "model": "gnn",
                "score": metrics["f1"],
                "metrics": metrics,
                "hyperparameters": asdict(params),
            }
        )
        print(f"GNN trial {trial_index}/{trials}: F1={metrics['f1']:.4f}, accuracy={metrics['accuracy']:.4f}")
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description="Run simple random-search hyperparameter tuning for FocusMate models.")
    parser.add_argument("--features", default="features_landmarks.csv", help="Feature CSV path.")
    parser.add_argument("--model", choices=["cnn_lstm", "gnn", "both"], default="both")
    parser.add_argument("--trials", type=int, default=4, help="Number of random-search trials per model.")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output", default="tuning_results.json", help="JSON file to store tuning results.")
    args = parser.parse_args()

    features_csv = Path(args.features)
    all_results: list[dict[str, object]] = []

    if args.model in {"cnn_lstm", "both"}:
        all_results.extend(tune_lstm(features_csv, args.trials, args.seed))
    if args.model in {"gnn", "both"}:
        all_results.extend(tune_gnn(features_csv, args.trials, args.seed + 100))

    all_results.sort(key=lambda item: item["score"], reverse=True)
    payload = {
        "objective": "maximize_f1",
        "trials": len(all_results),
        "results": all_results,
        "best": all_results[0] if all_results else None,
    }

    Path(args.output).write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload["best"], indent=2))


if __name__ == "__main__":
    main()
