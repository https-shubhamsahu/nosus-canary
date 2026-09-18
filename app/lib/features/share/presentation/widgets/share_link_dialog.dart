import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/share_providers.dart';
import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/utils/web_links.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';

/// Creates a share link for [fileId] and shows it in a copyable dialog.
///
/// The link opens for ANYONE — no NO SUS account required. Protection on that
/// anonymous view is watermark + (optionally) blur-until-touch + view
/// logging, never a hard screenshot block (that's only possible inside the
/// installed app). Whether the blur/touch-reveal gate applies is the
/// sender's own choice, made below before the link is created.
Future<void> showShareLinkDialog(
  BuildContext context,
  WidgetRef ref,
  String fileId,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ShareLinkDialog(fileId: fileId),
  );
}

enum _Step { settings, creating, ready, error }

class _ShareLinkDialog extends ConsumerStatefulWidget {
  const _ShareLinkDialog({required this.fileId});
  final String fileId;

  @override
  ConsumerState<_ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends ConsumerState<_ShareLinkDialog> {
  _Step _step = _Step.settings;
  bool _requireTouchReveal = true;
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(luxMascotProvider.notifier).play(MascotMood.guide);
    });
  }

  Future<void> _create() async {
    setState(() => _step = _Step.creating);
    ref.read(noxMascotProvider.notifier).play(MascotMood.verify);
    try {
      final link = await ref.read(shareRepositoryProvider).createShareLink(
            widget.fileId,
            requireTouchReveal: _requireTouchReveal,
          );
      if (!mounted) return;
      final (:origin, :basePath) = webShareLinkBase();
      final cb = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _url = '$origin$basePath/?cb=$cb#/v/${link.token}';
        _step = _Step.ready;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
    } catch (e, s) {
      debugLog('ShareLinkDialog: Failed to create share link: $e\n$s');
      if (!mounted) return;
      setState(() {
        _error = 'Could not create a share link. Only the person who uploaded '
            'this file can share it.';
        _step = _Step.error;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MascotView(
            character: _step == _Step.settings
                ? MascotCharacter.lux
                : MascotCharacter.nox,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('SHARE LINK',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: switch (_step) {
          _Step.settings => _buildSettingsStep(context),
          _Step.creating => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
          _Step.error => Text(_error!, style: const TextStyle(fontSize: 12)),
          _Step.ready => _buildReadyStep(context),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ),
        if (_step == _Step.settings)
          FilledButton(
            onPressed: _create,
            child: const Text('CREATE LINK', style: TextStyle(fontSize: 11)),
          ),
        if (_step == _Step.ready) ...[
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _url!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Link copied'),
                    behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('COPY', style: TextStyle(fontSize: 11)),
          ),
          FilledButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Here is a secure document link: $_url'),
            ),
            child: const Text('SHARE', style: TextStyle(fontSize: 11)),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingsStep(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anyone with this link can view the document — no account needed. '
          'It is always watermarked with their email and every view is logged.',
          style: TextStyle(fontSize: 11, color: subtle),
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Require touch-to-reveal',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          subtitle: Text(
            _requireTouchReveal
                ? 'Viewer must touch and hold to reveal the document.'
                : 'Document is visible immediately — no touch gate.',
            style: TextStyle(fontSize: 11, color: subtle),
          ),
          value: _requireTouchReveal,
          onChanged: (v) => setState(() => _requireTouchReveal = v),
        ),
      ],
    );
  }

  Widget _buildReadyStep(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(_url!, style: const TextStyle(fontSize: 11)),
        ),
        const SizedBox(height: 12),
        Text(
          _requireTouchReveal
              ? 'Touch-to-reveal is required for this link.'
              : 'Touch-to-reveal is OFF — the document shows immediately.',
          style: TextStyle(fontSize: 11, color: subtle),
        ),
      ],
    );
  }
}
