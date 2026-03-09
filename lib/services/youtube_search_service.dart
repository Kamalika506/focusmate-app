// lib/services/youtube_search_service.dart
// 
// Service for interfacing with the YouTube Data API v3.
// Allows searching for educational videos and parses the JSON response
// into structured YouTubeVideo data models.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/youtube_video.dart';

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
    final refinedQuery = '$query study course tutorial';

    try {
      // Step 1: Search for videos
      // Fetching more results to have enough buffer for strict filtering
      final searchUrl = Uri.parse(
        '$_baseUrl/search?part=snippet&q=${Uri.encodeComponent(refinedQuery)}&type=video&maxResults=25&relevanceLanguage=en&order=relevance&key=$_apiKey',
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

      // Step 2: Get video details to filter by duration and language
      final videoIds = rawItems.map((item) => item['id']['videoId']).join(',');
      final detailsUrl = Uri.parse(
        '$_baseUrl/videos?part=statistics,contentDetails,snippet&id=$videoIds&key=$_apiKey',
      );

      final detailsResponse = await http.get(detailsUrl);
      if (detailsResponse.statusCode != 200) {
        throw Exception('Failed to fetch video details');
      }

      final detailsData = json.decode(detailsResponse.body);
      final detailsItems = detailsData['items'] as List;

      // Step 3: Combine and filter: English only, No Shorts (> 240s), High Quality
      final filteredVideos = <YouTubeVideo>[];
      for (var detailsItem in detailsItems) {
        // 1. Language Check (if available in snippet)
        final lang = detailsItem['snippet']?['defaultAudioLanguage'] ?? '';
        // final title = detailsItem['snippet']?['title'] ?? '';
        
        // Basic heuristic: if lang is set, must be 'en'. If not set, check title for English chars.
        if (lang.isNotEmpty && !lang.startsWith('en')) continue;
        
        // 2. Duration Check (Exclude Shorts - < 4 minutes / 240 seconds)
        final isoDuration = detailsItem['contentDetails']['duration'];
        final durationInSeconds = _parseDurationToSeconds(isoDuration);
        if (durationInSeconds < 240) continue;

        // 3. Quality Check (Heuristic: high view count for 'bestest')
        final viewCount = int.tryParse(detailsItem['statistics']?['viewCount'] ?? '0') ?? 0;
        if (viewCount < 1000) continue; // Basic filter for relevance

        final searchItem = rawItems.firstWhere((i) => i['id']['videoId'] == detailsItem['id']);

        filteredVideos.add(YouTubeVideo.fromJson(
          searchItem,
          {
            'viewCount': detailsItem['statistics']?['viewCount'] ?? '0',
            'duration': _formatDuration(isoDuration),
          },
        ));
      }

      // Step 4: Return only top 5
      final top5 = filteredVideos.take(5).toList();
      debugPrint('Successfully found ${top5.length} high-quality study videos');
      return top5;
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
