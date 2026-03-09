// main.dart
// 
// The entry point of the FocusMate application.
// This file initializes Hive for local storage, registers necessary adapters,
// and sets up the primary MaterialApp with the app theme and initial landing screen.

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/database_service.dart';
import 'screens/landing_screen.dart';
import 'models/session_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive Adapters (SessionConfig has typeId 0 in session_config.g.dart)
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(SessionConfigAdapter());
  
  await DatabaseService().init();
  
  runApp(const FocusMateApp());
}

class FocusMateApp extends StatefulWidget {
  const FocusMateApp({super.key});

  @override
  State<FocusMateApp> createState() => _FocusMateAppState();
}

class _FocusMateAppState extends State<FocusMateApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // User switched to another app or minimized FocusMate
      debugPrint('App shifted to background/inactive. Triggering focus intervention.');
      _handleBackgroundPause();
    }
  }

  void _handleBackgroundPause() {
    // Logic to notify StudySessionScreen or a central FocusManager to pause
    // For now, we set a global flag or use a provider if available.
    // Given the current structure, we'll use a simple static notifier or similar if needed,
    // but typically StudySessionScreen should listen to this.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      ),
      home: const LandingScreen(),
    );
  }
}
