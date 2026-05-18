local M = {}

local function truncate(text, width, left)
  text = text or ""
  if vim.api.nvim_strwidth(text) <= width then
    return text
  end

  if width <= 2 then
    return string.rep(".", width)
  end

  local keep = width - 2
  if left then
    return ".." .. vim.fn.strcharpart(text, math.max(0, vim.fn.strchars(text) - keep), keep)
  end
  return vim.fn.strcharpart(text, 0, keep) .. ".."
end

local function pad(text, width)
  text = truncate(text, width)
  return text .. string.rep(" ", math.max(0, width - vim.api.nvim_strwidth(text)))
end

local function pad_left(text, width)
  text = truncate(text, width, true)
  return text .. string.rep(" ", math.max(0, width - vim.api.nvim_strwidth(text)))
end

local function pad_min(text, width)
  text = text or ""
  return text .. string.rep(" ", math.max(0, width - vim.api.nvim_strwidth(text)))
end

local function tail_path(path)
  path = (path or ""):gsub("[/\\]+$", "")
  if path == "" then
    return ""
  end

  local parts = {}
  for part in path:gmatch("[^/\\]+") do
    parts[#parts + 1] = part
  end
  if #parts <= 2 then
    return table.concat(parts, "/")
  end
  return parts[#parts - 1] .. "/" .. parts[#parts]
end

function M.select(items, opts, on_confirm)
  opts = opts or {}
  vim.ui.select(items, {
    prompt = opts.title or "Select Session",
    format_item = function(item)
      local age = pad(item.age or "", 5)
      local scope = pad(item.scope_label or "global", 19)
      local cwd = pad_left(tail_path(item.cwd or item.file), 24)
      local branch = item.branch and pad("Branch: " .. item.branch, 26) or ""
      local count = item.buffers and #item.buffers or 0
      local buffers = truncate(("[%d] Buffers: %s"):format(count, item.buffer_summary or ""), 56)
      return table.concat(vim.tbl_filter(function(part)
        return part ~= ""
      end, { age, scope, cwd, branch, buffers }), "  ")
    end,
  }, function(item)
    if item then
      on_confirm(item)
    end
  end)
end

return M
