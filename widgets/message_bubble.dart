import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showHeader;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showHeader,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt.toLocal());
    final username = message.username ?? 'Unknown';

    return Padding(
      padding: EdgeInsets.only(top: showHeader ? 14 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Left avatar (other users)
          if (!isMe) ...[
            showHeader
                ? UserAvatar(username: username, size: 30)
                : const SizedBox(width: 30),
            const SizedBox(width: 10),
          ],

          // Bubble column
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: isMe
                          ? [
                              Text(timeStr,
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 10)),
                              const SizedBox(width: 6),
                              Text('You',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentGlow)),
                            ]
                          : [
                              Text(username,
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(width: 6),
                              Text(timeStr,
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 10)),
                            ],
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.58,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.accentSoft : AppTheme.cardBg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                            isMe ? 14 : (showHeader ? 3 : 14)),
                        topRight: Radius.circular(
                            isMe ? (showHeader ? 3 : 14) : 14),
                        bottomLeft: const Radius.circular(14),
                        bottomRight: const Radius.circular(14),
                      ),
                      border: Border.all(
                        color: isMe
                            ? AppTheme.accentDim.withOpacity(0.4)
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isMe
                            ? AppTheme.accentGlow
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right avatar (me)
          if (isMe) ...[
            const SizedBox(width: 10),
            showHeader
                ? UserAvatar(username: username, size: 30, isMe: true)
                : const SizedBox(width: 30),
          ],
        ],
      ),
    );
  }
}
