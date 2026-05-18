local M = {}

function M.available()
  local ok, snacks = pcall(require, "snacks")
  snacks = ok and snacks or rawget(_G, "Snacks")
  return snacks and snacks.picker ~= nil
end

local function format(item)
  local Snacks = require("snacks")
  local align = Snacks.picker.util.align
  local cwd = item.cwd or ""
  local cwd_name = vim.fn.fnamemodify(cwd, ":t")
  local cwd_parent = cwd ~= "" and vim.fn.fnamemodify(cwd, ":h:~") or ""
  if cwd_name == "" then
    cwd_name = cwd ~= "" and cwd or "unknown"
  end

  local ret = {}
  ret[#ret + 1] = { align(item.age or "", 10), "SnacksPickerTime" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(item.scope_label or "global", 24, { truncate = true }), "Identifier" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(cwd_name, 24, { truncate = true }), "Directory" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(cwd_parent, 36, { truncate = true }), "Comment" }

  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(item.buffer_summary or "", 44, { truncate = true }), "Comment" }

  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(item.branch or "", 22, { truncate = true }), "Number" }
  return ret
end

function M.select(items, opts, on_confirm)
  opts = opts or {}
  local Snacks = require("snacks")

  local picker_opts = vim.tbl_deep_extend("force", opts.snacks or {}, {
    source = "persistence_scope",
    items = items,
    title = opts.title or "Sessions",
    format = format,
    preview = "preview",
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function()
          on_confirm(item)
        end)
      end
    end,
    sort = { fields = { "mtime:desc" } },
  })

  return Snacks.picker(picker_opts)
end

return M
