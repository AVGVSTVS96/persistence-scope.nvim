local M = {}

function M.select(items, opts, on_confirm)
  opts = opts or {}
  vim.ui.select(items, {
    prompt = opts.title or "Select Session",
    format_item = function(item)
      local scope = item.scope_label or "global"
      local branch = item.branch and (" [" .. item.branch .. "]") or ""
      return ("%s  %s  %s%s  %s"):format(item.age or "", scope, item.cwd or item.file, branch, item.buffer_summary or "")
    end,
  }, function(item)
    if item then
      on_confirm(item)
    end
  end)
end

return M
