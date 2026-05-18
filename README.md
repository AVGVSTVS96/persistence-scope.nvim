<h1 align="center">persistence-scope.nvim</h1>

<p align="center">
  <b>One project. Many sessions. Zero ceremony.</b><br/>
  Scoped sessions for <a href="https://github.com/folke/persistence.nvim"><code>folke/persistence.nvim</code></a>.
</p>

<p align="center">
  <a href="https://neovim.io"><img alt="Neovim" src="https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white"></a>
  <a href="https://github.com/folke/lazy.nvim"><img alt="Lazy.nvim" src="https://img.shields.io/badge/managed%20with-lazy.nvim-8A2BE2"></a>
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

---

## ✨ Why?

`persistence.nvim` saves one session per `cwd` (+ branch). That's perfect — until
you keep **several Neovim instances open in the same repo** for different threads
of work: one tmux window for the API, another for the UI, another for a code
review. They all collide on the same session file and clobber each other.

`persistence-scope.nvim` fixes that by adding a **scope** to the session path —
typically the current tmux window — so each instance gets its own isolated
session, restored automatically on the next launch.

```text
~/.local/state/nvim/sessions/
├── tmux-api/
│   └── %home%me%project.vim
├── tmux-ui/
│   └── %home%me%project.vim
└── tmux-review-auth/
    └── %home%me%project.vim
```

