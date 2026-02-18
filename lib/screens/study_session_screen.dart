import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/youtube_search_service.dart';
import '../services/adaptive_threshold_service.dart';
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

  // ML Kit Face Detection
  late FaceDetector _faceDetector;
  bool _isFaceDetected = false;
  bool _isLookingAtScreen = false;
  bool _isProcessingImage = false;
  
  // Detailed Face Metrics
  double? _headEulerAngleX; // Pitch
  double? _headEulerAngleY; // Yaw
  double? _headEulerAngleZ; // Roll
  double? _leftEyeOpenProb;
  double? _rightEyeOpenProb;

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

  // --- Reinforcement Learning (MAB) State ---
  final AdaptiveThresholdService _mabService = AdaptiveThresholdService();
  final List<double> _focusHistory10 = [];
  int _blinkCount = 0;
  DateTime? _lastBlinkTime;
  final List<double> _yawHistory = [];
  final List<double> _pitchHistory = [];
  MABArm? _currentArm;
  DateTime? _lastInterventionTime;
  List<double>? _lastDecisionContext;
  bool _waitingForReward = false;
  
  // Tracking the active video for history
  YouTubeVideo? _activeVideo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingDurationSeconds = widget.sessionConfig.durationMinutes * 60;
    
    _urlController = TextEditingController(text: 'https://www.youtube.com/watch?v=seMVR9lwrjM');
    _searchController = TextEditingController(text: widget.sessionConfig.topic);
    _notesController = TextEditingController();
    _editableTopicController = TextEditingController(text: widget.sessionConfig.topic);
    _initYoutubeController();
    
    if (widget.sessionConfig.topic.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchYouTube();
      });
    }
    
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        enableClassification: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    // Robust MAB Engine Initialization
    final params = DatabaseService().getMABParams();
    _mabService.init(params['A'] ?? {}, params['b'] ?? {});
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
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopCameraStream();
    } else if (state == AppLifecycleState.resumed && _showCameraPreview) {
      _initializeCamera();
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

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || !mounted) return;
    _isProcessingImage = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);
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

              // Blink Tracking (RL context)
              final currentEyeProb = ((_leftEyeOpenProb ?? 1.0) + (_rightEyeOpenProb ?? 1.0)) / 2;
              if (currentEyeProb < 0.2 && (_lastBlinkTime == null || DateTime.now().difference(_lastBlinkTime!) > const Duration(milliseconds: 500))) {
                _blinkCount++;
                _lastBlinkTime = DateTime.now();
              }

              // Stats for Variance Tracking
              if (_headEulerAngleY != null) {
                _yawHistory.add(_headEulerAngleY!);
                if (_yawHistory.length > 30) _yawHistory.removeAt(0);
              }

              // Adaptive Threshold Logic
              final double threshold = _currentArm?.threshold ?? 0.4;
              final double headLimit = 60.0 - (threshold * 50); 
              
              final bool isLookingStraight = (_headEulerAngleY?.abs() ?? 0) < headLimit && 
                                           (_headEulerAngleX?.abs() ?? 0) < headLimit;
                                           
              final bool isEyesOpen = (_leftEyeOpenProb ?? 0) > threshold || 
                                     (_rightEyeOpenProb ?? 0) > threshold;
              
              _isLookingAtScreen = isLookingStraight && isEyesOpen;
            } else {
              _isLookingAtScreen = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('ML Process Error: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) allBytes.putUint8List(plane.bytes);
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      return null;
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

  void _startSession() {
    if (_ytController == null || !_ytController!.value.isReady) {
      _showError('Video player not ready');
      return;
    }

    _makeMABDecision(); // Initial RL decision

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

          // Distraction Logic
          if (!_isLookingAtScreen) {
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
                  _makeMABDecision(); 
                }
            }
          } else {
            // Reward Signal Check
            if (_isDistracted && _waitingForReward && _lastInterventionTime != null) {
              if (DateTime.now().difference(_lastInterventionTime!).inSeconds < 15) {
                _provideMABReward(1.0);
              }
            }
            _isDistracted = false;
            _distractionSeconds = 0;
            if (_wasPausedByApp && _distractionCount < 6) {
              _ytController!.play();
              _wasPausedByApp = false;
            }
          }

          // Timeout Reward signal
          if (_waitingForReward && _lastInterventionTime != null) {
            if (DateTime.now().difference(_lastInterventionTime!).inSeconds >= 15) {
              _provideMABReward(0.0);
            }
          }

          if (!_isDistracted && _isLookingAtScreen) {
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

  void _makeMABDecision() {
    double yawVar = 0;
    if (_yawHistory.length > 1) {
      final mean = _yawHistory.reduce((a, b) => a + b) / _yawHistory.length;
      yawVar = _yawHistory.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / _yawHistory.length;
    }

    final List<double> context = [
      _focusScore / 100.0,
      1.0, 
      min(_blinkCount / 20.0, 1.0),
      min(yawVar / 100.0, 1.0),
      min(_secondsElapsed / 3600.0, 1.0),
      (DateTime.now().hour / 24.0),
      min(_distractionCount / 10.0, 1.0),
    ];

    _currentArm = _mabService.selectArm(context);
    _lastDecisionContext = context;
    _lastInterventionTime = DateTime.now();
    _waitingForReward = true;
    _executeArmAction(_currentArm!);
    _blinkCount = 0;
  }

  void _executeArmAction(MABArm arm) {
    debugPrint('Executing Arm: ${arm.interventionType}');
    switch (arm.interventionType) {
      case 'pulse':
        setState(() => _showPulse = true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _showPulse = false);
        });
        HapticFeedback.mediumImpact();
        break;
      case 'nudge':
        _showError('Focus check: Stay on track!');
        HapticFeedback.vibrate();
        break;
      case 'hard_pause':
        if (_ytController!.value.isPlaying) {
          _ytController!.pause();
          _wasPausedByApp = true;
        }
        break;
      case 'none':
      default:
        break;
    }
  }

  void _provideMABReward(double reward) {
    if (_currentArm != null && _lastDecisionContext != null) {
      _mabService.update(_currentArm!.id, _lastDecisionContext!, reward);
      DatabaseService().saveMABParams(_mabService.A, _mabService.b);
    }
    _waitingForReward = false;
  }

  void _stopSession() {
    _timer?.cancel();
    _ytController?.pause();
    if (_isSessionActive) {
      DatabaseService().addToHistory({
        'date': DateTime.now().toIso8601String(),
        'topic': _editableTopicController.text.trim(),
        'videoTitle': _activeVideo?.title ?? 'Unknown Video',
        'durationMinutes': widget.sessionConfig.durationMinutes,
        'secondsElapsed': _secondsElapsed,
        'focusScore': double.parse(_focusScore.toStringAsFixed(1)),
        'grade': _sessionGrade,
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
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
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
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _selectVideo(YouTubeVideo video) {
    setState(() {
      _activeVideo = video;
      _urlController.text = 'https://www.youtube.com/watch?v=${video.videoId}';
      _searchResults = [];
      _searchController.clear();
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
          actions: [IconButton(icon: Icon(_showCameraPreview ? Icons.videocam : Icons.videocam_off), onPressed: _toggleCamera)],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    player,
                    if (_isSessionActive && _isDistracted) _buildDistractionOverlay(),
                    if (_showPulse) _buildInterventionPulse(),
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

  Widget _buildDistractionOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 80),
            const SizedBox(height: 20),
            const Text('KEEP FOCUS!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            const Text('Look back at the screen to resume.', style: TextStyle(color: Colors.white70)),
          ],
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
        color = Colors.green; text = 'FOCUSING'; icon = Icons.face;
      } else {
        final eyesOpen = (_leftEyeOpenProb ?? 0) > 0.4 || (_rightEyeOpenProb ?? 0) > 0.4;
        color = eyesOpen ? Colors.amber : Colors.orange;
        text = eyesOpen ? 'LOOKING AWAY' : 'EYES CLOSED';
        icon = eyesOpen ? Icons.remove_red_eye : Icons.visibility_off;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, color: color), const SizedBox(width: 12), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold))],
      ),
    );
  }

  Widget _buildInterventionPulse() {
    return Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 15)))));
  }

  Widget _buildBreakOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.blue.withOpacity(0.9),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.indigo.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Row(children: [Icon(Icons.edit_note, color: Colors.indigo), SizedBox(width: 8), Text('STUDY NOTES', style: TextStyle(fontWeight: FontWeight.bold))]),
              TextButton(onPressed: _saveCurrentNotes, child: const Text('SAVE')),
            ]),
            TextField(controller: _notesController, maxLines: 5, decoration: const InputDecoration(hintText: 'Notes...', border: InputBorder.none, filled: true, fillColor: Color(0xFFFAFAFA))),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentNotes() async {
    final historyRecord = {
      'date': DateTime.now().toIso8601String(),
      'topic': _editableTopicController.text.trim(),
      'videoTitle': _activeVideo?.title ?? 'Unknown Video',
      'durationMinutes': widget.sessionConfig.durationMinutes,
      'secondsElapsed': _secondsElapsed,
      'focusScore': double.parse(_focusScore.toStringAsFixed(1)),
      'grade': _sessionGrade,
      'notes': _notesController.text.trim(),
      'thumbnailUrl': _activeVideo?.thumbnailUrl ?? '',
    };
    
    await DatabaseService().addToHistory(historyRecord);
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
