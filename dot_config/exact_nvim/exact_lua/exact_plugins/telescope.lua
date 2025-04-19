return {
	{
		"nvim-telescope/telescope.nvim",
		lazy = true,
		--event = "VeryLazy", -- key mappings do this for now
		cmd = {
			"Telescope",
		},
		version = "*",
		opts = {
			extensions = {
				fzf = {},
			},
		},
		dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-fzf-native.nvim" },
		keys = {
			{ "<leader>ff", "<Cmd>Telescope find_files<CR>", desc = "Telescope find files" },
			{
				"<leader>fa",
				[=[<Cmd>Telescope hidden=true no_ignore=true no_ignore_parent=true<CR>]=],
				desc = "Telescope find files (incl. hidden)",
			},
			{ "<leader>fg", "<Cmd>Telescope live_grep<CR>", desc = "Telescope live grep" },
			{ "<leader>fb", "<Cmd>Telescope buffers<CR>", desc = "Telescope buffers" },
			{ "<leader>fh", "<Cmd>Telescope help_tags<CR>", desc = "Telescope help tags" },
			{ "<leader>fr", "<Cmd>Telescope resume<CR>", desc = "Telescope resume previous search" },
		},
		config = function(_, opts)
			local telescope = require("telescope")
			telescope.setup(vim.tbl_deep_extend("force", opts, {}))

			-- To get fzf loaded and working with telescope, you need to call
			-- load_extension, somewhere after setup function:
			telescope.load_extension("fzf")

			local builtin = require("telescope.builtin")
			local wk = require("which-key")
			wk.add({
				{ "<leader>ff", builtin.find_files, desc = "Telescope find files" },
				{
					"<leader>fa",
					function()
						builtin.find_files({ hidden = true, no_ignore = true, no_ignore_parent = true })
					end,
					desc = "Telescope find files (incl. hidden)",
				},
				{ "<leader>fg", builtin.live_grep, desc = "Telescope live grep" },
				{ "<leader>fb", builtin.buffers, desc = "Telescope buffers" },
				{ "<leader>fh", builtin.help_tags, desc = "Telescope help tags" },
				{ "<leader>fr", builtin.resume, desc = "Telescope resume previous search" },
			})
		end,
	},

	{
		"nvim-telescope/telescope-fzf-native.nvim",
		lazy = true,
		build = function(plugin_spec)
			local result = vim.system({
				"nu",
				"-c",
				[[
# adding policy version minimum until #150 is merged
# https://github.com/nvim-telescope/telescope-fzf-native.nvim/pull/150
cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build build --config Release

let dll_path = './build/Release/libfzf.dll'
if ($dll_path | path exists) {
    cp --verbose $dll_path ./build/libfzf.dll
}
]],
			}, {
				cwd = plugin_spec.dir,
				text = true,
			}):wait()
			if result.code ~= 0 then
				coroutine.yield(result.stderr, vim.log.levels.TRACE)
				return error("failed to build telescope-fzf-native")
			end
			coroutine.yield(result.stdout, vim.log.levels.TRACE)
		end,
	},
}
