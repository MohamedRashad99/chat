import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/room_tile.dart';
import '../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Room> _rooms = [];
  List<Message> _messages = [];
  Room? _selectedRoom;
  Profile? _profile;
  bool _loadingRooms = true;
  bool _loadingMessages = false;
  RealtimeChannel? _channel;

  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRooms();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── data ────────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _profile = Profile.fromJson(data));
      }
    } catch (_) {}
  }

  Future<void> _loadRooms() async {
    try {
      final data = await supabase
          .from('rooms')
          .select()
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _rooms = (data as List).map((r) => Room.fromJson(r)).toList();
        _loadingRooms = false;
      });
      if (_rooms.isNotEmpty) _selectRoom(_rooms.first);
    } catch (_) {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _selectRoom(Room room) async {
    setState(() {
      _selectedRoom = room;
      _loadingMessages = true;
      _messages = [];
    });

    _channel?.unsubscribe();

    // fetch history
    try {
      final data = await supabase
          .from('messages')
          .select('*, profiles(username, avatar_url)')
          .eq('room_id', room.id)
          .order('created_at', ascending: true)
          .limit(100);
      if (mounted) {
        setState(() {
          _messages =
              (data as List).map((m) => Message.fromJson(m)).toList();
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }

    // realtime subscription
    _channel = supabase.channel('room:${room.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: room.id,
        ),
        callback: (payload) async {
          final row = Map<String, dynamic>.from(payload.newRecord);
          // fetch profile for sender
          try {
            final p = await supabase
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', row['user_id'])
                .maybeSingle();
            if (p != null) row['profiles'] = p;
          } catch (_) {}
          if (mounted) {
            setState(() => _messages.add(Message.fromJson(row)));
            _scrollToBottom();
          }
        },
      )
      ..subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _selectedRoom == null) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _msgCtrl.clear();
    try {
      await supabase.from('messages').insert({
        'room_id': _selectedRoom!.id,
        'user_id': uid,
        'content': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Send failed: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _NewRoomDialog(nameCtrl: nameCtrl, descCtrl: descCtrl),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await supabase.from('rooms').insert({
          'name': nameCtrl.text.trim(),
          'description': descCtrl.text.trim(),
        });
        _loadRooms();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    final uid = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(children: [
        // sidebar always visible on wide; only when no room selected on narrow
        if (wide || _selectedRoom == null)
          SizedBox(
            width: wide ? 240 : double.infinity,
            child: _buildSidebar(),
          ),

        // chat area
        if (wide || _selectedRoom != null)
          Expanded(child: _buildChat(uid, wide)),
      ]),
    );
  }

  // ── sidebar ──────────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(children: [
        // brand header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentGlow]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hexagon_outlined,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Text(
              'ONYX IX',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary, letterSpacing: 2.5,
              ),
            ),
          ]),
        ),

        // channels header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
          child: Row(children: [
            Expanded(
              child: Text(
                'CHANNELS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted, letterSpacing: 1.5,
                ),
              ),
            ),
            IconButton(
              onPressed: _createRoom,
              icon: const Icon(Icons.add, size: 16,
                  color: AppTheme.textSecondary),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'New channel',
            ),
          ]),
        ),

        // room list
        Expanded(
          child: _loadingRooms
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _rooms.length,
                  itemBuilder: (_, i) => RoomTile(
                    room: _rooms[i],
                    isSelected: _selectedRoom?.id == _rooms[i].id,
                    onTap: () => _selectRoom(_rooms[i]),
                  ),
                ),
        ),

        // user footer
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.cardBg,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            UserAvatar(
                username: _profile?.username ?? 'User', size: 30),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _profile?.username ?? 'User',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => supabase.auth.signOut(),
              icon: const Icon(Icons.logout_rounded,
                  size: 15, color: AppTheme.textMuted),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'Sign out',
            ),
          ]),
        ),
      ]),
    );
  }

  // ── chat area ────────────────────────────────────────────────────────────────

  Widget _buildChat(String uid, bool wide) {
    if (_selectedRoom == null) {
      return const Center(
        child: Text('Select a channel',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return Column(children: [
      // chat header
      Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          // back button on narrow
          if (!wide)
            IconButton(
              onPressed: () => setState(() => _selectedRoom = null),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppTheme.textSecondary),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          const Icon(Icons.tag, size: 15, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            _selectedRoom!.name,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          if (_selectedRoom!.description != null) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 14, color: AppTheme.border),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedRoom!.description!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
          ] else
            const Spacer(),

          // live indicator
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: AppTheme.online,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppTheme.online.withOpacity(0.45),
                    blurRadius: 5)
              ],
            ),
          ),
          const SizedBox(width: 5),
          const Text('Live',
              style: TextStyle(color: AppTheme.online, fontSize: 10)),
        ]),
      ),

      // messages
      Expanded(
        child: _loadingMessages
            ? const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent))
            : _messages.isEmpty
                ? const Center(
                    child: Text('No messages yet — say something!',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 13)),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg.userId == uid;
                      final showHeader = i == 0 ||
                          _messages[i - 1].userId != msg.userId;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        showHeader: showHeader,
                      );
                    },
                  ),
      ),

      // input
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Message #${_selectedRoom?.name}',
                  hintStyle: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42, height: 42,
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded,
                  color: AppTheme.accent, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.accentSoft,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── create room dialog ────────────────────────────────────────────────────────

class _NewRoomDialog extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;

  const _NewRoomDialog({
    required this.nameCtrl,
    required this.descCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text(
            'Create Channel',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Channel name',
              prefixIcon: Icon(Icons.tag, size: 16,
                  color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
                hintText: 'Description (optional)'),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ]),
        ]),
      ),
    );
  }
}
