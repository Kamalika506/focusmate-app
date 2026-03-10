// lib/screens/study_session_screen.dart
// 
// The core interactive study environment of FocusMate.
// Integrates a YouTube player with real-time AI monitoring to track user 
// attention, manage study/break cycles, and provide proactive focus interventions.

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

// ── ML Kit (RE-ENABLED for face cropping) ──────────────────────
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// ─────────────────────────────────────────────────────────────────────────


import '../models/youtube_video.dart';
import '../services/youtube_search_service.dart';
import '../services/neural_engine_classifier.dart';
import '../widgets/focus_score_card.dart';
import '../widgets/session_timer_card.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/video_search_input.dart';
import '../services/database_service.dart';
import '../models/session_config.dart';
import 'main_screen.dart';

class StudySessionScreen extends StatefulWidget {
  final SessionConfig sessionConfig;
  
  const StudySessionScreen({
    super.key,
    required this.sessionConfig,
  });

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> with WidgetsBindingObserver {
  // YouTube Controller
  YoutubePlayerController? _ytController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;
  late TextEditingController _noteTitleController;
  
  // Session State
  bool _isSessionActive = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  
  // Attention Logic
  bool _isDistracted = false;
  bool _wasPausedByApp = false;
  int _distractionSeconds = 0; // Countdown for grace period
  int _totalFocusedSeconds = 0;
  int _distractionCount = 0;
  double _focusScore = 100.0;
  static const int _gracePeriodMax = 5;

  String get _sessionGrade {
    if (_focusScore >= 90) return 'A+';
    if (_focusScore >= 80) return 'A';
    if (_focusScore >= 70) return 'B';
    if (_focusScore >= 60) return 'C';
    return 'D';
  }

  // Camera State
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _showCameraPreview = false;
  List<CameraDescription> _cameras = [];
  bool _isInitializingCamera = false;

  // ── Neural Engine Classifier (Advanced) ──────────────
  final NeuralEngineClassifier _neuralEngine = NeuralEngineClassifier();
  bool _isFaceDetected = false;      
  bool _isLookingAtScreen = false;   
  bool _isProcessingImage = false;
  double _currentEAR = 0.0;
  String _activeModelKey = 'neural';
  String _activeModelName = 'Neural Engine (v3)';
  bool _isDimmed = false;

  // ── ML Kit fields (RE-ENABLED for intelligent cropping) ─────────────
  late FaceDetector _faceDetector;
  // ──────────────────────────────────────────────────────────────────────

  // YouTube Search
  final YouTubeSearchService _searchService = YouTubeSearchService();
  List<YouTubeVideo> _searchResults = [];
  bool _isSearching = false;
  late TextEditingController _searchController;
  
  // Session Config State
  late int _remainingDurationSeconds;
  bool _isOnBreak = false;
  int _timeSinceLastBreak = 0;
  
  // Intervention State
  bool _showPulse = false;
  bool _hasSuggestedBreak = false;
  bool _isVideoSaved = false;
  late TextEditingController _editableTopicController;

  // History Tracking
  // Tracking the active video for history
  YouTubeVideo? _activeVideo;
  String? _sessionStartTime;
  bool _isSessionAutoStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingDurationSeconds = widget.sessionConfig.durationMinutes * 60;
    
    _urlController = TextEditingController(text: 'https://www.youtube.com/watch?v=seMVR9lwrjM');
    _searchController = TextEditingController(text: widget.sessionConfig.topic);
    _notesController = TextEditingController();
    _noteTitleController = TextEditingController();
    _editableTopicController = TextEditingController(text: widget.sessionConfig.topic);
    _initYoutubeController();
    
    if (widget.sessionConfig.topic.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchYouTube();
      });
    }
    
    // ── Initialize Neural Engine ──
    _neuralEngine.init().then((_) {
      // Load active model from DB and apply to engine
      final savedKey = DatabaseService().getSetting('active_model_key', defaultValue: 'neural') as String;
      _activeModelKey = savedKey;
      _activeModelName = _activeModelKey == 'neural' 
          ? 'CNN+LSTM Engine' 
          : 'Landmark GNN';
      
      if (_activeModelKey == 'gnn') _neuralEngine.activeEngine = EngineType.gnn;
      
      debugPrint('StudySessionScreen: Neural Engine initialized with model: $_activeModelKey');
    });

    // ── ML Kit FaceDetector (RE-ENABLED) ──────────────────────
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        enableClassification: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    // ──────────────────────────────────────────────────────────────────────
  }

  void _initYoutubeController() {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text) ?? '';
    _ytController?.dispose();
    _ytController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: false,
        loop: false,
      ),
    )..addListener(_onYoutubePlayerChange);
    
    if (mounted) {
      setState(() {});
      _checkIfVideoSaved();
    }
  }

  void _onYoutubePlayerChange() {
    if (mounted) {
      setState(() {
        if (_ytController!.value.isPlaying && _wasPausedByApp) {
          _wasPausedByApp = false;
        }
        if (_ytController!.value.hasError) {
          _showError('YouTube Player Error: ${_ytController!.value.errorCode}');
        }
        
        // Auto-start session if player is ready and we haven't auto-started yet
        if (!_isSessionActive && !_isSessionAutoStarted && _ytController!.value.isReady) {
          _isSessionAutoStarted = true;
          _startSession();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Pause video and stop camera when user switches apps
      _stopCameraStream();
      if (_isSessionActive && _ytController != null && _ytController!.value.isPlaying) {
        _ytController!.pause();
        _wasPausedByApp = true;
        debugPrint('FocusMate: App backgrounded. Session/Video paused.');
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_showCameraPreview) {
        _initializeCamera();
      }
      // Note: We don't auto-resume video to avoid surprising the user
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;
    setState(() => _isInitializingCamera = true);

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('Camera permission required.');
        setState(() => _isInitializingCamera = false);
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras found.');
        setState(() => _isInitializingCamera = false);
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _showCameraPreview = true;
          _isInitializingCamera = false;
        });
        _startCameraStream();
      }
    } catch (e) {
      _showError('Camera Error: $e');
      setState(() => _isInitializingCamera = false);
    }
  }

  void _startCameraStream() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.startImageStream(_processCameraImage);
    }
  }

  void _stopCameraStream() {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
  }

  /// Converts CameraImage to InputImage for ML Kit.
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('InputImage Conversion Error: $e');
      return null;
    }
  }

  // ── Detection Logic ────────────────────────────────────────────────────────

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || !mounted) return;
    _isProcessingImage = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;
      
      final output = await _neuralEngine.analyze(inputImage, image);
      if (mounted) {
        setState(() {
          _isFaceDetected = output.metrics != null;
          _isLookingAtScreen = !output.isDistracted;
          _currentEAR = output.ear;
          _handleGraduatedIntervention(output);
        });
      }
    } catch (e) {
      debugPrint('Detection Error: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  void _handleGraduatedIntervention(NeuralOutput output) {
    // Level 1: Visual Drift (Head Pose) -> Subtle Dimming
    if (output.isDistracted && !_isDimmed) {
      setState(() => _isDimmed = true);
    } else if (!output.isDistracted && _isDimmed) {
      setState(() => _isDimmed = false);
    }

    // Level 2: Fatigue (LSTM Drowsiness Pattern) -> Pomodoro Break
    if (output.isDrowsy && !_hasSuggestedBreak) {
      _showLevel4BreakDialog();
    }
  }

  void _toggleCamera() async {
    if (_showCameraPreview) {
      _stopCameraStream();
      await _cameraController?.dispose();
      setState(() {
        _cameraController = null;
        _isCameraInitialized = false;
        _showCameraPreview = false;
        _isFaceDetected = false;
        _isLookingAtScreen = false;
      });
    } else {
      await _initializeCamera();
    }
  }

  /// Captures a photo from the camera and saves it to the FocusMateCaptures folder.
  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera not ready');
      return;
    }
    try {
      _stopCameraStream();
      final XFile photo = await _cameraController!.takePicture();
      _startCameraStream();

      final dir = await getApplicationDocumentsDirectory();
      final capturesDir = Directory('${dir.path}/FocusMateCaptures');
      if (!await capturesDir.exists()) {
        await capturesDir.create(recursive: true);
      }
      final now = DateTime.now();
      final name = 'capture_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}.jpg';
      final savedPath = '${capturesDir.path}/$name';
      await photo.saveTo(savedPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo saved to FocusMateCaptures\n$name'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      _startCameraStream();
      _showError('Capture failed: $e');
    }
  }

  void _startSession() {
    if (_ytController == null || !_ytController!.value.isReady) {
      _showError('Video player not ready');
      return;
    }

    setState(() {
      _isSessionActive = true;
      _isDistracted = false;
      _wasPausedByApp = false;
      _distractionSeconds = 0;
      _distractionCount = 0;
      _timeSinceLastBreak = 0;
      _isOnBreak = false;
      _sessionStartTime = DateTime.now().toIso8601String();
    });
    
    _ytController!.play();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_isSessionActive) {
          // Break Interval Logic
          if (widget.sessionConfig.breakIntervalMinutes > 0 && !_isOnBreak) {
            _timeSinceLastBreak++;
            if (_timeSinceLastBreak >= widget.sessionConfig.breakIntervalMinutes * 60) {
              _isOnBreak = true;
              _timeSinceLastBreak = 0;
              _ytController!.pause();
            }
          }

          if (_isOnBreak) return;

          _secondsElapsed++;
          if (_remainingDurationSeconds > 0) {
            _remainingDurationSeconds--;
          } else {
            _stopSession();
            return;
          }

          // Distraction Logic (now includes No Face detection)
          if (!_isLookingAtScreen || !_isFaceDetected) {
            if (_distractionSeconds < _gracePeriodMax) {
              _distractionSeconds++;
            } else {
                if (!_isDistracted) {
                  _isDistracted = true;
                  _distractionCount++;
                  _handleProgressiveIntervention(); // Progressive system
                  
                  if (_ytController!.value.isPlaying) {
                    _ytController!.pause();
                    _wasPausedByApp = true;
                    HapticFeedback.heavyImpact();
                  }
                }
            }
          } else {
            _isDistracted = false;
            _distractionSeconds = 0;
            if (_wasPausedByApp && _distractionCount < 6) {
              _ytController!.play();
              _wasPausedByApp = false;
            }
          }

          if (!_isDistracted && _isLookingAtScreen && _isFaceDetected) {
            _totalFocusedSeconds++;
          }
          if (_secondsElapsed > 0) {
            _focusScore = (_totalFocusedSeconds / _secondsElapsed) * 100;
          }
        }
      });
    });

    if (!_isCameraInitialized) _initializeCamera();

    // Track active video for history
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) {
       _activeVideo = _searchResults.firstWhere(
        (v) => v.videoId == videoId, 
        orElse: () => YouTubeVideo(
          videoId: videoId, 
          title: _editableTopicController.text.trim(), 
          channelTitle: 'YouTube', 
          thumbnailUrl: '', 
          viewCount: '0', 
          duration: ''
        )
      );
      // Also mark as viewed for general history
      DatabaseService().markVideoAsViewed(_activeVideo!);
    }
  }

  void _handleProgressiveIntervention() {
    if (_distractionCount == 2) {
      // Level 1: Pulse
      setState(() => _showPulse = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showPulse = false);
      });
      HapticFeedback.mediumImpact();
    } else if (_distractionCount == 4) {
      // Level 2: Gentle Nudge
      _showError('Focus check: You seem distracted!');
      HapticFeedback.vibrate();
    } else if (_distractionCount == 6) {
      // Level 3: Hard Pause
      if (_ytController!.value.isPlaying) {
        _ytController!.pause();
        _wasPausedByApp = true;
      }
    } else if (_distractionCount >= 8 && !_hasSuggestedBreak) {
      // Level 4: Compassionate Break
      _showLevel4BreakDialog();
    }
  }

  void _showLevel4BreakDialog() {
    _hasSuggestedBreak = true;
    _ytController?.pause();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Focus Fatigue?'),
        content: const Text('You seem quite distracted. How about a quick break?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _ytController?.play();
            },
            child: const Text('I\'LL FOCUS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isOnBreak = true;
                _timeSinceLastBreak = 0;
              });
            },
            child: const Text('START BREAK'),
          ),
        ],
      ),
    );
  }


  void _stopSession() {
    _timer?.cancel();
    _ytController?.pause();
    if (_isSessionActive) {
      DatabaseService().upsertHistory({
        'date': _sessionStartTime ?? DateTime.now().toIso8601String(),
        'topic': _editableTopicController.text.trim(),
        'videoTitle': _activeVideo?.title ?? 'Unknown Video',
        'durationMinutes': widget.sessionConfig.durationMinutes,
        'secondsElapsed': _secondsElapsed,
        'focusScore': double.parse(_focusScore.toStringAsFixed(1)),
        'grade': _sessionGrade,
        'noteTitle': _noteTitleController.text.trim().isEmpty ? 'Session Note' : _noteTitleController.text.trim(),
        'notes': _notesController.text.trim(),
        'thumbnailUrl': _activeVideo?.thumbnailUrl ?? '',
      });
      _showSessionSummary();
    }
    setState(() => _isSessionActive = false);
  }

  void _showSessionSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Center(child: Text(_sessionGrade, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo))),
              ),
              const SizedBox(height: 16),
              const Text('Session Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(height: 32),
              _buildSummaryRow('Focused Time', _formatTime(_totalFocusedSeconds)),
              _buildSummaryRow('Distractions', '$_distractionCount times'),
              _buildSummaryRow('Focus Score', '${_focusScore.toStringAsFixed(1)}%'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (c) => const MainScreen()), (r) => false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                  child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: TextStyle(color: Colors.grey[600])), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  String _formatTime(int seconds) {
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _loadVideo() {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) _ytController?.load(videoId);
    _checkIfVideoSaved();
  }

  Future<void> _searchYouTube() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final res = await _searchService.searchVideos(query);
      setState(() { _searchResults = res; _isSearching = false; });
      
      // Auto-select first result if session is auto-starting and we have no active video yet
      if (res.isNotEmpty && !_isSessionActive && _activeVideo == null) {
        _selectVideo(res.first);
        // Note: _startSession will be called by _onYoutubePlayerChange once _selectVideo loads the new video
      }
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _selectVideo(YouTubeVideo video) {
    setState(() {
      _activeVideo = video;
      _urlController.text = 'https://www.youtube.com/watch?v=${video.videoId}';
      // _searchResults = []; // REMOVED: keep results so user can swap easily
      // _searchController.clear(); // REMOVED: keep search term visible
      // Optionally update topic with video title if it was empty?
      if (_editableTopicController.text.isEmpty) {
        _editableTopicController.text = video.title;
      }
    });
    _loadVideo();
  }

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ytController?.dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ytController == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return YoutubePlayerBuilder(
      player: YoutubePlayer(controller: _ytController!, showVideoProgressIndicator: true),
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: TextField(
            controller: _editableTopicController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none, suffixIcon: Icon(Icons.edit, color: Colors.white70, size: 16)),
          ),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_showCameraPreview ? Icons.videocam : Icons.videocam_off),
              onPressed: _toggleCamera,
              tooltip: _showCameraPreview ? 'Hide camera' : 'Show camera',
            ),
            if (_showCameraPreview && _isCameraInitialized)
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: _capturePhoto,
                tooltip: 'Capture photo',
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    player,
                    if (_isSessionActive && (_isDistracted || !_isFaceDetected)) 
                      _buildFocusAdaptiveBitrateOverlay(),
                    if (_isDimmed && !(_isDistracted || !_isFaceDetected)) 
                      _buildVisualDriftOverlay(),
                    if (_showPulse) 
                      _buildInterventionPulse(),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDetectionStatus(),
                        const SizedBox(height: 20),
                        if (_isSessionActive) FocusScoreCard(focusScore: _focusScore, sessionStatusText: _formatTime(_remainingDurationSeconds)),
                        const SizedBox(height: 20),
                        VideoSearchInput(
                          searchController: _searchController,
                          isSearching: _isSearching,
                          searchResults: _searchResults,
                          onSearch: _searchYouTube,
                          onSelect: _selectVideo,
                        ),
                        const SizedBox(height: 20),
                        SessionTimerCard(
                          formattedTime: _formatTime(_remainingDurationSeconds),
                          isSessionActive: _isSessionActive,
                          onStart: _startSession,
                          onStop: _stopSession,
                          onToggleSave: _toggleSaveVideo,
                          isSaved: _isVideoSaved,
                        ),
                        const SizedBox(height: 20),
                        _buildNotesSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            CameraPreviewWidget(controller: _cameraController, isFaceDetected: _isFaceDetected, showPreview: _showCameraPreview && _isCameraInitialized),
            if (_isOnBreak) _buildBreakOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualDriftOverlay() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _isDimmed ? 0.7 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Container(color: Colors.black),
      ),
    );
  }

  Widget _buildFocusAdaptiveBitrateOverlay() {
    final isNoFace = !_isFaceDetected;
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNoFace ? Icons.face_retouching_off : Icons.warning_amber_rounded,
                  color: isNoFace ? Colors.redAccent : Colors.amber, 
                  size: 60
                ),
                const SizedBox(height: 16),
                Text(
                  isNoFace ? 'FACE LOST' : 'FOCUS LOST', 
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                ),
                const SizedBox(height: 8),
                const Text(
                  'Video quality restricted until focus regained', 
                  style: TextStyle(color: Colors.white70, fontSize: 12)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionStatus() {
    Color color = Colors.red;
    String text = 'NO FACE';
    IconData icon = Icons.face_retouching_off;

    if (_isFaceDetected) {
      if (_isLookingAtScreen) {
        color = Colors.green; 
        text = 'FOCUSED (EAR: ${_currentEAR.toStringAsFixed(2)})'; 
        icon = Icons.face;
      } else {
        color = Colors.orange;
        text = 'VISUAL DRIFT';
        icon = Icons.visibility_off;
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color), 
              const SizedBox(width: 12), 
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold))
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Using: $_activeModelName', 
            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildInterventionPulse() {
    return Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 15)))));
  }

  Widget _buildBreakOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.blue.withValues(alpha: 0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.coffee, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            const Text('Break Time', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => setState(() => _isOnBreak = false), child: const Text('RESUME')),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Row(children: [Icon(Icons.edit_note, color: Colors.indigo), SizedBox(width: 8), Text('STUDY NOTES', style: TextStyle(fontWeight: FontWeight.bold))]),
              TextButton(onPressed: _saveCurrentNotes, child: const Text('SAVE')),
            ]),
            const Text('THEME (Topic)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
            TextField(
              controller: _editableTopicController,
              decoration: const InputDecoration(
                hintText: 'e.g. Machine Learning',
                border: InputBorder.none,
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 12),
            const Text('NOTE TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
            TextField(
              controller: _noteTitleController,
              decoration: const InputDecoration(
                hintText: 'e.g. Linear Regression',
                hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                border: InputBorder.none,
                filled: true,
                fillColor: Color(0xFFF0F2FF),
              ),
            ),
            const SizedBox(height: 12),
            const Text('CONTENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
            TextField(controller: _notesController, maxLines: 5, decoration: const InputDecoration(hintText: 'Start writing...', border: InputBorder.none, filled: true, fillColor: Color(0xFFFAFAFA))),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentNotes() async {
    final historyRecord = {
      'date': _sessionStartTime ?? DateTime.now().toIso8601String(),
      'topic': _editableTopicController.text.trim(),
      'videoTitle': _activeVideo?.title ?? 'Unknown Video',
      'durationMinutes': widget.sessionConfig.durationMinutes,
      'secondsElapsed': _secondsElapsed,
      'focusScore': double.parse(_focusScore.toStringAsFixed(1)),
      'grade': _sessionGrade,
      'noteTitle': _noteTitleController.text.trim().isEmpty ? 'Untitled Note' : _noteTitleController.text.trim(),
      'notes': _notesController.text.trim(),
      'thumbnailUrl': _activeVideo?.thumbnailUrl ?? '',
    };
    
    await DatabaseService().upsertHistory(historyRecord);
    _showError('Progress and notes saved to Library!');
  }

  void _checkIfVideoSaved() {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) {
      if (mounted) {
        setState(() {
          _isVideoSaved = DatabaseService().isVideoSaved(videoId);
        });
      }
    }
  }

  Future<void> _toggleSaveVideo() async {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) {
       final video = _searchResults.firstWhere(
        (v) => v.videoId == videoId, 
        orElse: () => YouTubeVideo(
          videoId: videoId, 
          title: _editableTopicController.text, 
          channelTitle: 'YouTube', 
          thumbnailUrl: '', 
          viewCount: '0', 
          duration: ''
        )
      );
      
      await DatabaseService().toggleSaveVideo(video);
      _checkIfVideoSaved();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isVideoSaved ? 'Saved to Library' : 'Removed from Library'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
}
