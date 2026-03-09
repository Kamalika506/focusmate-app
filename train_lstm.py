import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split

# Configuration
SEQ_LEN = 15  # 5 seconds at 3fps
FEATURE_COLS = ['ear', 'pitch', 'yaw', 'roll']

def load_data():
    df = pd.read_csv('features_landmarks.csv')
    X, y = [], []
    
    # Group by sub-folder to keep temporal sequences intact
    for folder, group in df.groupby('sub_folder'):
        if len(group) < SEQ_LEN: continue
        
        # Take sequences with overlap
        features = group[FEATURE_COLS].values
        label = group['label'].iloc[0]
        
        for i in range(0, len(features) - SEQ_LEN, SEQ_LEN // 2):
            X.append(features[i:i+SEQ_LEN])
            y.append(label)
            
    return np.array(X), np.array(y)

def train_landmark_lstm():
    print("Loading landmark sequences...")
    X, y = load_data()
    print(f"Loaded {len(X)} sequences of shape {X.shape[1:]}")
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    model = models.Sequential([
        # 1D CNN to extract local temporal patterns from EAR/Pose
        layers.Conv1D(64, kernel_size=3, activation='relu', input_shape=(SEQ_LEN, len(FEATURE_COLS))),
        layers.MaxPooling1D(2),
        layers.LSTM(64, return_sequences=False),
        layers.Dropout(0.3),
        layers.Dense(32, activation='relu'),
        layers.Dense(1, activation='sigmoid')
    ])
    
    model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
    model.fit(X_train, y_train, epochs=20, validation_data=(X_test, y_test), batch_size=16)
    
    model.save('landmark_lstm.h5')
    print("Saved landmark-based LSTM model.")

if __name__ == "__main__":
    train_landmark_lstm()
