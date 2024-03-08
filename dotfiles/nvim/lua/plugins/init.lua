-- plugins that don't fit a category and don't need configuration

-- NOTE: all plugins should have a version = "*" or config.defaults.version = "*" to be set
-- https://github.com/folke/lazy.nvim#versioning
return {
  {
    "folke/lazy.nvim",
    version = "*",
    branch = "main",
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1001,
    version = "*",
    branch = "main",
    opts = {
      flavour = "latte",
    },
    config = function(opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme "catppuccin"
    end,
  },
  {
    -- https://github.com/neovim/nvim-lspconfig?tab=readme-ov-file#suggested-configuration
    "neovim/nvim-lspconfig",
    lazy = true,
  },
  {
    "onsails/lspkind.nvim",
    config = function(_, _)
      require("lspkind").init{
        mode = "symbol_text",
      }
    end,
  },
  "nvim-lua/plenary.nvim",
  "tpope/vim-surround",
  "tpope/vim-repeat",
}
