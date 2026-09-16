# Independent-agent collaboration

Folder layout reduces context; it does not prevent merge conflicts. Treat each
task as a narrow charter, then isolate it in a worktree.

## Task charter

Every agent prompt starts with: objective, allowed paths, forbidden paths,
contracts touched, and acceptance checks. One task owns one path area. If a
change crosses contract/web/backend boundaries, write a short decision in
`docs/` first and create a separate integration task.

## Worktree pattern

From the parent directory, give every agent a separate branch and folder:

```powershell
git -C nosus-monad worktree add ..\nosus-monad-<task> -b codex/<task>
```

Do not let two unconnected agents edit the same folder or shared lockfile.
They each make small commits; an integration agent reviews the diffs, resolves
only intentional conflicts, and runs the focused checks.

## Current ownership boundaries

| Area | Owner task type | Forbidden to unrelated tasks |
|---|---|---|
| `contracts/` | contract invariant | web/backend changes |
| `web/` | UI or wallet flow | Solidity/migration changes |
| `supabase/` | isolated backend | production NO SUS or client secrets |
| `docs/` + `.cursor/` | operating model | product behavior without owner approval |

Main is the integration branch. Merge only after the explicit finalization
gate in `AGENTS.md`; deployment needs a named target.
