local util = require("persistence_scope.util")

local M = {}

local function display(format)
  if not vim.env.TMUX then
    return nil
  end

  local cmd = { "tmux", "display-message", "-p" }
  if vim.env.TMUX_PANE and vim.env.TMUX_PANE ~= "" then
    vim.list_extend(cmd, { "-t", vim.env.TMUX_PANE })
  end
  cmd[#cmd + 1] = format

  local ok, lines = pcall(vim.fn.systemlist, cmd)
  if not ok or vim.v.shell_error ~= 0 or not lines or not lines[1] or lines[1] == "" then
    return nil
  end
  return lines[1]
end

local function scope(kind, label, dir_prefix, meta)
  if not label or label == "" then
    return nil
  end

  return {
    kind = kind,
    label = label,
    dir = dir_prefix .. util.sanitize(label),
    meta = meta or {},
  }
end

function M.window_name()
  local label = display("#{window_name}")
  return scope("tmux_window_name", label, "tmux-", {
    window_name = label,
  })
end

function M.window_index()
  local label = display("#{window_index}")
  return scope("tmux_window_index", label, "tmux-window-", {
    window_index = label,
  })
end

function M.pane_id()
  local label = display("#{pane_id}")
  return scope("tmux_pane_id", label, "tmux-pane-", {
    pane_id = label,
  })
end

function M.pane_index()
  local label = display("#{pane_index}")
  return scope("tmux_pane_index", label, "tmux-pane-", {
    pane_index = label,
  })
end

function M.session_window()
  local session = display("#{session_name}")
  local window = display("#{window_name}")
  if not session or not window then
    return nil
  end

  local label = session .. ":" .. window
  return scope("tmux_session_window", label, "tmux-", {
    session_name = session,
    window_name = window,
  })
end

return M
