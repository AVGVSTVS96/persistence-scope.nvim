# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/AVGVSTVS96/persistence-scope.nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AVGVSTVS96/persistence-scope.nvim/releases/tag/v0.1.0
