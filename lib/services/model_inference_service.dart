import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'attention_model_config.dart';

enum AttentionEngine { cnnLstm, gnn }

class InferenceResult {
  final double distractionProbability;
  final double confidence;
  final bool modelLoaded;

  const InferenceResult({
    required this.distractionProbability,
    required this.confidence,
    required this.modelLoaded,
  });
}

class ModelInferenceService {
  Interpreter? _cnnInterpreter;
  Interpreter? _gnnInterpreter;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    final options = InterpreterOptions()..threads = 2;

    try {
      _cnnInterpreter = await Interpreter.fromAsset(
        AttentionModelConfig.cnnLstmAsset,
        options: options,
      );
    } catch (error) {
      debugPrint('CNN+LSTM model not loaded: $error');
    }

    try {
      _gnnInterpreter = await Interpreter.fromAsset(
        AttentionModelConfig.gnnAsset,
        options: options,
      );
    } catch (error) {
      debugPrint('GNN model not loaded: $error');
    }

    _initialized = true;
  }

  InferenceResult runCnnLstm(List<List<double>> sequence) {
    if (_cnnInterpreter == null) {
      return const InferenceResult(
        distractionProbability: 0,
        confidence: 0,
        modelLoaded: false,
      );
    }

    final input = sequence
        .map((frame) => frame.map((value) => value.toDouble()).toList())
        .toList();

    final output = List.generate(1, (_) => List.filled(1, 0.0));
    _cnnInterpreter!.run([input], output);
    final probability = (output[0][0] as num).toDouble().clamp(0.0, 1.0);
    return InferenceResult(
      distractionProbability: probability,
      confidence: _confidence(probability),
      modelLoaded: true,
    );
  }

  InferenceResult runGraphModel(List<List<double>> nodes) {
    if (_gnnInterpreter == null) {
      return const InferenceResult(
        distractionProbability: 0,
        confidence: 0,
        modelLoaded: false,
      );
    }

    final input = nodes
        .map((node) => node.map((value) => value.toDouble()).toList())
        .toList();
    final output = List.generate(1, (_) => List.filled(1, 0.0));
    _gnnInterpreter!.run([input], output);
    final probability = (output[0][0] as num).toDouble().clamp(0.0, 1.0);
    return InferenceResult(
      distractionProbability: probability,
      confidence: _confidence(probability),
      modelLoaded: true,
    );
  }

  double _confidence(double probability) {
    return ((probability - 0.5).abs() * 2).clamp(0.0, 1.0);
  }

  void dispose() {
    _cnnInterpreter?.close();
    _gnnInterpreter?.close();
  }
}
