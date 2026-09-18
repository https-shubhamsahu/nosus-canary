# NO SUS Canary: reference files

These are the finished, verified source files for NO SUS Canary. They are laid out in the same
folder structure as their destinations in this repo (`app/…`, `contracts/…`). Copy them into
place with the commands in [../NOSUS_CANARY_BUILD_PLAN.md](../NOSUS_CANARY_BUILD_PLAN.md).
Do not retype them.

- `app/` → Flutter feature, tests, the SQL migration and the `canary` edge function
- `contracts/` → `NoSusCanary.sol`, its tests, and the deploy and relayer scripts
- `tools/canary_edits.js` → applies the small edits to existing app files (run once, from `app/`)
- `tools/canary_fingerprint_harness.dart` → accuracy sweep for the fingerprint engine. Run
  `dart tools/canary_fingerprint_harness.dart` from this folder after changing the word list.
  It must end with `FAILURES: 0`.

See [VERIFICATION.md](VERIFICATION.md) for how each file was checked.

Delete this folder once every file has been committed in its real location. The project
constitution does not allow duplicate files.
