import 'package:flutter/material.dart';

class SessionTimerCard extends StatelessWidget {
  final String formattedTime;
  final bool isSessionActive;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onToggleSave;
  final bool isSaved;

  const SessionTimerCard({
    super.key,
    required this.formattedTime,
    required this.isSessionActive,
    required this.onStart,
    required this.onStop,
    required this.onToggleSave,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 0,
          color: Colors.indigo.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.indigo.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Text(
                  'SESSION PROGRESS',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.indigo[700],
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w200,
                    fontFamily: 'monospace',
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildControlButtons(),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isSessionActive)
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('START STUDYING', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.pause_rounded, size: 28),
            label: const Text('STOP SESSION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
          ),
        if (isSessionActive) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onToggleSave,
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            padding: const EdgeInsets.all(16),
            tooltip: isSaved ? 'Remove from Saved' : 'Save Video',
          ),
        ],
      ],
    );
  }
}
