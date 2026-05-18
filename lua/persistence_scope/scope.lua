local config = require("persistence_scope.config")
local providers = require("persistence_scope.providers")
local util = require("persistence_scope.util")

local M = {}

---@class PersistenceScope.Scope
---@field kind string         identifier for the provider (e.g. "tmux_window_name")
---@field label string        human-readable label shown in the picker
---@field dir string          directory name appended to base_dir
---@field meta table?         arbitrary extra info exposed to consumers

---The resolved scope for this Neovim instance (or nil for global).
---@type PersistenceScope.Scope?
M.current = nil

---@return string
function M.base_dir()
  return util.with_slash(config.options.base_dir)
end

---Directory where persistence.nvim should save sessions for the current scope.
---@return string
function M.session_dir()
  if M.current and M.current.dir then
    return util.join(M.base_dir(), M.current.dir) .. "/"
  end
  return M.base_dir()
end

---Re-resolve the current scope from the configured provider.
---@return PersistenceScope.Scope?
function M.resolve()
  M.current = providers.resolve(config.options.provider)
  return M.current
end

---Given an absolute session file path, return `(scope_dir, scope_label)`
---where `scope_dir` is nil and `scope_label` is "global" for unscoped files.
---@param file string
---@return string?, string
function M.from_file(file)
  local parent = vim.fn.fnamemodify(file, ":h")
  if util.normalize(parent) == util.normalize(M.base_dir()) then
    return nil, "global"
  end

  local dir = vim.fn.fnamemodify(parent, ":t")
  -- Strip the common "tmux-" prefix for nicer display.
  local label = dir:gsub("^tmux%-", "")
  return dir, label
end

return M
