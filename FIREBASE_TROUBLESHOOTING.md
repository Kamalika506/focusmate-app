# Google Sign-In Troubleshooting

If you are seeing "Sign-In Failed" on your Android device, it is most likely because the **SHA-1 Fingerprint** of your machine is not registered in the Firebase Console.

### Step 1: Get your SHA-1 Fingerprint (Windows)
1. Open a terminal (PowerShell or Command Prompt) in your project root.
2. Run these commands:
   ```powershell
   cd android
   .\gradlew.bat signingReport
   ```
3. Scroll through the output and look for the **`debug`** variant.
4. Copy the **SHA-1** value (e.g., `5E:8F:19...`).

### Step 2: Add SHA-1 to Firebase Console
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your project: **FocusMate**.
3. Click on the **Settings (gear icon)** > **Project settings**.
4. Scroll down to the **Your apps** section and select the **Android app**.
5. Click **Add fingerprint**.
6. Paste your **SHA-1** and save.
7. (**CRITICAL**) Go to **Build > Authentication > Sign-in method** and ensure **Google** is enabled WITH a "Project support email".

### Step 3: Re-download google-services.json
1. After adding the fingerprint, download the updated `google-services.json` from Project Settings.
2. Replace the existing one in `android/app/google-services.json`.

---

### Understanding the Error Dialog
When you try to sign in, watch for the dialog I added:
- **Error Code 10**: Your SHA-1 is missing from Firebase OR your "Project support email" is not set in the console.
- **Error Code 12500**: Usually an issue with the Google Play Services or the `google-services.json` being outdated.
- **Error Code 12501**: User cancelled the sign-in (normal if you just hit back).
