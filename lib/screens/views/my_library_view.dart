// lib/screens/views/my_library_view.dart
// 
// A personal dashboard for tracking user progress and history.
// Displays summarized focus stats, session history logs, and a collection 
// of the user's saved educational videos for easy access.

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/session_config.dart';
import '../study_session_screen.dart';

import 'package:intl/intl.dart';
import '../../models/youtube_video.dart';


class MyLibraryView extends StatefulWidget {
  const MyLibraryView({super.key});

  @override
  State<MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<MyLibraryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
                errorBuilder: (context, error, stackTrace) => Container(width: 80, height: 45, color: Colors.grey[300]),
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
                if (mounted) setState(() {});
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

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  Widget build(BuildContext context) {
    final history = DatabaseService().getHistory();

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No session history yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final record = history[index];
        final bool hasVideo = record['videoTitle'] != null;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  record['grade'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ),
            ),
            title: Text(
              record['topic'] ?? 'Untitled Session',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasVideo) 
                  Text(
                    'Video: ${record['videoTitle']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                Text(
                  '${DateFormat.yMMMd().format(DateTime.parse(record['date']))} • ${record['focusScore']}% focus',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await DatabaseService().deleteHistoryRecord(record['date']);
                if (mounted) setState(() {});
              },
            ),
          ),
        );
      },
    );
  }
}

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allNotes = DatabaseService().getAllNotes();

    if (allNotes.isEmpty) {
      return const Center(child: Text('No notes taken yet.', style: TextStyle(color: Colors.grey)));
    }

    // Filter notes based on search query (Theme, Title, or Date)
    final filteredNotes = allNotes.where((note) {
      final theme = (note['topic'] ?? 'General').toString().toLowerCase();
      final title = (note['noteTitle'] ?? 'Untitled Note').toString().toLowerCase();
      final date = DateFormat.yMMMd().format(DateTime.parse(note['date'])).toLowerCase();
      
      return theme.contains(_searchQuery) || 
             title.contains(_searchQuery) || 
             date.contains(_searchQuery);
    }).toList();

    // Group filtered notes by topic (Theme)
    final Map<String, List<Map<String, dynamic>>> groupedNotes = {};
    for (var note in filteredNotes) {
      final theme = note['topic'] ?? 'General';
      groupedNotes.putIfAbsent(theme, () => []).add(note);
    }

    final themes = groupedNotes.keys.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Theme, Title, or Date...',
              prefixIcon: const Icon(Icons.search, color: Colors.indigo),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            ),
          ),
        ),
        if (filteredNotes.isEmpty && _searchQuery.isNotEmpty)
          const Expanded(
            child: Center(child: Text('No matching notes found.', style: TextStyle(color: Colors.grey))),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final theme = themes[index];
                final themeNotes = groupedNotes[theme]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    initiallyExpanded: _searchQuery.isNotEmpty || index == 0,
                    leading: const Icon(Icons.folder_special, color: Colors.indigo),
                    title: Text(
                      theme.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13),
                    ),
                    subtitle: Text('${themeNotes.length} notes', style: const TextStyle(fontSize: 11)),
                    children: themeNotes.map((note) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            note['noteTitle'] ?? 'Untitled Note',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.yMMMd().format(DateTime.parse(note['date'])),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: () => _showNoteDetail(context, note),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showNoteDetail(BuildContext context, Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note['noteTitle'] ?? 'Untitled Note',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Part of ${note['topic']}',
                        style: const TextStyle(color: Colors.indigo, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              DateFormat.yMMMMEEEEd().format(DateTime.parse(note['date'])),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  note['notes'] ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await DatabaseService().deleteHistoryRecord(note['date']);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('DELETE NOTE', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
