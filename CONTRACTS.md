# Contracts

Stable behavioral contracts for `persistence-scope.nvim` — the source of truth for behavioral logic. 

## Restore filters

Three entry points, each dropping one filter:

- `.load()` — scope + cwd + branch.
- `.load({ last = true })` — scope only (ignores cwd and branch).
- `.select()` — unfiltered; any scope, cwd, or branch may be shown.

Branch matching applies to `.load()` autorestore only:

- Prefers the current branch's sessions. On a miss the fallback depends on the
  `branch` option: `true` falls back to the branchless session only
  (upstream-faithful); `false` falls back to a session on any branch — a
  deliberate divergence from upstream.
- `main`, `master`, non-git, and undetectable branches count as branchless.
- Sessions are always saved per-branch and ranked by branch in the picker,
  regardless of `branch`; the option governs autorestore strictness only.

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
