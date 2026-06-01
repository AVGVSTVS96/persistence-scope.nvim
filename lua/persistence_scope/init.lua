-- Scoped sessions for folke/persistence.nvim. Submodules are lazy-required
-- to keep startup cost minimal.

local M = {}

---@type PersistenceScope.Config
M.config = require("persistence_scope.config").defaults

---@type PersistenceScope.Scope?
M.scope = nil

-- Public API

---List session items matching the given filter.
---@param opts? { cwd?: string, scope_dir?: string, items?: PersistenceScope.SessionItem[] }
---@return PersistenceScope.SessionItem[]
function M.sessions(opts)
  return require("persistence_scope.session").list(opts)
end

---Source a specific session file, firing persistence's LoadPre/LoadPost.
---@param file string
---@return boolean
function M.load_file(file)
  return require("persistence_scope.session").load_file(file)
end

---Open the session picker. Always opens — use `restore()` for the smart path.
---@param opts? { items?: PersistenceScope.SessionItem[], title?: string, picker?: string, snacks?: table }
function M.select(opts)
  local config = require("persistence_scope.config").options
  opts = vim.tbl_deep_extend("force", {
    picker = config.picker,
    snacks = config.snacks,
    title = "Sessions",
  }, opts or {})

  local items = M.sessions(opts)
  if #items == 0 then
    vim.notify("persistence-scope: no saved sessions found", vim.log.levels.INFO)
    return
  end

  return require("persistence_scope.pickers").select(items, opts, function(item)
    require("persistence_scope.session").load_item(item)
  end)
end

---Smart restore. See |persistence-scope-restore|.
---
---Installed as `require("persistence").load` by setup(). Returns a boolean
---where upstream's `.load()` returns nil — almost no caller checks it.
---@param opts? { last?: boolean }
---@return boolean
function M.restore(opts)
  return require("persistence_scope.restore").run(M.select, opts)
end

-- Setup

local function ensure_persistence()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    vim.notify(
      "persistence-scope.nvim: folke/persistence.nvim is not installed. "
        .. "Add it as a dependency to enable session persistence.",
      vim.log.levels.ERROR
    )
    return nil
  end
  return persistence
end

local function create_commands()
  vim.api.nvim_create_user_command("PersistenceScopeRestore", function()
    M.restore()
  end, { desc = "Restore the best matching session for cwd + scope", force = true })

  vim.api.nvim_create_user_command("PersistenceScopeSelect", function()
    M.select()
  end, { desc = "Open the persistence-scope session picker", force = true })
end

-- Override with `:hi PersistenceScopeRecent ...` to taste.
local function define_highlights()
  vim.api.nvim_set_hl(0, "PersistenceScopeRecent", { link = "Special", bold = true, default = true })
end

---Configure persistence-scope. Safe to call multiple times.
---@param opts? PersistenceScope.Config
function M.setup(opts)
  local config = require("persistence_scope.config")
  local scope = require("persistence_scope.scope")

  M.config = config.setup(opts)
  M.scope = scope.resolve()

  local persistence = ensure_persistence()
  if persistence then
    persistence.setup({
      dir = scope.session_dir(),
      branch = M.config.branch,
      need = M.config.need,
    })

    -- Upgrade upstream entry points so existing keymaps become scope-aware.
    persistence.load = M.restore
    persistence.select = M.select
    persistence.load_file = M.load_file

    -- Collision-safe save: fresh instances claim a new `~N` slot instead of overwriting.
    local session = require("persistence_scope.session")
    persistence.save = function()
      local file = session.save_path()
      session.current_session_file = file
      vim.cmd("mks! " .. vim.fn.fnameescape(file))
    end
  end

  define_highlights()
  create_commands()
end

return M
