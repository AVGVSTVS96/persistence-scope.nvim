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
  if type(provider) == "function" then
    return provider()
  end

  local fn = providers[provider or "tmux_window_name"]
  if not fn then
    vim.notify(("Unknown persistence-scope provider: %s"):format(provider), vim.log.levels.WARN)
    return nil
  end
  return fn()
end

return M
