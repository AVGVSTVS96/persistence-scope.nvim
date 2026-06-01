local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

function M.check()
  start("persistence-scope.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10")
  else
    error("Neovim 0.10+ is required (using " .. tostring(vim.version()) .. ")")
  end

  local has_persistence, persistence = pcall(require, "persistence")
  if has_persistence then
    ok("folke/persistence.nvim is installed")
    if type(persistence.fire) ~= "function" then
      warn("persistence.nvim is missing `fire()` — load events may not be emitted")
    end
  else
    error("folke/persistence.nvim is not installed (required dependency)")
    return
  end

  local has_snacks = pcall(require, "snacks")
  if has_snacks then
    ok("folke/snacks.nvim is installed — rich picker enabled")
  else
    info("folke/snacks.nvim is not installed — falling back to vim.ui.select")
  end

  local config = require("persistence_scope.config")
  if config.did_setup then
    ok("Configured")
  else
    info("`require('persistence_scope').setup()` has not been called — using defaults")
  end

  local scope = require("persistence_scope.scope")
  if scope.current then
    ok(("Scope resolved: %s (%s) → %s"):format(scope.current.label, scope.current.kind, scope.session_dir()))
  else
    info("No scope resolved — sessions are saved in `base_dir` directly")
    info(("Sessions directory: %s"):format(scope.session_dir()))
  end

  if vim.env.TMUX and vim.env.TMUX ~= "" then
    ok("Running inside tmux (" .. (vim.env.TMUX_PANE or "?") .. ")")
  else
    info("Not running inside tmux — built-in tmux providers will return nil")
  end

  local util = require("persistence_scope.util")
  local files = util.glob_sessions(scope.base_dir())
  info(("Found %d session file(s) under %s"):format(#files, scope.base_dir()))
end

return M
