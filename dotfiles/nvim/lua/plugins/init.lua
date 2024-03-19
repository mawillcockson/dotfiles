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
      background = {
        light = "latte",
        dark = "mocha",
      },
      term_colors = true,
    },
    config = function(opts)
      -- vim.g.catppuccin_debug = true
      require("catppuccin").setup(opts.opts)
      vim.cmd.colorscheme "catppuccin"
    end,
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
