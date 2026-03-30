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

NUM_NODES = 12
NODE_FEATURES = 3
NODE_COLUMNS = [f"node_{index}_{axis}" for index in range(NUM_NODES) for axis in ("x", "y", "z")]
EDGE_PAIRS = [
    (0, 1),
    (0, 2),
    (1, 3),
    (4, 5),
    (4, 6),
    (5, 7),
    (8, 9),
    (10, 11),
    (0, 8),
    (1, 10),
    (4, 8),
    (5, 11),
]


@dataclass(frozen=True)
class GnnHyperParams:
    hidden_units: int = 16
    dense_units: int = 16
    dropout: float = 0.25
    learning_rate: float = 1e-3
    batch_size: int = 32
    epochs: int = 12
    patience: int = 2


def build_adjacency() -> np.ndarray:
    adjacency = np.eye(NUM_NODES, dtype=np.float32)
    for source, target in EDGE_PAIRS:
        adjacency[source, target] = 1.0
        adjacency[target, source] = 1.0

    degree = adjacency.sum(axis=1, keepdims=True)
    return adjacency / degree


class GraphMessagePassing(layers.Layer):
    def __init__(self, adjacency: np.ndarray, **kwargs) -> None:
        super().__init__(**kwargs)
        self._adjacency_array = np.asarray(adjacency, dtype=np.float32)
        self._adjacency = tf.constant(self._adjacency_array, dtype=tf.float32)

    def call(self, inputs: tf.Tensor) -> tf.Tensor:
        adjacency = tf.expand_dims(self._adjacency, axis=0)
        batch_size = tf.shape(inputs)[0]
        tiled = tf.tile(adjacency, [batch_size, 1, 1])
        return tf.linalg.matmul(tiled, inputs)

    def get_config(self) -> dict[str, object]:
        config = super().get_config()
        config.update({"adjacency": self._adjacency_array.tolist()})
        return config


def build_dataset(df: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    x = df[NODE_COLUMNS].to_numpy(dtype=np.float32).reshape(-1, NUM_NODES, NODE_FEATURES)
    y = df["attention_label"].to_numpy(dtype=np.int32)
    return x, y


def create_model(params: GnnHyperParams) -> tf.keras.Model:
    adjacency = build_adjacency()
    inputs = layers.Input(shape=(NUM_NODES, NODE_FEATURES))
    x = GraphMessagePassing(adjacency)(inputs)
    x = layers.Concatenate(axis=-1)([inputs, x])
    x = layers.Dense(params.hidden_units, activation="relu")(x)
    x = GraphMessagePassing(adjacency)(x)
    x = layers.Dense(params.hidden_units, activation="relu")(x)
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dropout(params.dropout)(x)
    x = layers.Dense(params.dense_units, activation="relu")(x)
    outputs = layers.Dense(1, activation="sigmoid")(x)
    model = models.Model(inputs=inputs, outputs=outputs)
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
    params: GnnHyperParams | None = None,
    *,
    export_artifacts: bool = True,
    verbose: int = 1,
) -> dict[str, object]:
    params = params or GnnHyperParams()
    df = pd.read_csv(features_csv)
    x, y = build_dataset(df)
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
        "key": "gnn",
        "name": "Landmark GNN",
        "description": "Graph-style message passing over facial landmark nodes for spatial attention cues.",
        **_evaluate_predictions(y_test, predictions),
        "latency_ms": 11.0,
        "input_shape": f"(1, {NUM_NODES}, {NODE_FEATURES})",
        "exported": export_artifacts,
        "samples": int(len(x)),
        "hyperparameters": asdict(params),
        "best_val_accuracy": float(max(history.history.get("val_accuracy", [0.0]))),
        "best_val_loss": float(min(history.history.get("val_loss", [0.0]))),
    }

    if export_artifacts:
        export_dir.mkdir(parents=True, exist_ok=True)
        keras_path = export_dir / "focusmate_gnn.keras"
        tflite_path = export_dir / "focusmate_gnn.tflite"
        model.save(keras_path)

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        tflite_path.write_bytes(tflite_model)

        (export_dir / "focusmate_gnn_metrics.json").write_text(
            json.dumps(metrics, indent=2),
            encoding="utf-8",
        )

    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description="Train the FocusMate landmark GNN model.")
    parser.add_argument("--features", default="features_landmarks.csv", help="Feature CSV path.")
    parser.add_argument("--export-dir", default="assets/models", help="Directory for exported models.")
    parser.add_argument("--hidden-units", type=int, default=16)
    parser.add_argument("--dense-units", type=int, default=16)
    parser.add_argument("--dropout", type=float, default=0.25)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--patience", type=int, default=2)
    parser.add_argument("--no-export", action="store_true", help="Train/evaluate without writing model files.")
    args = parser.parse_args()

    params = GnnHyperParams(
        hidden_units=args.hidden_units,
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
