import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ChatInput extends StatefulWidget {
  final List<RoomMember> members;
  final Message? replyTo;
  final VoidCallback? onCancelReply;
  final Future<void> Function(
    String text,
    List<String> mentionIds,
    bool mentionsAll,
    String? replyToId,
    String? imageUrl,
  ) onSend;

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
  final _ctrl   = TextEditingController();
  final _focus  = FocusNode();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  List<RoomMember> _suggestions = [];
  bool _showSuggestions = false;
  bool _showEmojiPicker = false;
  bool _isRecording    = false;
  bool _uploadingImage = false;
  DateTime? _recordStartedAt;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── mention autocomplete ──────────────────────────────────────────────────

  void _onChanged(String val) {
    final cursor = _ctrl.selection.baseOffset;
    if (cursor <= 0) { _hideSuggestions(); return; }
    final textBefore = val.substring(0, cursor);
    final atIdx = textBefore.lastIndexOf('@');
    if (atIdx == -1) { _hideSuggestions(); return; }
    final query = textBefore.substring(atIdx + 1).toLowerCase();
    if (query.contains(' ')) { _hideSuggestions(); return; }

    final filtered = <RoomMember>[];
    if ('all'.startsWith(query)) {
      filtered.add(RoomMember(userId: '__all__', roomId: '', username: 'all'));
    }
    for (final m in widget.members) {
      if (m.username.toLowerCase().startsWith(query)) filtered.add(m);
    }
    setState(() {
      _suggestions   = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _hideSuggestions() {
    if (_showSuggestions) setState(() => _showSuggestions = false);
  }

  void _insertMention(RoomMember member) {
    final text   = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIdx  = before.lastIndexOf('@');
    final after  = text.substring(cursor);
    final rep    = '@${member.username} ';
    final newText = before.substring(0, atIdx) + rep + after;
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIdx + rep.length),
    );
    _hideSuggestions();
    _focus.requestFocus();
  }

  // ── send text ─────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final mentionIds  = <String>[];
    bool mentionsAll  = false;
    final pattern     = RegExp(r'@(\w+)', caseSensitive: false);
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

    _ctrl.clear();
    _hideSuggestions();
    if (mounted) setState(() => _showEmojiPicker = false);

    try {
      await widget.onSend(text, mentionIds, mentionsAll, widget.replyTo?.id, null);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  // ── upload image → send ───────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() => _uploadingImage = true);
    try {
      final uid   = supabase.auth.currentUser!.id;
      final bytes = await image.readAsBytes();

      // Determine MIME type safely — never parse the path on web (blob URLs)
      final mimeType = image.mimeType ?? 'image/jpeg';
      // Derive extension from MIME, fallback to jpg
      final ext = mimeType.contains('png')
          ? 'png'
          : mimeType.contains('webp')
              ? 'webp'
              : mimeType.contains('gif')
                  ? 'gif'
                  : 'jpg';
      final key = 'chat/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('chat-images').uploadBinary(
        key, bytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: false,
        ),
      );

      final publicUrl =
          supabase.storage.from('chat-images').getPublicUrl(key);

      await widget.onSend('', const [], false, widget.replyTo?.id, publicUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e'),
            backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ── voice recording ───────────────────────────────────────────────────────

  Future<void> _toggleRecordVoice() async {
    if (_isRecording) {
      final path       = await _audioRecorder.stop();
      final startedAt  = _recordStartedAt;
      setState(() { _isRecording = false; _recordStartedAt = null; });
      if (path == null || startedAt == null) return;
      final seconds = DateTime.now().difference(startedAt).inSeconds;
      await widget.onSend('[voice] ${seconds}s', const [], false,
          widget.replyTo?.id, null);
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    final tmpDir   = await getTemporaryDirectory();
    final filePath =
        '${tmpDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: filePath,
    );
    setState(() { _isRecording = true; _recordStartedAt = DateTime.now(); });
  }

  void _onEmojiSelected(Emoji emoji) {
    final cursor  = _ctrl.selection.baseOffset;
    final text    = _ctrl.text;
    final newText = cursor < 0 || cursor > text.length
        ? '$text${emoji.emoji}'
        : text.replaceRange(cursor, cursor, emoji.emoji);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: (cursor < 0 ? text.length : cursor) + emoji.emoji.length),
    );
    _focus.requestFocus();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final surfaceColor   = AppTheme.surfaceColor(context);
    final surfaceAltColor = AppTheme.surfaceAltColor(context);
    final inputBgColor   = AppTheme.inputBgColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(mainAxisSize: MainAxisSize.min, children: [

      // mention suggestions
      if (_showSuggestions)
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(isAll ? Icons.group : Icons.person,
                          color: AppTheme.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(isAll ? '@all' : '@${m.username}',
                        style: TextStyle(
                          color: AppTheme.primaryText(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                  ]),
                ),
              );
            },
          ),
        ),

      // reply preview
      if (widget.replyTo != null)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(
              top: BorderSide(color: AppTheme.borderColor(context)),
              left: const BorderSide(color: AppTheme.accent, width: 3),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.replyTo!.username ?? 'Unknown',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text(
                    widget.replyTo!.isDeleted
                        ? 'Deleted message'
                        : widget.replyTo!.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.secondaryText(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onCancelReply,
              icon: Icon(Icons.close, size: 18,
                  color: AppTheme.secondaryText(context)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ),

      // main input row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: surfaceAltColor,
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () =>
                      setState(() => _showEmojiPicker = !_showEmojiPicker),
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: AppTheme.textMuted, size: 22),
                  splashRadius: 18,
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _send(),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                        color: AppTheme.primaryText(context), fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                // image upload button
                if (_uploadingImage)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent),
                  )
                else
                  IconButton(
                    onPressed: _pickAndUploadImage,
                    icon: const Icon(Icons.image_outlined,
                        color: AppTheme.textMuted, size: 22),
                    splashRadius: 18,
                    tooltip: 'Send image',
                  ),
                const SizedBox(width: 6),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // send / mic button
          ListenableBuilder(
            listenable: _ctrl,
            builder: (_, __) {
              final hasText = _ctrl.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _send : _toggleRecordVoice,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _isRecording ? AppTheme.danger : AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasText
                        ? Icons.send
                        : (_isRecording ? Icons.stop : Icons.mic),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ]),
      ),

      // emoji picker
      if (_showEmojiPicker)
        SizedBox(
          height: 280,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) => _onEmojiSelected(emoji),
            config: Config(
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: surfaceColor,
                emojiSizeMax: 26,
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: surfaceAltColor,
                iconColor: AppTheme.textMuted,
                iconColorSelected: AppTheme.accent,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: surfaceAltColor,
                buttonColor: AppTheme.accent,
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: surfaceColor,
                buttonIconColor: AppTheme.textMuted,
              ),
            ),
          ),
        ),
    ]);
  }
}
