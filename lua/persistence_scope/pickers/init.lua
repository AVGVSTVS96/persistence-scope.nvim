local M = {}

function M.select(items, opts, on_confirm)
  opts = opts or {}
  local picker = opts.picker or "auto"

  if picker == "auto" or picker == "snacks" then
    local snacks = require("persistence_scope.pickers.snacks")
    if snacks.available() then
      return snacks.select(items, opts, on_confirm)
    elseif picker == "snacks" then
      vim.notify("persistence-scope.nvim: Snacks picker is not available", vim.log.levels.WARN)
    end
  end

  return require("persistence_scope.pickers.vim_ui").select(items, opts, on_confirm)
end

return M
