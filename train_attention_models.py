from __future__ import annotations

import argparse
import json
from pathlib import Path

from extract_features import extract_features
from train_gnn import GnnHyperParams
from train_gnn import train_model as train_gnn_model
from train_lstm import LstmHyperParams
from train_lstm import train_model as train_lstm_model


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the full FocusMate training and export pipeline.")
    parser.add_argument("--dataset", default="dataset", help="Dataset directory.")
    parser.add_argument("--model-task", default="face_landmarker.task", help="MediaPipe face landmarker task file.")
    parser.add_argument("--features", default="features_landmarks.csv", help="Feature CSV output path.")
    parser.add_argument("--export-dir", default="assets/models", help="Directory for exported model files.")
    parser.add_argument("--metrics-output", default="assets/model_metrics.json", help="Metrics JSON path.")
    parser.add_argument("--lstm-epochs", type=int, default=None)
    parser.add_argument("--gnn-epochs", type=int, default=None)
    args = parser.parse_args()

    dataset_dir = Path(args.dataset)
    model_task = Path(args.model_task)
    features_path = Path(args.features)
    export_dir = Path(args.export_dir)
    metrics_output = Path(args.metrics_output)

    df = extract_features(dataset_dir, model_task, features_path)
    if df.empty:
        raise RuntimeError("No features were extracted. Check dataset images and face landmarker setup.")

    lstm_params = LstmHyperParams() if args.lstm_epochs is None else LstmHyperParams(epochs=args.lstm_epochs)
    gnn_params = GnnHyperParams() if args.gnn_epochs is None else GnnHyperParams(epochs=args.gnn_epochs)

    lstm_metrics = train_lstm_model(features_path, export_dir, lstm_params)
    gnn_metrics = train_gnn_model(features_path, export_dir, gnn_params)

    metrics_payload = {
        "dataset": {
            "frames": int(len(df)),
            "sequences": int(df["sequence_id"].nunique()),
            "labels": {
                "engaged": int((df["attention_label"] == 0).sum()),
                "distracted": int((df["attention_label"] == 1).sum()),
            },
        },
        "models": [lstm_metrics, gnn_metrics],
    }

    metrics_output.parent.mkdir(parents=True, exist_ok=True)
    metrics_output.write_text(json.dumps(metrics_payload, indent=2), encoding="utf-8")
    print(json.dumps(metrics_payload, indent=2))


if __name__ == "__main__":
    main()
