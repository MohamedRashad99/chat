import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Manages an outgoing or incoming voice/video call using Supabase Realtime
/// for signaling and LiveKit for actual Audio/Video streaming.
class CallScreen extends StatefulWidget {
  final Profile peer;
  final String roomId;
  final bool isVideo;
  final bool isCaller;
  final String? incomingSignalId;

  const CallScreen({
    super.key,
    required this.peer,
    required this.roomId,
    required this.isVideo,
    required this.isCaller,
    this.incomingSignalId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _myId = supabase.auth.currentUser!.id;

  CallStatus _status = CallStatus.ringing;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  RealtimeChannel? _channel;

  // LiveKit setup
  late final lk.Room _room;
  late final lk.EventsListener<lk.RoomEvent> _listener;
  lk.VideoTrack? _remoteVideoTrack;

  bool _muted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    _room = lk.Room();
    _subscribeToSignals();
    if (widget.isCaller) _sendOffer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    _disconnectLiveKit();
    super.dispose();
  }

  Future<void> _disconnectLiveKit() async {
    await _listener.dispose();
    await _room.disconnect();
    await _room.dispose();
  }

  // ── signaling ─────────────────────────────────────────────────────────────

  void _subscribeToSignals() {
    _channel = supabase
        .channel('call_signals:${widget.roomId}:${widget.peer.id}:$_myId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'call_signals',
        callback: _handleSignal,
      )
      ..subscribe();
  }

  void _handleSignal(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final type = row['signal_type'] as String?;
    final callerId = row['caller_id'] as String?;
    final calleeId = row['callee_id'] as String?;

    final isForMe = calleeId == _myId || callerId == _myId;
    final isFromPeer = callerId == widget.peer.id || calleeId == widget.peer.id;
    if (!isForMe || !isFromPeer) return;

    switch (type) {
      case 'offer':
        if (!widget.isCaller) {
          setState(() => _status = CallStatus.ringing);
        }
        break;
      case 'answer':
        if (widget.isCaller && mounted) {
          setState(() => _status = CallStatus.connected);
          _startTimer();
          _connectToLiveKit(); // Actual media connection
        }
        break;
      case 'end':
      case 'reject':
        if (mounted) {
          setState(() => _status = type == 'reject'
              ? CallStatus.rejected
              : CallStatus.ended);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
        break;
    }
  }

  Future<void> _sendSignal(String type, {Map<String, dynamic>? data}) async {
    try {
      await supabase.from('call_signals').insert({
        'room_id': widget.roomId,
        'caller_id': _myId,
        'callee_id': widget.peer.id,
        'call_type': widget.isVideo ? 'video' : 'voice',
        'signal_type': type,
        'signal_data': data,
      });
    } catch (e) {
      debugPrint('Signal error: $e');
    }
  }

  Future<void> _sendOffer() async {
    await _sendSignal('offer');
  }

  Future<void> _answer() async {
    setState(() => _status = CallStatus.connected);
    _startTimer();
    await _sendSignal('answer');
    await _connectToLiveKit(); // Actual media connection
  }

  Future<void> _hangUp() async {
    await _sendSignal('end');
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    await _sendSignal('reject');
    if (mounted) Navigator.of(context).pop();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  // ── livekit media connection ──────────────────────────────────────────────

  Future<void> _connectToLiveKit() async {
    // Note: To make this robust in production, you should call a backend endpoint
    // representing an Edge Function that generates a secure LiveKit token.
    // Replace below URL and Token with your generated values or endpoint call!

    const wsUrl = 'wss://YOUR_LIVEKIT_PROJECT_URL.livekit.cloud';
    const token = 'YOUR_GENERATED_LIVEKIT_TOKEN';

    _listener = _room.createListener();

    _listener.on<lk.TrackSubscribedEvent>((e) {
      debugPrint('Track subscribed: ${e.track.kind}');
      if (e.track.kind == lk.TrackType.VIDEO && mounted) {
        setState(() {
          _remoteVideoTrack = e.track as lk.VideoTrack;
        });
      }
    });

    _listener.on<lk.TrackUnsubscribedEvent>((e) {
      if (e.track == _remoteVideoTrack && mounted) {
        setState(() {
          _remoteVideoTrack = null;
        });
      }
    });

    try {
      if (!token.startsWith('YOUR_')) {
        await _room.connect(wsUrl, token);
        await _room.localParticipant?.setMicrophoneEnabled(true);
        if (widget.isVideo) {
          await _room.localParticipant?.setCameraEnabled(true);
        }
      } else {
        debugPrint('---⚠️ LIVEKIT NOT CONFIGURED properly yet! Please add a valid Token and URL.');
      }
    } catch (e) {
      debugPrint('LiveKit Connection Error: $e');
    }
  }

  void _toggleMute() async {
    final newState = !_muted;
    setState(() => _muted = newState);
    if (_room.connectionState == lk.ConnectionState.connected) {
      await _room.localParticipant?.setMicrophoneEnabled(!newState);
    }
  }

  void _toggleCamera() async {
    if (!widget.isVideo) return;
    final newState = !_cameraOff;
    setState(() => _cameraOff = newState);
    if (_room.connectionState == lk.ConnectionState.connected) {
      await _room.localParticipant?.setCameraEnabled(!newState);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  String _formatElapsed() {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(children: [
          // Background UI / Video Renderer
          if (widget.isVideo && _status == CallStatus.connected && _remoteVideoTrack != null)
            Positioned.fill(
              child: lk.VideoTrackRenderer(_remoteVideoTrack!),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A1A2E),
                      AppTheme.accent.withOpacity(0.3),
                      const Color(0xFF1A1A2E),
                    ],
                  ),
                ),
              ),
            ),
          
          // Own Camera PIP (Picture-In-Picture)
          if (widget.isVideo && _status == CallStatus.connected && !_cameraOff && _room.localParticipant?.videoTrackPublications.isNotEmpty == true)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: lk.VideoTrackRenderer(_room.localParticipant!.videoTrackPublications.first.track as lk.VideoTrack),
                ),
              ),
            ),

