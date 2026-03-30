import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import 'attention_model_config.dart';
import 'face_mesh_service.dart';
import 'model_inference_service.dart';

enum EngineType { neural, gnn }

class NeuralEngineClassifier {
  final FaceMeshService _faceMeshService = FaceMeshService();
  final ModelInferenceService _modelInferenceService = ModelInferenceService();

  EngineType activeEngine = EngineType.neural;
  final List<List<double>> _featureHistory = [];

  Future<void> init() async {
    await _faceMeshService.init();
    await _modelInferenceService.init();
  }

  Future<NeuralOutput> analyze(InputImage inputImage, dynamic rawImage) async {
    final meshMetrics = await _faceMeshService.processImage(inputImage);
    if (meshMetrics == null) {
      _featureHistory.clear();
      return const NeuralOutput.empty();
    }

    _updateHistory(meshMetrics.temporalFeatures);

    final useGraphModel = activeEngine == EngineType.gnn;
    final inference = useGraphModel
        ? _modelInferenceService.runGraphModel(meshMetrics.normalizedLandmarks)
        : _runTemporalInference(meshMetrics);

    final fallbackProbability = _fallbackProbability(meshMetrics);
    final modelLoaded = inference.modelLoaded;
    final distractionProbability =
        modelLoaded ? inference.distractionProbability : fallbackProbability;
    final confidence = modelLoaded ? inference.confidence : 0.45;
    final isDistracted = distractionProbability >= 0.55;
    final isDrowsy = meshMetrics.isDrowsy || meshMetrics.ear < 0.18;

    return NeuralOutput(
      ear: meshMetrics.ear,
      distractionProbability: distractionProbability,
      confidence: confidence,
      isDistracted: isDistracted,
      isDrowsy: isDrowsy,
      metrics: meshMetrics,
      modelLoaded: modelLoaded,
      activeModelKey: useGraphModel ? 'gnn' : 'cnn_lstm',
    );
  }

  InferenceResult _runTemporalInference(FaceMeshMetrics metrics) {
    if (_featureHistory.length < AttentionModelConfig.sequenceLength) {
      return const InferenceResult(
        distractionProbability: 0,
        confidence: 0,
        modelLoaded: false,
      );
    }

    final sequence = _featureHistory
        .skip(_featureHistory.length - AttentionModelConfig.sequenceLength)
        .toList();
    return _modelInferenceService.runCnnLstm(sequence);
  }

  void _updateHistory(List<double> features) {
    _featureHistory.add(features);
    if (_featureHistory.length > AttentionModelConfig.sequenceLength) {
      _featureHistory.removeAt(0);
    }
  }

  double _fallbackProbability(FaceMeshMetrics metrics) {
    final yawRisk = (metrics.yaw.abs() / 0.75).clamp(0.0, 1.0);
    final pitchRisk = (metrics.pitch.abs() / 0.85).clamp(0.0, 1.0);
    final earRisk = ((0.24 - metrics.ear) / 0.12).clamp(0.0, 1.0);
    final mouthRisk = ((metrics.mouthAspectRatio - 0.18) / 0.24).clamp(0.0, 1.0);

    return (0.45 * yawRisk) +
        (0.25 * pitchRisk) +
        (0.2 * earRisk) +
        (0.1 * mouthRisk);
  }

  void dispose() {
    _faceMeshService.dispose();
    _modelInferenceService.dispose();
  }
}

class NeuralOutput {
  final double ear;
  final double distractionProbability;
  final double confidence;
  final bool isDistracted;
  final bool isDrowsy;
  final FaceMeshMetrics? metrics;
  final bool modelLoaded;
  final String activeModelKey;

  const NeuralOutput({
    required this.ear,
    required this.distractionProbability,
    required this.confidence,
    required this.isDistracted,
    required this.isDrowsy,
    this.metrics,
    required this.modelLoaded,
    required this.activeModelKey,
  });

  const NeuralOutput.empty()
      : ear = 0,
        distractionProbability = 0,
        confidence = 0,
        isDistracted = false,
        isDrowsy = false,
        metrics = null,
        modelLoaded = false,
        activeModelKey = 'cnn_lstm';
}
