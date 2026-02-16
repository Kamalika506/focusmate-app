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
- **🔐 Google Sign-In & Sync**: Secure authentication with Firebase and seamless cloud synchronization of your data across devices.
- **🚀 Offline-First**: Uses Hive for blazing-fast local storage, ensuring the app works even without an internet connection.

## 🤖 Machine Learning & AI Models

FocusMate leverages state-of-the-art on-device machine learning to provide a private and responsive experience.

### 1. Google ML Kit: Face Detection
The core focus tracking engine uses **Google ML Kit's Face Detection** API. 
- **Function**: It tracks your head orientation (Pitch, Yaw, and Roll) and eye state.
- **Focus Logic**: The app determines you are "Focused" if:
    - Your head is facing the screen (within ±30 degrees).
    - At least one eye is detected as open.
- **Engagement Scoring**: A real-time "Focus Score" is calculated based on the percentage of time you spend looking at the screen during a session.

### 2. Generative AI (Future Integration)
The app includes the **Google Generative AI (Gemini)** SDK, which is prepared for future features like:
- Automated study summaries from session notes.
- Smart recommendations for study topics.
- Interactive Q&A for YouTube educational content.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth & Cloud Firestore)
- **Local Database**: [Hive](https://pub.dev/packages/hive)
- **APIs**: YouTube Data API v3
- **ML Engine**: [Google ML Kit](https://developers.google.com/ml-kit)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- A Google Cloud Project for YouTube API and Firebase.

### Installation
1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective directories.
4. Add your YouTube API Key in the relevant service file.
5. Build and run: `flutter run`

---

Created with ❤️ by KamalHp
