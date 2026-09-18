# NO SUS — MASCOT GUIDE
> Exclusive documentation for Lux and Nox — the emotional guides and silent security guards of NO SUS.

---

## 1. Mascot Profiles

### Lux (Light Guide)
* **Personality**: Curious, encouraging, observant.
* **Role**: Primary UI navigator, study desk companion, and success celebrator. Lux helps users feel oriented and supported in their workspace tasks.
* **Visual Theme**: Light-aligned monochrome, clean strokes.

### Nox (Dark Guard)
* **Personality**: Protective, alerts-driven, quiet.
* **Role**: Visual guardian. Appears during high-security moments, security event notices, and when recipients open documents (e.g. notifications snackbars).
* **Visual Theme**: Dark-aligned monochrome, sharp outlines.

### Duo (The Composition)
* **Role**: Reserved for scarce bookend moments, such as session logins and log summaries. The launch screen stays deliberately mascot-free so it can load quickly and remain focused.
* **Visual Asset**: Falls back to `assets/icon/LuxandNox.png` when the `.riv` asset is absent.

---

## 2. Animation States & Moods
The mascots use the Rive State Machine (`SM`) with a control input named `stateIndex` (mapping to the integer values of `MascotMood` below) and `reducedMotion` (boolean).

| Mood Index | Mood Name | Rive Artboard Behavior | Trigger Condition / Usage |
|---|---|---|---|
| 0 | `idle` | Slow breathing loop | Default state |
| 1 | `sleep` | Closed eyes, slow pacing | App inactive / idle timer |
| 2 | `wake` | Eyes opening, small stretch | App resume |
| 3 | `walk` | Moving legs in profile | Transition animations |
| 4 | `lookAround` | Head turns left/right | WorkspaceTab initialization (played once on tab boot) |
| 5 | `think` | Hand-to-chin, eyes upward | Running computation or search |
| 6 | `observe` | Leaning forward, watching | Reading state or page scroll |
| 7 | `guide` | Pointing gesture | Onboarding tutorials / tooltips |
| 8 | `celebrate` | Small jump / wave | Upload completed, milestone achieved |
| 9 | `wait` | Tapping foot | Async job in queue / pending state |
| 10 | `sit` | Resting pose | Inactive on workspace desk |
| 11 | `stretch` | Quick body extension | Long session transition |
| 12 | `protect` | Arms crossed, alert posture | Private directory focus |
| 13 | `approve` | Nods head | Validation checks pass |
| 14 | `verify` | Adjusts glasses / lens lookup | Cryptographic chain validation success |
| 15 | `guard` | Standing sentinel | RLS check active / Vault tab focus |
| 16 | `alert` | Surprised expression, flash | Threat detected / screenshot block |
| 17 | `stamp` | Overlaying action | Watermark successfully stamped on view |
| 18 | `returnToLogo` | Fades out to logo mark | Transition to main navigation logo |

---

## 3. Motion Language & Interaction Rules
1. **Never Interfere with Content**: Mascots must only occupy designated empty spaces or side containers (like headers, snackbars, and teaser card elements).
2. **Reduced Motion Compliance**:
   * If `MediaQuery.of(context).disableAnimations` is `true`, the `reducedMotion` input is set on the Rive artboard, forcing the mascot controller to lock visual states directly to `MascotMood.idle`.
3. **Imperative Control**:
   * Mascots are driven imperatively via Riverpod providers. Use `ref.read(luxMascotProvider.notifier).play(MascotMood.lookAround)` to trigger animations.

---

## 4. Design Constraints
* **Format**: Rive `.riv` assets located in `assets/mascot/<character_name>.riv`.
* **Fallback Behavior**:
   * `MascotView` uses a fallback widget placeholder before a `.riv` file is loaded to prevent visual breaks.
   * Duo falls back to the static png `assets/icon/LuxandNox.png`.
   * Solo Lux/Nox fallback defaults to `SizedBox.shrink()` (silent hidden state) or explicit icons (e.g. `Icon(Icons.notifications_active)` in share notifications).
