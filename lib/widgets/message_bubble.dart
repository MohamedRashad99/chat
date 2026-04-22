import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'mention_text.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showUsername;
  final bool isMentioned;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showUsername = true,
    this.isMentioned = false,
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());
    final bubbleBg = isMe
        ? AppTheme.bubbleMeColor(context)
        : AppTheme.bubbleOtherColor(context);
    final textColor = isMe
        ? AppTheme.bubbleMeTextColor(context)
        : AppTheme.bubbleOtherTextColor(context);

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Container(
        color: isMentioned
            ? AppTheme.mentionBg.withOpacity(0.35)
            : Colors.transparent,
        padding: EdgeInsets.only(
          left: isMe ? 60 : 8,
          right: isMe ? 8 : 60,
          top: showUsername ? 6 : 2,
          bottom: 2,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(8),
                topRight: const Radius.circular(8),
                bottomLeft: Radius.circular(isMe ? 8 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 3, offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.replyToId != null) _buildReplyPreview(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showUsername && !isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            message.username ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _usernameColor(message.username ?? ''),
                            ),
                          ),
                        ),

                      if (message.isDeleted)
                        Row(children: [
                          const Icon(Icons.block, size: 14,
                              color: AppTheme.textMuted),
                          const SizedBox(width: 5),
                          const Text('This message was deleted',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              )),
                        ])
                      else
                        _buildContent(context, textColor),

                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Spacer(),
                          Text(time,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.done_all,
                                size: 14, color: AppTheme.accent),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    // Real image from Supabase Storage
    if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          message.imageUrl!,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 220, height: 150,
              color: AppTheme.inputBg,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: 220, height: 80,
            color: AppTheme.inputBg,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image,
                color: AppTheme.textMuted),
          ),
        ),
      );
    }

    // Legacy text-based markers
    if (message.content.startsWith('[voice] ')) {
      final dur = message.content.replaceFirst('[voice] ', '');
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.mic, size: 16, color: AppTheme.accent),
        const SizedBox(width: 6),
        Text('Voice note ($dur)',
            style: TextStyle(color: textColor, fontSize: 14)),
      ]);
    }
    if (message.content.startsWith('[file] ')) {
      final name = message.content.replaceFirst('[file] ', '');
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.attach_file, size: 16, color: AppTheme.accent),
        const SizedBox(width: 6),
        Flexible(child: Text(name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: 14))),
      ]);
    }

    return MentionText(
      text: message.content,
      baseStyle: TextStyle(fontSize: 14, height: 1.4, color: textColor),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
        border: const Border(left: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message.replyToUsername ?? 'Unknown',
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(message.replyToContent ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppTheme.secondaryText(context), fontSize: 12)),
      ]),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.borderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.reply, color: AppTheme.accent),
            title: Text('Reply',
                style: TextStyle(color: AppTheme.primaryText(context))),
            onTap: () { Navigator.pop(context); onReply?.call(); },
          ),
          if (isMe && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: const Text('Delete',
                  style: TextStyle(color: AppTheme.danger)),
              onTap: () { Navigator.pop(context); onDelete?.call(); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Color _usernameColor(String name) {
    const colors = [
      Color(0xFF00A884), Color(0xFF53BDEB), Color(0xFFFF9A3C),
      Color(0xFFBA68C8), Color(0xFF4FC3F7), Color(0xFF81C784), Color(0xFFFF6B6B),
    ];
    int h = 0;
    for (final c in name.codeUnits) h = (h * 31 + c) & 0xFFFFFFFF;
    return colors[h % colors.length];
  }
}
