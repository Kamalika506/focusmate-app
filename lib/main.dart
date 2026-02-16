import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/database_service.dart';
import 'screens/auth_screen.dart';
// import 'models/playlist.dart';
import 'models/session_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive Adapters
  // if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlaylistModelAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SessionConfigAdapter());
  
  await DatabaseService().init();
  
  runApp(const FocusMateApp());
}

class FocusMateApp extends StatelessWidget {
  const FocusMateApp({super.key});

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
      home: const AuthScreen(),
    );
  }
}
