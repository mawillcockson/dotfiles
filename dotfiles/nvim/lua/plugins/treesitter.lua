-- DONE: make the condition based off how nvim-treesitter itself searches to
-- see if a C compiler is installed, and only enable it when one is.
-- Based off of nvim-tresitter instal process:
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/v0.9.2/lua/nvim-treesitter/install.lua#L19
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/v0.9.2/lua/nvim-treesitter/shell_command_selectors.lua#L74-L80

local default_compilers = { vim.fn.getenv "CC", "cc", "gcc", "clang", "cl", "zig" }

---@return bool|nil
function has_compiler()
  return vim.tbl_filter(function(c) ---@param c string
    return c ~= vim.NIL and vim.fn.executable(c) == 1
  end, default_compilers)[1]
end

vim.notify("has_compiler() -> " .. tostring(has_compiler()) .. "\n" ..
           "has tree-sitter -> " .. vim.fn.executable("tree-sitter"),
  vim.log.levels.INFO,
  {}
)

return {
  "nvim-treesitter/nvim-treesitter",
  enabled = has_compiler() and vim.fn.executable "tree-sitter",
  version = "*",
  build = ":TSUpdate",
  config = function() 
    local configs = require("nvim-treesitter.configs")

    configs.setup({
        ensure_installed = {
          -- NOTE: need better automatic installation
          -- NOTE: commented out languages have either broken parsers, or don't
          -- have automatically included parsers:
          -- https://github.com/nvim-treesitter/nvim-treesitter/tree/v0.9.2#adding-parsers

          "python", --"markdown", "javascript", "clojure", "html", "css", "scss",
          --[==[
          -- commonly used
          --[["lua",]] "python", "markdown",
          -- less common
          "toml", "html", "css", "bash", --[["powershell",]]
          -- uncommon/hopeful
          "javascript", "scss", "rust", "clojure", --[["csharp",]] "haskell",
          --]==]
        },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },  
      })
  end,
}
