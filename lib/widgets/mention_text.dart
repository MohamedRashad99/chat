import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders message content with @mentions highlighted in green.
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final void Function(String mention)? onMentionTap;

  const MentionText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(@\w+|@all)', caseSensitive: false);
    int last = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: baseStyle,
        ));
      }
      final mention = match.group(0)!;
      spans.add(TextSpan(
        text: mention,
        style: baseStyle.copyWith(
          color: AppTheme.mentionText,
          fontWeight: FontWeight.w600,
          backgroundColor: AppTheme.mentionBg,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => onMentionTap?.call(mention),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
