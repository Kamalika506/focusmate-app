// lib/screens/main_screen.dart
// 
// The primary navigation hub of the application.
// Uses a Scaffold with a BottomNavigationBar to manage and switch between 
// the search, study setup, and personal library views.

import 'package:flutter/material.dart';
import 'views/setup_view.dart';
import 'views/my_library_view.dart';
import 'model_lab_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _views = [
    const SetupView(),
    const MyLibraryView(),
    const ModelLabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _views[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_rounded),
            label: 'Session',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science_rounded),
            label: 'Model Lab',
          ),
        ],
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
