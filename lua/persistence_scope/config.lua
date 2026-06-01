local M = {}

---@class PersistenceScope.Config
---@field provider string|fun():PersistenceScope.Scope?
---@field picker "auto"|"snacks"|"vim_ui"
---@field base_dir string
---@field branch boolean
---@field need integer?
---@field recent_seconds integer
---@field snacks table

---@type PersistenceScope.Config
M.defaults = {
  -- Scope used to choose the session directory. Either the name of a
  -- built-in provider (see |persistence-scope-providers|) or a function
  -- returning a scope table.
  provider = "tmux_window_name",

  -- Picker used by `select()` and ambiguous restores.
  --   "auto"   → Snacks when available, otherwise vim.ui.select
  --   "snacks" → force Snacks
  --   "vim_ui" → force vim.ui.select
  picker = "auto",

  -- Base directory for all session files. The scope's directory is appended.
  base_dir = vim.fn.stdpath("state") .. "/sessions/",

  -- Forwarded to persistence.nvim. When true, non-main branches get
  -- their own session files.
  branch = true,

  -- Forwarded to persistence.nvim. Minimum number of file buffers required
  -- to autosave a session.
  need = nil,

  -- If more than one current-scope session was modified within this window
  -- of time, restore opens the picker instead of guessing.
  recent_seconds = 4 * 60 * 60,

  -- Extra options forwarded to the Snacks picker.
  snacks = {},
}

---@type PersistenceScope.Config
M.options = vim.deepcopy(M.defaults)

---Whether setup() has run. `M.options` is a deepcopy of defaults, so identity
---comparison can't tell "configured" from "untouched" — track it explicitly.
---@type boolean
M.did_setup = false

local util = require("persistence_scope.util")

---@param opts table?
function M.setup(opts)
  M.did_setup = true
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.options.base_dir = util.with_slash(M.options.base_dir)
  return M.options
end

return M
