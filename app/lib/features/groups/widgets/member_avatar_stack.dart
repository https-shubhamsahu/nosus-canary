import 'package:flutter/material.dart';
import '../domain/models/study_group.dart';
import '../../../theme.dart';

/// Stacked circular avatar chips — up to [maxVisible] shown, then "+N" overflow.
class MemberAvatarStack extends StatelessWidget {
  final List<GroupMember> members;
  final int maxVisible;
  final double size;

  const MemberAvatarStack({
    super.key,
    required this.members,
    this.maxVisible = 3,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final bg = isDark ? NoSusTheme.dCard : NoSusTheme.lCard;
    final border = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;

    final visible = members.take(maxVisible).toList();
    final overflow = members.length - maxVisible;

    return SizedBox(
      height: size,
      width: size * visible.length * 0.65 + (overflow > 0 ? size * 0.65 : 0),
      child: Stack(
        children: [
          // Render visible avatars right-to-left so left ones sit on top
          for (int i = visible.length - 1; i >= 0; i--)
            Positioned(
              left: i * size * 0.65,
              child: _Avatar(
                initials: visible[i].initials,
                size: size,
                fg: fg,
                bg: bg,
                borderColor: border,
              ),
            ),
          // Overflow count bubble
          if (overflow > 0)
            Positioned(
              left: visible.length * size * 0.65,
              child: _Avatar(
                initials: '+$overflow',
                size: size,
                fg: fg.withValues(alpha: 0.5),
                bg: bg,
                borderColor: border,
                fontSize: 8,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color fg;
  final Color bg;
  final Color borderColor;
  final double? fontSize;

  const _Avatar({
    required this.initials,
    required this.size,
    required this.fg,
    required this.bg,
    required this.borderColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: fontSize ?? (size * 0.3),
            fontWeight: FontWeight.w600,
            color: fg,
            height: 1,
          ),
        ),
      ),
    );
  }
}
