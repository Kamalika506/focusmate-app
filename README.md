# FocusMate 🚀

FocusMate is a powerful student productivity app designed to help you stay engaged while studying with YouTube. It uses On-Device AI to track your focus levels and provides a structured environment for deep work.

## 🌟 Key Features

- **🎯 AI Focus Tracking**: Real-time monitoring of your engagement using your device's camera.
- **📺 YouTube Integration**: Search for educational videos and play them directly inside the app with focus-aware controls (auto-pause when distracted).
- **⏱️ Smart Session Timer**: Customizable study sessions with automated break reminders and focus scoring.
- **📚 Personal Library**: 
    - **Saved Videos**: Bookmark videos for future focus sessions.
    - **History**: Track your focus progress and session stats over time.
    - **Notes**: Take and store notes during your study sessions.
- **🚀 Offline-First**: Uses Hive for blazing-fast local storage, ensuring the app works even without an internet connection.

## �🤖 Machine Learning & AI Models

FocusMate uses **on-device ML** for distraction detection: your face is analyzed locally and no video is sent to the cloud.

### 1. Focus Engine
FocusMate uses **on-device ML** for focus tracking. Your face is analyzed locally and no video is sent to the cloud. The engine utilizes a **Mesh + CNN + LSTM** pipeline run via **TensorFlow Lite**.
- **Assets**: `distraction_cnn.tflite` and `drowsiness_lstm.tflite`.

### 2. ML Pipeline (Python)
- **Full training** (requires dataset): `ml_pipeline/distraction_model_training.py`. Produces the TFLite assets.
- **Minimal CNN only**: `ml_pipeline/export_minimal_cnn.py`.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth & Cloud Firestore)
- **Local Database**: [Hive](https://pub.dev/packages/hive)
- **APIs**: YouTube Data API v3
- **ML Engine**: Neural Engine (Mesh + CNN + LSTM via TFLite)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- A Google Cloud Project for YouTube API and Firebase.

### Installation
1. Clone the repository.
2. Refer to the [TEAMMATE_RUN_GUIDE.md](TEAMMATE_RUN_GUIDE.md) for a detailed step-by-step setup (API keys, Firebase, etc.).
3. Run `flutter pub get` to install dependencies.
4. Build and run: `flutter run`

---

Created with ❤️ by KamalHp
