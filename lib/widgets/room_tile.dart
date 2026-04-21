import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class RoomTile extends StatelessWidget {
  final Room room;
  final bool isSelected;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final VoidCallback onTap;

  const RoomTile({
    super.key,
    required this.room,
    required this.isSelected,
    required this.onTap,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = lastMessageAt != null
        ? _formatTime(lastMessageAt!)
        : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? AppTheme.surface
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // group avatar
          _GroupAvatar(name: room.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      room.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: unreadCount > 0
                          ? AppTheme.unread
                          : AppTheme.textMuted,
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(
                    child: Text(
                      lastMessage ?? room.description ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.unread,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (now.difference(local).inDays == 0) {
      return DateFormat('HH:mm').format(local);
    } else if (now.difference(local).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(local);
    }
  }
}

class _GroupAvatar extends StatelessWidget {
  final String name;
  const _GroupAvatar({required this.name});

  Color _color(String n) {
    const colors = [
      Color(0xFF00A884), Color(0xFF53BDEB), Color(0xFFFF9A3C),
      Color(0xFFBA68C8), Color(0xFF4FC3F7), Color(0xFF81C784),
    ];
    int h = 0;
    for (final c in n.codeUnits) h = (h * 31 + c) & 0xFFFFFFFF;
    return colors[h % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(name);
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.group, color: Colors.white70, size: 24),
    );
  }
}
