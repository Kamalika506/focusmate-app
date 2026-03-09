// lib/services/database_service.dart
// 
// A singleton service managing all Hive-based local data operations.
// Handles persistence for settings, session history, viewed videos,
// saved videos, and search history, providing methods for CRUD operations.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/youtube_video.dart';
class DatabaseService {
  static const String _settingsBoxName = 'settings';
  static const String _historyBoxName = 'history';
  static const String _viewedVideosBoxName = 'viewed_videos';
  static const String _savedVideosBoxName = 'saved_videos';
  static const String _searchHistoryBoxName = 'search_history';

  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Box _settingsBox;
  late Box _historyBox;
  late Box _viewedVideosBox;
  late Box _savedVideosBox;
  late Box _searchHistoryBox;

  Future<void> init() async {
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _historyBox = await Hive.openBox(_historyBoxName);
    _viewedVideosBox = await Hive.openBox(_viewedVideosBoxName);
    _savedVideosBox = await Hive.openBox(_savedVideosBoxName);
    _searchHistoryBox = await Hive.openBox(_searchHistoryBoxName);
  }

  // Generic Settings Methods
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  // History Methods
  Future<void> addToHistory(Map<String, dynamic> sessionData) async {
    final date = sessionData['date'] as String?;
    if (date != null) {
      await _historyBox.put(date, sessionData);
    } else {
      await _historyBox.add(sessionData);
    }
  }

  Future<void> upsertHistory(Map<String, dynamic> sessionData) async {
    final date = sessionData['date'] as String?;
    if (date == null) return;
    await _historyBox.put(date, sessionData);
  }

  List<Map<String, dynamic>> getHistory() {
    return _historyBox.values.map((v) => Map<String, dynamic>.from(v as Map)).toList().reversed.toList();
  }

  List<String> getRecentTopics() {
    final history = getHistory();
    final topics = history.map((e) => (e['topic'] as String?) ?? '').where((t) => t.isNotEmpty).toSet().toList();
    return topics.take(5).toList();
  }

  List<Map<String, dynamic>> getAllNotes() {
    final history = getHistory();
    return history.where((h) => h['notes'] != null && (h['notes'] as String).isNotEmpty).toList();
  }

  String? getLastHighFocusTopic() {
    final history = getHistory();
    for (var record in history) {
      final score = record['focusScore'] as num?;
      if (score != null && score >= 80) return record['topic'] as String?;
    }
    return null;
  }

  String? getLastLowFocusTopic() {
    final history = getHistory();
    if (history.isEmpty) return null;
    final last = history.first;
    final score = last['focusScore'] as num?;
    if (score != null && score < 50) return last['topic'] as String?;
    return null;
  }

  // Viewed Videos Tracking (Local only for bandwidth efficiency)
  Future<void> markVideoAsViewed(YouTubeVideo video) async {
    await _viewedVideosBox.put(video.videoId, {
      ...video.toMap(),
      'lastViewed': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> getViewedVideos() {
    final list = _viewedVideosBox.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
    list.sort((a, b) => (b['lastViewed'] as String).compareTo(a['lastViewed'] as String));
    return list;
  }

  // Saved Videos Methods
  Future<void> toggleSaveVideo(YouTubeVideo video) async {
    if (_savedVideosBox.containsKey(video.videoId)) {
      await _savedVideosBox.delete(video.videoId);
    } else {
      await _savedVideosBox.put(video.videoId, {
        ...video.toMap(),
        'savedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  bool isVideoSaved(String videoId) {
    return _savedVideosBox.containsKey(videoId);
  }

  List<Map<String, dynamic>> getSavedVideos() {
    final list = _savedVideosBox.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
    list.sort((a, b) => (b['savedAt'] as String).compareTo(a['savedAt'] as String));
    return list;
  }

  Future<void> deleteHistoryRecord(String date) async {
    await _historyBox.delete(date);
  }

  Future<void> deleteViewedVideo(String videoId) async {
    await _viewedVideosBox.delete(videoId);
  }

  // Search History Methods
  Future<void> addToSearchHistory(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    
    // Make search history unique: if exists, delete old one to move it to the latest (top)
    final existingKey = _searchHistoryBox.keys.firstWhere(
      (k) => _searchHistoryBox.get(k) == trimmedQuery,
      orElse: () => null,
    );
    if (existingKey != null) {
      await _searchHistoryBox.delete(existingKey);
    }
    
    await _searchHistoryBox.put(DateTime.now().toIso8601String(), trimmedQuery);
  }

  List<Map<String, String>> getSearchHistory() {
    return _searchHistoryBox.keys.map((k) => {
      'date': k as String,
      'query': _searchHistoryBox.get(k) as String,
    }).toList().reversed.toList();
  }
}
