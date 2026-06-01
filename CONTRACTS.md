# Contracts

Stable behavioral contracts for `persistence-scope.nvim` — the source of truth for behavioral logic. 

## Restore filters

Three entry points, each dropping one filter:

- `.load()` — scope + cwd + branch.
- `.load({ last = true })` — scope only (ignores cwd and branch).
- `.select()` — unfiltered; any scope, cwd, or branch may be shown.

Branch matching applies to `.load()` only, when `branch = true`:

- Prefers the current branch's sessions; when none match, every branch stays a
  candidate (branch ranks matches, it never excludes them).
- `main`, `master`, and non-git directories are branchless — they prefer
  branchless sessions, with the same fall-back to all branches.
- `branch = false`, or an undetectable branch, disables branch filtering —
  sessions with branch metadata stay eligible.

## Ranking & fallback

- Primary match order: scope + cwd + branch → scope + cwd → scope → other.
- No primary match → open the picker; never silently load an unrelated session.
- 2+ primary matches modified within `recent_seconds` → open the picker instead of guessing.
- The picker lists all sessions, ranked by the tiers above, newest-first within a tier.

## Save & multiple sessions

- Multiple sessions may share the same scope + cwd + branch.
- A fresh instance never overwrites an existing match: it writes the canonical file if free, else the next `~N` slot.
- An instance that loaded a session owns that file and saves back to it.

## Scope & providers

- Scope is resolved once at setup/startup and is that instance's session namespace for its lifetime.
- Scope sets the save location and `.load()` / `.last()` eligibility, but never hides sessions from `.select()`.
- A provider returns a scope table (`kind`, `label`, `dir`, `meta`) or `nil`; `nil` saves directly under `base_dir` (global, unscoped).

## Integration surface

- `setup()` is idempotent and replaces `persistence.load`, `.select`, `.load_file`, and `.save` with scope-aware versions.
- `.last`, `.start`, `.stop`, `.current`, `.list`, `.active`, `.branch` are untouched — scope-aware only via the redirected `dir`.
- `.load()` (restore) returns a boolean: `false` when nothing was restored.
- `.load_file()` fires `PersistenceLoadPre` / `PersistenceLoadPost`.
