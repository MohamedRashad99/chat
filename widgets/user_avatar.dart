import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String username;
  final double size;
  final bool isMe;
  final String? avatarUrl;

  const UserAvatar({
    super.key,
    required this.username,
    this.size = 36,
    this.isMe = false,
    this.avatarUrl,
  });

  Color _colorFromUsername(String name) {
    final colors = [
      const Color(0xFF7B61FF),
      const Color(0xFF22D3A4),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFB347),
      const Color(0xFF4FC3F7),
      const Color(0xFFBA68C8),
      const Color(0xFF81C784),
    ];
    int hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = isMe ? AppTheme.accent : _colorFromUsername(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initial(color, initial),
        ),
      );
    }
    return _initial(color, initial);
  }

  Widget _initial(Color color, String initial) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
