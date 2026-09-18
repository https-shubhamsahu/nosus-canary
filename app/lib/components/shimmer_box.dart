import 'package:flutter/material.dart';

/// Shared shimmer-sweep animation driver — the 1200ms color-sweep loop
/// originally hand-rolled inside `GroupCardSkeleton`
/// (lib/features/groups/widgets/group_card.dart), extracted so every
/// skeleton loader in the app reuses one animation controller
/// implementation instead of each hand-rolling its own.
class ShimmerSweep extends StatefulWidget {
  final Widget Function(BuildContext context, double shimmerValue) builder;

  const ShimmerSweep({super.key, required this.builder});

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}

/// A single shimmering placeholder block — generalizes the `_Bone` widget
/// from `GroupCardSkeleton`. Sweeps a gradient highlight left-to-right on a
/// continuous 1200ms loop, theme-aware for light/dark.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEC);
    final highlight =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);

    return ShimmerSweep(
      builder: (context, v) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + v * 3, 0),
            end: Alignment(-0.5 + v * 3, 0),
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Generalizes `groups_screen.dart`'s `_SkeletonList` — a non-scrollable
/// stack of placeholder items shown while an `AsyncValue` is loading.
class ShimmerListSkeleton extends StatelessWidget {
  final int itemCount;
  final WidgetBuilder itemBuilder;
  final double spacing;

  const ShimmerListSkeleton({
    super.key,
    this.itemCount = 3,
    required this.itemBuilder,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: spacing),
      itemBuilder: (context, index) => itemBuilder(context),
    );
  }
}
