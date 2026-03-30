import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import 'attention_model_config.dart';

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
    if (!_isInitialized) {
      return null;
    }

    final meshes = await _detector.processImage(inputImage);
    if (meshes.isEmpty) {
      return null;
    }

    final points = meshes.first.points;
    if (points.length <= AttentionModelConfig.landmarkIndices.last) {
      return null;
    }

    final faceBox = _calculateBoundingBox(points);
    final pose = _calculateHeadPose(points);
    final ear = _calculateAverageEar(points);
    final mouthAspectRatio = _calculateMouthAspectRatio(points);
    final browDistance = _calculateBrowDistance(points);
    final irisDistance = _calculateIrisDistance(points);
    final normalizedLandmarks = _extractNormalizedLandmarks(points);

    return FaceMeshMetrics(
      ear: ear,
      yaw: pose.yaw,
      pitch: pose.pitch,
      roll: pose.roll,
      isDrowsy: ear < 0.19,
      faceBox: faceBox,
      mouthAspectRatio: mouthAspectRatio,
      browDistance: browDistance,
      irisDistance: irisDistance,
      normalizedLandmarks: normalizedLandmarks,
      temporalFeatures: [
        ear,
        pose.yaw,
        pose.pitch,
        pose.roll,
        mouthAspectRatio,
        browDistance,
        irisDistance,
        faceBox.width == 0 ? 0 : faceBox.height / faceBox.width,
        ...normalizedLandmarks.expand((coords) => coords),
      ],
    );
  }

  Rect _calculateBoundingBox(List<FaceMeshPoint> points) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final point in points) {
      minX = min(minX, point.x.toDouble());
      minY = min(minY, point.y.toDouble());
      maxX = max(maxX, point.x.toDouble());
      maxY = max(maxY, point.y.toDouble());
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _calculateAverageEar(List<FaceMeshPoint> points) {
    final left = _calculateEar(points, [362, 385, 387, 263, 373, 380]);
    final right = _calculateEar(points, [33, 160, 158, 133, 153, 144]);
    return (left + right) / 2;
  }

  double _calculateEar(List<FaceMeshPoint> points, List<int> indices) {
    final p1 = points[indices[0]];
    final p2 = points[indices[1]];
    final p3 = points[indices[2]];
    final p4 = points[indices[3]];
    final p5 = points[indices[4]];
    final p6 = points[indices[5]];

    final v1 = _distance(p2, p6);
    final v2 = _distance(p3, p5);
    final h = _distance(p1, p4);

    if (h == 0) {
      return 0;
    }
    return (v1 + v2) / (2 * h);
  }

  double _calculateMouthAspectRatio(List<FaceMeshPoint> points) {
    final upperLip = points[13];
    final lowerLip = points[14];
    final leftMouth = points[61];
    final rightMouth = points[291];
    final width = _distance(leftMouth, rightMouth);

    if (width == 0) {
      return 0;
    }
    return _distance(upperLip, lowerLip) / width;
  }

  double _calculateBrowDistance(List<FaceMeshPoint> points) {
    final leftBrow = points[70];
    final rightBrow = points[300];
    final leftEye = points[159];
    final rightEye = points[386];

    final left = _distance(leftBrow, leftEye);
    final right = _distance(rightBrow, rightEye);
    return (left + right) / 2;
  }

  double _calculateIrisDistance(List<FaceMeshPoint> points) {
    final noseTip = points[1];
    final leftEye = points[33];
    final rightEye = points[263];
    final eyeSpan = _distance(leftEye, rightEye);
    if (eyeSpan == 0) {
      return 0;
    }

    return _distance(noseTip, points[4]) / eyeSpan;
  }

  List<List<double>> _extractNormalizedLandmarks(List<FaceMeshPoint> points) {
    final nose = points[1];
    final leftEye = points[33];
    final rightEye = points[263];
    final scale = max(_distance(leftEye, rightEye), 1e-6);

    return AttentionModelConfig.landmarkIndices.map((index) {
      final point = points[index];
      return [
        (point.x - nose.x) / scale,
        (point.y - nose.y) / scale,
        (point.z - nose.z) / scale,
      ];
    }).toList();
  }

  HeadPose _calculateHeadPose(List<FaceMeshPoint> points) {
    final noseTip = points[4];
    final chin = points[152];
    final leftEye = points[33];
    final rightEye = points[263];

    final pitchDenominator = max(chin.y - noseTip.y, 1e-6);
    final yawDenominator = max(rightEye.x - leftEye.x, 1e-6);

    final pitch = (noseTip.y - (leftEye.y + rightEye.y) / 2) / pitchDenominator;
    final yaw = (noseTip.x - (leftEye.x + rightEye.x) / 2) / yawDenominator;
    final roll = (rightEye.y - leftEye.y) / yawDenominator;

    return HeadPose(yaw: yaw, pitch: pitch, roll: roll);
  }

  double _distance(FaceMeshPoint a, FaceMeshPoint b) {
    return sqrt(
      pow(a.x - b.x, 2) +
          pow(a.y - b.y, 2) +
          pow(a.z - b.z, 2),
    );
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
  final double mouthAspectRatio;
  final double browDistance;
  final double irisDistance;
  final List<List<double>> normalizedLandmarks;
  final List<double> temporalFeatures;

  FaceMeshMetrics({
    required this.ear,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.isDrowsy,
    required this.faceBox,
    required this.mouthAspectRatio,
    required this.browDistance,
    required this.irisDistance,
    required this.normalizedLandmarks,
    required this.temporalFeatures,
  });
}

class HeadPose {
  final double yaw;
  final double pitch;
  final double roll;

  const HeadPose({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });
}
