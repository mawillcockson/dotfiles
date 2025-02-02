return {
	"folke/which-key.nvim",
	branch = "main",
	version = "*",
	lazy = true,
	event = "VeryLazy",
	init = function()
		-- recommended config:
		-- https://github.com/folke/which-key.nvim?tab=readme-ov-file#lazynvim
		vim.o.timeout = true
		vim.o.timeoutlen = 300
	end,
	opts = {
		spec = {
			-- NOTE::BUG mapping just the leader to something, and then mapping something
			-- to e.g. <Leader>a makes the original just-<Leader> mapping delay as it waits
			-- to see if just <Leader> was intended, or if another key is about to be
			-- pressed. (:help map-ambiguous)
			-- Is there a way to set this timeout to zero, and rely on being able to press
			-- and hold <Leader> key sequences? Would that make multi-key sequences like
			-- <Leader>ab require holding <Leader>, then a, and while still holding down
			-- both, pressing b? Or would it work more like Windows numpad keycombos of
			-- pressing and holding Alt, then typing in a code on the keypad without having
			-- to hold any of the number keys down, finished by releasing Alt.
			-- Holding the <Leader> is the same as holding any other key: the action is
			-- repeated. So if it's mapped to anything, holding isn't an option.
			--
			-- This repository might have some hints on how to work around this delay:
			-- https://github.com/max397574/better-escape.nvim
			--
			-- Best we can do is map it to a no-op
			-- NOTE: commenting this out so that which-key shows options on potential
			-- next keys
			--["<Space>"] = { "<Nop>", "map leader to do nothing on its own" },
			{ "<BS>", "<Nop>", desc = "disable backspace" },
			{
				"j",
				function()
					-- What is the internal representation of the <C-e> sequence?
					local c_e = vim.api.nvim_replace_termcodes("<C-e>", true, false, true)

					-- what count was given with j? defaults to 1 (e.g. 10j to move 10 lines
					-- down, j the same as 1j)
					local count1 = vim.v.count1
					local nvim_command = vim.api.nvim_command
					local line = vim.fn.line
					-- how far from the end of the file is the current cursor position?
					local distance = line("$") - line(".")
					-- if the number of times j should be pressed is greater than the number of
					-- lines until the bottom of the file
					if count1 > distance then
						-- if the cursor isn't on the last line already
						if distance > 0 then
							-- press j to get to the bottom of the file
							-- NOTE: Is there a way to call :normal! besides this?
							nvim_command("normal! " .. distance .. "j")
						end
						-- then press Ctrl+E for the rest of the count
						nvim_command("normal! " .. (count1 - distance) .. c_e)
					-- if the count is smaller and the cursor isn't on the last line
					elseif distance > 0 then
						-- press j as much as requested
						nvim_command("normal! " .. count1 .. "j")
					else
						-- otherwise press Ctrl+E the requested number of times
						nvim_command("normal! " .. count1 .. c_e)
					end
				end,
				desc = "continue scrolling past end of file with j",
			},

			-- Disable in favor of TJ Devries' use of C-y
			-- I never remember it anyways
			-- {"<C-y>", "<Cmd>%y+<CR>", desc = "copy whole file" },
			{ "<leader>yy", "<Cmd>%y+<CR>", desc = "copy whole buffer into system clipboard" },

			{
				"<C-^>",
				"<C-[><C-^>",
				desc = "also enable switching to alternate files in insert mode"
					.. " (this does overwrite a default mapping, but I never use it)",
				mode = "i",
			},

			{
				"<C-v>",
				function()
					vim.api.nvim_put({ vim.fn.getreg("+") }, "", true, true)
				end,
				desc = "enable easy pasting in terminals",
				mode = "t",
			},

			{
				"<C-^>",
				[[<C-\><C-n><C-^>]],
				desc = "when in Terminal input mode, pressing Ctrl+Shift+6 will go "
					.. "to Terminal-Normal mode, then switch to the alternate buffer",
				mode = "t",
			},

			{
				"<leader>h",
				function()
					-- from:
					-- https://www.reddit.com/r/neovim/comments/wrj7eu/comment/ikswlfo/?utm_source=share&utm_medium=web2x&context=3
					local num_matches = vim.fn.searchcount({ recompute = false }).total or 0
					if num_matches < 1 then
						vim.notify("nothing to highlight", vim.log.levels.WARN, {})
						return
					end
					vim.opt.hlsearch = not vim.o.hlsearch
				end,
				desc = "toggles highlighting of search results in Normal mode",
			},
			{ "<leader>s", "<Cmd>set spell!<CR>", desc = "toggle spellchecking underlines" },

			{
				"<C-e>",
				require("terminal-handling").open_and_switch,
				desc = "switch to terminal",
				mode = { "n", "i" },
			},

			{ "<C-l>", "<Cmd>:tabnext<CR>", desc = "switch tab rightwards", mode = { "n", "i", "t" } },
			{ "<C-PageDown>", "<Cmd>:tabnext<CR>", desc = "switch tab rightwards", mode = { "n", "i", "t" } },
			{ "<C-h>", "<Cmd>:tabprevious<CR>", desc = "switch tab leftwards", mode = { "n", "i", "t" } },
			{ "<C-PageUp>", "<Cmd>:tabprevious<CR>", desc = "switch tab leftwards", mode = { "n", "i", "t" } },
			{ "<C-S-PageUp>", "<Cmd>:-tabmove<CR>", desc = "move current tab leftwards", mode = { "n", "i", "t" } },
			{ "<C-S-PageDown>", "<Cmd>:+tabmove<CR>", desc = "move current tab rightwards", mode = { "n", "i", "t" } },
			{ "<leader>m", group = "miscellaneous" },
			{
				"<leader>mi",
				vim.cmd.Inspect,
				desc = ":Inspect the syntax and highlighting of the text under the cursor",
			},
			{
				"<leader>mh",
				function()
					local info = vim.inspect_pos(nil, nil, nil, {
						syntax = false,
						treesitter = true,
						extmarks = false,
						semantic_tokens = false,
					})
					local ts_info = info.treesitter
					local last = ts_info[#ts_info]
					if last == nil then
						vim.notify("no treesitter stuff under cursor", vim.log.levels.WARN)
					end
					local hl_group = last.hl_group
					local syntax_id = vim.fn.synIDtrans(vim.fn.hlID(hl_group))
					local fg = tostring(vim.fn.synIDattr(syntax_id, "fg#"))
					local bg = tostring(vim.fn.synIDattr(syntax_id, "bg#"))

					-- create a highlight group in the global namespace
					local temp_hl_name = "TempHighlightGroup"
					local fg_hl_name = temp_hl_name .. "FG"
					local bg_hl_name = temp_hl_name .. "BG"
					vim.api.nvim_set_hl(0, fg_hl_name, { fg = fg, force = true })
					vim.api.nvim_set_hl(0, bg_hl_name, { bg = bg, force = true })
					if vim.fn.has("clipboard") == 1 then
						vim.fn.setreg("+", (fg or bg):gsub("#", ""))
					end
					vim.api.nvim_echo({
						{ "fg: ", "None" },
						{ fg, fg_hl_name },
						{ ", bg: ", "None" },
						{ bg, bg_hl_name },
					}, true, { verbose = false })
				end,
				desc = "try to show the :Inspect colors under the cursor",
			},
		},
	},
	config = function(_, opts)
		vim.notify("setting keymaps", vim.log.levels.DEBUG, {})
		require("which-key").setup(opts)
	end,
}
