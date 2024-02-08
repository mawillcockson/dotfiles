return {
  "nvim-treesitter/nvim-treesitter",
  -- NOTE: make the condition based off how nvim-treesitter itself seraches to
  -- see if a C compiler is installed, and only enable it when one is
  cond = false,
  build = ":TSUpdate",
  config = function() 
    local configs = require("nvim-treesitter.configs")

    configs.setup({
        ensure_installed = {
          -- commonly used
          "lua", "python", "markdown",
          -- less common
          "toml", "html", "css", "bash", "powershell",
          -- uncommon/hopeful
          "javascript", "scss", "rust", "powershell", "clojure", "csharp", "haskell",
        },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },  
      })
  end,
}
