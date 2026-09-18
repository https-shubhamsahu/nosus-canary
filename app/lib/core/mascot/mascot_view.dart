import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

import 'mascot_controller.dart';
import 'mascot_state.dart';

/// One load attempt per character per app run, shared by every [MascotView]
/// instance. Resolves to null when the .riv doesn't exist yet — that's the
/// designed pre-asset state, so it must NOT surface as an unhandled async
/// error (RiveAnimation.asset throws one into the root zone on every mount
/// otherwise, polluting production logs).
final _riveFileCache = <MascotCharacter, Future<rive.RiveFile?>>{};

Future<rive.RiveFile?> _loadRiveFile(MascotCharacter character) {
  return _riveFileCache.putIfAbsent(character, () async {
    try {
      return await rive.RiveFile.asset('assets/mascot/${character.name}.riv');
    } catch (_) {
      return null;
    }
  });
}

/// Renders one mascot (Lux, Nox, or the scarce Duo bookend composition),
/// driven imperatively by [mascotProvider] — call
/// `ref.read(mascotProvider(character).notifier).play(mood)` from wherever
/// the app state change happens; this widget doesn't need to rebuild for
/// that to take effect.
///
/// Looks up `assets/mascot/<character>.riv` by convention (see
/// assets/mascot/README.md). Until that file exists, Rive's own
/// `placeHolder` mechanism renders instead — nothing for solo Lux/Nox, the
/// existing static logo mark for the Duo — so every call site below is safe
/// to ship today, before any real Rive asset has been authored.
class MascotView extends ConsumerWidget {
  final MascotCharacter character;
  final double size;

  /// Only set this when the mascot is the *sole* carrier of a state change
  /// not already reflected in surrounding text/UI — per the accessibility
  /// rule in docs/design/MASCOT_MOTION_BIBLE.md, that should be rare.
  final String? semanticLabel;

  /// What to show before a real `.riv` asset exists for [character]. Defaults
  /// to nothing for solo Lux/Nox (the mascot simply isn't visible yet) — but
  /// pass the widget being *replaced* at a call site (e.g. an existing empty
  /// -state icon) so today's UI doesn't lose content while waiting on real
  /// mascot art.
  final Widget? fallback;

  const MascotView({
    super.key,
    required this.character,
    this.size = 48,
    this.semanticLabel,
    this.fallback,
  });

  Widget get _placeholder {
    if (fallback != null) return fallback!;
    if (character == MascotCharacter.duo) {
      return Image.asset('assets/icon/LuxandNox.png', fit: BoxFit.contain);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final notifier = ref.read(mascotProvider(character).notifier);
    notifier.setReducedMotion(reducedMotion);

    return Semantics(
      excludeSemantics: semanticLabel == null,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<rive.RiveFile?>(
          future: _loadRiveFile(character),
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file == null) return _placeholder;
            return rive.RiveAnimation.direct(
              file,
              stateMachines: const ['SM'],
              fit: BoxFit.contain,
              onInit: (artboard) => notifier.attach(artboard),
            );
          },
        ),
      ),
    );
  }
}
