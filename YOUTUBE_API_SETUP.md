# YouTube API Key Setup Guide

Follow these steps to get your free YouTube Data API v3 key:

## Step 1: Go to Google Cloud Console
1. Open your browser and go to: https://console.cloud.google.com/
2. Sign in with your Google account

## Step 2: Create a New Project
1. Click the **project dropdown** at the top (next to "Google Cloud")
2. Click **"NEW PROJECT"**
3. Enter project name: `FocusMate`
4. Click **"CREATE"**
5. Wait for the project to be created (takes ~10 seconds)

## Step 3: Enable YouTube Data API v3
1. In the search bar at the top, type: `YouTube Data API v3`
2. Click on **"YouTube Data API v3"** in the results
3. Click the blue **"ENABLE"** button
4. Wait for it to enable (~5 seconds)

## Step 4: Create API Key
1. Click **"CREATE CREDENTIALS"** button (top right)
2. Select **"API key"**
3. Your API key will be generated and displayed
4. **COPY THE KEY** (it looks like: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`)

## Step 5: Restrict the API Key (Optional but Recommended)
1. Click **"RESTRICT KEY"**
2. Under "API restrictions", select **"Restrict key"**
3. Choose **"YouTube Data API v3"** from the dropdown
4. Click **"SAVE"**

## Step 6: Add Key to FocusMate
1. Open the file: `lib/services/youtube_search_service.dart`
2. Find line 48: `static const String _apiKey = 'YOUR_API_KEY_HERE';`
3. Replace `YOUR_API_KEY_HERE` with your actual API key
4. Save the file

## Done! 🎉
Your app can now search YouTube videos. The free tier gives you 10,000 quota units per day, which is approximately 100 searches.

---

**Need Help?** If you encounter any issues, let me know and I can assist you!
