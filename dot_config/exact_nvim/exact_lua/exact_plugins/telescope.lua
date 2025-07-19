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
				-- defined in their own config entries
				fzf = {},
				undo = {},
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
			{
				"<leader>fs",
				"<Cmd>Telescope spell_suggest<CR>",
				desc = "suggest words based on the one under the cursor",
			},
			{ "<leader>fo", "<Cmd>Telescope oldfiles<CR>", desc = "Telescope find recent files" },
		},
	},

	{
		"nvim-telescope/telescope-fzf-native.nvim",
		lazy = true,
		dependencies = { "nvim-telescope/telescope.nvim" },
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
		config = function(_, _)
			local telescope = require("telescope")
			telescope.setup({ extensions = { fzf = {} } })
			telescope.load_extension("fzf")
		end,
	},
	{
		"debugloop/telescope-undo.nvim",
		enabled = true,
		lazy = true,
		keys = {
			{ -- lazy style key map
				"<leader>fu",
				"<cmd>Telescope undo<cr>",
				desc = "undo history",
			},
		},
		dependencies = { -- note how they're inverted to above example
			{
				"nvim-telescope/telescope.nvim",
			},
		},
		opts = {
			-- don't use `defaults = { }` here, do this in the main telescope spec
			extensions = {
				undo = {
					-- telescope-undo.nvim config, see below
				},
				-- no other extensions here, they can have their own spec too
			},
		},
		config = function(_, opts)
			-- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
			-- configs for us. We won't use data, as everything is in it's own namespace (telescope
			-- defaults, as well as each extension).
			require("telescope").setup(opts)
			require("telescope").load_extension("undo")
		end,
	},
}
