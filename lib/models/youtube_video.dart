// lib/models/youtube_video.dart
// 
// Data model for YouTube videos.

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
