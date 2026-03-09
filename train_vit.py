import tensorflow as tf
from tensorflow.keras import layers, models
import pandas as pd
import numpy as np

# Landmark-Transformer (ViT adaptation for vectors)
NUM_LANDMARKS = 478
CHANNELS = 3 
INPUT_DIM = NUM_LANDMARKS * CHANNELS
PROJECTION_DIM = 128
NUM_HEADS = 8
TRANSFORMER_LAYERS = 3

def create_landmark_transformer():
    inputs = layers.Input(shape=(INPUT_DIM,))
    
    # Treat landmark vector as a set of tokens
    x = layers.Reshape((NUM_LANDMARKS, CHANNELS))(inputs)
    x = layers.Dense(PROJECTION_DIM)(x)
    
    # Transformer Encoder blocks
    for _ in range(TRANSFORMER_LAYERS):
        # Multi-head attention
        x1 = layers.LayerNormalization(epsilon=1e-6)(x)
        attention_output = layers.MultiHeadAttention(num_heads=NUM_HEADS, key_dim=PROJECTION_DIM)(x1, x1)
        x2 = layers.Add()([attention_output, x])
        
        # MLP
        x3 = layers.LayerNormalization(epsilon=1e-6)(x2)
        x4 = layers.Dense(PROJECTION_DIM * 2, activation="gelu")(x3)
        x4 = layers.Dense(PROJECTION_DIM)(x4)
        x = layers.Add()([x4, x2])

    representation = layers.LayerNormalization(epsilon=1e-6)(x)
    representation = layers.GlobalAveragePooling1D()(representation)
    logits = layers.Dense(1, activation="sigmoid")(representation)

    return models.Model(inputs=inputs, outputs=logits)

if __name__ == "__main__":
    model = create_landmark_transformer()
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])
    print("Landmark Transformer (ViT adaptation) Created.")
