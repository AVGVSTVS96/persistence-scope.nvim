local scope = require("persistence_scope.scope")
local session = require("persistence_scope.session")
local util = require("persistence_scope.util")

local M = {}

---Restore the best session for the current cwd + scope. See
---|persistence-scope-restore| for the full decision tree.
---@param select fun(opts: table)  picker entry point used for ambiguous cases
---@return boolean
function M.run(select)
  local cwd = util.normalize(vim.fn.getcwd())
  local candidates = session.list({ cwd = cwd })

  if scope.current and scope.current.dir then
    local same_scope = vim.tbl_filter(function(item)
      return item.scope_dir == scope.current.dir
    end, candidates)

    if #same_scope > 0 then
      if session.recent_count(same_scope) > 1 then
        select({
          items = same_scope,
          title = ("Recent sessions for %s"):format(scope.current.label),
        })
        return true
      end
      return session.load_file(util.newest(same_scope).file)
    end

    if #candidates > 0 then
      select({
        items = candidates,
        title = "Sessions for this directory",
      })
      return true
    end
  elseif #candidates == 1 then
    return session.load_file(candidates[1].file)
  elseif #candidates > 1 then
    if session.recent_count(candidates) > 1 then
      select({
        items = candidates,
        title = "Sessions for this directory",
      })
      return true
    end
    return session.load_file(util.newest(candidates).file)
  end

  vim.notify("persistence-scope: no saved session for this scope or cwd", vim.log.levels.INFO)
  return false
end

return M
