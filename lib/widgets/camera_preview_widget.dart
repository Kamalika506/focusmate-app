// lib/widgets/camera_preview_widget.dart
// 
// A dedicated widget for displaying the real-time camera feed.
// Includes visual indicators (colored border, face detection overlay)
// to provide immediate feedback on the user's tracking status.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController? controller;
  final bool isFaceDetected;
  final bool showPreview;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.isFaceDetected,
    required this.showPreview,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPreview || controller == null || !controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 20,
      bottom: 20,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFaceDetected ? Colors.green : Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: CameraPreview(controller!),
          ),
        ),
      ),
    );
  }
}