          // Main Control overlay
          Column(children: [
            const SizedBox(height: 40),

            if (_remoteVideoTrack == null) ...[
              Text(
                widget.isVideo ? 'Video Call' : 'Voice Call',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildAvatar(),
              const SizedBox(height: 20),
              Text(
                widget.peer.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _statusText(),
              const SizedBox(height: 12),
              if (_status == CallStatus.connected)
                Text(
                  _formatElapsed(),
                  style: TextStyle(
                    color: AppTheme.accentLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ] else ...[
              // If video is rendered behind, just display the timer lightly at the top
              Text(
                _formatElapsed(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ],

            const Spacer(),

            if (_status == CallStatus.ringing && !widget.isCaller)
              _incomingControls()
            else if (_status == CallStatus.connected || widget.isCaller)
              _activeControls()
            else
              const SizedBox.shrink(),

            const SizedBox(height: 48),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: widget.peer.avatarUrl != null
            ? Image.network(widget.peer.avatarUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback())
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AppTheme.accent.withOpacity(0.2),
      alignment: Alignment.center,
      child: Text(
        widget.peer.username.isNotEmpty
            ? widget.peer.username[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusText() {
    String text;
    Color color;
    switch (_status) {
      case CallStatus.ringing:
        text = widget.isCaller ? 'Ringing…' : 'Incoming call';
        color = Colors.white70;
        break;
      case CallStatus.connected:
        text = 'Connected';
        color = AppTheme.accentLight;
        break;
      case CallStatus.ended:
        text = 'Call ended';
        color = Colors.white54;
        break;
      case CallStatus.rejected:
        text = 'Call declined';
        color = AppTheme.danger;
        break;
    }
    return Text(text, style: TextStyle(color: color, fontSize: 14));
  }

  Widget _incomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _callButton(
          icon: Icons.call_end,
          color: AppTheme.danger,
          label: 'Decline',
          onTap: _reject,
        ),
        _callButton(
          icon: widget.isVideo ? Icons.videocam : Icons.call,
          color: AppTheme.accentLight,
          label: 'Answer',
          onTap: _answer,
        ),
      ],
    );
  }

  Widget _activeControls() {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toggleButton(
            icon: _muted ? Icons.mic_off : Icons.mic,
            label: _muted ? 'Unmute' : 'Mute',
            active: _muted,
            onTap: _toggleMute,
          ),
          if (widget.isVideo)
            _toggleButton(
              icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
              label: 'Camera',
              active: !_cameraOff,
              onTap: _toggleCamera,
            ),
        ],
      ),
      const SizedBox(height: 32),
      _callButton(
        icon: Icons.call_end,
        color: AppTheme.danger,
        label: 'End Call',
        onTap: _hangUp,
        size: 70,
      ),
    ]);
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    double size = 64,
  }) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.42),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }

  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? Colors.white38 : Colors.white12,
            ),
          ),
          child: Icon(icon,
              color: active ? Colors.white : Colors.white38, size: 24),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}

enum CallStatus { ringing, connected, ended, rejected }
