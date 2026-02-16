import 'package:flutter/material.dart';

class FocusScoreCard extends StatelessWidget {
  final double focusScore;
  final String sessionStatusText;

  const FocusScoreCard({
    super.key,
    required this.focusScore,
    required this.sessionStatusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('focus_score_card'),
      elevation: 8,
      shadowColor: Colors.indigo.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.indigo[800]!, Colors.indigo[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: focusScore / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 8,
                  ),
                ),
                Text(
                  '${focusScore.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Focus Score',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildTrendIndicator(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sessionStatusText,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    bool isGood = focusScore >= 80;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isGood ? Colors.greenAccent : Colors.orangeAccent).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isGood ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
        color: isGood ? Colors.greenAccent : Colors.orangeAccent,
        size: 16,
      ),
    );
  }
}
