# FocusMate Model Training Guide

## 1. Problem framing

The project is a binary attention-classification system:

- `0 = engaged`
- `1 = distracted / not engaged`

The phone camera never needs to store raw face images for inference. Instead, the pipeline extracts facial landmarks and derived features, then sends those numerical values into the model.

## 2. Dataset structure

The dataset is organized into:

- `dataset/Engaged/...`
- `dataset/Not_Engaged/...`

Each subfolder is treated as a short sequence. During feature extraction, every image is processed with MediaPipe face landmarker and converted into one row of numerical features.

## 3. Feature extraction

Implemented in [`extract_features.py`](/c:/Users/KamalHp/Downloads/focusmateapp/extract_features.py).

For each frame the script extracts:

- `EAR` for blink / drowsiness signal
- `yaw`, `pitch`, `roll` for head orientation
- `mouth_aspect_ratio`
- `brow_distance`
- `iris_distance`
- `face_aspect_ratio`
- normalized coordinates for 12 selected facial landmarks

These features are written to [`features_landmarks.csv`](/c:/Users/KamalHp/Downloads/focusmateapp/features_landmarks.csv).

## 4. CNN+LSTM model

Implemented in [`train_lstm.py`](/c:/Users/KamalHp/Downloads/focusmateapp/train_lstm.py).

Input:
- rolling sequence of `15` frames
- each frame has `44` features

Architecture:
- `Conv1D`
- `BatchNormalization`
- `Conv1D`
- `MaxPooling1D`
- `LSTM`
- `Dropout`
- `Dense`
- `Sigmoid output`

Why this model:
- `CNN` learns short temporal patterns in the feature stream
- `LSTM` captures attention drift across multiple frames
- good for drowsiness, looking away, and gradual loss of focus

## 5. Landmark GNN model

Implemented in [`train_gnn.py`](/c:/Users/KamalHp/Downloads/focusmateapp/train_gnn.py).

Input:
- `12` landmark nodes
- each node has `x, y, z`

Architecture:
- graph-style message passing using a fixed adjacency matrix
- dense projection on node features
- second message-passing block
- global pooling
- dense classifier

Why this model:
- focuses on spatial relations between facial parts
- lighter than the temporal model
- useful for structural attention cues like head pose and face geometry

## 6. Training and evaluation

Training entry points:

- [`train_lstm.py`](/c:/Users/KamalHp/Downloads/focusmateapp/train_lstm.py)
- [`train_gnn.py`](/c:/Users/KamalHp/Downloads/focusmateapp/train_gnn.py)
- [`train_attention_models.py`](/c:/Users/KamalHp/Downloads/focusmateapp/train_attention_models.py)

Evaluation metrics:

- accuracy
- precision
- recall
- F1-score

Why F1 matters:
- attention datasets can become imbalanced
- F1 balances false positives and false negatives better than accuracy alone

## 7. Hyperparameter tuning

Implemented in [`hyperparameter_tuning.py`](/c:/Users/KamalHp/Downloads/focusmateapp/hyperparameter_tuning.py).

This performs random-search tuning over model hyperparameters.

Important practical note:

- the dataset is still small in terms of distinct sequences
- some hyperparameter combinations can look excellent in one trial but become unstable when retrained
- because of that, the final deployed configuration should be chosen using both `F1-score` and `stability across reruns`
- in this repo, the exported `CNN+LSTM` deployment config is a stable baseline, while the `GNN` export uses the tuned settings that remained strong during reruns

### CNN+LSTM hyperparameters tuned

- `conv_filters`
- `kernel_size`
- `lstm_units`
- `dense_units`
- `dropout`
- `learning_rate`
- `batch_size`
- `epochs`
- `patience`

### GNN hyperparameters tuned

- `hidden_units`
- `dense_units`
- `dropout`
- `learning_rate`
- `batch_size`
- `epochs`
- `patience`

### Example commands

Run full training:

```powershell
.\venv310\Scripts\python.exe train_attention_models.py
```

Tune both models:

```powershell
.\venv310\Scripts\python.exe hyperparameter_tuning.py --model both --trials 4
```

Tune only CNN+LSTM:

```powershell
.\venv310\Scripts\python.exe hyperparameter_tuning.py --model cnn_lstm --trials 6
```

Tune only GNN:

```powershell
.\venv310\Scripts\python.exe hyperparameter_tuning.py --model gnn --trials 6
```

## 8. What to explain to your professor

You should be able to explain:

- why landmarks are used instead of raw images
- why `CNN+LSTM` is temporal and `GNN` is spatial
- what each extracted feature represents
- how training data is labeled
- what hyperparameters were tuned
- why F1-score is important for comparison
- why the app exports models to TFLite for on-device inference

## 9. Mobile deployment

The exported models are:

- [`focusmate_cnn_lstm.tflite`](/c:/Users/KamalHp/Downloads/focusmateapp/assets/models/focusmate_cnn_lstm.tflite)
- [`focusmate_gnn.tflite`](/c:/Users/KamalHp/Downloads/focusmateapp/assets/models/focusmate_gnn.tflite)

The app loads them through:

- [`model_inference_service.dart`](/c:/Users/KamalHp/Downloads/focusmateapp/lib/services/model_inference_service.dart)

The user can switch between them in:

- [`model_lab_screen.dart`](/c:/Users/KamalHp/Downloads/focusmateapp/lib/screens/model_lab_screen.dart)
