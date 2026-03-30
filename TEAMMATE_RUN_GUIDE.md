# FocusMate Run Guide

## 1. Flutter app

Run the app with a YouTube API key:

```powershell
flutter pub get
flutter run --dart-define=YOUTUBE_API_KEY=YOUR_KEY
```

The app does not require Firebase.

## 2. Train or refresh the models

Use the included Python environment:

```powershell
.\venv310\Scripts\python.exe train_attention_models.py
```

This regenerates:

- `features_landmarks.csv`
- `assets/models/focusmate_cnn_lstm.tflite`
- `assets/models/focusmate_gnn.tflite`
- `assets/model_metrics.json`

## 3. Hyperparameter tuning

```powershell
.\venv310\Scripts\python.exe hyperparameter_tuning.py --model both --trials 4
```

This writes a ranking file:

- `tuning_results.json`

## 4. Professor demo flow

1. Open the app
2. Go to `Model Lab`
3. Switch between `CNN+LSTM` and `Landmark GNN`
4. Start a study session with camera enabled
5. Show how the selected model pauses or dims the YouTube session when attention drops
