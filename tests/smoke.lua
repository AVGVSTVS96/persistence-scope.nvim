-- Headless smoke test for persistence-scope.nvim.
-- Run via:  nvim --headless ... -c "luafile tests/smoke.lua" -c "qa!"

local function fail(msg)
  vim.api.nvim_err_writeln("smoke test FAILED: " .. tostring(msg))
  -- os.exit() is required; cquit runs too late and -c "qa!" overrides it.
  os.exit(1)
end

-- Stub vim.ui.select so picker-opening paths don't block the headless run.
vim.ui.select = function(_, _, on_choice)
  on_choice(nil)
end

local ok, err = pcall(function()
  -- Sandbox base_dir so the test never touches the user's real session dir.
  local sandbox = vim.fn.tempname() .. "/"

  require("persistence_scope").setup({
    provider = function()
      return nil
    end,
    base_dir = sandbox,
  })

  local persistence = require("persistence")
  local ps = require("persistence_scope")

  assert(persistence.load == ps.restore, "persistence.load is not patched to ps.restore")
  assert(type(persistence.load_file) == "function", "persistence.load_file is not installed")
  assert(type(persistence.select) == "function", "persistence.select is missing")

  -- Empty-sandbox: every restore call must return false (no sessions on disk).
  assert(ps.restore({ last = true }) == false, "restore({ last = true }) should return false on empty sandbox")
  assert(ps.restore() == false, "restore() should return false on empty sandbox")

  -- Upstream-style calls against the patched method must not crash.
  persistence.load({ last = true })
  persistence.load()

  -- The PersistenceScopeRecent highlight should be defined after setup.
  local hl = vim.api.nvim_get_hl(0, { name = "PersistenceScopeRecent" })
  assert(type(hl) == "table", "PersistenceScopeRecent highlight is not defined")

  -- :checkhealth must execute without errors.
  vim.cmd("checkhealth persistence_scope")

  -- ── Multi-session save safety (v0.2.0) ──────────────────────────────────
  -- `branch = false` + tempdir cwd → deterministic filename encoding.
  -- Resetting `current_session_file` is the in-process stand-in for a fresh
  -- nvim startup.
  local save_sandbox = vim.fn.tempname() .. "/"
  local tmpcwd = vim.fn.tempname()
  vim.fn.mkdir(tmpcwd, "p")
  vim.cmd("cd " .. vim.fn.fnameescape(tmpcwd))

  require("persistence_scope").setup({
    provider = function()
      return nil
    end,
    base_dir = save_sandbox,
    branch = false,
  })

  local session = require("persistence_scope.session")
  local function list_saved()
    return vim.fn.glob(save_sandbox .. "*.vim", false, true)
  end

  assert(session.current_session_file == nil, "current_session_file should start nil")
  assert(#list_saved() == 0, "save sandbox should start empty")

  persistence.save()
  local files1 = list_saved()
  assert(#files1 == 1, "first save should create exactly 1 file, got " .. #files1)
  local canonical = files1[1]
  assert(not canonical:match("~%d+%.vim$"), "first save should be canonical, got: " .. canonical)
  assert(session.current_session_file == canonical, "save() must commit current_session_file")

  session.current_session_file = nil
  persistence.save()
  local files2 = list_saved()
  assert(#files2 == 2, "fresh instance save should create a 2nd file, got " .. #files2)
  local second
  for _, f in ipairs(files2) do
    if f ~= canonical then
      second = f
    end
  end
  assert(second and second:match("~2%.vim$"), "fresh-instance file should end in ~2.vim, got: " .. tostring(second))

  session.current_session_file = nil
  persistence.save()
  local files3 = list_saved()
  assert(#files3 == 3, "third fresh instance should create a 3rd file, got " .. #files3)
  local has_tilde3 = false
  for _, f in ipairs(files3) do
    if f:match("~3%.vim$") then
      has_tilde3 = true
    end
  end
  assert(has_tilde3, "third-instance file should end in ~3.vim")

  session.current_session_file = canonical
  persistence.save()
  assert(#list_saved() == 3, "save-after-load must not create a new file")
  assert(session.current_session_file == canonical, "save() must keep current_session_file pinned")
end)

if not ok then
  fail(err)
end

print("smoke test OK")
