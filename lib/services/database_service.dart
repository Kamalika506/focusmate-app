import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import '../models/playlist.dart';
import 'youtube_search_service.dart';

class DatabaseService {
  static const String _settingsBoxName = 'settings';
  static const String _historyBoxName = 'history';
  static const String _viewedVideosBoxName = 'viewed_videos';
  static const String _savedVideosBoxName = 'saved_videos';

  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Box _settingsBox;
  late Box _historyBox;
  late Box _viewedVideosBox;
  late Box _savedVideosBox;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  Future<void> init() async {
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _historyBox = await Hive.openBox(_historyBoxName);
    _viewedVideosBox = await Hive.openBox(_viewedVideosBoxName);
    _savedVideosBox = await Hive.openBox(_savedVideosBoxName);
    
    // Attempt to sync from Firestore if logged in
    if (_uid != null) {
      _syncFromCloud();
    }
  }

  Future<void> _syncFromCloud() async {
    if (_uid == null) return;
    
    try {
      // Sync History
      final historySnap = await _firestore.collection('users').doc(_uid).collection('history').get();
      for (var doc in historySnap.docs) {
        final data = doc.data();
        // Check if already in Hive
        final alreadyInHive = _historyBox.values.any((h) {
          final map = Map<String, dynamic>.from(h as Map);
          return map['date'] == data['date'];
        });
        if (!alreadyInHive) {
          await _historyBox.add(data);
        }
      }

      // Sync Playlists - Removed for now or migrate to saved videos if needed
      /*
      final playlistsSnap = await _firestore.collection('users').doc(_uid).collection('playlists').get();
      for (var doc in playlistsSnap.docs) {
         // Migration logic could go here
      }
      */
    } catch (e) {
      // Logic for failed sync
    }
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
    await _historyBox.add(sessionData);
    
    // Cloud Sync
    if (_uid != null) {
      await _firestore.collection('users').doc(_uid).collection('history').add(sessionData);
    }
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
    final key = _historyBox.keys.firstWhere(
      (k) => Map<String, dynamic>.from(_historyBox.get(k) as Map)['date'] == date,
      orElse: () => null,
    );
    if (key != null) {
      await _historyBox.delete(key);
      if (_uid != null) {
        final snap = await _firestore.collection('users').doc(_uid).collection('history').where('date', isEqualTo: date).get();
        for (var doc in snap.docs) {
          await doc.reference.delete();
        }
      }
    }
  }

  Future<void> deleteViewedVideo(String videoId) async {
    await _viewedVideosBox.delete(videoId);
  }
}
