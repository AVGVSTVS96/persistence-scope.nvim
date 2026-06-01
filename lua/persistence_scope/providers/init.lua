local util = require("persistence_scope.util")

local M = {}

local tmux = require("persistence_scope.providers.tmux")

local providers = {
  tmux_window_name = tmux.window_name,
  tmux_window_index = tmux.window_index,
  tmux_pane_id = tmux.pane_id,
  tmux_pane_index = tmux.pane_index,
  tmux_session_window = tmux.session_window,
}

function M.resolve(provider)
  local scope
  if type(provider) == "function" then
    scope = provider()
  else
    local fn = providers[provider or "tmux_window_name"]
    if not fn then
      vim.notify(("Unknown persistence-scope provider: %s"):format(provider), vim.log.levels.WARN)
      return nil
    end
    scope = fn()
  end

  if scope == nil then
    return nil
  end

  -- Custom providers can return any string; `dir` is used as a folder name.
  scope.dir = util.sanitize(scope.dir or scope.label)
  return scope
end

return M