> Not a tmux user? Bring your own scope — any Lua function works (see [Custom providers](#custom-providers)).

## 📚 Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Commands](#-commands)
- [Lua API](#-lua-api)
- [Configuration](#%EF%B8%8F-configuration)
- [Providers](#-providers)
- [Restore Behavior](#-restore-behavior)
- [Examples](#-examples)
- [FAQ](#-faq)
- [Acknowledgements](#-acknowledgements)
- [License](#-license)

## 🚀 Features

- 🪟 **Per-tmux-window sessions** out of the box — name your windows, get named workspaces.
- 🔌 **Pluggable scopes** — pane id, pane index, session+window, or a custom Lua function.
- 🍿 **Rich Snacks picker** with age, scope, branch, buffer summary, and a preview.
- 🪶 **Falls back gracefully** to `vim.ui.select` when Snacks isn't installed.
- 🤝 **Drop-in compatible** with existing `persistence.nvim` keymaps and dashboards.
- 🧠 **Smart restore** — picks the best match for your cwd + scope, or asks when it's ambiguous.

## ✅ Requirements

| Requirement | Notes |
| --- | --- |
| Neovim `>= 0.10` | Uses `vim.uv` / `vim.fs.normalize`. |
| [`folke/persistence.nvim`](https://github.com/folke/persistence.nvim) | Required — used as the session backend. |
| [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) | Optional — enables the rich picker. |
| `tmux` | Optional — only needed for the built-in tmux providers. |

## 📦 Installation

With [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
  "avgvstvs96/persistence-scope.nvim",
  dependencies = {
    "folke/persistence.nvim",
    "folke/snacks.nvim", -- optional, for the rich picker
  },
  lazy = false, -- load eagerly so sessions restore on startup
  opts = {
    provider = "tmux_window_name",
  },
  keys = {
    { "<leader>qr", function() require("persistence_scope").restore() end, desc = "Restore session" },
    { "<leader>qs", function() require("persistence_scope").select()  end, desc = "Select session" },
  },
}
```

> ⚠️ `persistence-scope.nvim` calls `require("persistence").setup()` for you.
> If you already configure `persistence.nvim` separately, move those options
> into this plugin's `opts` and remove the standalone setup call.

## ⚡ Quick Start

1. Name your tmux windows — these become your session labels:

   ```text
   api · ui · review-auth · scratch
   ```

2. Open Neovim in any project from those windows and work normally.

3. Re-open Neovim from the same window — your session restores automatically
   via `:PersistenceScopeRestore` (or trigger it from a dashboard / keymap).

That's it. Each window in each project now has its own independent session.

## 🧭 Commands

| Command | Description |
| --- | --- |
| `:PersistenceScopeRestore` | Restore the best matching session for the current cwd + scope. Opens the picker if the choice is ambiguous. |
| `:PersistenceScopeSelect`  | Always open the session picker. |

## 🧩 Lua API

```lua
local ps = require("persistence_scope")

ps.restore()                 -- smart restore (see Restore Behavior)
ps.select(opts)              -- open the picker
ps.sessions(opts)            -- list session items (filter by { cwd, scope_dir })
ps.load_file(path)           -- source a session file and fire persistence events
```

When [`patch_persistence`](#patch_persistence) is enabled (default), the same
helpers are mirrored onto `require("persistence")`, so any code already wired to
`persistence.nvim` works unchanged:

```lua
require("persistence").load_tmux_fallback() -- alias for ps.restore()
require("persistence").select()             -- alias for ps.select()
require("persistence").load_file(path)
require("persistence").session_items()
```

## ⚙️ Configuration

Defaults — pass any subset to `opts`:

```lua
require("persistence_scope").setup({
  -- Scope used to choose the session directory.
  -- Built-in providers (see below) or a custom function.
  provider = "tmux_window_name",

  -- Picker used by `select()` and ambiguous restores.
  --   "auto"    → Snacks when available, otherwise vim.ui.select
  --   "snacks"  → force Snacks
  --   "vim_ui"  → force vim.ui.select
  picker = "auto",

  -- Base directory for all session files.
  base_dir = vim.fn.stdpath("state") .. "/sessions/",

  -- Forwarded to persistence.nvim. When true, non-main branches get
  -- their own session files.
  branch = true,

  -- If more than one current-scope session was modified within this
  -- window of time, restore opens the picker instead of guessing.
  recent_seconds = 4 * 60 * 60,

  -- Mirror this plugin's helpers onto `require("persistence")` so existing
  -- keymaps/dashboards keep working unchanged.
  patch_persistence = true,

  -- Extra options forwarded to the Snacks picker.
  snacks = {},
})
```

## 🔌 Providers

A provider is just a function that returns a **scope table** (or `nil`):

```lua
{
  kind  = "tmux_window_name", -- identifier for the provider
  label = "api",          -- human-readable label shown in the picker
  dir   = "tmux-api",     -- directory name appended to base_dir
  meta  = { ... },        -- arbitrary extra info
}
```

If the provider returns `nil`, sessions are saved directly in `base_dir` with
no extra scope directory.

### Built-in providers

| Provider | Scope label source | Example dir |
| --- | --- | --- |
| `"tmux_window_name"` *(default)* | `#{window_name}` | `tmux-api/` |
| `"tmux_window_index"`       | `#{window_index}` | `tmux-window-2/` |
| `"tmux_pane_id"`            | `#{pane_id}` | `tmux-pane-%17/` |
| `"tmux_pane_index"`         | `#{pane_index}` | `tmux-pane-0/` |
| `"tmux_session_window"`     | `#{session_name}:#{window_name}` | `tmux-work_api/` |

### Custom providers

```lua
require("persistence_scope").setup({
  provider = function()
    -- Example: scope by the WezTerm tab title, env var, etc.
    local label = vim.env.WORKSPACE_LABEL
    if not label or label == "" then return nil end
    return {
      kind  = "workspace_env",
      label = label,
      dir   = "ws-" .. label,
      meta  = { source = "env" },
    }
  end,
})
```

## 🧠 Restore Behavior

`:PersistenceScopeRestore` walks this decision tree:

```text
┌─ sessions for current cwd?
│   ├─ in current scope?
│   │   ├─ multiple modified within recent_seconds → 🟡 open picker (scope)
│   │   └─ otherwise                                → ✅ load newest in scope
│   └─ no match in current scope                    → 🟡 open picker (cwd, all scopes)
│
└─ no scope resolved?
    ├─ exactly one cwd match                        → ✅ load it
    ├─ multiple, with >1 recent                     → 🟡 open picker
    └─ multiple, none recent                        → ✅ load newest
```

If nothing matches at all, you get a friendly `vim.notify` and no session is
sourced.

## 🧪 Examples

### Scope by tmux window name (default)

```lua
require("persistence_scope").setup({ provider = "tmux_window_name" })
```

### Scope by tmux pane id (truly per-pane sessions)

```lua
require("persistence_scope").setup({ provider = "tmux_pane_id" })
```

### Force `vim.ui.select` (skip Snacks)

```lua
require("persistence_scope").setup({ picker = "vim_ui" })
```

### Disable compatibility patching

```lua
require("persistence_scope").setup({ patch_persistence = false })
```

### Custom Snacks picker options

```lua
require("persistence_scope").setup({
  picker = "snacks",
  snacks = {
    layout = { preset = "vertical" },
  },
})
```

## ❓ FAQ

<details>
<summary><b>I'm not using tmux — does this still work?</b></summary>

Yes. Write a custom provider (see [Custom providers](#custom-providers)) that
returns a scope from whatever signal you want — a WezTerm tab title, an env
var, the GUI window title, etc.

</details>

<details>
<summary><b>Do I still need to call <code>require("persistence").setup()</code>?</b></summary>

No. `persistence-scope.nvim` calls it for you with the correct `dir` and
`branch`. Move any extra persistence options into this plugin's `opts`.

</details>

<details>
<summary><b>Will this break my existing persistence.nvim keymaps?</b></summary>

No. With `patch_persistence = true` (default), this plugin mirrors its helpers
onto `require("persistence")` so existing code keeps working.

</details>

<details>
<summary><b>Where are my sessions stored?</b></summary>

Under `base_dir` (default: `stdpath("state") .. "/sessions/"`), inside a
subdirectory named after the current scope. See the diagram at the top of this
README.

</details>

<details>
<summary><b>What's <code>recent_seconds</code> for?</b></summary>

If you've been working in the same scope on multiple branches (or the same
project from multiple panes) within a short window, picking the absolute newest
session can be wrong. When more than one session was touched within
`recent_seconds`, restore opens the picker instead of guessing.

</details>

## 🙏 Acknowledgements

- [folke/persistence.nvim](https://github.com/folke/persistence.nvim) — the session backend doing the heavy lifting.
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) — for the gorgeous picker.

## 📄 License

[MIT](./LICENSE) © Bassim Shahidy
