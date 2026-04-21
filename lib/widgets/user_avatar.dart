import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String username;
  final double size;
  final bool isMe;
  final String? avatarUrl;
  final bool showOnline;

  const UserAvatar({
    super.key,
    required this.username,
    this.size = 40,
    this.isMe = false,
    this.avatarUrl,
    this.showOnline = false,
  });

  Color _color(String name) {
    const colors = [
      Color(0xFF00A884),
      Color(0xFF25D366),
      Color(0xFF53BDEB),
      Color(0xFFFF9A3C),
      Color(0xFFFF6B6B),
      Color(0xFFBA68C8),
      Color(0xFF4FC3F7),
      Color(0xFF81C784),
    ];
    int h = 0;
    for (final c in name.codeUnits) h = (h * 31 + c) & 0xFFFFFFFF;
    return colors[h % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    Widget avatar;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _circle(color, initial),
        ),
      );
    } else {
      avatar = _circle(color, initial);
    }

    if (!showOnline) return avatar;

    return Stack(children: [
      avatar,
      Positioned(
        right: 0, bottom: 0,
        child: Container(
          width: size * 0.28,
          height: size * 0.28,
          decoration: BoxDecoration(
            color: AppTheme.online,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.surfaceAlt, width: 1.5),
          ),
        ),
      ),
    ]);
  }

  Widget _circle(Color color, String initial) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
