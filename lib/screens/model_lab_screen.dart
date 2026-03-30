import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/database_service.dart';

class ModelMetrics {
  final String key;
  final String name;
  final String description;
  final double accuracy;
  final double precision;
  final double recall;
  final double f1;
  final double latencyMs;
  final String inputShape;
  final bool exported;

  const ModelMetrics({
    required this.key,
    required this.name,
    required this.description,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.latencyMs,
    required this.inputShape,
    required this.exported,
  });

  factory ModelMetrics.fromJson(Map<String, dynamic> json) {
    return ModelMetrics(
      key: json['key'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      precision: (json['precision'] as num?)?.toDouble() ?? 0,
      recall: (json['recall'] as num?)?.toDouble() ?? 0,
      f1: (json['f1'] as num?)?.toDouble() ?? 0,
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0,
      inputShape: json['input_shape'] as String? ?? 'Unknown',
      exported: json['exported'] as bool? ?? false,
    );
  }
}

class ModelLabScreen extends StatefulWidget {
  const ModelLabScreen({super.key});

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen> {
  String _activeModelKey = 'cnn_lstm';
  bool _isLoading = true;
  String _errorMessage = '';
  List<ModelMetrics> _models = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final savedKey = DatabaseService().getSetting(
      'active_model_key',
      defaultValue: 'cnn_lstm',
    ) as String;
    final normalizedSavedKey = savedKey == 'neural' ? 'cnn_lstm' : savedKey;

    try {
      final rawJson = await rootBundle.loadString('assets/model_metrics.json');
      final decoded = json.decode(rawJson) as Map<String, dynamic>;
      final models = (decoded['models'] as List<dynamic>)
          .map((entry) => ModelMetrics.fromJson(entry as Map<String, dynamic>))
          .toList();

      setState(() {
        _activeModelKey = models.any((model) => model.key == normalizedSavedKey)
            ? normalizedSavedKey
            : 'cnn_lstm';
        _models = models;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _activeModelKey = normalizedSavedKey;
        _models = const [];
        _isLoading = false;
        _errorMessage =
            'Model metrics are missing. Run the Python training pipeline to generate TFLite artifacts and comparison results.';
      });
    }
  }

  Future<void> _selectModel(String key) async {
    await DatabaseService().saveSetting('active_model_key', key);
    setState(() => _activeModelKey = key);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key == 'gnn'
              ? 'Landmark GNN is now active for study sessions.'
              : 'CNN+LSTM is now active for study sessions.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Model Lab'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload metrics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildError()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    ..._models.map(_buildModelCard),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined, size: 64, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text(
              'Training Artifacts Not Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final exportedCount = _models.where((model) => model.exported).length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade500],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professor Demo Comparison',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$exportedCount of ${_models.length} models exported to mobile and ready for on-device testing.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _models.map((model) {
              return _metricChip(
                model.name,
                '${(model.f1 * 100).toStringAsFixed(1)}% F1',
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildModelCard(ModelMetrics model) {
    final isActive = model.key == _activeModelKey;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? Colors.indigo : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      model.description,
                      style: TextStyle(color: Colors.grey[700], height: 1.4),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (_) => _selectModel(model.key),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricTile('Accuracy', model.accuracy),
              _buildMetricTile('Precision', model.precision),
              _buildMetricTile('Recall', model.recall),
              _buildMetricTile('F1', model.f1),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Input: ${model.inputShape}  •  Latency: ${model.latencyMs.toStringAsFixed(1)} ms  •  Exported: ${model.exported ? 'Yes' : 'No'}',
            style: TextStyle(
              color: model.exported ? Colors.green.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, double value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text(
            '${(value * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
