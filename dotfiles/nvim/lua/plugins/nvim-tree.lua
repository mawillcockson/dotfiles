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

			local function opts(desc)
				return {
					["desc"] = "nvim-tree: " .. tostring(desc),
					buffer = bufnr,
					noremap = true,
					silent = true,
					nowait = true,
				}
			end

      --[[
			vim.keymap.set("n", "-", function()
				nvim_tree_api.tree.change_root_to_parent()
			end, opts("Go up a directory"))
      --]]
		end,
	},
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
}
