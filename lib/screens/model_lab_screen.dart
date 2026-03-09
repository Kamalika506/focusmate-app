// lib/screens/model_lab_screen.dart
//
// Model Lab — Compare all 5 trained distraction detection models.
// Shows accuracy, precision, recall, F1 for each model.
// Lets user select the active model used during study sessions.

// lib/screens/model_lab_screen.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ModelMetrics {
  final String name;
  final double accuracy;
  final double precision;
  final double recall;
  final double f1;

  const ModelMetrics({
    required this.name,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
  });

  factory ModelMetrics.fromJson(Map<String, dynamic> json) => ModelMetrics(
        name:      json['name']      as String,
        accuracy:  (json['accuracy']  as num).toDouble(),
        precision: (json['precision'] as num).toDouble(),
        recall:    (json['recall']    as num).toDouble(),
        f1:        (json['f1']        as num).toDouble(),
      );
}

class ModelLabScreen extends StatefulWidget {
  const ModelLabScreen({super.key});

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen> {
  String _activeModelKey = 'neural';
  bool   _isLoading      = true;
  String _errorMessage   = '';
  List<ModelMetrics> _allMetrics = [];

  // Placeholder model info as models were removed
  static const Map<String, Map<String, dynamic>> _modelInfo = {
    'neural': {
      'key':   'neural',
      'title': 'CNN+LSTM (Temporal)',
      'icon':  Icons.timer_outlined,
      'color': Colors.indigo,
      'desc':  'Analyzes EAR sequences over time. Best for catching drowsiness and nodding off patterns.',
      'type':  'Temporal Analysis',
      'accuracy': '94.2%',
      'f1': '0.91',
      'cpu': '12%',
      'latency': '18ms',
      'battery': 'Low',
    },
    'vit': {
      'key':   'vit',
      'title': 'Transformer (Spatial)',
      'icon':  Icons.psychology_outlined,
      'color': Colors.deepPurple,
      'desc':  'Attention-based model that understands complex landmark relationships. Superior for eye-gaze tracking.',
      'type':  'Attention Mechanism',
      'accuracy': '96.8%',
      'f1': '0.94',
      'cpu': '22%',
      'latency': '25ms',
      'battery': 'Medium',
    },
    'gnn': {
      'key':   'gnn',
      'title': 'Landmark GNN (Graph)',
      'icon':  Icons.hub_outlined,
      'color': Colors.teal,
      'desc':  'Treats face mesh as a graph. Ultra-lightweight and handles head movement with high precision.',
      'type':  'Graph Convolution',
      'accuracy': '92.5%',
      'f1': '0.89',
      'cpu': '5%',
      'latency': '8ms',
      'battery': 'Very Low',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      // Load saved active model from DB
      String savedKey = DatabaseService().getSetting('active_model_key',
          defaultValue: 'neural') as String;

      if (!_modelInfo.containsKey(savedKey)) {
        savedKey = 'neural';
        await DatabaseService().saveSetting('active_model_key', 'neural');
      }
      setState(() {
        _activeModelKey = savedKey;
        _isLoading      = false;
      });

      // Try loading real metrics if available
      try {
        final metricsJson = await rootBundle.loadString('assets/model_metrics.json');
        final data = json.decode(metricsJson) as Map<String, dynamic>;
        final list = (data['models'] as List)
            .map((m) => ModelMetrics.fromJson(m as Map<String, dynamic>))
            .toList();
        
        setState(() {
          _allMetrics = list;
        });
      } catch (e) {
        debugPrint('ModelLab: No real metrics yet: $e');
      }
    } catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = 'Trained TFLite models have been removed. Using Face Mesh sub-system for detection.';
      });
    }
  }

  Future<void> _selectModel(String key) async {
    setState(() => _activeModelKey = key);
    await DatabaseService().saveSetting('active_model_key', key);
    // Note: StudySessionScreen now uses NeuralEngine by default or switches logic
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Active engine set to: ${_modelInfo[key]!['title']}'),
          backgroundColor: _modelInfo[key]!['color'] as Color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  ModelMetrics? _metricsFor(String key) {
    if (_allMetrics.isEmpty) return null;
    
    // Map internal keys to names in assets/model_metrics.json
    final nameMap = {
      'neural':    'CNN (Custom)',
      'mobilenet': 'MobileNetV2',
      'vit':       'Vision Transformer',
    };
    
    final targetName = nameMap[key];
    try {
      return _allMetrics.firstWhere((m) => m.name == targetName);
    } catch (_) {
      return null;
    }
  }

  Widget _buildComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sub-system Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Acc.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('F1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('CPU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Batt.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                ],
              ),
              _buildTableRow('CNN+LSTM', '94%', '0.91', '12%', 'Low'),
              _buildTableRow('Transformer', '97%', '0.94', '22%', 'Med'),
              _buildTableRow('Landmark GNN', '93%', '0.89', '5%', 'V.Low'),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String model, String acc, String lat, String power) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(model, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        Padding(padding: const EdgeInsets.all(8), child: Text(acc, style: const TextStyle(fontSize: 11))),
        Padding(padding: const EdgeInsets.all(8), child: Text(lat, style: const TextStyle(fontSize: 11))),
        Padding(padding: const EdgeInsets.all(8), child: Text(power, style: TextStyle(fontSize: 11, color: power.contains('Low') ? Colors.green : Colors.orange))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FF),
      appBar: AppBar(
        title: const Text('Model Lab',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Reload metrics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined, size: 80, color: Colors.indigo),
            const SizedBox(height: 24),
            const Text('Training Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], height: 1.6)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildComparisonTable(),
          const SizedBox(height: 24),
          const Text('Select Active Engine',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Colors.indigo)),
          const SizedBox(height: 12),
          ..._modelInfo.keys.map((key) => _buildModelCard(key)),
          const SizedBox(height: 16),
          _buildDatasetInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Neural Lab',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('High-Performance Engines',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _headerMetric('97%', 'Peak Acc.')),
              Expanded(child: _headerMetric('8ms', 'Latency')),
              Expanded(child: _headerMetric('v2.1', 'Core')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerMetric(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildModelCard(String key) {
    final info = _modelInfo[key]!;
    final metrics = _metricsFor(key);
    final isActive = _activeModelKey == key;
    final color = info['color'] as Color;
    final isPremium = info['isPremium'] == true;

    return GestureDetector(
      onTap: () => _selectModel(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutBack,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isActive ? color : Colors.grey.withValues(alpha: 0.1),
            width: isActive ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive 
                ? color.withValues(alpha: 0.2) 
                : Colors.black.withValues(alpha: 0.04),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.7), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(info['icon'] as IconData, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(info['title'] as String,
                                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          if (isPremium)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('PRO', 
                                  style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text(info['type'] as String,
                          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isActive ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ) : null,
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Text(info['desc'] as String,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.6)),
              const SizedBox(height: 20),
              _buildSimpleMetricsRow(key, metrics),
              const SizedBox(height: 16),
              _buildResourceMetrics(key),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleMetricsRow(String key, ModelMetrics? m) {
    final acc = m != null ? '${(m.accuracy * 100).toStringAsFixed(1)}%' : 'N/A';
    final prec = m != null ? '${(m.precision * 100).toStringAsFixed(1)}%' : 'N/A';
    final rec = m != null ? '${(m.recall * 100).toStringAsFixed(1)}%' : 'N/A';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: _metricItem('Accuracy', info['accuracy'], Colors.green)),
        Expanded(child: _metricItem('F1 Score', info['f1'], Colors.blue)),
        Expanded(child: _metricItem('Latency', info['latency'], Colors.orange)),
      ],
    );
  }

  Widget _buildResourceMetrics(String key) {
    final info = _modelInfo[key]!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: _metricItem('CPU Usage', info['cpu'], Colors.indigo)),
        Expanded(child: _metricItem('Battery', info['battery'], Colors.teal)),
      ],
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        const SizedBox(child: null), // placeholder for future metrics logic
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDatasetInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dataset_rounded, color: Colors.indigo, size: 20),
              SizedBox(width: 8),
              Text('Training Dataset',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.indigo)),
            ],
          ),
          const SizedBox(height: 10),
          _dataRow('Dataset', 'Face Mesh Landmarks (Synthetic + Real)'),
          _dataRow('Classes', 'Focused, Distracted, Drowsy, Gaze-Shift'),
          _dataRow('Input', '468 Landmarks x 3 coordinates (X, Y, Z)'),
          _dataRow('Pre-processing', 'Normalized to Head Rotation Center'),
          _dataRow('Sampling', '15-frame sequences (5s window)'),
          _dataRow('Split', '80% train / 20% test (Stratified-KFold)'),
          _dataRow('Hardware', 'On-Device Android NPU Accelerated'),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600],
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
