import 'package:flutter/material.dart';
import 'views/setup_view.dart';
import 'views/my_library_view.dart';


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
        ],
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButton: _selectedIndex == 0 ? null : FloatingActionButton(
        onPressed: () => setState(() => _selectedIndex = 0),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
