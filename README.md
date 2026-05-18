# persistence-scope.nvim

Scoped sessions for [`persistence.nvim`](https://github.com/folke/persistence.nvim).

`persistence-scope.nvim` lets one working directory have multiple independent
sessions by saving each session under a scope, such as the current tmux window.
It is useful when you keep several Neovim instances open in the same repository
for different threads of work.

```text
~/.local/state/nvim/sessions/
  tmux-api/
    %home%me%project.vim
  tmux-ui/
    %home%me%project.vim
```

## Features

- Uses `persistence.nvim` as the session backend.
- Defaults to scoping sessions by tmux window name.
- Supports alternate tmux scopes such as pane id, pane index, and session+window.
- Provides `:PersistenceScopeRestore` and `:PersistenceScopeSelect`.
- Uses Snacks for a rich picker when available.
- Falls back to `vim.ui.select`.

## Requirements

- Neovim 0.10+
- [`folke/persistence.nvim`](https://github.com/folke/persistence.nvim)
- Optional: [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) for the rich picker
- Optional: tmux for the built-in tmux providers

## Installation

With [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
  "avgvstvs96/persistence-scope.nvim",
  dependencies = {
    "folke/persistence.nvim",
    "folke/snacks.nvim", -- optional
  },
  lazy = false,
  opts = {},
}
```

`persistence-scope.nvim` calls `require("persistence").setup()` for you. If you
currently have a separate `persistence.nvim` setup block, move those options
into this plugin's `opts`.

## Quick Start

The default configuration scopes sessions by tmux window name:

```lua
{
  "avgvstvs96/persistence-scope.nvim",
  dependencies = { "folke/persistence.nvim" },
  lazy = false,
  opts = {
    provider = "tmux_window",
  },
}
```

Use named tmux windows as your session labels:

```text
api
ui
review-auth
```

Then restore or select sessions with:

```vim
:PersistenceScopeRestore
:PersistenceScopeSelect
```

## Commands

### `:PersistenceScopeRestore`

Restore the best matching session for the current working directory and current scope. If more
than one match is found, the picker is opened for manual selection with rich per-session details.

### `:PersistenceScopeSelect`

Open the session picker.

## Lua API

```lua
require("persistence_scope").restore()
require("persistence_scope").select()
require("persistence_scope").sessions()
require("persistence_scope").load_file(path)
```

## Configuration

Defaults:

```lua
require("persistence_scope").setup({
  provider = "tmux_window",
  picker = "auto",
  base_dir = vim.fn.stdpath("state") .. "/sessions/",
  branch = true,
  recent_seconds = 4 * 60 * 60,
  patch_persistence = true,
  snacks = {},
})
```

### `provider`

The scope used to choose the session directory.

```lua
provider = "tmux_window"
```

Built-in providers:

```lua
"tmux_window"
"tmux_window_name"
"tmux_window_index"
"tmux_pane_id"
"tmux_pane_index"
"tmux_session_window"
```

Custom providers return a scope table:

```lua
provider = function()
  return {
    kind = "custom",
    label = "my-scope",
    dir = "custom-my-scope",
    meta = {},
  }
end
```

If the provider returns `nil`, sessions are saved in `base_dir` without an
extra scope directory.

### `picker`

Picker used by `select()` and ambiguous restores.

```lua
picker = "auto"   -- Snacks when available, otherwise vim.ui.select
picker = "snacks"
picker = "vim_ui"
```

The Snacks picker shows age, scope, cwd, branch, buffer summary, and a preview.

### `base_dir`

Base directory for all session files.

```lua
base_dir = vim.fn.stdpath("state") .. "/sessions/"
```

### `branch`

Passed to `persistence.nvim`. When enabled, non-main branches get separate
session files.

```lua
branch = true
```

### `recent_seconds`

When more than one session for the current cwd and scope was modified recently,
restore opens the picker instead of guessing.

```lua
recent_seconds = 4 * 60 * 60
```

### `patch_persistence`

Adds compatibility helpers to `require("persistence")`:

```lua
require("persistence").load_tmux_fallback()
require("persistence").select()
require("persistence").load_file(path)
require("persistence").session_items()
```

This is useful for dashboards or keymaps that already call `persistence.nvim`.

```lua
patch_persistence = true
```

### `snacks`

Extra options passed to the Snacks picker.

```lua
snacks = {
  -- any Snacks.picker option
}
```

## Restore Behavior

`:PersistenceScopeRestore` uses this order:

1. Find sessions for the current working directory.
2. Prefer sessions in the current scope.
3. If more than one current-scope session was modified within `recent_seconds`,
   open the picker.
4. Otherwise load the newest current-scope session.
5. If no current-scope session exists, open a picker for the current working
   directory across all scopes.
6. Outside a resolved scope, load the only current-directory session or ask when
   there are multiple.

## Examples

### Scope By Tmux Window Name

```lua
require("persistence_scope").setup({
  provider = "tmux_window",
})
```

### Scope By Tmux Pane Id

```lua
require("persistence_scope").setup({
  provider = "tmux_pane_id",
})
```

### Disable Compatibility Patching

```lua
require("persistence_scope").setup({
  patch_persistence = false,
})
```

### Use `vim.ui.select`

```lua
require("persistence_scope").setup({
  picker = "vim_ui",
})
```

## License

MIT
