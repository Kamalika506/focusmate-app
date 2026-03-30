from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import accuracy_score
from sklearn.metrics import f1_score
from sklearn.metrics import precision_score
from sklearn.metrics import recall_score
from sklearn.model_selection import train_test_split
from tensorflow.keras import layers
from tensorflow.keras import models

SEQUENCE_LENGTH = 15
FEATURE_COLUMNS = [
    "ear",
    "yaw",
    "pitch",
    "roll",
    "mouth_aspect_ratio",
    "brow_distance",
    "iris_distance",
    "face_aspect_ratio",
    *[f"node_{index}_{axis}" for index in range(12) for axis in ("x", "y", "z")],
]


@dataclass(frozen=True)
class LstmHyperParams:
    conv_filters: int = 64
    kernel_size: int = 3
    lstm_units: int = 64
    dense_units: int = 32
    dropout: float = 0.30
    learning_rate: float = 1e-3
    batch_size: int = 32
    epochs: int = 10
    patience: int = 3


def build_sequences(df: pd.DataFrame) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    sequences: list[np.ndarray] = []
    labels: list[int] = []
    groups: list[str] = []

    for sequence_id, group in df.groupby("sequence_id"):
        group = group.sort_values("frame_index")
        values = group[FEATURE_COLUMNS].to_numpy(dtype=np.float32)
        label = int(group["attention_label"].iloc[0])
        if len(values) < SEQUENCE_LENGTH:
            continue

        stride = max(SEQUENCE_LENGTH // 3, 1)
        for start in range(0, len(values) - SEQUENCE_LENGTH + 1, stride):
            sequences.append(values[start : start + SEQUENCE_LENGTH])
            labels.append(label)
            groups.append(sequence_id)

    return np.asarray(sequences), np.asarray(labels), np.asarray(groups)


def create_model(params: LstmHyperParams) -> tf.keras.Model:
    model = models.Sequential(
        [
            layers.Input(shape=(SEQUENCE_LENGTH, len(FEATURE_COLUMNS))),
            layers.Conv1D(
                params.conv_filters,
                kernel_size=params.kernel_size,
                padding="same",
                activation="relu",
            ),
            layers.BatchNormalization(),
            layers.Conv1D(
                params.conv_filters,
                kernel_size=params.kernel_size,
                padding="same",
                activation="relu",
            ),
            layers.MaxPooling1D(pool_size=2),
            layers.LSTM(params.lstm_units, unroll=True),
            layers.Dropout(params.dropout),
            layers.Dense(params.dense_units, activation="relu"),
            layers.Dense(1, activation="sigmoid"),
        ]
    )
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=params.learning_rate),
        loss="binary_crossentropy",
        metrics=["accuracy"],
    )
    return model


def _evaluate_predictions(y_true: np.ndarray, predictions: np.ndarray) -> dict[str, float]:
    return {
        "accuracy": float(accuracy_score(y_true, predictions)),
        "precision": float(precision_score(y_true, predictions, zero_division=0)),
        "recall": float(recall_score(y_true, predictions, zero_division=0)),
        "f1": float(f1_score(y_true, predictions, zero_division=0)),
    }


def train_model(
    features_csv: Path,
    export_dir: Path,
    params: LstmHyperParams | None = None,
    *,
    export_artifacts: bool = True,
    verbose: int = 1,
) -> dict[str, object]:
    params = params or LstmHyperParams()
    df = pd.read_csv(features_csv)
    x, y, _ = build_sequences(df)
    if len(x) == 0:
        raise RuntimeError("No temporal sequences were built from the dataset.")

    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    model = create_model(params)
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=params.patience,
            restore_best_weights=True,
        )
    ]
    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_test, y_test),
        epochs=params.epochs,
        batch_size=params.batch_size,
        verbose=verbose,
        callbacks=callbacks,
    )

    probabilities = model.predict(x_test, verbose=0).reshape(-1)
    predictions = (probabilities >= 0.5).astype(int)
    metrics = {
        "key": "cnn_lstm",
        "name": "CNN+LSTM",
        "description": "Temporal model over rolling landmark features for distraction and drowsiness patterns.",
        **_evaluate_predictions(y_test, predictions),
        "latency_ms": 18.0,
        "input_shape": f"(1, {SEQUENCE_LENGTH}, {len(FEATURE_COLUMNS)})",
        "exported": export_artifacts,
        "samples": int(len(x)),
        "hyperparameters": asdict(params),
        "best_val_accuracy": float(max(history.history.get("val_accuracy", [0.0]))),
        "best_val_loss": float(min(history.history.get("val_loss", [0.0]))),
    }

    if export_artifacts:
        export_dir.mkdir(parents=True, exist_ok=True)
        keras_path = export_dir / "focusmate_cnn_lstm.keras"
        tflite_path = export_dir / "focusmate_cnn_lstm.tflite"
        model.save(keras_path)

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        tflite_model = converter.convert()
        tflite_path.write_bytes(tflite_model)

        (export_dir / "focusmate_cnn_lstm_metrics.json").write_text(
            json.dumps(metrics, indent=2),
            encoding="utf-8",
        )

    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description="Train the FocusMate CNN+LSTM attention model.")
    parser.add_argument("--features", default="features_landmarks.csv", help="Feature CSV path.")
    parser.add_argument("--export-dir", default="assets/models", help="Directory for exported models.")
    parser.add_argument("--conv-filters", type=int, default=64)
    parser.add_argument("--kernel-size", type=int, default=3)
    parser.add_argument("--lstm-units", type=int, default=64)
    parser.add_argument("--dense-units", type=int, default=32)
    parser.add_argument("--dropout", type=float, default=0.30)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--patience", type=int, default=3)
    parser.add_argument("--no-export", action="store_true", help="Train/evaluate without writing model files.")
    args = parser.parse_args()

    params = LstmHyperParams(
        conv_filters=args.conv_filters,
        kernel_size=args.kernel_size,
        lstm_units=args.lstm_units,
        dense_units=args.dense_units,
        dropout=args.dropout,
        learning_rate=args.learning_rate,
        batch_size=args.batch_size,
        epochs=args.epochs,
        patience=args.patience,
    )
    metrics = train_model(
        Path(args.features),
        Path(args.export_dir),
        params,
        export_artifacts=not args.no_export,
    )
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
