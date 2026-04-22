import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Manages an outgoing or incoming voice/video call using Supabase Realtime
/// for signaling. Each side listens to the call_signals table and exchanges
/// offer / answer / ice-candidate / end / reject events.
class CallScreen extends StatefulWidget {
  final Profile peer;           // the other person
  final String roomId;          // chat room context
  final bool isVideo;           // voice vs video
  final bool isCaller;          // true = I initiated the call
  final String? incomingSignalId; // set when answering an incoming call

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
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    _subscribeToSignals();
    if (widget.isCaller) _sendOffer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
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

    // Only process signals addressed to me
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

  String _formatElapsed() {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(children: [
          // Background gradient
          Container(
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

          Column(children: [
            const SizedBox(height: 40),

            // Call type label
            Text(
              widget.isVideo ? 'Video Call' : 'Voice Call',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Peer avatar
            Container(
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
            ),
            const SizedBox(height: 20),

            // Peer name
            Text(
              widget.peer.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Status text
            _statusText(),
            const SizedBox(height: 12),

            // Timer (when connected)
            if (_status == CallStatus.connected)
              Text(
                _formatElapsed(),
                style: TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

            const Spacer(),

            // Controls
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

  // For incoming call: answer or reject
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

  // During active call
  Widget _activeControls() {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toggleButton(
            icon: _muted ? Icons.mic_off : Icons.mic,
            label: _muted ? 'Unmute' : 'Mute',
            active: _muted,
            onTap: () => setState(() => _muted = !_muted),
          ),
          _toggleButton(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
            label: 'Speaker',
            active: _speakerOn,
            onTap: () => setState(() => _speakerOn = !_speakerOn),
          ),
          if (widget.isVideo)
            _toggleButton(
              icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
              label: 'Camera',
              active: !_cameraOff,
              onTap: () => setState(() => _cameraOff = !_cameraOff),
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
