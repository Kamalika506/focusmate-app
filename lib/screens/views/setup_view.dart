// lib/screens/views/setup_view.dart
// 
// The configuration view for starting new study sessions.
// Displays recent search topics and quick-start session templates, 
// facilitating a fast and efficient setup for the user's next learning period.

import 'package:flutter/material.dart';
import '../../models/session_config.dart';
import '../../models/youtube_video.dart';
import '../study_session_screen.dart';
import '../../services/youtube_search_service.dart';
import '../../services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SetupView extends StatefulWidget {
  const SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  
  double _durationMinutes = 25;
  String _selectedMethod = 'Standard';
  
  List<YouTubeVideo> _recommendations = [];
  bool _isLoadingRecommendations = false;
  
  final Map<String, Map<String, int>> _methods = {
    'Standard': {'duration': 60, 'break_interval': 0, 'break_duration': 0},
    'Pomodoro': {'duration': 25, 'break_interval': 25, 'break_duration': 5},
    'Deep Work': {'duration': 90, 'break_interval': 90, 'break_duration': 15},
  };

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _onMethodChanged(String? method) {
    if (method != null) {
      setState(() {
        _selectedMethod = method;
        _durationMinutes = _methods[method]!['duration']!.toDouble();
      });
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoadingRecommendations = true);
    try {
      final db = DatabaseService();
      final highFocusTopic = db.getLastHighFocusTopic();
      final lowFocusTopic = db.getLastLowFocusTopic();
      final searchService = YouTubeSearchService();
      final recs = await searchService.getRecommendedVideos(highFocusTopic, lowFocusTopic);
      
      if (mounted) {
        setState(() {
          _recommendations = recs;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  void _startSession() {
    if (_formKey.currentState!.validate()) {
      final config = SessionConfig(
        topic: _topicController.text.trim(),
        durationMinutes: _durationMinutes.toInt(),
        breakIntervalMinutes: _methods[_selectedMethod]!['break_interval']!,
        breakDurationMinutes: _methods[_selectedMethod]!['break_duration']!,
        goal: '',
      );

      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => StudySessionScreen(sessionConfig: config)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      appBar: AppBar(
        title: const Text('Setup Session', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      labelText: 'Study Topic',
                      prefixIcon: const Icon(Icons.topic_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter a topic' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMethod,
                    decoration: InputDecoration(
                      labelText: 'Method',
                      prefixIcon: const Icon(Icons.timer_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: _methods.keys.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: _onMethodChanged,
                  ),
                  const SizedBox(height: 20),
                  Text('Duration: ${_durationMinutes.toInt()} min', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _durationMinutes,
                    min: 5, max: 120, divisions: 23,
                    onChanged: (v) => setState(() => _durationMinutes = v),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoadingRecommendations)
                    const Center(child: CircularProgressIndicator())
                  else if (_recommendations.isNotEmpty) ...[
                    const Text('Recommended', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          final video = _recommendations[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => setState(() => _topicController.text = video.title),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(imageUrl: video.thumbnailUrl, height: 90, width: 160, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(width: 160, child: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _startSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('START SESSION', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
