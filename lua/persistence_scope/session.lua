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
    if item and (not wanted_cwd or item.cwd == wanted_cwd) and (not wanted_scope or item.scope_dir == wanted_scope) then
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

---Return items in `items` modified within `recent_seconds`.
---@param items PersistenceScope.SessionItem[]
---@return PersistenceScope.SessionItem[]
function M.recent(items)
  local now = os.time()
  local window = config.options.recent_seconds
  local out = {}
  for _, item in ipairs(items) do
    if now - item.mtime <= window then
      out[#out + 1] = item
    end
  end
  return out
end

---Count how many items in `items` were modified within `recent_seconds`.
---@param items PersistenceScope.SessionItem[]
---@return integer
function M.recent_count(items)
  return #M.recent(items)
end

---Annotate items with `tier` + `is_recent` and sort in place.
---
---Tiers: 1 = in `recent_files`, 2 = scope+cwd match, 3 = scope match,
---4 = other. Within a tier, newer mtime wins.
---@param items PersistenceScope.SessionItem[]
---@param opts? { recent_files?: table<string, boolean>, cwd?: string, scope_dir?: string }
---@return PersistenceScope.SessionItem[]
function M.sort_tiered(items, opts)
  opts = opts or {}
  local recent_files = opts.recent_files or {}
  local cwd = opts.cwd or util.normalize(vim.fn.getcwd())
  local scope_dir = opts.scope_dir
  if scope_dir == nil then
    scope_dir = scope.current and scope.current.dir or nil
  end

  for _, item in ipairs(items) do
    if recent_files[item.file] then
      item.tier = 1
      item.is_recent = true
    else
      item.is_recent = false
      if scope_dir and item.scope_dir == scope_dir then
        if cwd and item.cwd == cwd then
          item.tier = 2
        else
          item.tier = 3
        end
      else
        item.tier = 4
      end
    end
  end

  table.sort(items, function(a, b)
    if a.tier ~= b.tier then
      return a.tier < b.tier
    end
    if a.mtime == b.mtime then
      return a.file < b.file
    end
    return a.mtime > b.mtime
  end)
  return items
end

return M
