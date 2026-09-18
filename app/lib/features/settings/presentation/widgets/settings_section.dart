import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme.dart';

/// A labelled group of settings rows.
///
/// Shared so every section is spaced, bordered and announced identically —
/// the previous single-screen version hand-rolled each block and drifted.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// Tints the heading and border. Used only for destructive groups, so the
  /// colour means something rather than being decoration.
  final bool isDanger;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final accent = isDanger ? Colors.redAccent : fg;

    return Padding(
      padding: const EdgeInsets.only(top: NoSusTheme.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 10,
              letterSpacing: 1.5,
              color: accent.withValues(alpha: isDanger ? 0.7 : 0.45),
            ),
          ),
          const SizedBox(height: NoSusTheme.s8),
          Container(
            decoration: BoxDecoration(
              color: isDanger
                  ? Colors.redAccent.withValues(alpha: 0.03)
                  : (theme.brightness == Brightness.dark
                        ? NoSusTheme.dCard
                        : NoSusTheme.lCard),
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
              border: Border.all(
                color: isDanger
                    ? Colors.redAccent.withValues(alpha: 0.18)
                    : fg.withValues(alpha: 0.08),
                width: 0.75,
              ),
            ),
            // The decoration above would otherwise be the nearest thing painted
            // under the rows, swallowing every tile's ink splash. A transparent
            // Material sits between the two so taps ripple over the card, and
            // clipping keeps the splash inside the rounded corners.
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: NoSusTheme.s16,
                        endIndent: NoSusTheme.s16,
                        color: fg.withValues(alpha: 0.08),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable (or purely informational) settings row.
///
/// A row without [onTap] renders as a value display and is not announced as a
/// button — an "Email" row that reads as tappable but does nothing is exactly
/// the dead control this refactor was meant to remove.
class SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDanger;

  const SettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.55);
    final tint = isDanger ? Colors.redAccent : fg;

    final tile = ListTile(
      // ListTile's default minimum height already clears the 48dp target.
      leading: icon == null
          ? null
          : Icon(icon, size: 18, color: tint.withValues(alpha: 0.9)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: isDanger ? Colors.redAccent : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: subtle, fontSize: 10.5, height: 1.35),
            ),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right, size: 16, color: subtle),
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
    );

    if (onTap == null) return tile;

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: ExcludeSemantics(child: tile),
    );
  }
}

/// A settings row whose control is a switch.
class SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.55);

    return Semantics(
      toggled: value,
      label: subtitle == null ? title : '$title. $subtitle',
      child: ExcludeSemantics(
        child: SwitchListTile(
          title: Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: TextStyle(color: subtle, fontSize: 10.5, height: 1.35),
                ),
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          activeTrackColor: fg,
          activeThumbColor: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
