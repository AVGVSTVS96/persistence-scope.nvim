-- persistence-scope.nvim — bootstrap
--
-- User commands are defined here so they're discoverable even before
-- `require("persistence_scope").setup()` has been called. `setup()` will
-- replace them with the final (identical) handlers.

if vim.g.loaded_persistence_scope == 1 then
  return
end
vim.g.loaded_persistence_scope = 1

local function lazy(name)
  return function()
    require("persistence_scope")[name]()
  end
end

vim.api.nvim_create_user_command("PersistenceScopeRestore", lazy("restore"), {
  desc = "Restore the best matching session for cwd + scope",
})

vim.api.nvim_create_user_command("PersistenceScopeSelect", lazy("select"), {
  desc = "Open the persistence-scope session picker",
})
