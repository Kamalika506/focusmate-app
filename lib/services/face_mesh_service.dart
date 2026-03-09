// lib/services/face_mesh_service.dart
// 
// Service utilizing Google ML Kit Face Mesh Detection to analyze facial landmarks.
// Calculates metrics such as Eye Aspect Ratio (EAR) for drowsiness detection
// and estimates head pose (Yaw, Pitch, Roll) for tracking visual focus.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class FaceMeshService {
  late final FaceMeshDetector _detector;
  bool _isInitialized = false;

  FaceMeshService() {
    _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  }

  Future<void> init() async {
    _isInitialized = true;
  }

  Future<FaceMeshMetrics?> processImage(InputImage inputImage) async {
    if (!_isInitialized) return null;

    final List<FaceMesh> meshes = await _detector.processImage(inputImage);
    if (meshes.isEmpty) return null;

    final mesh = meshes.first;
    final points = mesh.points;

    // Calculate EAR for both eyes
    final leftEAR = _calculateEAR(points, [362, 385, 387, 263, 373, 380]);
    final rightEAR = _calculateEAR(points, [33, 160, 158, 133, 153, 144]);
    final avgEAR = (leftEAR + rightEAR) / 2;

    // Calculate Head Pose (simplified)
    final pose = _calculateHeadPose(points);

    // Calculate Bounding Box
    final faceBox = _calculateBoundingBox(points);

    return FaceMeshMetrics(
      ear: avgEAR,
      yaw: pose.yaw,
      pitch: pose.pitch,
      roll: pose.roll,
      isDrowsy: avgEAR < 0.2, // Baseline threshold
      faceBox: faceBox,
    );
  }

  Rect _calculateBoundingBox(List<FaceMeshPoint> points) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var point in points) {
      if (point.x < minX) minX = point.x.toDouble();
      if (point.y < minY) minY = point.y.toDouble();
      if (point.x > maxX) maxX = point.x.toDouble();
      if (point.y > maxY) maxY = point.y.toDouble();
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _calculateEAR(List<FaceMeshPoint> points, List<int> indices) {
    // MediaPipe EAR formula
    // EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
    final p1 = points[indices[0]];
    final p2 = points[indices[1]];
    final p3 = points[indices[2]];
    final p4 = points[indices[3]];
    final p5 = points[indices[4]];
    final p6 = points[indices[5]];

    final v1 = _dist(p2, p6);
    final v2 = _dist(p3, p5);
    final h = _dist(p1, p4);

    return (v1 + v2) / (2.0 * h);
  }

  double _dist(FaceMeshPoint a, FaceMeshPoint b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2) + pow(a.z - b.z, 2));
  }

  HeadPose _calculateHeadPose(List<FaceMeshPoint> points) {
    // Simplified pose estimation based on landmarks
    // Nose tip: 4, Chin: 152, Left eye: 33, Right eye: 263, etc.
    // This is a rough approximation for the demo.
    final noseTip = points[4];
    final chin = points[152];
    final leftEye = points[33];
    final rightEye = points[263];

    // Pitch: vertical rotation (nose vs eyes/chin)
    final pitch = (noseTip.y - (leftEye.y + rightEye.y) / 2) / (chin.y - noseTip.y);
    
    // Yaw: horizontal rotation (nose vs eyes)
    final yaw = (noseTip.x - (leftEye.x + rightEye.x) / 2) / (rightEye.x - leftEye.x);

    // Roll: side-to-side tilt (eyes level)
    final roll = (rightEye.y - leftEye.y) / (rightEye.x - leftEye.x);

    return HeadPose(yaw: yaw, pitch: pitch, roll: roll);
  }

  Future<void> dispose() async {
    await _detector.close();
  }
}

class FaceMeshMetrics {
  final double ear;
  final double yaw;
  final double pitch;
  final double roll;
  final bool isDrowsy;
  final Rect faceBox;

  FaceMeshMetrics({
    required this.ear,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.isDrowsy,
    required this.faceBox,
  });
}

class HeadPose {
  final double yaw;
  final double pitch;
  final double roll;

  HeadPose({required this.yaw, required this.pitch, required this.roll});
}
