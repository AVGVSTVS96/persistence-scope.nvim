local config = require("persistence_scope.config")
local scope = require("persistence_scope.scope")
local util = require("persistence_scope.util")

local M = {}

---@class PersistenceScope.SessionItem
---@field file string             absolute path to the .vim session file
---@field session string          alias for `file` (compatibility with persistence.nvim items)
---@field cwd string              normalized cwd the session was saved from
---@field branch string?          git branch encoded in the session filename
---@field scope_dir string?       sanitized scope directory ("tmux-api" etc.), nil for global
---@field scope_label string      human-readable scope label ("api", "global", …)
---@field mtime number            modification time (seconds since epoch)
---@field age string              short relative age ("3h", "2d", …)
---@field buffers string[]        absolute paths of buffers parsed out of the session file
---@field buffer_summary string   short comma-joined buffer summary
---@field text string             search haystack for the picker
---@field preview table?          optional Snacks preview payload

---@param file string
---@return PersistenceScope.SessionItem?
function M.item_from_file(file)
  local mtime = util.stat(file)
  if not mtime then
    return nil
  end

  local name_cwd, branch = util.decode_session_name(file)
  local file_cwd, buffers = util.parse_session_file(file)
  local scope_dir, scope_label = scope.from_file(file)
  local cwd = file_cwd or name_cwd
  if not cwd then
    return nil
  end

  local item = {
    file = file,
    session = file,
    cwd = cwd,
    branch = branch,
    scope_dir = scope_dir,
    scope_label = scope_label,
    mtime = mtime,
    age = util.reltime(mtime),
    buffers = buffers,
    buffer_summary = util.buffer_summary(buffers),
  }

  item.text = table.concat({
    item.scope_label or "global",
    item.cwd,
    item.branch or "",
    item.buffer_summary,
    table.concat(item.buffers, " "),
  }, " ")

  return item
end

---@param opts { cwd?: string, scope_dir?: string, items?: PersistenceScope.SessionItem[] }
---@return PersistenceScope.SessionItem[]
function M.list(opts)
  opts = opts or {}
  if opts.items then
    return opts.items
  end

  local wanted_cwd = util.normalize(opts.cwd)
  local wanted_scope = opts.scope_dir
  local items = {}

  for _, file in ipairs(util.glob_sessions(scope.base_dir())) do
    local item = M.item_from_file(file)
    if
      item
      and (not wanted_cwd or item.cwd == wanted_cwd)
      and (not wanted_scope or item.scope_dir == wanted_scope)
    then
      items[#items + 1] = item
    end
  end

  table.sort(items, function(a, b)
    if a.mtime == b.mtime then
      return a.file < b.file
    end
    return a.mtime > b.mtime
  end)
  return items
end

---Source a session file, firing the usual persistence Pre/Post events.
---@param file string
---@return boolean
function M.load_file(file)
  if not file or vim.fn.filereadable(file) == 0 then
    return false
  end

  local persistence = require("persistence")
  persistence.fire("LoadPre")
  vim.cmd("silent! source " .. vim.fn.fnameescape(file))
  persistence.fire("LoadPost")
  return true
end

---Count how many items in `items` were modified within `recent_seconds`.
---@param items PersistenceScope.SessionItem[]
---@return integer
function M.recent_count(items)
  local now = os.time()
  local window = config.options.recent_seconds
  local count = 0
  for _, item in ipairs(items) do
    if now - item.mtime <= window then
      count = count + 1
    end
  end
  return count
end

return M
