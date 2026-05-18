local M = {}

local path_width = 32

function M.available()
  local ok, snacks = pcall(require, "snacks")
  snacks = ok and snacks or rawget(_G, "Snacks")
  return snacks and snacks.picker ~= nil
end

-- Path helpers

local function home_alias(path)
  if not path or path == "" then
    return "unknown"
  end
  return vim.fn.fnamemodify(path, ":~")
end

local function cwd_relative(path, cwd)
  if not path or path == "" then
    return "unknown"
  end
  if not cwd or path == cwd then
    return path == cwd and "." or home_alias(path)
  end
  local prefix = cwd .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return home_alias(path)
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

-- Preview (Snacks-specific markdown rendering)

local function preview_line(lines, extmarks, text, marks)
  lines[#lines + 1] = text
  local row = #lines
  for _, mark in ipairs(marks or {}) do
    extmarks[#extmarks + 1] = {
      row = row,
      col = mark.col,
      end_col = mark.end_col,
      hl_group = mark.hl_group,
      hl_mode = "replace",
      priority = 200,
    }
  end
end

local function preview_field(lines, extmarks, label, value, hl_group)
  value = tostring(value or "none")
  local text = ("%-8s %s"):format(label, value)
  preview_line(lines, extmarks, text, {
    { col = 0, end_col = #label, hl_group = "SnacksPickerDimmed" },
    { col = 9, end_col = #text, hl_group = hl_group },
  })
end

local function build_preview(item)
  local lines = {}
  local extmarks = {}

  preview_line(lines, extmarks, "# Session", {
    { col = 0, end_col = 9, hl_group = "@markup.heading.1.markdown" },
  })
  preview_field(lines, extmarks, "Path", home_alias(item.file), "SnacksPickerComment")
  preview_field(lines, extmarks, "CWD", home_alias(item.cwd), "SnacksPickerDirectory")
  preview_field(lines, extmarks, "Scope", item.scope_label or "global", "SnacksPickerSpecial")
  preview_field(
    lines,
    extmarks,
    "Branch",
    item.branch or "none",
    item.branch and "SnacksPickerGitBranch" or "SnacksPickerComment"
  )
  preview_field(lines, extmarks, "Modified", os.date("%Y-%m-%d %H:%M:%S", item.mtime), "SnacksPickerTime")
  preview_line(lines, extmarks, "")

  local files_title = ("## Files (%d)"):format(#item.buffers)
  preview_line(lines, extmarks, files_title, {
    { col = 0, end_col = #files_title, hl_group = "@markup.heading.2.markdown" },
  })

  if #item.buffers == 0 then
    preview_line(lines, extmarks, "  none parsed", {
      { col = 2, end_col = 13, hl_group = "SnacksPickerComment" },
    })
  else
    for _, file in ipairs(item.buffers) do
      local path = cwd_relative(file, item.cwd)
      local text = "- " .. path
      preview_line(lines, extmarks, text, {
        { col = 2, end_col = #text, hl_group = "SnacksPickerFile" },
      })
    end
  end

  return {
    text = table.concat(lines, "\n"),
    ft = "markdown",
    extmarks = extmarks,
    loc = false,
  }
end

-- Row formatter

local function format_row(item)
  local Snacks = require("snacks")
  local align = Snacks.picker.util.align
  local cwd = format_path(tail_path(item.cwd))

  return {
    { align(item.age or "", 7), "SnacksPickerTime" },
    { " " },
    { align(item.scope_label or "global", 24, { truncate = true }), "Identifier" },
    { " " },
    { align(cwd, path_width), "Directory" },
    { " " },
    { align(item.buffer_summary or "", 44, { truncate = true }), "Comment" },
    { " " },
    { align(item.branch or "", 22, { truncate = true }), "Number" },
  }
end

-- Entry point

function M.select(items, opts, on_confirm)
  opts = opts or {}
  local Snacks = require("snacks")

  -- Attach preview payloads lazily so the cheap vim.ui fallback never pays
  -- for them.
  for _, item in ipairs(items) do
    if not item.preview then
      item.preview = build_preview(item)
    end
  end

  local picker_opts = vim.tbl_deep_extend("force", opts.snacks or {}, {
    source = "persistence_scope",
    items = items,
    title = opts.title or "Sessions",
    format = format_row,
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
