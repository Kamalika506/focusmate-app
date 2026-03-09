# FocusMate: Project Workflow 🚀

FocusMate is a productivity application designed to help students maintain focus during study sessions involving YouTube videos. This document outlines the end-to-end workflow of the application.

## 1. Local-First Initialization
- **Privacy Core**: No external login is required. The app initializes directly.
- **Data Initialization**: Upon start, the app initializes Hive (local storage) to manage session records, settings, and library offline.

## 2. Main Navigation (Landing Screen)
- **Dashboard**: Displays a summary of recent focus scores and quick access to study sessions.
- **Search**: Integrated YouTube search allowing users to find educational content.
- **Library**: Access to bookmarked videos and session history.

## 3. Session Setup
- **Video Selection**: Users select a video from search results or their library.
- **Timer Configuration**: Users set the duration for their study session and break intervals.
- **Goal Setting**: Optional input for session objectives.

## 4. AI-Monitored Study Session
- **Real-time Video Playback**: An embedded YouTube player handles video delivery.
- **The Neural Engine**:
    - **Landmark-First Tracking**: Continuous tracking of 468 facial landmarks using Google ML Kit.
    - **Feature Extraction**: Real-time conversion of landmarks into Eye Aspect Ratio (EAR) and Head Pose.
    - **Multi-Model Inference**: Analyzes focus using the user's choice of CNN-LSTM, Transformer, or GNN architectures trained on landmark vectors.
- **Proactive Interventions**:
    - **Auto-Pause**: If a distraction is detected for a sustained period, the video pauses automatically.
    - **Visual Alerts**: On-screen prompts warn the user if they look away or show signs of drowsiness.
- **Focus Scoring**: A persistent score is calculated based on real-time engagement data.

## 5. Session Wrap-Up & Persistence
- **Statistics Summary**: At the end of a session, users see a detailed breakdown of their focus levels, total study time, and highlights.
- **Data Storage**:
    - **100% Local**: Session data and analytics are saved exclusively to Hive. No data ever leaves the device.

## 6. Model Lab (Advanced Tools)
- **Comparison Tool**: A dedicated screen allows users to test different AI models (CNN, MobileNetV2, ViT) and view their performance metrics (Accuracy, F1-Score).
- **In-App Training**: Users can trigger simplified "training" simulations to understand how models learn from focus data.
