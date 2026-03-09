import tensorflow as tf
from tensorflow.keras import layers, models
import pandas as pd
import numpy as np

# Landmark GNN Configuration (Landmarks only, no pixels!)
NUM_LANDMARKS = 478 # MediaPipe Face Mesh
CHANNELS = 3 # X, Y, Z coordinates

def create_gnn_classifier():
    # Input is (Batch, Landmarks, XYZ)
    inputs = layers.Input(shape=(NUM_LANDMARKS, CHANNELS))
    
    # Graph Convolution Proxy: Dense layers applied per landmark (Point-wise)
    # This simulates a GNN layer where each node (landmark) updates its state
    x = layers.Dense(32, activation='relu')(inputs)
    x = layers.BatchNormalization()(x)
    
    # Global pooling over landmarks to get a face-wide embedding (Graph Pooling)
    x = layers.GlobalAveragePooling1D()(x)
    
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.4)(x)
    logits = layers.Dense(1, activation='sigmoid')(x)
    
    model = models.Model(inputs=inputs, outputs=logits)
    return model

if __name__ == "__main__":
    model = create_gnn_classifier()
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])
    print("Landmark-based GNN Model Created (Face Mesh Graph).")
