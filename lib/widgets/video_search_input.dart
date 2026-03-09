// lib/widgets/video_search_input.dart
// 
// An interactive search field specialized for YouTube content.
// Features a clean UI with real-time suggestion overlays, loading states,
// and horizontal scrolling result cards for quick video selection.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/youtube_video.dart';
import '../services/database_service.dart';

class VideoSearchInput extends StatefulWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final List<YouTubeVideo> searchResults;
  final VoidCallback onSearch;
  final Function(YouTubeVideo) onSelect;

  const VideoSearchInput({
    super.key,
    required this.searchController,
    required this.isSearching,
    required this.searchResults,
    required this.onSearch,
    required this.onSelect,
  });

  @override
  State<VideoSearchInput> createState() => _VideoSearchInputState();
}

class _VideoSearchInputState extends State<VideoSearchInput> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        TextField(
          controller: widget.searchController,
          decoration: InputDecoration(
            labelText: 'Search YouTube Videos',
            hintText: 'Enter topic (e.g., "Python tutorial")...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: widget.isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: widget.onSearch,
                    tooltip: 'Search',
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          onSubmitted: (_) => widget.onSearch(),
          textInputAction: TextInputAction.search,
        ),
        
        // Search Results
        if (widget.searchResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Top Results',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(widget.searchResults.length, (index) {
            final video = widget.searchResults[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildVideoCard(video),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildVideoCard(YouTubeVideo video) {
    final isSaved = DatabaseService().isVideoSaved(video.videoId);
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => widget.onSelect(video),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 120,
                        height: 90,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 90,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                    if (video.duration.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Video Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          video.viewCount,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Save Button and Play Icon
              Column(
                children: [
                   IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.indigo,
                    ),
                    onPressed: () async {
                      await DatabaseService().toggleSaveVideo(video);
                      setState(() {});
                    },
                  ),
                  Icon(Icons.play_circle_outline, color: Colors.indigo[700], size: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
