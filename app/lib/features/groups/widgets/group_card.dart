import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/models/study_group.dart';
import '../../../theme.dart';
import '../../../components/shimmer_box.dart';
import 'member_avatar_stack.dart';

/// Premium group card with group name, meta info, stacked avatars, and security badge.
/// Provides press feedback via [_pressed] scale animation.
class GroupCard extends StatefulWidget {
  final StudyGroup group;
  final VoidCallback onTap;
  final int animationIndex;

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
    this.animationIndex = 0,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Semantics(
      button: true,
      label: 'Open group ${widget.group.name}',
      onTap: widget.onTap,
      child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NoSusTheme.s16,
                vertical: 14.0,
              ),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Group name & Watermark Row ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.group.isWatermarkEnabled) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.water_drop_outlined,
                          size: 13,
                          color: subtle,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Description
                  Text(
                    widget.group.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: subtle.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14.0),

                  // ── Bottom row: avatars + stats ──────────────────────────────
                  Row(
                    children: [
                      MemberAvatarStack(
                        members: widget.group.members,
                        maxVisible: 3,
                        size: 24,
                      ),
                      const SizedBox(width: NoSusTheme.s12),
                      Text(
                        '${widget.group.memberCount} members',
                        style: TextStyle(fontSize: 11, color: subtle),
                      ),
                      const Spacer(),
                      // File count pill
                      _MetaPill(
                        icon: Icons.description_outlined,
                        label: '${widget.group.fileCount}',
                        fg: fg,
                        subtle: subtle,
                      ),
                      const SizedBox(width: 8),
                      // Last activity
                      Text(
                        widget.group.lastActivityLabel,
                        style: TextStyle(fontSize: 11, color: subtle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
        // Cap the delay so items far down a long list don't wait multiple
        // seconds before fading in once scrolled into view.
        .animate(delay: (widget.animationIndex.clamp(0, 10) * 60).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOut),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color subtle;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: subtle),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: subtle)),
      ],
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

/// Shimmer loading placeholder matching the GroupCard layout. Delegates its
/// shimmer-sweep animation to the shared [ShimmerBox]/[ShimmerSweep]
/// primitives (lib/components/shimmer_box.dart) so the timing/curve lives
/// in one place.
class GroupCardSkeleton extends StatelessWidget {
  const GroupCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      decoration: NoSusTheme.cardDecoration(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 72, height: 18),
              Spacer(),
              ShimmerBox(width: 18, height: 18, radius: 9),
            ],
          ),
          SizedBox(height: NoSusTheme.s16),
          ShimmerBox(width: 160, height: 16),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 12),
          SizedBox(height: 5),
          ShimmerBox(width: 180, height: 12),
          SizedBox(height: 20.0),
          Row(
            children: [
              ShimmerBox(width: 80, height: 24, radius: 12),
              Spacer(),
              ShimmerBox(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}
