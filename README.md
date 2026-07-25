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
own isolated session scoped to its tmux window name — autosaved on exit and
restored on demand from that same window.

```text
~/.local/state/nvim/sessions/
├── tmux-api/
│   └── %home%me%project.vim
├── tmux-ui/
│   └── %home%me%project.vim
└── tmux-review-auth/
    └── %home%me%project.vim
```

> Sessions are still written by `folke/persistence.nvim` — this plugin only
> redirects them into a per-scope subdirectory and adds a smarter picker on top.

> Not a tmux user? Bring your own scope — any Lua function works (see [Custom providers](#custom-providers)).

## 📚 Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [How it integrates with persistence.nvim](#-how-it-integrates-with-persistencenvim)
- [Commands](#-commands)
- [Lua API](#-lua-api)
- [Configuration](#%EF%B8%8F-configuration)
- [Providers](#-providers)
- [Restore Behavior](#-restore-behavior)
- [Examples](#-examples)
- [Troubleshooting](#-troubleshooting)
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
  "AVGVSTVS96/persistence-scope.nvim",
  dependencies = {
    "folke/persistence.nvim",
    "folke/snacks.nvim", -- optional, for the rich picker
  },
  lazy = false, -- load eagerly so autosave + scope-aware restore keymaps work
  opts = {
    provider = "tmux_window_name",
  },
  -- Standard persistence.nvim keymaps — scope-aware after install.
  keys = {
    { "<leader>qs", function() require("persistence").load() end,                desc = "Restore session" },
    { "<leader>qS", function() require("persistence").select() end,              desc = "Select session" },
    { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
  },
}
```

With Neovim's native package manager (`vim.pack`, Neovim `>= 0.12`):

```lua
vim.pack.add({
  { src = "https://github.com/folke/persistence.nvim" },
  { src = "https://github.com/folke/snacks.nvim" }, -- optional, for the rich picker
  { src = "https://github.com/AVGVSTVS96/persistence-scope.nvim" },
})

require("persistence_scope").setup({
  provider = "tmux_window_name",
})

-- Standard persistence.nvim keymaps — scope-aware after install.
vim.keymap.set("n", "<leader>qs", function()
  require("persistence").load()
end, { desc = "Restore session" })

vim.keymap.set("n", "<leader>qS", function()
  require("persistence").select()
end, { desc = "Select session" })

vim.keymap.set("n", "<leader>ql", function()
  require("persistence").load({ last = true })
end, { desc = "Restore last session" })
```

>[!IMPORTANT]
>`persistence-scope.nvim` calls `require("persistence").setup()` for you.
> If you already configure `persistence.nvim` separately, move those options
> into this plugin's `opts` / `setup()` call and remove the standalone setup call.

## ⚡ Quick Start

1. Name your tmux windows — these become your session labels:

   ```text
   api · ui · review-auth · scratch
   ```

2. Open Neovim in any project from those windows and work normally.

3. Re-open Neovim from the same window, then trigger your normal persistence
   restore — the `:PersistenceScopeRestore` command, your `<leader>qs` keymap,
   or a dashboard "Restore Session" action. The session for that window loads.

That's it. Each tmux window now gets its own isolated neovim session, even when there are multiple instances of the same project CWD.

> [!TIP]
> Prefer restoring on startup without a keypress? Add an opt-in autocmd —
> but note many users dislike unconditional startup restores:
>
> ```lua
> vim.api.nvim_create_autocmd("VimEnter", {
>   nested = true,
>   callback = function()
>     -- only when nvim was started without file args
>     if vim.fn.argc() == 0 then require("persistence").load() end
>   end,
> })
> ```

## 🔗 How it integrates with persistence.nvim

Existing `persistence.nvim` keymaps and dashboard "Restore Session"
buttons keep working — they're now scope-aware.

| `require("persistence")` method | What it does after install |
| --- | --- |
| `.load()`                            | Smart restore. Newest match for the current scope + cwd + branch, or [tiered picker](#-restore-behavior) on ambiguity. |
| `.load({ last = true })`             | Same as `.load()` but **ignores cwd** — newest match in the current scope across any cwd. |
| `.select()`                          | Always opens the tiered picker. |
| `.load_file(path)`                   | **New.** Source a specific session file with `PersistenceLoadPre` / `LoadPost` fired. |
| `.last()` *(query)*                  | Returns newest in *current scope* (because `dir` is redirected). |
| `.save()`                            | Saves each instance's session to its own file even when scope + cwd + branch all match. An instance that loaded a session saves back to it; a fresh one writes canonical first, then `~2.vim`, `~3.vim`, … |
| `.start` / `.stop` / `.current` / `.list` / `.active` / `.branch` | Untouched. Work via the redirected `dir`. |

> [!NOTE]
> `<leader>ql` (`persistence.load({ last = true })`) now returns the
> newest session in your *current scope* (any cwd) instead of the
> globally newest. If the scope is empty, the picker opens over all
> sessions.

## 🧭 Commands

| Command | Description |
| --- | --- |
| `:PersistenceScopeRestore` | Restore the best matching session for the current cwd + scope. Opens the picker if the choice is ambiguous. |
| `:PersistenceScopeSelect`  | Always open the session picker. |

## 🧩 Lua API

For everyday use, call `persistence.nvim` directly — it's scope-aware after
install:

```lua
require("persistence").load()                  -- smart restore (cwd + scope)
require("persistence").load({ last = true })   -- newest in current scope (any cwd)
require("persistence").select()                -- scope-aware picker
require("persistence").load_file(path)         -- source a specific session file
```

`persistence_scope`'s own namespace is just configuration + querying:

```lua
require("persistence_scope").setup(opts)       -- configure (lazy.nvim users pass `opts` instead)
require("persistence_scope").sessions(opts)    -- list/filter session items
require("persistence_scope").config            -- merged config (read-only)
```

`sessions(opts)` returns an array of items with `file`, `cwd`, `scope_label`,
`scope_dir`, `branch`, `mtime`, `age`, `buffers`, `buffer_summary` — useful
for custom dashboards or pickers.

## ⚙️ Configuration

Defaults — pass any subset to `opts`:

```lua
require("persistence_scope").setup({
  -- Scope used to choose the session directory. Either the name of a
  -- built-in provider (see below) or a function returning a scope table.
  provider = "tmux_window_name",

  -- Picker used by `select()` and ambiguous restores.
  --   "auto"    → Snacks when available, otherwise vim.ui.select
  --   "snacks"  → force Snacks
  --   "vim_ui"  → force vim.ui.select
  picker = "auto",

  -- Base directory for all session files. The current scope's directory
  -- is appended to this for the actual save location.
  base_dir = vim.fn.stdpath("state") .. "/sessions/",

  -- Is the git branch a required match for autorestore? Sessions are always
  -- saved per-branch and ranked by branch in the picker regardless.
  --   true  → autorestore loads only the current branch (or branchless) session
  --   false → falls back to any branch on a miss (diverges from persistence.nvim)
  branch = true,

  -- Forwarded to persistence.nvim. Minimum file buffers required for
  -- autosave. `nil` uses the upstream default (1). Set to 0 to always save.
  need = nil,

  -- If more than one current-scope session was modified within this
  -- window of time, restore opens the picker instead of guessing.
  recent_seconds = 4 * 60 * 60,

  -- Extra options forwarded to the Snacks picker.
  snacks = {},
})
```

All options are optional — `require("persistence_scope").setup()` with no
arguments works fine and uses the defaults shown above.

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

Three entry points. Each drops one more filter than the previous:

| Call | scope respected? | cwd respected? | branch respected? |
| --- | :---: | :---: | :---: |
| `persistence.load()`                | ✅ | ✅ | ✅ |
| `persistence.load({ last = true })` | ✅ | ❌ | ❌ |
| `persistence.select()`              | ❌ | ❌ | ❌ |

For `.load()`, the primary filter is also **branch-aware**: it prefers the
current git branch's sessions. On a miss the fallback depends on `branch` — with
`true` (default) it falls back to the branchless (`main`/`master`) session only,
matching `persistence.nvim`; with `false` it falls back to a session on any
branch. `main`/`master` and non-git directories count as branchless.
(`.load({ last = true })` is branch-agnostic by design.)

Decision tree for `.load()` and `.load({ last = true })`:

```text
┌─ run primary filter (scope+cwd[+branch] for .load(), scope-only for .load({last=true}))
│
├─ ≥ 2 matches modified within recent_seconds → 🟡 tiered picker
│                                                  (recent items highlighted)
├─ 1+ match, no recency conflict              → ✅ load newest match
├─ 0 matches but disk has other sessions      → 🟡 tiered picker (no highlights)
└─ 0 sessions on disk anywhere                → ✋ vim.notify, return false
```

**Every picker shows the full session list, sorted by relevance:**

1. 🟡 **Recent in active filter** *(triggered the picker)* — highlighted (`★` in vim.ui.select, bold accent in Snacks)
2. **Same scope + same cwd + same branch**
3. **Same scope + same cwd**, different branch
4. **Same scope**, different cwd
5. **Different scope**

Within a tier, newer mtime wins. `persistence.select()` uses the same
sort with no highlights.

> [!NOTE]
> Multiple sessions can share the same scope + cwd + branch — each
> instance gets its own file (canonical first, then `~2.vim`, `~3.vim`,
> …) and all variants show up in the picker, sorted by mtime.

### Customizing the highlight

```lua
vim.api.nvim_set_hl(0, "PersistenceScopeRecent", { fg = "#f5a97f", bold = true })
```

(Default: linked to `Special` + bold.)

## 🩺 Troubleshooting

Run `:checkhealth persistence_scope` — it reports your Neovim version, whether
`persistence.nvim` / `snacks.nvim` are installed, the resolved scope, where
sessions are being saved, and how many session files already exist.

If scoping doesn't seem to be working:

1. Confirm `:checkhealth` shows a non-`global` scope.
2. Make sure nothing else in your config calls `require("persistence").setup()`
   *after* this plugin loads (see the FAQ entry below).
3. Check `:lua = require("persistence_scope").config.base_dir` and inspect the
   subdirectories there.

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
  "AVGVSTVS96/persistence-scope.nvim",
  dependencies = { "folke/persistence.nvim" },
  opts = { branch = true, need = 1, provider = "tmux_window_name" },
}
```

</details>

<details>
<summary><b>Will my existing persistence.nvim keymaps still work?</b></summary>

Yes. The plugin's primary surface *is* upstream's API — see
[How it integrates with persistence.nvim](#-how-it-integrates-with-persistencenvim)
for the full mapping. Existing `<leader>qs` / `<leader>ql` / `<leader>qS`
keymaps and dashboard "Restore Session" buttons become scope-aware
automatically with no code changes.

This is **separate** from the [setup question above](#do-i-still-need-to-call-requirepersistencesetup):
that one is about `setup()` *options*; this one is about the *runtime functions*
you call from keymaps.

</details>

<details>
<summary><b>Where are my sessions stored?</b></summary>

Under `base_dir` (default: `stdpath("state") .. "/sessions/"`), inside a
subdirectory named after the current scope. See the diagram at the top of this
README.

</details>

<details>
<summary><b>What's <code>recent_seconds</code> for?</b></summary>

When more than one session in the current scope (or scope+cwd) was
touched within this window, restore opens the
[tiered picker](#-restore-behavior) with the recent items highlighted
instead of guessing.

</details>

<details>
<summary><b>Why does the picker show sessions from other scopes / directories?</b></summary>

So you can reach any session in one click instead of canceling and
pressing another keymap. The highlight on the date column marks the
items that triggered the open. See [Restore Behavior](#-restore-behavior)
for the full model.

</details>

## 🙏 Acknowledgements

- [folke/persistence.nvim](https://github.com/folke/persistence.nvim) — the session backend doing the heavy lifting.
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) — for the gorgeous picker.

## 📄 License

[MIT](./LICENSE) © Bassim Shahidy
