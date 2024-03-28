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
		version = "*",
		branch = "main",
		lazy = false, -- load this as soon as possible, do not wait
		priority = 1001,
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
			vim.cmd.colorscheme("catppuccin")
		end,
	},
	{
		"onsails/lspkind.nvim",
		lazy = false, -- small enough that it can be loaded immediately
		config = function(_, _)
			require("lspkind").init({
				mode = "symbol_text",
			})
		end,
	},
	{ "nvim-lua/plenary.nvim", lazy = true },
	{ "tpope/vim-surround", lazy = true },
	{ "tpope/vim-repeat", lazy = true },
}
