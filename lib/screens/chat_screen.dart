import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/room_tile.dart';
import '../widgets/user_avatar.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ── state ────────────────────────────────────────────────────────────────────
  List<Room> _rooms = [];
  Room? _selectedRoom;
  List<Message> _messages = [];
  List<RoomMember> _members = [];
  Profile? _myProfile;

  bool _loadingRooms = true;
  bool _loadingMessages = false;
  Message? _replyTo;

  // unread counts per room
  final Map<String, int> _unread = {};
  // last message per room
  final Map<String, String> _lastMsg = {};
  final Map<String, DateTime> _lastMsgAt = {};

  RealtimeChannel? _msgChannel;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
    _loadRooms();
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadMyProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final d = await supabase
          .from('profiles').select().eq('id', uid).maybeSingle();
      if (d != null && mounted) setState(() => _myProfile = Profile.fromJson(d));
    } catch (_) {}
  }

  Future<void> _loadRooms() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      // get rooms user is member of
      final memberRows = await supabase
          .from('room_members')
          .select('room_id')
          .eq('user_id', uid!);
      final roomIds = (memberRows as List)
          .map((r) => r['room_id'] as String)
          .toList();

      if (roomIds.isEmpty) {
        if (mounted) setState(() => _loadingRooms = false);
        return;
      }

      final data = await supabase
          .from('rooms')
          .select()
          .inFilter('id', roomIds)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _rooms = (data as List).map((r) => Room.fromJson(r)).toList();
        _loadingRooms = false;
      });

      // fetch last messages
      for (final room in _rooms) {
        _fetchLastMessage(room.id);
      }

      if (_rooms.isNotEmpty && _selectedRoom == null) {
        _selectRoom(_rooms.first);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _fetchLastMessage(String roomId) async {
    try {
      final d = await supabase
          .from('messages')
          .select('content, created_at')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (d != null && mounted) {
        setState(() {
          _lastMsg[roomId] = d['content'] as String? ?? '';
          _lastMsgAt[roomId] =
              DateTime.parse(d['created_at'] as String);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMembers(String roomId) async {
    try {
      final data = await supabase
          .from('room_members')
          .select('*, profiles(username, avatar_url)')
          .eq('room_id', roomId);
      if (mounted) {
        setState(() {
          _members =
              (data as List).map((m) => RoomMember.fromJson(m)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _selectRoom(Room room) async {
    setState(() {
      _selectedRoom = room;
      _loadingMessages = true;
      _messages = [];
      _replyTo = null;
      _unread[room.id] = 0;
    });

    _msgChannel?.unsubscribe();
    await _loadMembers(room.id);

    // history
    try {
      final data = await supabase
          .from('messages')
          .select('*, profiles(username, avatar_url)')
          .eq('room_id', room.id)
          .order('created_at', ascending: true)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _messages =
            (data as List).map((m) => Message.fromJson(m)).toList();
        _loadingMessages = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }

    // realtime
    _msgChannel = supabase.channel('room:${room.id}')
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
          try {
            final p = await supabase
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', row['user_id'])
                .maybeSingle();
            if (p != null) row['profiles'] = p;
          } catch (_) {}
          if (!mounted) return;
          final msg = Message.fromJson(row);
          setState(() {
            _messages.add(msg);
            _lastMsg[room.id] = msg.content;
            _lastMsgAt[room.id] = msg.createdAt;
          });
          _scrollToBottom();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: room.id,
        ),
        callback: (payload) {
          final updated = payload.newRecord;
          if (!mounted) return;
          setState(() {
            final idx = _messages
                .indexWhere((m) => m.id == updated['id']);
            if (idx != -1) {
              final row = Map<String, dynamic>.from(updated);
              row['profiles'] = {
                'username': _messages[idx].username,
                'avatar_url': _messages[idx].avatarUrl,
              };
              _messages[idx] = Message.fromJson(row);
            }
          });
        },
      )
      ..subscribe();
  }

  Future<void> _sendMessage(
    String text,
    List<String> mentionIds,
    bool mentionsAll,
    String? replyToId,
  ) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || _selectedRoom == null) return;

    // find reply content
    String? replyContent;
    String? replyUsername;
    if (replyToId != null) {
      final orig =
          _messages.where((m) => m.id == replyToId).firstOrNull;
      replyContent = orig?.content;
      replyUsername = orig?.username;
    }

    try {
      await supabase.from('messages').insert({
        'room_id': _selectedRoom!.id,
        'user_id': uid,
        'content': text,
        'mentions': mentionIds,
        'mentions_all': mentionsAll,
        'reply_to_id': replyToId,
        'reply_to_content': replyContent,
        'reply_to_username': replyUsername,
      });
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      debugPrint('Send message primary insert failed: $e');
      // Fallback for schemas that don't have optional columns yet.
      try {
        await supabase.from('messages').insert({
          'room_id': _selectedRoom!.id,
          'user_id': uid,
          'content': text,
        });
        if (mounted) setState(() => _replyTo = null);
        debugPrint('Send message fallback insert succeeded.');
        return;
      } catch (fallbackError) {
        debugPrint('Send message fallback insert failed: $fallbackError');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message msg) async {
    try {
      await supabase
          .from('messages')
          .update({'is_deleted': true, 'content': ''})
          .eq('id', msg.id);
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateGroupDialog(
          nameCtrl: nameCtrl, descCtrl: descCtrl),
    );

    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // create room
      final res = await supabase.from('rooms').insert({
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'is_group': true,
        'created_by': uid,
      }).select().single();

      final roomId = res['id'] as String;

      // add creator as admin member
      await supabase.from('room_members').insert({
        'room_id': roomId,
        'user_id': uid,
        'is_admin': true,
      });

      await _loadRooms();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
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
        // sidebar
        if (wide || _selectedRoom == null)
          SizedBox(
            width: wide ? 320 : double.infinity,
            child: _buildSidebar(),
          ),
        // chat
        if (wide || _selectedRoom != null)
          Expanded(child: _buildChatArea(uid, wide)),
      ]),
    );
  }

  // ── sidebar ───────────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      color: AppTheme.surfaceAlt,
      child: Column(children: [
        // top bar
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppTheme.surface,
          child: Row(children: [
            UserAvatar(
              username: _myProfile?.username ?? 'Me',
              avatarUrl: _myProfile?.avatarUrl,
              size: 38,
              isMe: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ONYX IX',
                style: GoogleFonts.notoSans(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _createGroup,
              icon: const Icon(Icons.group_add_outlined,
                  color: AppTheme.textSecondary),
              tooltip: 'New Group',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppTheme.textSecondary),
              color: AppTheme.surface,
              onSelected: (val) {
                if (val == 'signout') supabase.auth.signOut();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'signout',
                  child: Text('Sign out',
                      style: TextStyle(color: AppTheme.textPrimary)),
                ),
              ],
            ),
          ]),
        ),

        // search bar
        Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.inputBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(children: [
              SizedBox(width: 12),
              Icon(Icons.search, color: AppTheme.textMuted, size: 18),
              SizedBox(width: 8),
              Text('Search or start new chat',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 13)),
            ]),
          ),
        ),

        // room list
        Expanded(
          child: _loadingRooms
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent))
              : _rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text('No groups yet',
                              style: TextStyle(color: AppTheme.textMuted)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _createGroup,
                            icon: const Icon(Icons.add, color: AppTheme.accent),
                            label: const Text('Create a group',
                                style: TextStyle(color: AppTheme.accent)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _rooms.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppTheme.border, indent: 78),
                      itemBuilder: (_, i) {
                        final room = _rooms[i];
                        return RoomTile(
                          room: room,
                          isSelected: _selectedRoom?.id == room.id,
                          lastMessage: _lastMsg[room.id],
                          lastMessageAt: _lastMsgAt[room.id],
                          unreadCount: _unread[room.id] ?? 0,
                          onTap: () => _selectRoom(room),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  // ── chat area ─────────────────────────────────────────────────────────────────

  Widget _buildChatArea(String uid, bool wide) {
    if (_selectedRoom == null) {
      return Container(
        color: AppTheme.background,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('Select a group to start chatting',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
          ]),
        ),
      );
    }

    final myUsername = _myProfile?.username ?? '';

    return Column(children: [
      // chat app bar
      Container(
        height: 60,
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          if (!wide)
            IconButton(
              onPressed: () => setState(() => _selectedRoom = null),
              icon: const Icon(Icons.arrow_back,
                  color: AppTheme.textPrimary),
            ),
          // group avatar + info (tappable)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(
                  room: _selectedRoom!,
                  members: _members,
                  isAdmin: _members
                      .where((m) => m.userId == uid)
                      .firstOrNull?.isAdmin ?? false,
                ),
              ),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group,
                    color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedRoom!.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_members.length} members',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ]),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
        ]),
      ),

      // message list — WhatsApp wallpaper background
      Expanded(
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            image: DecorationImage(
              image: NetworkImage(
                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSbUYCNe7GstXUBFFOEsxF09-1sOL0uVquMRA&s'), // fallback
              fit: BoxFit.cover,
              opacity: 0.03,
            ),
          ),
          child: _loadingMessages
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent))
              : _messages.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No messages yet',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        final isMe = msg.userId == uid;
                        final showUsername = !isMe &&
                            (i == 0 ||
                                _messages[i - 1].userId != msg.userId);
                        final mentioned = msg.isMentioned(uid, myUsername);

                        return MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showUsername: showUsername,
                          isMentioned: mentioned,
                          onReply: () =>
                              setState(() => _replyTo = msg),
                          onDelete: () => _deleteMessage(msg),
                        );
                      },
                    ),
        ),
      ),

      // input
      ChatInput(
        members: _members,
        replyTo: _replyTo,
        onCancelReply: () => setState(() => _replyTo = null),
        onSend: _sendMessage,
      ),
    ]);
  }
}

// ── create group dialog ───────────────────────────────────────────────────────

class _CreateGroupDialog extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;

  const _CreateGroupDialog({
    required this.nameCtrl,
    required this.descCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New Group',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: AppTheme.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.group,
                    color: AppTheme.textMuted, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                filled: true,
                fillColor: AppTheme.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
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
          ],
        ),
      ),
    );
  }
}
