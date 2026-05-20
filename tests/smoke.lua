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
end)

if not ok then
  fail(err)
end

print("smoke test OK")
