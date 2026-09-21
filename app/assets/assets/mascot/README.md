# Mascot assets

Drop the authored Rive files here with these exact names — `MascotView` (see
`lib/core/mascot/mascot_view.dart`) looks them up by convention:

- `lux.riv`
- `nox.riv`
- `duo.riv`

Each file must expose a State Machine named `SM` with:

- a `Number` input named `stateIndex` (see `MascotMood` order in
  `lib/core/mascot/mascot_state.dart` for the index mapping)
- a `Boolean` input named `reducedMotion` (when true, the artboard should hold on its
  Idle frame regardless of `stateIndex`)

Until a given file exists, `MascotView` falls back automatically (see its `placeHolder`) —
solo Lux/Nox render nothing, and the duo placeholder renders the static
`assets/icon/LuxandNox.png` mark. No code changes are needed when the real files are added,
just drop them in.

See `MASCOT_GUIDE.md` (repo root) for the full animation spec.
