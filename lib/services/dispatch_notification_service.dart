import 'dart:async';
import 'dart:collection';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MentionRequest {
  final String targetUser;
  final String senderName;

  _MentionRequest({required this.targetUser, required this.senderName});
}

class DispatchNotificationService {
  static final DispatchNotificationService _instance = DispatchNotificationService._internal();
  factory DispatchNotificationService() => _instance;

  DispatchNotificationService._internal();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  bool _isVoiceEnabled = true;
  DateTime _lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Queue<_MentionRequest> _queue = Queue();
  bool _isPlaying = false;

  // Using Local AssetSource to completely bypass all Web Browser Network/Format Errors!
  final AssetSource _staticSound = AssetSource('sounds/static.mp3');
  final AssetSource _beepSound = AssetSource('sounds/beep.mp3');
  final AssetSource _clickOut = AssetSource('sounds/click.mp3');

  // Arabic pronunciation mapping
  String _getSpokenName(String username) {
    final lower = username.toLowerCase();
    if (lower.contains('omaromar201145')) return 'عمر';
    if (lower.contains('onyx')) return 'رشاد';
    if (lower.contains('mo.nader')) return 'نادر';
    return username.replaceAll('.', ' ').replaceAll('_', ' ');
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isVoiceEnabled = prefs.getBool('enable_dispatch_voice') ?? true;

    // Set Arabic Voice & radio dispatch tone tuning
    await _tts.setLanguage("ar");
    await _tts.setPitch(1.3); 
    await _tts.setSpeechRate(0.5);

    // Handler when TTS concludes speaking
    _tts.setCompletionHandler(() {
      _finishTtsAndContinue();
    });
  }

  bool get isVoiceEnabled => _isVoiceEnabled;

  Future<void> setVoiceEnabled(bool val) async {
    _isVoiceEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_dispatch_voice', val);
  }

  /// Entry point for a Mention Notification
  void playSecurityDispatchAlert({required String myName, required String senderName}) {
    if (!_isVoiceEnabled) return;

    final now = DateTime.now();
    // Cooldown Logic: 5 seconds. Avoids repeating sound spam for rapid mentions.
    if (now.difference(_lastNotificationTime).inSeconds < 5) {
      debugPrint("🔕 Dispatch Notification suppressed due to strict cooldown window.");
      return;
    }
    
    _lastNotificationTime = now;
    _queue.add(_MentionRequest(targetUser: myName, senderName: senderName));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isPlaying || _queue.isEmpty) return;
    _isPlaying = true;

    final req = _queue.removeFirst();
    await _executeDispatchSequence(req.targetUser, req.senderName);
  }

  Completer<void>? _ttsCompleter;

  Future<void> _executeDispatchSequence(String myName, String senderName) async {
    try {
      // 1. Play Pre-communication crackle (Radio Static)
      try {
        await _sfxPlayer.play(_staticSound);
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (_) {}
      
      // 2. Double Alert Beep tone
      try {
        await _sfxPlayer.play(_beepSound);
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (_) {}

      // Convert usernames to spoken Arabic names
      final spokenMyName = _getSpokenName(myName);
      final spokenSenderName = _getSpokenName(senderName);

      // 3. Play Synthetic Arabic TTS Message
      String message = "نداءٌ إلى مستر $spokenMyName... لدَيك منشن جَدِيد من $spokenSenderName";
      _ttsCompleter = Completer<void>();
      await _tts.speak(message);
      
      // Await TTS to finish reading the message
      await _ttsCompleter?.future;

      // 4. End transmission click (optional push-to-talk release)
      try {
        await _sfxPlayer.play(_clickOut);
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}
      
    } catch (e) {
      debugPrint("🔊 Dispatch Service TTS Error: $e");
    } finally {
      // Allow minor buffer before accepting next queue item
      await Future.delayed(const Duration(seconds: 1));
      _isPlaying = false;
      _processQueue();
    }
  }

  void _finishTtsAndContinue() {
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
  }
}
