return {
	"nvim-tree/nvim-tree.lua",
	branch = "master",
	version = "*",
	lazy = true,
	keys = {
		{ "<leader>fb", "<cmd>NvimTreeToggle<cr>", desc = "NvimTree" },
	},
	opts = {
		actions = {
			change_dir = {
				enable = true,
				-- runs :cd when the root is changed
				global = true,
			},
		},
		-- updates the nvim-tree folder browser when :cd is run
		sync_root_with_cwd = false,
		-- custom keymappings
		on_attach = function(bufnr)
			local nvim_tree_api = require("nvim-tree.api")
			-- configure default mappings
			nvim_tree_api.config.mappings.default_on_attach(bufnr)

			--[[
			require("which-key").add({
				{
					"-",
					function()
						nvim_tree_api.tree.change_root_to_parent()
					end,
					desc = "Go up a directory",

					buffer = bufnr,
					noremap = true,
					silent = true,
					nowait = true,
				},
			})
      --]]
		end,
	},
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
}
