import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class YouTubeVideo {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String viewCount;
  final String duration;

  YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.duration,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json, Map<String, dynamic> statistics) {
    return YouTubeVideo(
      videoId: json['id']['videoId'] ?? json['id'],
      title: json['snippet']['title'] ?? 'Unknown Title',
      channelTitle: json['snippet']['channelTitle'] ?? 'Unknown Channel',
      thumbnailUrl: json['snippet']['thumbnails']['high']['url'] ?? '',
      viewCount: _formatViewCount(statistics['viewCount'] ?? '0'),
      duration: statistics['duration'] ?? '',
    );
  }

  static String _formatViewCount(String count) {
    try {
      int views = int.parse(count);
      if (views >= 1000000) {
        return '${(views / 1000000).toStringAsFixed(1)}M views';
      } else if (views >= 1000) {
        return '${(views / 1000).toStringAsFixed(1)}K views';
      }
      return '$views views';
    } catch (e) {
      return '0 views';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'channelTitle': channelTitle,
      'thumbnailUrl': thumbnailUrl,
      'viewCount': viewCount,
      'duration': duration,
    };
  }

  factory YouTubeVideo.fromMap(Map<String, dynamic> map) {
    return YouTubeVideo(
      videoId: map['videoId'],
      title: map['title'],
      channelTitle: map['channelTitle'],
      thumbnailUrl: map['thumbnailUrl'],
      viewCount: map['viewCount'],
      duration: map['duration'],
    );
  }
}

class YouTubeSearchService {
  // TODO: Replace with your YouTube Data API v3 key
  static const String _apiKey = 'AIzaSyDfkdUGuauWpSWqrtuhMx1OT5vQHwG6MOk';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  /// Search YouTube for videos matching the query
  /// Returns top 3 most viewed and relevant study videos
  Future<List<YouTubeVideo>> searchVideos(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    // Append 'study' to ensure educational content
    final refinedQuery = '$query study';

    try {
      // Step 1: Search for videos
      // Fetching 15 results to have enough buffer for filtering
      final searchUrl = Uri.parse(
        '$_baseUrl/search?part=snippet&q=${Uri.encodeComponent(refinedQuery)}&type=video&maxResults=15&order=viewCount&key=$_apiKey',
      );

      debugPrint('YouTube API Request: $searchUrl');
      final searchResponse = await http.get(searchUrl);

      if (searchResponse.statusCode != 200) {
        throw Exception('Failed to search videos: ${searchResponse.statusCode}');
      }

      final searchData = json.decode(searchResponse.body);
      final rawItems = searchData['items'] as List;

      if (rawItems.isEmpty) {
        return [];
      }

      // Step 2: Get video statistics for all results to filter by duration
      final videoIds = rawItems.map((item) => item['id']['videoId']).join(',');
      final statsUrl = Uri.parse(
        '$_baseUrl/videos?part=statistics,contentDetails&id=$videoIds&key=$_apiKey',
      );

      final statsResponse = await http.get(statsUrl);
      if (statsResponse.statusCode != 200) {
        throw Exception('Failed to fetch video stats');
      }

      final statsData = json.decode(statsResponse.body);
      final statsItems = statsData['items'] as List;

      // Step 3: Combine and filter out shorts (less than 2 minutes)
      final allVideos = <YouTubeVideo>[];
      for (var searchItem in rawItems) {
        final videoId = searchItem['id']['videoId'];
        final statsItem = statsItems.firstWhere(
          (stat) => stat['id'] == videoId,
          orElse: () => null,
        );

        if (statsItem == null) continue;

        final isoDuration = statsItem['contentDetails']['duration'];
        final durationInSeconds = _parseDurationToSeconds(isoDuration);

        // Filter out videos < 120 seconds (Shorts are typically < 60s, but study videos should be substantial)
        if (durationInSeconds < 120) continue;

        allVideos.add(YouTubeVideo.fromJson(
          searchItem,
          {
            'viewCount': statsItem['statistics']?['viewCount'] ?? '0',
            'duration': _formatDuration(isoDuration),
          },
        ));
      }

      // Step 4: Return only top 3
      final top3 = allVideos.take(3).toList();
      debugPrint('Successfully found ${top3.length} study videos');
      return top3;
    } catch (e, stackTrace) {
      debugPrint('YouTube Search Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return [];
    }
  }

  /// Parses ISO 8601 duration to total seconds
  static int _parseDurationToSeconds(String isoDuration) {
    if (isoDuration.isEmpty) return 0;
    try {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(isoDuration);
      if (match == null) return 0;

      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

      return (hours * 3600) + (minutes * 60) + seconds;
    } catch (e) {
      return 0;
    }
  }

  // Removed searchPlaylists method as playlists are no longer suggested

  /// Get recommendations based on last high-focus or low-focus topic
  Future<List<YouTubeVideo>> getRecommendedVideos(String? highFocusTopic, String? lowFocusTopic) async {
    String query = '';
    if (highFocusTopic != null) {
      query = '$highFocusTopic advanced next level';
    } else if (lowFocusTopic != null) {
      query = '$lowFocusTopic basics introduction';
    } else {
      // Default recommendation if no history
      query = 'best study music lofi focus';
    }
    
    return await searchVideos(query);
  }

  /// Convert ISO 8601 duration (e.g., PT15M33S) to readable format (15:33)
  static String _formatDuration(String isoDuration) {
    if (isoDuration.isEmpty) return '0:00';

    try {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(isoDuration);

      if (match == null) return '0:00';

      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

      if (hours > 0) {
        return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '0:00';
    }
  }
}
