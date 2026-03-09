import 'dart:math';
import 'package:flutter/foundation.dart';

/// Represents an "Arm" in the Multi-Armed Bandit problem.
/// Each arm is a combination of a threshold and an intervention type.
class MABArm {
  final int id;
  final double threshold;
  final String interventionType; // 'none', 'pulse', 'nudge', 'hard_pause'

  const MABArm(this.id, this.threshold, this.interventionType);

  @override
  String toString() => 'Arm(id: $id, threshold: $threshold, type: $interventionType)';
}

/// The Contextual Multi-Armed Bandit Engine using LinUCB.
class AdaptiveThresholdService {
  // Singleton Pattern
  static final AdaptiveThresholdService _instance = AdaptiveThresholdService._internal();
  factory AdaptiveThresholdService() => _instance;
  AdaptiveThresholdService._internal();

  // MAB Constants
  static const int contextDim = 7; // Number of features in context
  static const double delta = 0.1; // Confidence level
  static const double alpha = 1.0 + (debugMode ? 0.5 : 0.0); // Exploration vs Exploitation
  static const bool debugMode = true;

  // Available Arms (Actions)
  static const List<MABArm> arms = [
    MABArm(0, 0.4, 'pulse'),       // Arm 0: Low sensitivity, soft alert
    MABArm(1, 0.5, 'pulse'),       // Arm 1: Mid sensitivity, soft alert
    MABArm(2, 0.6, 'nudge'),       // Arm 2: High sensitivity, gentle nudge
    MABArm(3, 0.7, 'nudge'),       // Arm 3: Very High sensitivity, gentle nudge
    MABArm(4, 0.6, 'hard_pause'),  // Arm 4: Aggressive intervention
    MABArm(5, 0.0, 'none'),        // Arm 5: No intervention (Silence)
  ];

  // Model Parameters per Arm (Persistent in DB)
  // A_a = d x d identity matrix initially
  // b_a = d x 1 zero vector initially
  Map<int, List<List<double>>> _A = {};
  Map<int, List<double>> _b = {};

  void init(Map<dynamic, dynamic> initialA, Map<dynamic, dynamic> initialB) {
    // Perform robust deep casting from dynamic maps (Hive data)
    initialA.forEach((rawK, v) {
      final k = (rawK is int) ? rawK : int.tryParse(rawK.toString());
      if (k != null && v is List) {
        try {
          _A[k] = (v as List).map((row) => 
            (row as List).map((e) => (e as num).toDouble()).toList()
          ).toList();
        } catch (e) {
          debugPrint('Error casting A for arm $k: $e');
        }
      }
    });

    initialB.forEach((rawK, v) {
      final k = (rawK is int) ? rawK : int.tryParse(rawK.toString());
      if (k != null && v is List) {
        try {
          _b[k] = (v as List).map((e) => (e as num).toDouble()).toList();
        } catch (e) {
          debugPrint('Error casting b for arm $k: $e');
        }
      }
    });

    // Initialize if empty or missing arms
    for (var arm in arms) {
      _A.putIfAbsent(arm.id, () => List.generate(contextDim, (i) => List.generate(contextDim, (j) => i == j ? 1.0 : 0.0)));
      _b.putIfAbsent(arm.id, () => List.generate(contextDim, (i) => 0.0));
    }
  }

  /// Selects the best arm based on current context.
  MABArm selectArm(List<double> context) {
    int bestArmId = 0;
    double maxUCB = -double.infinity;

    for (var arm in arms) {
      final A_inv = _invertMatrix(_A[arm.id]!);
      final theta = _multiplyMatrixVector(A_inv, _b[arm.id]!);
      
      // Expected payoff: p_t_a = theta' * x_t_a
      final double expectedPayoff = _dotProduct(theta, context);
      
      // Confidence bound: c_t_a = alpha * sqrt(x' * A_inv * x)
      final double confidence = alpha * sqrt(_quadForm(context, A_inv));
      
      final double ucb = expectedPayoff + confidence;

      if (ucb > maxUCB) {
        maxUCB = ucb;
        bestArmId = arm.id;
      }
    }

    debugPrint('MAB Selected Arm $bestArmId (UCB: $maxUCB) for Context: $context');
    return arms[bestArmId];
  }

  /// Updates the parameters based on the observed reward.
  void update(int armId, List<double> context, double reward) {
    // A_a = A_a + x_t * x_t'
    for (int i = 0; i < contextDim; i++) {
      for (int j = 0; j < contextDim; j++) {
        _A[armId]![i][j] += context[i] * context[j];
      }
    }

    // b_a = b_a + reward * x_t
    for (int i = 0; i < contextDim; i++) {
      _b[armId]![i] += reward * context[i];
    }
    
    debugPrint('MAB Updated Arm $armId with Reward: $reward');
  }

  // --- Linear Algebra Helpers ---

  double _dotProduct(List<double> v1, List<double> v2) {
    double sum = 0;
    for (int i = 0; i < v1.length; i++) sum += v1[i] * v2[i];
    return sum;
  }

  List<double> _multiplyMatrixVector(List<List<double>> m, List<double> v) {
    return List.generate(m.length, (i) => _dotProduct(m[i], v));
  }

  double _quadForm(List<double> v, List<List<double>> m) {
    final temp = _multiplyMatrixVector(m, v);
    return _dotProduct(v, temp);
  }

  /// Simplified Matrix Inversion (using Gauss-Jordan for small 7x7)
  List<List<double>> _invertMatrix(List<List<double>> matrix) {
    int n = matrix.length;
    List<List<double>> augmented = List.generate(n, (i) => List.generate(2 * n, (j) => j < n ? matrix[i][j] : (j == n + i ? 1.0 : 0.0)));

    for (int i = 0; i < n; i++) {
      double pivot = augmented[i][i];
      if (pivot.abs() < 1e-10) continue; // Should not happen with A init as Identity

      for (int j = 0; j < 2 * n; j++) augmented[i][j] /= pivot;
      for (int k = 0; k < n; k++) {
        if (k != i) {
          double factor = augmented[k][i];
          for (int j = 0; j < 2 * n; j++) augmented[k][j] -= factor * augmented[i][j];
        }
      }
    }

    return List.generate(n, (i) => augmented[i].sublist(n));
  }

  // Getters for saving to DB
  Map<int, List<List<double>>> get A => _A;
  Map<int, List<double>> get b => _b;
}
