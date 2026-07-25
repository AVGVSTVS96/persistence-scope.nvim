local scope = require("persistence_scope.scope")
local session = require("persistence_scope.session")
local util = require("persistence_scope.util")

local M = {}

---Smart restore. See |persistence-scope-restore|.
---
---`opts.last = true` drops the cwd filter; primary filter becomes scope-only.
---@param select fun(opts: table)  picker entry point (M.select in init.lua)
---@param opts? { last?: boolean }
---@return boolean
function M.run(select, opts)
  opts = opts or {}

  local all = session.list()
  if #all == 0 then
    vim.notify("persistence-scope: no saved sessions found", vim.log.levels.INFO)
    return false
  end

  local cwd = util.normalize(vim.fn.getcwd())
  local scope_dir = scope.current and scope.current.dir or nil

  -- Primary filter: scope (always) and cwd (unless last=true).
  local primary = vim.tbl_filter(function(item)
    if scope_dir and item.scope_dir ~= scope_dir then
      return false
    end
    if not opts.last and cwd and item.cwd ~= cwd then
      return false
    end
    return true
  end, all)

  -- Prefer the current branch's sessions (skipped for last=true, which is
  -- branch-agnostic like upstream's .last()). On a miss, `branch = true` keeps
  -- only branchless candidates (upstream); `branch = false` keeps every branch.
  -- Applied before the recency check so a single recent session on the current
  -- branch wins outright over newer ones elsewhere.
  if not opts.last then
    primary = session.branch_subset(primary, session.current_branch())
  end

  local recent = session.recent(primary)

  -- 2+ recent matches → picker with those items highlighted.
  if #recent > 1 then
    local highlight = {}
    for _, item in ipairs(recent) do
      highlight[item.file] = true
    end
    local title = opts.last and "Sessions  (recent in scope highlighted)"
      or "Sessions  (recent in scope + cwd highlighted)"
    select({
      title = title,
      sort_context = { recent_files = highlight, cwd = cwd, scope_dir = scope_dir },
    })
    return true
  end

  -- 1+ match, no recency conflict → load newest.
  if #primary >= 1 then
    return session.load_file(util.newest(primary).file)
  end

  -- Primary filter empty but disk isn't → tiered fallback over all sessions.
  local title
  if opts.last then
    title = scope.current and ("Sessions  (no matches in scope '%s')"):format(scope.current.label) or "Sessions"
  else
    title = scope.current and ("Sessions  (no match for this cwd in scope '%s')"):format(scope.current.label)
      or "Sessions  (no match for this cwd)"
  end
  select({
    title = title,
    sort_context = { cwd = cwd, scope_dir = scope_dir },
  })
  return true
end

return M
