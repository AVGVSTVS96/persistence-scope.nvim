local M = {}

local uv = vim.uv or vim.loop

function M.join(...)
  local parts = { ... }
  local path = table.concat(
    vim.tbl_filter(function(part)
      return part and part ~= ""
    end, parts),
    "/"
  )
  return path:gsub("/+", "/")
end

function M.with_slash(path)
  path = path or ""
  return path:sub(-1) == "/" and path or (path .. "/")
end

function M.trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.sanitize(value)
  value = M.trim(value)
  value = value:gsub("[/\\:]", "_")
  value = value:gsub("%s+", "_")
  value = value:gsub("[^%w%._-]", "_")
  value = value:gsub("_+", "_")
  return value ~= "" and value or "default"
end

function M.normalize(path)
  if not path or path == "" then
    return nil
  end

  path = M.trim(path)
  if vim.fs and vim.fs.normalize then
    local ok, normalized = pcall(vim.fs.normalize, path)
    if ok and normalized and normalized ~= "" then
      path = normalized
    end
  end

  local full = vim.fn.fnamemodify(path, ":p")
  full = full:gsub("[/\\]+$", "")
  if full == "" and path:match("^[/\\]") then
    return path:sub(1, 1)
  end
  return full
end

function M.unescape(value)
  return M.trim(value):gsub("\\(.)", "%1")
end

function M.reltime(ts)
  local seconds = math.max(0, os.time() - ts)
  if seconds < 60 then
    return "now"
  elseif seconds < 3600 then
    return ("%dm"):format(math.floor(seconds / 60))
  elseif seconds < 86400 then
    return ("%dh"):format(math.floor(seconds / 3600))
  elseif seconds < 604800 then
    return ("%dd"):format(math.floor(seconds / 86400))
  end
  return os.date("%m/%d", ts)
end

function M.newest(items)
  table.sort(items, function(a, b)
    if a.mtime == b.mtime then
      return a.file < b.file
    end
    return a.mtime > b.mtime
  end)
  return items[1]
end

function M.glob_sessions(base_dir)
  base_dir = M.with_slash(base_dir)
  local files = {}
  local seen = {}
  for _, pattern in ipairs({ base_dir .. "*.vim", base_dir .. "**/*.vim" }) do
    for _, file in ipairs(vim.fn.glob(pattern, false, true)) do
      if not seen[file] and vim.fn.filereadable(file) == 1 then
        seen[file] = true
        files[#files + 1] = file
      end
    end
  end
  return files
end

function M.decode_session_name(file)
  local name = vim.fn.fnamemodify(file, ":t:r")
  if name == "" then
    return nil, nil
  end

  local cwd_key, branch_key = name:match("^(.-)%%%%(.+)$")
  if not cwd_key then
    cwd_key = name
  end

  local cwd = cwd_key ~= "" and cwd_key:gsub("%%", "/") or nil
  local branch = branch_key and branch_key:gsub("%%", "/") or nil

  return M.normalize(cwd), branch
end

local function absolute(path, cwd)
  if not path or path == "" or path:find("://") then
    return nil
  end

  path = M.unescape(path)
  if path == "" or path:find("://") then
    return nil
  end

  if path:sub(1, 1) == "~" then
    return M.normalize(path)
  end
  if path:match("^[/\\]") or path:match("^%a:[/\\]") then
    return M.normalize(path)
  end
  return cwd and M.normalize(cwd .. "/" .. path) or path
end

local function file_arg(line)
  local arg = line:match("^%s*badd%s+(.+)$")
  if arg then
    return (arg:gsub("^%+%d+%s+", ""))
  end

  arg = line:match("^%s*edit%s+(.+)$")
  if not arg then
    return nil
  end

  while arg:match("^%+%S+%s+") or arg:match("^%+%+%S+%s+") do
    arg = arg:gsub("^%+%S+%s+", "", 1)
    arg = arg:gsub("^%+%+%S+%s+", "", 1)
  end
  return arg
end

function M.parse_session_file(file)
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok then
    return nil, {}
  end

  local cwd
  local raw_files = {}
  for _, line in ipairs(lines) do
    local cd = line:match("^%s*[lt]?cd%s+(.+)$")
    if cd then
      cwd = M.normalize(M.unescape(cd))
    end

    local arg = file_arg(line)
    if arg then
      raw_files[#raw_files + 1] = arg
    end
  end

  local files = {}
  local seen = {}
  for _, raw in ipairs(raw_files) do
    local path = absolute(raw, cwd)
    if path and not seen[path] then
      seen[path] = true
      files[#files + 1] = path
    end
  end

  return cwd, files
end

function M.buffer_summary(files)
  if #files == 0 then
    return "no files"
  end

  local names = {}
  local seen = {}
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t")
    if name ~= "" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end

  if #names == 0 then
    return "no files"
  end

  local shown = vim.list_slice(names, 1, math.min(#names, 3))
  local summary = table.concat(shown, ", ")
  if #names > #shown then
    summary = summary .. (" +%d"):format(#names - #shown)
  end
  return summary
end

function M.stat(file)
  local stat = uv.fs_stat(file)
  if not stat then
    return nil
  end
  return stat.mtime.sec + ((stat.mtime.nsec or 0) / 1000000000)
end

return M
