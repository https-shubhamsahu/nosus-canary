import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class FloatingNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 480;

  static double contentClearance(BuildContext context) {
    return isCompact(context) ? 92 : 110;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compact = isCompact(context);
    final horizontalInset = compact ? NoSusTheme.s12 : NoSusTheme.s24;
    final bottomInset = compact ? NoSusTheme.s12 : NoSusTheme.s24;
    final height = compact ? 64.0 : 72.0;

    final List<NavTabItem> items = [
      NavTabItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Workspace',
      ),
      NavTabItem(
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield,
        label: 'Vault',
      ),
      NavTabItem(
        icon: Icons.remove_red_eye_outlined,
        selectedIcon: Icons.remove_red_eye,
        label: 'Study Desk',
      ),
      NavTabItem(
        icon: Icons.history_edu_outlined,
        selectedIcon: Icons.history_edu,
        label: 'Audit Log',
      ),
      NavTabItem(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Groups',
      ),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalInset,
            right: horizontalInset,
            bottom: bottomInset,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(NoSusTheme.r24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: isDark
                      ? NoSusTheme.dCard.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(NoSusTheme.r24),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = currentIndex == index;

                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: '${item.label} tab',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: Alignment.center,
                            child: ExcludeSemantics(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    duration: const Duration(milliseconds: 200),
                                    scale: isSelected ? 1.12 : 1.0,
                                    child: Icon(
                                      isSelected
                                          ? item.selectedIcon
                                          : item.icon,
                                      color: isSelected
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                      size: 24,
                                    ),
                                  ),
                                  if (!compact) ...[
                                    const SizedBox(height: NoSusTheme.s4),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontSize: 10,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? theme.colorScheme.onSurface
                                                : theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.4),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavTabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
