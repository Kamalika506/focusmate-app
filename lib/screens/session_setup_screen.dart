import 'package:flutter/material.dart';
import '../models/session_config.dart';
import '../models/playlist.dart';
import 'study_session_screen.dart';
import '../services/youtube_search_service.dart';
import '../services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _goalController = TextEditingController();
  
  double _durationMinutes = 25;
  String _selectedMethod = 'Standard'; // Standard, Pomodoro, Deep Work
  
  // Recommendations State
  List<YouTubeVideo> _recommendations = [];
  bool _isLoadingRecommendations = false;
  YouTubeVideo? _selectedRecommendedVideo;
  List<String> _recentTopics = [];
  
  // Saved Videos State
  List<Map<String, dynamic>> _savedVideos = [];
  List<Map<String, dynamic>> _viewedVideos = [];
  int _selectedTab = 0; // 0: Search/Recs, 1: Saved, 2: Library
  
  // Method Presets
  final Map<String, Map<String, int>> _methods = {
    'Standard': {'duration': 60, 'break_interval': 0, 'break_duration': 0},
    'Pomodoro': {'duration': 25, 'break_interval': 25, 'break_duration': 5},
    'Deep Work': {'duration': 90, 'break_interval': 90, 'break_duration': 15},
  };

  void _onMethodChanged(String? method) {
    if (method != null) {
      setState(() {
        _selectedMethod = method;
        _durationMinutes = _methods[method]!['duration']!.toDouble();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoadingRecommendations = true);
    
    try {
      final db = DatabaseService();
      final highFocusTopic = db.getLastHighFocusTopic();
      final lowFocusTopic = db.getLastLowFocusTopic();
      
      final searchService = YouTubeSearchService();
      final recs = await searchService.getRecommendedVideos(highFocusTopic, lowFocusTopic);
      
      final recentTopics = db.getRecentTopics();
      
      if (mounted) {
        setState(() {
          _recommendations = recs;
          _recentTopics = recentTopics;
          _isLoadingRecommendations = false;
        });
      }
      
      _loadSavedVideos();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRecommendations = false);
      }
    }
  }

  void _loadSavedVideos() {
    final db = DatabaseService();
    final saved = db.getSavedVideos();
    final viewedVideos = db.getViewedVideos();
    setState(() {
      _savedVideos = saved;
      _viewedVideos = viewedVideos;
    });
  }

  void _startSession() {
    if (_formKey.currentState!.validate()) {
      final config = SessionConfig(
        topic: _topicController.text.trim(),
        durationMinutes: _durationMinutes.toInt(),
        breakIntervalMinutes: _methods[_selectedMethod]!['break_interval']!,
        breakDurationMinutes: _methods[_selectedMethod]!['break_duration']!,
        goal: _goalController.text.trim(),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => StudySessionScreen(sessionConfig: config),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Setup Session',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tabs (Phase 12/16)
                      Row(
                        children: [
                          _buildTabButton(0, 'Setup', Icons.settings_rounded),
                          const SizedBox(width: 8),
                          _buildTabButton(1, 'Saved', Icons.bookmark_rounded),
                          const SizedBox(width: 8),
                          _buildTabButton(2, 'Library', Icons.video_library_rounded),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_selectedTab == 0) ...[
                        // Topic Chips (Phase 17)
                        if (_recentTopics.isNotEmpty) ...[
                          const Text(
                            'Recent Topics',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _recentTopics.map((topic) {
                              return ActionChip(
                                label: Text(topic),
                                avatar: const Icon(Icons.history_rounded, size: 16),
                                backgroundColor: Colors.white,
                                onPressed: () {
                                  setState(() {
                                    _topicController.text = topic;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Topic Input
                        TextFormField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          labelText: 'What are you studying?',
                          hintText: 'e.g. Calculus, History, Coding',
                          prefixIcon: const Icon(Icons.topic_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter a topic' : null,
                      ),
                      const SizedBox(height: 24),
                      
                      // Method Selector
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMethod,
                        decoration: InputDecoration(
                          labelText: 'Study Method',
                          prefixIcon: const Icon(Icons.timer_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _methods.keys.map((method) {
                          return DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          );
                        }).toList(),
                        onChanged: _onMethodChanged,
                      ),
                      const SizedBox(height: 24),
                      
                      // Duration Slider
                      Text(
                        'Duration: ${_durationMinutes.toInt()} minutes',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Slider(
                        value: _durationMinutes,
                        min: 5,
                        max: 120,
                        divisions: 23,
                        label: '${_durationMinutes.toInt()} min',
                        onChanged: (value) {
                          setState(() {
                            _durationMinutes = value;
                            // Reset to "Standard" if user manually changes slider logic 
                            // (optional, keeping simple for now)
                          });
                        },
                      ),
                      
                      // Goal Input (Optional)
                      TextFormField(
                        controller: _goalController,
                        decoration: InputDecoration(
                          labelText: 'Session Goal (Optional)',
                          hintText: 'e.g. Complete chapter 3',
                          prefixIcon: const Icon(Icons.flag_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Recommendations Section (Phase 12)
                      if (_isLoadingRecommendations)
                        const Center(child: CircularProgressIndicator())
                      else if (_recommendations.isNotEmpty) ...[
                        const Text(
                          'Recommended for You',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recommendations.length,
                            itemBuilder: (context, index) {
                              final video = _recommendations[index];
                              final isSelected = _selectedRecommendedVideo?.videoId == video.videoId;
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedRecommendedVideo = video;
                                      _topicController.text = video.title;
                                    });
                                  },
                                  child: Container(
                                    width: 160,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? Colors.indigo : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: video.thumbnailUrl,
                                            height: 90,
                                            width: 160,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          video.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      ] else if (_selectedTab == 1) ...[
                        // Saved Videos Tab
                        if (_savedVideos.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32.0),
                              child: Text(
                                'No saved videos yet.\nSave videos from search to study later.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 300,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _savedVideos.length,
                              itemBuilder: (context, index) {
                                final videoData = _savedVideos[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        videoData['thumbnailUrl'] ?? '',
                                        width: 80,
                                        height: 45,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_,__,___) => Container(width: 80, height: 45, color: Colors.grey[300]),
                                      ),
                                    ),
                                    title: Text(videoData['title'] ?? 'Unknown', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text(videoData['channelTitle'] ?? '', maxLines: 1),
                                    onTap: () {
                                      setState(() {
                                        _topicController.text = videoData['title'];
                                        _selectedTab = 0; // Switch back to setup with video title
                                      });
                                    },
                                    trailing: IconButton(
                                      icon: const Icon(Icons.bookmark_remove, color: Colors.indigo),
                                      onPressed: () async {
                                        await DatabaseService().toggleSaveVideo(YouTubeVideo.fromMap(videoData));
                                        _loadSavedVideos(); // Refresh
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],

                      // Library Tab (Phase 16)
                      if (_selectedTab == 2) ...[
                        const Text(
                          'Recently Viewed',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                        const SizedBox(height: 16),
                        if (_viewedVideos.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('No videos viewed yet.'),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _viewedVideos.length,
                            itemBuilder: (context, index) {
                              final videoData = _viewedVideos[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      videoData['thumbnailUrl'] ?? '',
                                      width: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.video_library),
                                    ),
                                  ),
                                  title: Text(
                                    videoData['title'] ?? 'Title',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(videoData['channelTitle'] ?? ''),
                                  onTap: () {
                                    setState(() {
                                      _topicController.text = videoData['title'];
                                      _selectedTab = 0;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      // Start Button
                      ElevatedButton(
                        onPressed: _startSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'START FOCUS SESSION',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildTabButton(int index, String label, IconData icon) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
            boxShadow: [
              if (isSelected)
                BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
