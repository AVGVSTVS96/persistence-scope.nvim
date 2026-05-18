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

`persistence.nvim` saves one session per `cwd` (+ branch). That's perfect, until
you keep **several Neovim instances open in the same repo** for different threads
of work: one tmux window for the API, another for the UI, another for a code
review. They all collide on the same session file and clobber each other.

`persistence-scope.nvim` fixes that by adding a **scope** to the session path.
By default it uses the current tmux window name; each Neovim instance gets its
own isolated session scoped to its tmux window name for automatic persistence
and restoration.

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

- 🪟 **Per-tmux-window sessions** out of the box - name your windows, get named workspaces.
- 🔌 **Pluggable scopes** - pane id, pane index, session+window, or a custom Lua function.
- 🍿 **Rich Snacks picker** with age, scope, branch, buffer summary, and a preview.
- 🪶 **Falls back gracefully** to `vim.ui.select` when Snacks isn't installed.
- 🤝 **Drop-in compatible** with existing `persistence.nvim` keymaps and dashboards.
- 🧠 **Smart restore** picks the best match for your cwd + scope, or asks when it's ambiguous.

## ✅ Requirements

| Requirement | Notes |
| --- | --- |
| Neovim `>= 0.10` | Uses `vim.uv` / `vim.fs.normalize`. |
| [`folke/persistence.nvim`](https://github.com/folke/persistence.nvim) | Required: used as the session backend. |
| [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) | Optional: enables the rich picker. |
| `tmux` | Optional: only needed for the built-in tmux providers. |

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

>[!IMPORTANT]
>`persistence-scope.nvim` calls `require("persistence").setup()` for you.
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

That's it. Each tmux window now gets its own isolated neovim session, even when there are multiple instances of the same project CWD.

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

This plugin also wires itself into `require("persistence")` so existing
keymaps and dashboards benefit from scoping with no code changes:

```lua
require("persistence").select()        -- upgraded to the scope-aware picker
require("persistence").load_file(path) -- added: source a specific session file
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
| `"tmux_pane_id"`            | `#{pane_id}` | `tmux-pane-_17/` *(`%` is sanitized to `_`)* |
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

No — and you should actively **remove** any existing call. `persistence-scope.nvim`
calls `require("persistence").setup()` for you with the correct `dir` and
`branch`. If anything else in your config calls `setup()` afterwards, it will
overwrite `dir` and silently break scoping (all sessions land back in the
shared default directory).

Concretely, make sure none of the following exist in your config:

- A standalone `require("persistence").setup({ ... })` call in your init.lua.
- A separate lazy.nvim spec like `{ "folke/persistence.nvim", opts = {...} }`
  — lazy will call `setup()` on it. Keep persistence.nvim *only* as a
  dependency of `persistence-scope.nvim`, as shown in [Installation](#-installation).

Move any options you were passing to persistence.nvim into this plugin's `opts`
instead:

```lua
-- ❌ Before
{ "folke/persistence.nvim", opts = { branch = true, need = 1 } }

-- ✅ After
{
  "avgvstvs96/persistence-scope.nvim",
  dependencies = { "folke/persistence.nvim" },
  opts = { branch = true, need = 1, provider = "tmux_window_name" },
}
```

</details>

<details>
<summary><b>Will my existing persistence.nvim keymaps still work?</b></summary>

Yes. persistence.nvim is still loaded normally and its full runtime API
(`.load`, `.save`, `.start`, `.stop`, `.list`, `.current`, `.last`, `.branch`,
`.active`, …) keeps working exactly as before.

This is **separate** from the [setup question above](#do-i-still-need-to-call-requirepersistencesetup):
that one is about `setup()` *options*; this one is about the *runtime functions*
you call from keymaps.

This plugin makes two small additions to `require("persistence")`:

| Method on `require("persistence")` | Upstream? | Effect |
| --- | --- | --- |
| `.select()`        | yes | **Upgraded** to the scope-aware / Snacks-capable picker. Existing `<leader>qs → persistence.select()` keymaps benefit automatically. |
| `.load_file(path)` | no  | Added — forwards to `persistence_scope.load_file(path)`. Fills a gap in upstream's API (upstream's `.load()` takes no arguments). |

No other upstream functions are touched. If you'd rather call this plugin
directly, use `require("persistence_scope").select()` from your keymaps —
it's the same function `.select` now points to.

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
