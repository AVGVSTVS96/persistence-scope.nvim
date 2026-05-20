# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-05-18

Unified picker model with recency highlighting, plus a critical fix to
the v0.1.0 drop-in promise.

### Fixed

- `require("persistence").load()` is now patched to the scope-aware
  restore. v0.1.0 only patched `.select()`, so the stock `<leader>qs`
  keymap and dashboard restore buttons silently bypassed the plugin.
- README/FAQ no longer claim upstream's `.load()` takes no arguments.

### Added

- **Unified tiered picker.** Every picker shows the full session list
  sorted by relevance (recent → scope+cwd → scope → other), with the
  items that triggered the picker visually flagged.
- **`PersistenceScopeRecent` highlight** for the date column of recent
  items in the Snacks picker; `vim.ui.select` uses a `★` prefix.
  Override with `vim.api.nvim_set_hl(0, "PersistenceScopeRecent", {...})`.

### Changed

- **`.load()` and `.load({ last = true })` are now symmetric.** Both
  respect scope; `last = true` just drops the cwd filter. Both open the
  tiered picker on 2+ recent matches in their primary filter, and fall
  back to the picker over all sessions when their primary filter is
  empty.
- `<leader>ql` returns the newest session in your *current scope* (any
  cwd) instead of the globally newest. When the scope is empty the
  picker opens over all sessions rather than silently loading from a
  different scope.

### Docs

- README + vimdoc restructured around the drop-in promise. Restore
  Behavior section rewritten with the tiered model.
- Public `persistence_scope` API narrowed to `setup()` + `sessions()`.
  `restore()` / `select()` / `load_file()` remain as undocumented
  aliases for v0.1.0 backwards compat; recommended surface is now
  `require("persistence")` for actions, `require("persistence_scope")`
  for config/querying.

## [0.1.0] — 2026-05-18

First public release.

### Added

- Scope-aware sessions for [`folke/persistence.nvim`](https://github.com/folke/persistence.nvim).
  Each Neovim instance gets its own isolated session under a per-scope
  subdirectory so multiple instances of the same project no longer clobber
  each other.
- Five built-in tmux providers: `tmux_window_name` (default), `tmux_window_index`,
  `tmux_pane_id`, `tmux_pane_index`, `tmux_session_window`.
- Custom-provider support — any Lua function returning a scope table works.
- Rich [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) picker with
  age, scope, cwd, branch, buffer summary, and a markdown preview. Graceful
  fallback to `vim.ui.select` when Snacks isn't installed.
- Smart restore (`:PersistenceScopeRestore`) that picks the best match for
  the current cwd + scope, or asks when the choice is ambiguous.
- `:PersistenceScopeSelect` to always open the picker.
- Public Lua API: `setup`, `restore`, `select`, `sessions`, `load_file`.
- Upgrades `require("persistence").select()` in place so existing keymaps
  and dashboards get scope-aware picking with no code changes.
- `:checkhealth persistence_scope` reporting Neovim version, dependencies,
  resolved scope, target directory, tmux state, and session-file count.
- Typed LuaCATS annotations (`PersistenceScope.Config`, `Scope`, `SessionItem`).
- Comprehensive vimdoc with per-function helptags.
- CI: stylua, luacheck, and headless smoke test across Neovim 0.10.4 /
  stable / nightly.

[Unreleased]: https://github.com/AVGVSTVS96/persistence-scope.nvim/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/AVGVSTVS96/persistence-scope.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/AVGVSTVS96/persistence-scope.nvim/releases/tag/v0.1.0
