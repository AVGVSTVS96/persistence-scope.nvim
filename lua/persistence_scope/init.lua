local providers = require("persistence_scope.providers")
local pickers = require("persistence_scope.pickers")
local util = require("persistence_scope.util")

local M = {}

M.config = {
  provider = "tmux_window_name",
  picker = "auto",
  base_dir = vim.fn.stdpath("state") .. "/sessions/",
  branch = true,
  recent_seconds = 4 * 60 * 60,
  patch_persistence = true,
  snacks = {},
}

M.scope = nil

local function base_dir()
  return util.with_slash(M.config.base_dir)
end

local function session_dir()
  if M.scope and M.scope.dir then
    return util.join(base_dir(), M.scope.dir) .. "/"
  end
  return base_dir()
end

local function scope_from_file(file)
  local parent = vim.fn.fnamemodify(file, ":h")
  if util.normalize(parent) == util.normalize(base_dir()) then
    return nil, "global"
  end

  local dir = vim.fn.fnamemodify(parent, ":t")
  local label = dir:gsub("^tmux%-", "")
  return dir, label
end

local function preview_text(item)
  local lines = {
    "# Session",
    "",
    ("Path: `%s`"):format(item.file),
    ("CWD: `%s`"):format(item.cwd or "unknown"),
    ("Scope: `%s`"):format(item.scope_label or "global"),
    ("Branch: `%s`"):format(item.branch or "none"),
    ("Modified: `%s`"):format(os.date("%Y-%m-%d %H:%M:%S", item.mtime)),
    "",
    "Files:",
  }

  if #item.buffers == 0 then
    lines[#lines + 1] = "- none parsed"
  else
    for _, file in ipairs(item.buffers) do
      lines[#lines + 1] = "- `" .. file .. "`"
    end
  end

  return table.concat(lines, "\n")
end

local function item_from_file(file)
  local mtime = util.stat(file)
  if not mtime then
    return nil
  end

  local name_cwd, branch = util.decode_session_name(file)
  local file_cwd, buffers = util.parse_session_file(file)
  local scope_dir, scope_label = scope_from_file(file)
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
  item.preview = {
    text = preview_text(item),
    ft = "markdown",
    loc = false,
  }

  return item
end

function M.sessions(opts)
  opts = opts or {}
  if opts.items then
    return opts.items
  end

  local wanted_cwd = util.normalize(opts.cwd)
  local wanted_scope = opts.scope_dir
  local items = {}

  for _, file in ipairs(util.glob_sessions(base_dir())) do
    local item = item_from_file(file)
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

M.session_items = M.sessions

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

function M.select(opts)
  opts = vim.tbl_deep_extend("force", {
    picker = M.config.picker,
    snacks = M.config.snacks,
    title = "Sessions",
  }, opts or {})

  local items = M.sessions(opts)
  if #items == 0 then
    vim.notify("No saved sessions found", vim.log.levels.INFO)
    return
  end

  return pickers.select(items, opts, function(item)
    M.load_file(item.file)
  end)
end

local function recent_count(items)
  local now = os.time()
  local count = 0
  for _, item in ipairs(items) do
    if now - item.mtime <= M.config.recent_seconds then
      count = count + 1
    end
  end
  return count
end

function M.restore()
  local cwd = util.normalize(vim.fn.getcwd())
  local candidates = M.sessions({ cwd = cwd })

  if M.scope and M.scope.dir then
    local same_scope = vim.tbl_filter(function(item)
      return item.scope_dir == M.scope.dir
    end, candidates)

    if #same_scope > 0 then
      if recent_count(same_scope) > 1 then
        return M.select({
          items = same_scope,
          title = ("Recent sessions for %s"):format(M.scope.label),
        })
      end
      return M.load_file(util.newest(same_scope).file)
    end

    if #candidates > 0 then
      return M.select({
        items = candidates,
        title = "Sessions for this directory",
      })
    end
  elseif #candidates == 1 then
    return M.load_file(candidates[1].file)
  elseif #candidates > 1 then
    if recent_count(candidates) > 1 then
      return M.select({
        items = candidates,
        title = "Sessions for this directory",
      })
    end
    return M.load_file(util.newest(candidates).file)
  end

  vim.notify("No saved session found for this scope or cwd", vim.log.levels.INFO)
  return false
end

local function create_commands()
  vim.api.nvim_create_user_command("PersistenceScopeRestore", function()
    M.restore()
  end, { force = true })
  vim.api.nvim_create_user_command("PersistenceScopeSelect", function()
    M.select()
  end, { force = true })
end

local function patch_persistence()
  if not M.config.patch_persistence then
    return
  end

  local persistence = require("persistence")
  persistence.load_tmux_fallback = M.restore
  persistence.select = M.select
  persistence.load_file = M.load_file
  persistence.session_items = M.sessions
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.base_dir = base_dir()
  M.scope = providers.resolve(M.config.provider)

  require("persistence").setup({
    dir = session_dir(),
    branch = M.config.branch,
    need = M.config.need,
  })

  create_commands()
  patch_persistence()
end

return M
