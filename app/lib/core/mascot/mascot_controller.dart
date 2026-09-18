import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import 'mascot_state.dart';

/// Drives one mascot artboard's Rive State Machine inputs (`stateIndex`,
/// `reducedMotion`) from app-level events. [state] tracks the current mood
/// for anything that wants to observe it; `reducedMotion` is intentionally
/// kept as a plain field (not Riverpod state) since it's toggled from
/// [MascotView]'s build method and must never trigger a provider mutation
/// during a widget build.
class MascotNotifier extends Notifier<MascotMood> {
  StateMachineController? _smController;
  SMINumber? _stateIndexInput;
  SMIBool? _reducedMotionInput;
  bool _reducedMotion = false;

  @override
  MascotMood build() {
    ref.onDispose(() => _smController?.dispose());
    return MascotMood.idle;
  }

  /// Called from [MascotView.onInit] once the artboard has loaded.
  void attach(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, 'SM');
    if (controller == null) return;
    _smController = controller;
    artboard.addController(controller);
    _stateIndexInput = controller.findInput<double>('stateIndex') as SMINumber?;
    _reducedMotionInput = controller.findInput<bool>('reducedMotion') as SMIBool?;
    _apply();
  }

  /// Plays a catalogued mood. One-shots are expected to be followed by a
  /// call back to [MascotMood.idle] by the caller once the moment has passed
  /// (Rive's `oneShotDone` trigger output can automate this once authored).
  void play(MascotMood mood) {
    state = mood;
    _apply();
  }

  void setReducedMotion(bool value) {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    _apply();
  }

  void _apply() {
    _reducedMotionInput?.value = _reducedMotion;
    _stateIndexInput?.value =
        (_reducedMotion ? MascotMood.idle : state).index.toDouble();
  }
}

final luxMascotProvider =
    NotifierProvider<MascotNotifier, MascotMood>(MascotNotifier.new);
final noxMascotProvider =
    NotifierProvider<MascotNotifier, MascotMood>(MascotNotifier.new);
final duoMascotProvider =
    NotifierProvider<MascotNotifier, MascotMood>(MascotNotifier.new);

/// Looks up the right provider instance for a given character so call sites
/// can write `ref.read(mascotProvider(MascotCharacter.nox).notifier)` instead
/// of branching on the enum themselves.
NotifierProvider<MascotNotifier, MascotMood> mascotProvider(
  MascotCharacter character,
) {
  switch (character) {
    case MascotCharacter.lux:
      return luxMascotProvider;
    case MascotCharacter.nox:
      return noxMascotProvider;
    case MascotCharacter.duo:
      return duoMascotProvider;
  }
}
