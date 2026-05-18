local M = {}

local path_width = 32

function M.available()
  local ok, snacks = pcall(require, "snacks")
  snacks = ok and snacks or rawget(_G, "Snacks")
  return snacks and snacks.picker ~= nil
end

local function tail_path(path)
  path = (path or ""):gsub("[/\\]+$", "")
  if path == "" then
    return "unknown"
  end

  local parts = {}
  for part in path:gmatch("[^/\\]+") do
    parts[#parts + 1] = part
  end
  if #parts == 0 then
    return "unknown"
  end
  if #parts == 1 then
    return "../" .. parts[1]
  end
  return "../" .. parts[#parts - 1] .. "/" .. parts[#parts]
end

local function format_path(path)
  if vim.api.nvim_strwidth(path) <= path_width then
    return path
  end

  local parent, current = path:match("^%.%./(.*)/([^/]+)$")
  if not parent or not current then
    return ".." .. vim.fn.strcharpart(path, math.max(0, vim.fn.strchars(path) - path_width + 2), path_width - 2)
  end

  local current_width = vim.api.nvim_strwidth(current)
  if current_width + 3 >= path_width then
    return ".." .. vim.fn.strcharpart(current, math.max(0, vim.fn.strchars(current) - path_width + 2), path_width - 2)
  end

  local parent_width = path_width - current_width - 3
  local trimmed_parent = vim.fn.strcharpart(parent, math.max(0, vim.fn.strchars(parent) - parent_width), parent_width)
  return ".." .. trimmed_parent .. "/" .. current
end

local function format(item)
  local Snacks = require("snacks")
  local align = Snacks.picker.util.align
  local cwd = format_path(tail_path(item.cwd))

  local ret = {}
  ret[#ret + 1] = { align(item.age or "", 7), "SnacksPickerTime" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(item.scope_label or "global", 24, { truncate = true }), "Identifier" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { align(cwd, path_width), "Directory" }

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
