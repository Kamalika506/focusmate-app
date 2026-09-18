# FocusMate

FocusMate is a Flutter app for studying with YouTube while monitoring user attention from the front camera. It uses a privacy-first landmark pipeline: facial landmarks are processed on-device, then either a `CNN+LSTM` or a `Landmark GNN` predicts distraction in real time.

## What the app does

- Plays YouTube videos inside a guided study session
- Watches facial landmarks from the camera on-device
- Lets the user choose `CNN` before or during a demo
- Detects distraction and drowsiness cues
- Intervenes by dimming, pausing, and suggesting breaks
- Stores settings and session history locally with Hive

## Model pipeline

1. `extract_features.py`
   Extracts landmark-based features and normalized node coordinates from the dataset.
2. `train_cnn.py`
   Trains and exports the temporal `CNN` model to `assets/models/focusmate_cnn_lstm.tflite`.
3. `train_attention_models.py`
   Runs the full pipeline and writes `assets/model_metrics.json` for the in-app Model Lab screen.


## Generated artifacts

- `features_landmarks.csv`
- `assets/models/focusmate_cnn.tflite`
- `assets/model_metrics.json`

## Run the app

1. `flutter pub get`
2. `flutter run --dart-define=YOUTUBE_API_KEY=YOUR_KEY`

## Train the models again

Use the repo Python environment that already has TensorFlow and MediaPipe:

```powershell
.\venv310\Scripts\python.exe train_attention_models.py
```

## Notes

- No Firebase is required.
- All study-session data is local-first.
- If the TFLite models are missing, the app falls back to landmark heuristics so the demo still runs.
- Hyperparameter tuning artifacts can be used for viva discussion, but the deployed config should be the one that stays stable across reruns.
