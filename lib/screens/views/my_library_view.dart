import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/session_config.dart';
import '../study_session_screen.dart';

import 'package:intl/intl.dart';
import '../../services/youtube_search_service.dart';

class MyLibraryView extends StatefulWidget {
  const MyLibraryView({super.key});

  @override
  State<MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<MyLibraryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50], // Consistent background
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'Saved', icon: Icon(Icons.bookmark)),
            Tab(text: 'History', icon: Icon(Icons.history)),
            Tab(text: 'Notes', icon: Icon(Icons.note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SavedVideosTab(),
          HistoryTab(),
          NotesTab(),
        ],
      ),
    );
  }
}

class SavedVideosTab extends StatefulWidget {
  const SavedVideosTab({super.key});

  @override
  State<SavedVideosTab> createState() => _SavedVideosTabState();
}

class _SavedVideosTabState extends State<SavedVideosTab> {
  @override
  Widget build(BuildContext context) {
    final savedVideos = DatabaseService().getSavedVideos();

    if (savedVideos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No saved videos yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('Save videos from search to study later.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: savedVideos.length,
      itemBuilder: (context, index) {
        final videoData = savedVideos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                videoData['thumbnailUrl'] ?? '',
                width: 80,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(width: 80, height: 45, color: Colors.grey[300]),
              ),
            ),
            title: Text(
              videoData['title'] ?? 'Unknown',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(videoData['channelTitle'] ?? '', style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.bookmark_remove, color: Colors.indigo),
              tooltip: 'Remove',
              onPressed: () async {
                await DatabaseService().toggleSaveVideo(YouTubeVideo.fromMap(videoData));
                setState(() {});
              },
            ),
            onTap: () => _showStartSessionDialog(context, videoData),
          ),
        );
      },
    );
  }

  void _showStartSessionDialog(BuildContext context, Map<String, dynamic> videoData) {
    final topicController = TextEditingController(text: videoData['title'] ?? 'Study Session');
    double duration = 25;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start Study Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: 'Study Topic',
                  prefixIcon: Icon(Icons.topic_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Text('Duration: ${duration.toInt()} min'),
              Slider(
                value: duration,
                min: 5, max: 120, divisions: 23,
                onChanged: (v) => setDialogState(() => duration = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => StudySessionScreen(
                      sessionConfig: SessionConfig(
                        topic: topicController.text.trim(),
                        durationMinutes: duration.toInt(),
                        breakIntervalMinutes: 0,
                        breakDurationMinutes: 0,
                        goal: 'Study ${videoData['title']}',
                      ),
                    ),
                  ),
                );
              },
              child: const Text('START'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final viewedVideos = DatabaseService().getViewedVideos();

    if (viewedVideos.isEmpty) {
      return const Center(child: Text('No viewing history.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: viewedVideos.length,
      itemBuilder: (context, index) {
        final video = viewedVideos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
               child: video['thumbnailUrl'] != null && (video['thumbnailUrl'] as String).isNotEmpty
                  ? Image.network(video['thumbnailUrl'], width: 60, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.video_library))
                  : const Icon(Icons.video_library),
            ),
            title: Text(video['title'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              'Viewed: ${DateFormat.yMMMd().format(DateTime.parse(video['lastViewed']))}', 
              style: const TextStyle(fontSize: 12)
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () async {
                await DatabaseService().deleteViewedVideo(video['videoId']);
                (context as Element).markNeedsBuild(); // Refresh
              },
            ),
          ),
        );
      },
    );
  }
}

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notes = DatabaseService().getAllNotes();

    if (notes.isEmpty) {
      return const Center(child: Text('No notes taken yet.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(Icons.note_alt_rounded, color: Colors.amber),
            title: Text(note['topic'] ?? 'Session Note', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat.yMMMd().format(DateTime.parse(note['date']))),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(note['notes'] ?? '', style: const TextStyle(fontSize: 16)),
                    const Divider(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await DatabaseService().deleteHistoryRecord(note['date']);
                          (context as Element).markNeedsBuild();
                        },
                        icon: const Icon(Icons.delete_rounded, color: Colors.red),
                        label: const Text('DELETE NOTE', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
