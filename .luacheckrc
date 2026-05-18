-- vim: ft=lua tw=80

stds.nvim = {
  globals = {
    "vim",
  },
  read_globals = {
    "Snacks",
  },
}

std = "min+nvim"
cache = true

self = false
codes = true
max_line_length = 120

ignore = {
  "212", -- unused argument
  "631", -- max_line_length
}

files["lua/persistence_scope/util.lua"] = {
  -- shadowing `error` from the global namespace is intentional in some lua helpers
  ignore = { "431" },
}
