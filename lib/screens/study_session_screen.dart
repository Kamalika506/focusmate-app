import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/youtube_search_service.dart';
import '../widgets/focus_score_card.dart';
import '../widgets/session_timer_card.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/video_search_input.dart';
import '../services/database_service.dart';


import '../models/session_config.dart';
// import '../models/playlist.dart'; // Removed
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
  
  // Session State
  bool _isSessionActive = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  
  // Attention Logic (Phase 5 & 6)
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

  // ML Kit Face Detection
  late FaceDetector _faceDetector;
  bool _isFaceDetected = false;
  bool _isLookingAtScreen = false;
  bool _isProcessingImage = false;
  
  // Detailed Face Metrics
  double? _headEulerAngleX; // Pitch (up/down)
  double? _headEulerAngleY; // Yaw (left/right)
  double? _headEulerAngleZ; // Roll (tilt)
  double? _leftEyeOpenProb;
  double? _rightEyeOpenProb;

  // YouTube Search (Phase 9)
  final YouTubeSearchService _searchService = YouTubeSearchService();
  List<YouTubeVideo> _searchResults = [];
  bool _isSearching = false;
  late TextEditingController _searchController;
  
  // Phase 11: Session Config State
  late int _remainingDurationSeconds;
  bool _isOnBreak = false;
  int _timeSinceLastBreak = 0;
  
  // Phase 13: Progressive Intervention State
  bool _showPulse = false;
  bool _hasSuggestedBreak = false;
  
  // Phase 12: Save Video State
  bool _isVideoSaved = false;
  
  // Phase 16: Editable Topic
  late TextEditingController _editableTopicController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize Session State (Phase 11)
    _remainingDurationSeconds = widget.sessionConfig.durationMinutes * 60;
    
    _urlController = TextEditingController(text: 'https://www.youtube.com/watch?v=seMVR9lwrjM');
    _searchController = TextEditingController(text: widget.sessionConfig.topic);
    _notesController = TextEditingController();
    _editableTopicController = TextEditingController(text: widget.sessionConfig.topic);
    _initYoutubeController();
    
    // Auto-search if topic provided
    if (widget.sessionConfig.topic.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchYouTube();
      });
    }
    
    // Initialize Face Detector with advanced classification for Phase 4
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        enableClassification: true, // For eye open probability
        enableLandmarks: true, // For pose/landmarks
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  void _initYoutubeController() {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text) ?? '';
    
    // Dispose old controller if exists
    _ytController?.dispose();

    _ytController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
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
        // If playing and we were in a paused state from the app, 
        // reset the flag because the user manually took over
        if (_ytController!.value.isPlaying && _wasPausedByApp) {
          _wasPausedByApp = false;
        }

        // Handle YouTube Errors (Phase 8)
        if (_ytController!.value.hasError) {
          int code = _ytController!.value.errorCode;
          String msg = 'YouTube Error ($code)';
          if (code == 100) msg = 'Video not found or private';
          if (code == 101 || code == 150) msg = 'Embedding not allowed for this video';
          _showError(msg);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCameraStream();
      _cameraController?.dispose();
      setState(() {
        _isCameraInitialized = false;
      });
    } else if (state == AppLifecycleState.resumed && _showCameraPreview) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;
    
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      _showError('Camera features are optimized for Android/iOS.');
      return;
    }

    setState(() => _isInitializingCamera = true);

    try {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _showError('Camera permission is required for focus tracking.');
        setState(() => _isInitializingCamera = false);
        return;
      }

      _cameras = await availableCameras();
      
      if (_cameras.isEmpty) {
        _showError('No cameras found on this device.');
        setState(() => _isInitializingCamera = false);
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
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
      debugPrint('Camera Init Error: $e');
      _showError('Failed to initialize camera.');
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

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage) return;
    _isProcessingImage = true;

    try {
      final InputImage? inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        final List<Face> faces = await _faceDetector.processImage(inputImage);
        if (mounted) {
          setState(() {
            _isFaceDetected = faces.isNotEmpty;
            if (_isFaceDetected) {
              final face = faces.first;
              _headEulerAngleX = face.headEulerAngleX;
              _headEulerAngleY = face.headEulerAngleY;
              _headEulerAngleZ = face.headEulerAngleZ;
              _leftEyeOpenProb = face.leftEyeOpenProbability;
              _rightEyeOpenProb = face.rightEyeOpenProbability;

              // Classification Logic for Phase 4:
              // Looking at screen if:
              // 1. Head angles (Yaw & Pitch) are within ±30 degrees
              // 2. At least one eye is detected open (> 0.4 probability)
              final bool isLookingStraight = (_headEulerAngleY?.abs() ?? 0) < 30 && 
                                           (_headEulerAngleX?.abs() ?? 0) < 30;
              final bool isEyesOpen = (_leftEyeOpenProb ?? 0) > 0.4 || 
                                     (_rightEyeOpenProb ?? 0) > 0.4;
              
              _isLookingAtScreen = isLookingStraight && isEyesOpen;
            } else {
              _isLookingAtScreen = false;
              _headEulerAngleX = null;
              _headEulerAngleY = null;
              _headEulerAngleZ = null;
              _leftEyeOpenProb = null;
              _rightEyeOpenProb = null;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    // This is a simplified conversion. For production, you'd need the full implementation
    // including rotation handling based on the camera description.
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getCameraRotation(),
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  InputImageRotation _getCameraRotation() {
    // Assuming front camera and portrait orientation for now
    // In a full app, you'd calculate this based on device orientation
    return InputImageRotation.rotation270deg;
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
        _headEulerAngleX = null;
        _headEulerAngleY = null;
        _headEulerAngleZ = null;
        _leftEyeOpenProb = null;
        _rightEyeOpenProb = null;
      });
    } else {
      await _initializeCamera();
    }
  }

  void _startSession() {
    if (_ytController == null || !_ytController!.value.isReady) {
      _showError('Waiting for video player to initialize...');
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
    });
    
    _ytController!.play();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_isSessionActive) {
            
            // Check for Break
            if (widget.sessionConfig.breakIntervalMinutes > 0 && !_isOnBreak) {
              _timeSinceLastBreak++;
              if (_timeSinceLastBreak >= widget.sessionConfig.breakIntervalMinutes * 60) {
                _isOnBreak = true;
                _timeSinceLastBreak = 0;
                _ytController!.pause();
                // Play notification sound here if available
              }
            }

            if (_isOnBreak) {
              // Break Logic (Simple countdown for break could be added here, 
              // for now just manual resume or waiting)
              return; 
            }

            // Regular Session Logic
            _secondsElapsed++; // Keep tracking total elapsed
            
            if (_remainingDurationSeconds > 0) {
               _remainingDurationSeconds--;
            } else {
               // Session Complete
               _stopSession();
               // Show completion dialog?
               return;
            }

            // Distraction Logic with Grace Period
            if (!_isLookingAtScreen) {
              if (_distractionSeconds < _gracePeriodMax) {
                _distractionSeconds++;
              } else {
                bool justDistracted = !_isDistracted;
                _isDistracted = true;
                
                // track distraction count
                if (justDistracted) {
                  _distractionCount++;
                  _handleProgressiveIntervention();
                }

                // Auto-Pause
                if (justDistracted && _ytController!.value.isPlaying) {
                  _ytController!.pause();
                  _wasPausedByApp = true;
                  HapticFeedback.heavyImpact();
                }
              }
            } else {
              _distractionSeconds = 0;
              bool justFocused = _isDistracted;
              _isDistracted = false;

              // Auto-Resume
              if (justFocused && _wasPausedByApp) {
                // Only auto-resume if we're not in a hard pause (Level 3 or 4)
                if (_distractionCount < 6) {
                  _ytController!.play();
                  _wasPausedByApp = false;
                }
              }
            }

            // Update Focus Time
            if (!_isDistracted && _isLookingAtScreen) {
              _totalFocusedSeconds++;
            }
            
            // Calculate Focus Score
            if (_secondsElapsed > 0) {
              _focusScore = (_totalFocusedSeconds / _secondsElapsed) * 100;
            }
          }
        });
      }
    });

    if (!_isCameraInitialized) {
      _initializeCamera();
    }

    // Phase 16: Mark video as viewed when session starts
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) {
      final video = _searchResults.firstWhere(
        (v) => v.videoId == videoId, 
        orElse: () => YouTubeVideo(
          videoId: videoId, 
          title: widget.sessionConfig.topic, 
          channelTitle: 'YouTube', 
          thumbnailUrl: '', 
          viewCount: '0', 
          duration: ''
        )
      );
      DatabaseService().markVideoAsViewed(video);
    }
  }

  void _handleProgressiveIntervention() {
    if (_distractionCount == 2) {
      // Level 1: Pulse
      setState(() => _showPulse = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showPulse = false);
      });
    } else if (_distractionCount == 4) {
      // Level 2: Gentle Nudge
      _showError('Focus is slipping! Try taking a deep breath.');
    } else if (_distractionCount == 6) {
      // Level 3: Hard Pause
      // Logic already prevents auto-resume in _startSession
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
        content: const Text('You seem quite distracted. How about a quick 5-minute break to recharge?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _ytController?.play();
            },
            child: const Text('I\'M GOING TO FOCUS'),
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

  void _checkIfVideoSaved() {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) {
      setState(() {
        _isVideoSaved = DatabaseService().isVideoSaved(videoId);
      });
    }
  }

  Future<void> _toggleSaveVideo() async {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null) {
       final video = _searchResults.firstWhere(
        (v) => v.videoId == videoId, 
        orElse: () => YouTubeVideo(
          videoId: videoId, 
          title: widget.sessionConfig.topic, 
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

  // Removed _showAddPlaylistDialog

  void _stopSession() {
    _timer?.cancel();
    if (_ytController != null && _ytController!.value.isReady) {
      _ytController!.pause();
    }
    
    // Show Summary (Phase 7)
    if (_isSessionActive) {
      _isSessionActive = false; // Prevent double save
      // Save History (Phase 11)
      final historyRecord = {
        'date': DateTime.now().toIso8601String(),
        'topic': _editableTopicController.text.trim(),
        'durationMinutes': widget.sessionConfig.durationMinutes,
        'secondsElapsed': _secondsElapsed,
        'focusScore': double.parse(_focusScore.toStringAsFixed(1)),
        'grade': _sessionGrade,
        'notes': _notesController.text.trim(),
      };
      
      DatabaseService().addToHistory(historyRecord).then((_) {
        debugPrint('History saved: $historyRecord');
      });

      _showSessionSummary();
    }

    setState(() {
      _isSessionActive = false;
    });
  }

  Future<void> _saveCurrentNotes() async {
    final historyRecord = {
      'date': DateTime.now().toIso8601String(),
      'topic': _editableTopicController.text.trim(),
      'durationMinutes': widget.sessionConfig.durationMinutes,
      'secondsElapsed': _secondsElapsed,
      'focusScore': double.parse(_focusScore.toStringAsFixed(1)),
      'grade': _sessionGrade,
      'notes': _notesController.text.trim(),
    };
    
    await DatabaseService().addToHistory(historyRecord);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progress and notes saved!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSessionSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _sessionGrade,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Session Summary',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildSummaryRow('Total Session', _formatTime(_secondsElapsed)),
              const Divider(height: 32),
              _buildSummaryRow('Focused Time', _formatTime(_totalFocusedSeconds)),
              const Divider(height: 32),
              _buildSummaryRow('Distractions', '$_distractionCount times'),
              const Divider(height: 32),
              _buildSummaryRow('Final Focus Score', '${_focusScore.toStringAsFixed(1)}%'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('RETURN TO SETUP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  String _formatTime(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _loadVideo() {
    final videoId = YoutubePlayer.convertUrlToId(_urlController.text);
    if (videoId != null && _ytController != null) {
      _ytController!.load(videoId);
    } else {
      _showError('Please enter a valid YouTube URL');
    }
    _checkIfVideoSaved();
  }

  // Phase 9: YouTube Search
  Future<void> _searchYouTube() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showError('Please enter a search topic');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _searchService.searchVideos(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });

        if (results.isEmpty) {
          _showError('No videos found. Try a different search term.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showError('Search failed. Check your API key or internet connection.');
      }
    }
  }

  void _selectVideo(YouTubeVideo video) {
    setState(() {
      _urlController.text = 'https://www.youtube.com/watch?v=${video.videoId}';
      _searchResults = [];
      _searchController.clear();
    });
    _loadVideo();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ytController?.removeListener(_onYoutubePlayerChange);
    _ytController?.dispose();
    _stopCameraStream();
    _cameraController?.dispose();
    _faceDetector.close();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ytController == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.amber,
        onReady: () => debugPrint('YouTube Controller Ready'),
        onEnded: (data) => _stopSession(),
      ),
      builder: (context, player) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            _stopSession();
          },
          child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: TextField(
              controller: _editableTopicController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Session Topic',
                suffixIcon: Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
              ),
            ),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (_isInitializingCamera)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  ),
                )
              else
                IconButton(
                  icon: Icon(_showCameraPreview ? Icons.videocam_rounded : Icons.videocam_off_rounded),
                  onPressed: _toggleCamera,
                  tooltip: 'Toggle Focus Tracking Camera',
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Video Player Section
                  Container(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        player,
                        if (_isSessionActive && _isDistracted)
                          _buildDistractionOverlay(),
                        if (_showPulse)
                          _buildInterventionPulse(),
                      ],
                    ),
                  ),
                  
                  // Content Section
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDetectionStatus(),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
                              },
                              child: _isSessionActive 
                                ? FocusScoreCard(
                                    focusScore: _focusScore,
                                    sessionStatusText: '${_formatTime(_totalFocusedSeconds)} focused of ${_formatTime(_secondsElapsed)}',
                                  ) 
                                : const SizedBox.shrink(),
                            ),
                            if (_isSessionActive) const SizedBox(height: 20),
                            
                            // Video Search
                            VideoSearchInput(
                              searchController: _searchController,
                              isSearching: _isSearching,
                              searchResults: _searchResults,
                              onSearch: _searchYouTube,
                              onSelect: _selectVideo,
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Timer & Controls
                              SessionTimerCard(
                                formattedTime: _formatTime(_remainingDurationSeconds),
                                isSessionActive: _isSessionActive,
                                onStart: _startSession,
                                onStop: _stopSession,
                                onToggleSave: _toggleSaveVideo,
                                isSaved: _isVideoSaved,
                              ),
                            
                            const SizedBox(height: 30),
                            
                            if (_isSessionActive) ...[
                              // Notes & AI (Phase 15)
                              _buildNotesSection(),
                              const SizedBox(height: 30),
                            ],
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Mobile Camera Preview Overlay
              CameraPreviewWidget(
                controller: _cameraController,
                isFaceDetected: _isFaceDetected,
                showPreview: _showCameraPreview && _isCameraInitialized,
              ),

              // Break Overlay
              _buildBreakOverlay(),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildDistractionOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 80),
            ),
            const SizedBox(height: 20),
            const Text(
              'KEEP FOCUS!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Video will resume automatically once you look back at the screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionStatus() {
    Color statusColor = Colors.red;
    String statusText = 'NO FACE DETECTED';
    IconData statusIcon = Icons.face_retouching_off;

    if (_isFaceDetected) {
      if (_isLookingAtScreen) {
        statusColor = Colors.green;
        statusText = 'LOOKING AT SCREEN';
        statusIcon = Icons.face;
      } else {
        // Determine why not looking at screen
        final bool isEyesOpen = (_leftEyeOpenProb ?? 0) > 0.4 || 
                               (_rightEyeOpenProb ?? 0) > 0.4;
        if (!isEyesOpen) {
          statusColor = Colors.orange;
          statusText = 'EYES CLOSED';
          statusIcon = Icons.visibility_off;
        } else {
          statusColor = Colors.amber;
          statusText = 'LOOKING AWAY';
          statusIcon = Icons.remove_red_eye;
        }
        
        // Add countdown if session is active
        if (_isSessionActive && _distractionSeconds > 0 && !_isDistracted) {
          statusText += ' (${_gracePeriodMax - _distractionSeconds}s)';
        }
      }
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (_isFaceDetected) ...[
          const SizedBox(height: 8),
          _buildDebugMetrics(),
        ],
      ],
    );
  }

  Widget _buildDebugMetrics() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _metricText('Yaw: ${_headEulerAngleY?.toStringAsFixed(0)}°'),
          _metricText('Pitch: ${_headEulerAngleX?.toStringAsFixed(0)}°'),
          _metricText('Roll: ${_headEulerAngleZ?.toStringAsFixed(0)}°'),
          _metricText('Eyes: ${(((_leftEyeOpenProb ?? 0) + (_rightEyeOpenProb ?? 0)) / 2 * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _metricText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
    );
  }

  Widget _buildBreakOverlay() {
    if (!_isOnBreak) return const SizedBox.shrink();
    
    return Positioned.fill(
      child: Container(
        color: Colors.blue.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.coffee_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Time for a Break!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Take ${widget.sessionConfig.breakDurationMinutes} minutes to relax.',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isOnBreak = false;
                  _ytController!.play();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('RESUME SESSION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Colors.indigo),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'STUDY NOTES',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _saveCurrentNotes,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('SAVE PROGRESS'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Type your study notes here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildInterventionPulse() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber.withOpacity(0.8),
              width: 15,
            ),
          ),
        ),
      ),
    );
  }
}
