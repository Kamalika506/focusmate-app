// lib/services/neural_engine_classifier.dart
// 
// The central AI orchestration service for the FocusMate application.
// Coordinates with the FaceMeshService to provide real-time distraction and drowsiness classification.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'face_mesh_service.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:image/image.dart' as img;
// import 'package:camera/camera.dart';

enum EngineType { neural, gnn }

class NeuralEngineClassifier {
  final FaceMeshService _faceMeshService = FaceMeshService();
  
  EngineType activeEngine = EngineType.neural;
  
  // Temporal Buffer for LSTM (e.g., last 5 seconds of EAR and Pose)
  final List<List<double>> _featureHistory = [];
  static const int _historyLimit = 15; // ~5 seconds at 3fps

  Future<void> init() async {
    await _faceMeshService.init();
  }

  Future<NeuralOutput> analyze(InputImage inputImage, dynamic rawImage) async {
    // 1. Get Face Mesh Metrics (Foundation for all)
    final meshMetrics = await _faceMeshService.processImage(inputImage);
    
    if (meshMetrics != null) {
      _updateHistory(meshMetrics);
    }

    bool isDistracted = false;
    bool isDrowsy = false;

    // Defaulting to Mesh-based detection as TFLite models are gone
    switch (activeEngine) {
      case EngineType.neural:
        // Model 1: CNN+LSTM on EAR sequences
        isDistracted = (meshMetrics?.yaw.abs() ?? 0) > 0.45 || (meshMetrics?.pitch.abs() ?? 0) > 0.45;
        isDrowsy = (meshMetrics?.isDrowsy ?? false);
        break;

      case EngineType.gnn:
        // Model 3: Landmark GNN
        isDistracted = (meshMetrics?.yaw.abs() ?? 0) > 0.55 || (meshMetrics?.pitch.abs() ?? 0) > 0.55;
        isDrowsy = (meshMetrics?.ear ?? 1.0) < 0.18;
        break;
    }

    return NeuralOutput(
      ear: meshMetrics?.ear ?? 0.0,
      isDistracted: isDistracted,
      isDrowsy: isDrowsy,
      metrics: meshMetrics,
    );
  }

  void _updateHistory(FaceMeshMetrics metrics) {
    _featureHistory.add([metrics.ear, metrics.yaw, metrics.pitch, metrics.roll]);
    if (_featureHistory.length > _historyLimit) {
      _featureHistory.removeAt(0);
    }
  }


 

  void dispose() {
    _faceMeshService.dispose();
    // _lstmInterpreter?.close();
    // _mobilenetInterpreter?.close();
    // _vitInterpreter?.close();
  }
}

class NeuralOutput {
  final double ear;
  final bool isDistracted;
  final bool isDrowsy;
  final FaceMeshMetrics? metrics;

  NeuralOutput({
    required this.ear,
    required this.isDistracted,
    required this.isDrowsy,
    this.metrics,
  });
}
