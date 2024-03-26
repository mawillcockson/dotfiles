return {
	spec = { import = "plugins" },
	concurrency = vim.g.max_nproc or vim.g.max_nproc_default or 1,
	-- https://github.com/LazyVim/starter/blob/914c60ae75cdf61bf77434d2ad2fbf775efd963b/lua/config/lazy.lua#L31-L45
	performance = {
		rtp = {
			-- disable some rtp plugins
			disabled_plugins = {
				"gzip",
				-- "matchit",
				-- "matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
}
