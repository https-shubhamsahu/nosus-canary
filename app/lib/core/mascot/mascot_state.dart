/// Which mascot artboard/state-machine to drive. `duo` is reserved for the
/// scarce together-moments (session bookends) — see docs/design/MASCOT_MOTION_BIBLE.md.
enum MascotCharacter { lux, nox, duo }

/// Union of every catalogued animation state across Lux and Nox. Not every
/// mood applies to every character — a character's .riv simply won't define
/// an animation for moods it doesn't use, and the state machine holds on
/// Idle instead. Order matters: it is the `stateIndex` sent to Rive.
enum MascotMood {
  idle,
  sleep,
  wake,
  walk,
  lookAround,
  think,
  observe,
  guide,
  celebrate,
  wait,
  sit,
  stretch,
  protect,
  approve,
  verify,
  guard,
  alert,
  stamp,
  returnToLogo,
}
