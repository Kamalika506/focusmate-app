import 'package:flutter/material.dart';
import '../../services/youtube_search_service.dart';
import '../study_session_screen.dart';
import '../../models/session_config.dart';
import '../../services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final YouTubeSearchService _searchService = YouTubeSearchService();
  
  List<YouTubeVideo> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      List<YouTubeVideo> results;
      results = await _searchService.searchVideos(query);
      
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  void _onResultTap(YouTubeVideo video) {
    // Start Session with Video
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudySessionScreen(
          sessionConfig: SessionConfig(
            topic: video.title,
            durationMinutes: 25, // Default
            breakIntervalMinutes: 0,
            breakDurationMinutes: 0,
            goal: 'Study ${video.title}',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search YouTube...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter removed
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('Search for study materials', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final video = _results[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              onTap: () => _onResultTap(video),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        width: 120,
                                        height: 68,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => 
                                          Container(width: 120, height: 68, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            video.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            video.channelTitle,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            video.viewCount,
                                            style: TextStyle(color: Colors.indigo[300], fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        DatabaseService().isVideoSaved(video.videoId) 
                                            ? Icons.bookmark 
                                            : Icons.bookmark_border,
                                        color: Colors.indigo,
                                      ),
                                      onPressed: () async {
                                        await DatabaseService().toggleSaveVideo(video);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }


}
