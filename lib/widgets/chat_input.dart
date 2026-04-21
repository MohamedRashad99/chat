import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:io';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ChatInput extends StatefulWidget {
  final List<RoomMember> members;
  final Message? replyTo;
  final VoidCallback? onCancelReply;
  final Future<void> Function(String text, List<String> mentionIds, bool mentionsAll,
      String? replyToId) onSend;

  const ChatInput({
    super.key,
    required this.members,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  List<RoomMember> _suggestions = [];
  bool _showSuggestions = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  bool _hasText = false;
  DateTime? _recordStartedAt;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    final hasText = val.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
    // detect @mention trigger
    final cursor = _ctrl.selection.baseOffset;
    if (cursor <= 0) {
      _hideSuggestions();
      return;
    }
    final textBefore = val.substring(0, cursor);
    final atIdx = textBefore.lastIndexOf('@');
    if (atIdx == -1) {
      _hideSuggestions();
      return;
    }
    final query = textBefore.substring(atIdx + 1).toLowerCase();
    // only show if no space in query
    if (query.contains(' ')) {
      _hideSuggestions();
      return;
    }

    // build suggestions: @all first, then members
    final filtered = <RoomMember>[];
    // virtual @all entry — represented as member with userId='__all__'
    if ('all'.startsWith(query)) {
      filtered.add(RoomMember(
        userId: '__all__',
        roomId: '',
        username: 'all',
        isAdmin: false,
      ));
    }
    for (final m in widget.members) {
      if (m.username.toLowerCase().startsWith(query)) {
        filtered.add(m);
      }
    }

    setState(() {
      _suggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _hideSuggestions() {
    if (_showSuggestions) setState(() => _showSuggestions = false);
  }

  void _insertMention(RoomMember member) {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    final textBefore = text.substring(0, cursor);
    final atIdx = textBefore.lastIndexOf('@');
    final after = text.substring(cursor);
    final replacement = '@${member.username} ';
    final newText = textBefore.substring(0, atIdx) + replacement + after;
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: atIdx + replacement.length,
      ),
    );
    _hideSuggestions();
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    // parse mentions from text
    final mentionIds = <String>[];
    bool mentionsAll = false;
    final pattern = RegExp(r'@(\w+)', caseSensitive: false);
    for (final m in pattern.allMatches(text)) {
      final name = m.group(1)!.toLowerCase();
      if (name == 'all') {
        mentionsAll = true;
      } else {
        final member = widget.members
            .where((mem) => mem.username.toLowerCase() == name)
            .firstOrNull;
        if (member != null && !mentionIds.contains(member.userId)) {
          mentionIds.add(member.userId);
        }
      }
    }

    try {
      await widget.onSend(
        text,
        mentionIds,
        mentionsAll,
        widget.replyTo?.id,
      );
      _ctrl.clear();
      _hasText = false;
      _hideSuggestions();
      if (mounted) setState(() => _showEmojiPicker = false);
    } catch (e, st) {
      debugPrint('Send message error (chat_input): $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> _pickImageAndSend() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final ext = image.path.contains('.') ? image.path.split('.').last : 'jpg';
      final key =
          'chat/${DateTime.now().millisecondsSinceEpoch}_${image.name}.$ext';
      await supabase.storage.from('chat-media').uploadBinary(key, bytes);
      final url = supabase.storage.from('chat-media').getPublicUrl(key);
      await widget.onSend(
        '[image]|${image.name}|$url',
        const [],
        false,
        widget.replyTo?.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image send failed: $e')),
      );
    }
  }

  Future<void> _pickFromCameraAndSend() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final ext = image.path.contains('.') ? image.path.split('.').last : 'jpg';
      final key =
          'chat/${DateTime.now().millisecondsSinceEpoch}_${image.name}.$ext';
      await supabase.storage.from('chat-media').uploadBinary(key, bytes);
      final url = supabase.storage.from('chat-media').getPublicUrl(key);
      await widget.onSend(
        '[image]|${image.name}|$url',
        const [],
        false,
        widget.replyTo?.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera send failed: $e')),
      );
    }
  }

  Future<void> _pickFileAndSend() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      final data = file.bytes ?? await File(file.path!).readAsBytes();
      final key = 'chat/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('chat-media').uploadBinary(key, data);
      final url = supabase.storage.from('chat-media').getPublicUrl(key);
      await widget.onSend(
        '[file]|${file.name}|$url',
        const [],
        false,
        widget.replyTo?.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File send failed: $e')),
      );
    }
  }

  Future<void> _toggleRecordVoice() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      final startedAt = _recordStartedAt;
      setState(() {
        _isRecording = false;
        _recordStartedAt = null;
      });
      if (path == null || startedAt == null) return;
      final seconds = DateTime.now().difference(startedAt).inSeconds;
      await widget.onSend('[voice] ${seconds}s', const [], false, widget.replyTo?.id);
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final filePath =
        '${tmpDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: filePath,
    );
    setState(() {
      _isRecording = true;
      _recordStartedAt = DateTime.now();
    });
  }

  void _onEmojiSelected(Emoji emoji) {
    final cursor = _ctrl.selection.baseOffset;
    final text = _ctrl.text;
    if (cursor < 0 || cursor > text.length) {
      _ctrl.text = '$text${emoji.emoji}';
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    } else {
      final newText = text.replaceRange(cursor, cursor, emoji.emoji);
      _ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + emoji.emoji.length),
      );
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // mention suggestions popup
      if (_showSuggestions)
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suggestions.length,
            itemBuilder: (_, i) {
              final m = _suggestions[i];
              final isAll = m.userId == '__all__';
              return InkWell(
                onTap: () => _insertMention(m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isAll ? Icons.group : Icons.person,
                        color: AppTheme.accent, size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAll ? '@all' : '@${m.username}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isAll)
                          const Text(
                            'Notify all members',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                      ],
                    ),
                  ]),
                ),
              );
            },
          ),
        ),

      // reply preview bar
      if (widget.replyTo != null)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              top: BorderSide(color: AppTheme.border),
              left: BorderSide(color: AppTheme.accent, width: 3),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.replyTo!.username ?? 'Unknown',
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    widget.replyTo!.isDeleted
                        ? 'Deleted message'
                        : widget.replyTo!.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onCancelReply,
              icon: const Icon(Icons.close,
                  size: 18, color: AppTheme.textSecondary),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ),

      // main input row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: AppTheme.surfaceAlt,
        child: Row(children: [
          // text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.inputBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: AppTheme.textMuted, size: 22),
                  splashRadius: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _send(),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _pickFileAndSend,
                  icon: const Icon(Icons.attach_file,
                      color: AppTheme.textMuted, size: 22),
                  splashRadius: 18,
                ),
                IconButton(
                  onPressed: _pickImageAndSend,
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: AppTheme.textMuted, size: 22),
                  splashRadius: 18,
                  tooltip: 'Gallery',
                ),
                IconButton(
                  onPressed: _pickFromCameraAndSend,
                  icon: const Icon(Icons.photo_camera_outlined,
                      color: AppTheme.textMuted, size: 22),
                  splashRadius: 18,
                  tooltip: 'Camera',
                ),
                const SizedBox(width: 10),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // send button
          GestureDetector(
            onTap: _hasText ? _send : _toggleRecordVoice,
            child: Container(
              width: 46, height: 46,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasText ? Icons.send : (_isRecording ? Icons.stop : Icons.mic),
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ]),
      ),
      if (_showEmojiPicker)
        SizedBox(
          height: 280,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) => _onEmojiSelected(emoji),
            config: const Config(
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: AppTheme.surface,
                emojiSizeMax: 26,
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: AppTheme.surfaceAlt,
                iconColor: AppTheme.textMuted,
                iconColorSelected: AppTheme.accent,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: AppTheme.surfaceAlt,
                buttonColor: AppTheme.accent,
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: AppTheme.surface,
                buttonIconColor: AppTheme.textMuted,
              ),
            ),
          ),
        ),
    ]);
  }
}
