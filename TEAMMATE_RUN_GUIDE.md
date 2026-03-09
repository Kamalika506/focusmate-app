# 🚀 Teammate Onboarding Guide: FocusMate

Follow these steps to get the project running on your local machine.

## 1. Prerequisites
- **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install) (Ensure `flutter doctor` passes).
- **Git**: [Install Git](https://git-scm.com/downloads).
- **IDE**: VS Code (with Flutter extension) or Android Studio.

## 2. Clone the Repository
Open your terminal and run:
```bash
git clone https://github.com/Kamalika506/focusmate-app.git
cd focusmate-app
```

## 3. Install Dependencies
```bash
flutter pub get
```

## 4. Setup API Keys & Config (Crucial)
Since sensitive files are ignored for privacy, you need to add your own:

### A. YouTube API Key
1. Follow the [YOUTUBE_API_SETUP.md](YOUTUBE_API_SETUP.md) guide to get a key.
2. Open `lib/services/youtube_search_service.dart`.
3. Replace the placeholder in `static const String _apiKey = '...';` with your key.

### B. Firebase Setup
1. Create a project in [Firebase Console](https://console.firebase.google.com/).
2. Add an Android and iOS app to the project.
3. **Android**: Download `google-services.json` and place it in `android/app/`.
4. **iOS**: Download `GoogleService-Info.plist` and place it in `ios/Runner/`.

## 5. Run the App
Connect a physical device or start an emulator, then:
```bash
flutter run
```

---
**Note**: If you face any issues with ML models, ensure the `.tflite` files are present in the `assets/` directory (they should be included in the repo).
