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
		--[==[ v1.6.0
		plugins = {
			marks = true, -- shows a list of your marks on ' and `
			registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
			-- the presets plugin, adds help for a bunch of default keybindings in Neovim
			-- No actual key bindings are created
			spelling = {
				enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
				suggestions = 20, -- how many suggestions should be shown in the list?
			},
			presets = {
				operators = true, -- adds help for operators like d, y, ...
				motions = true, -- adds help for motions
				text_objects = true, -- help for text objects triggered after entering an operator
				windows = true, -- default bindings on <c-w>
				nav = true, -- misc bindings to work with windows
				z = true, -- bindings for folds, spelling and others prefixed with z
				g = true, -- bindings for prefixed with g
			},
		},
		-- add operators that will trigger motion and text object completion
		-- to enable all native operators, set the preset / operators plugin above
		operators = { gc = "Comments" },
		key_labels = {
			-- override the label used to display some keys. It doesn't effect WK in any other way.
			-- For example:
			-- ["<space>"] = "SPC",
			-- ["<cr>"] = "RET",
			-- ["<tab>"] = "TAB",
		},
		motions = {
			count = true,
		},
		icons = {
			breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
			separator = "➜", -- symbol used between a key and it's label
			group = "+", -- symbol prepended to a group
		},
		popup_mappings = {
			scroll_down = "<c-d>", -- binding to scroll down inside the popup
			scroll_up = "<c-u>", -- binding to scroll up inside the popup
		},
		window = {
			border = "none", -- none, single, double, shadow
			position = "bottom", -- bottom, top
			margin = { 1, 0, 1, 0 }, -- extra window margin [top, right, bottom, left]. When between 0 and 1, will be treated as a percentage of the screen size.
			padding = { 1, 2, 1, 2 }, -- extra window padding [top, right, bottom, left]
			winblend = 0, -- value between 0-100 0 for fully opaque and 100 for fully transparent
			zindex = 1000, -- positive value to position WhichKey above other floating windows.
		},
		layout = {
			height = { min = 4, max = 25 }, -- min and max height of the columns
			width = { min = 20, max = 50 }, -- min and max width of the columns
			spacing = 3, -- spacing between columns
			align = "left", -- align columns left, center or right
		},
		ignore_missing = false, -- enable this to hide mappings for which you didn't specify a label
		hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "^:", "^ ", "^call ", "^lua " }, -- hide mapping boilerplate
		show_help = true, -- show a help message in the command line for using WhichKey
		show_keys = true, -- show the currently pressed key and its label as a message in the command line
		triggers = "auto", -- automatically setup triggers
		-- triggers = {"<leader>"} -- or specifiy a list manually
		-- list of triggers, where WhichKey should not wait for timeoutlen and show immediately
		triggers_nowait = {
			-- marks
			"`",
			"'",
			"g`",
			"g'",
			-- registers
			'"',
			"<c-r>",
			-- spelling
			"z=",
		},
		triggers_blacklist = {
			-- list of mode / prefixes that should never be hooked by WhichKey
			-- this is mostly relevant for keymaps that start with a native binding
			i = { "j", "k" },
			v = { "j", "k" },
		},
		-- disable the WhichKey popup for certain buf types and file types.
		-- Disabled by default for Telescope
		disable = {
			buftypes = {},
			filetypes = {},
		},
  --]==]
	},

	config = function(_, opts)
		vim.notify("setting keymaps", vim.log.levels.INFO, {})
		local wk = require("which-key")

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

		wk.register({
			-- Best we can do is map it to a no-op
			-- NOTE: commenting this out so that which-key shows options on potential
			-- next keys
			--["<Space>"] = { "<Nop>", "map leader to do nothing on its own" },
			["<BS>"] = { "<Nop>", "disable backspace" },
			j = {
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
				"continue scrolling past end of file with j",
			},
			["<C-y>"] = { "<Cmd>%y+<CR>", "copy whole file" },
		}, { mode = "n" })

		wk.register({
			["<C-^>"] = {
				"<C-[><C-^>",
				"also enable switching to alternate files in insert mode"
					.. " (this does overwrite a default mapping, but I never use it)",
			},
		}, { mode = "i" })

		wk.register({
			["<C-v>"] = {
				function()
					vim.api.nvim_put({ vim.fn.getreg("+") }, "", true, true)
				end,
				"enable easy pasting in terminals",
			},

			["<C-^>"] = {
				[[<C-\><C-n><C-^>]],
				"when in Terminal input mode, pressing Ctrl+Shift+6 will go "
					.. "to Terminal-Normal mode, then switch to the alternate buffer",
			},
		}, { mode = "t" })

		wk.register({
			h = {
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
				"toggles highlighting of search results in Normal mode",
			},
			s = {
				"<Cmd>set spell!<CR>",
				"toggle spellchecking underlines",
			},
		}, { mode = "n", prefix = "<leader>" })

		local term = require("terminal-handling")
		wk.register({
			["<C-e>"] = {
				term.open_and_switch,
				"switch to terminal",
			},
		}, { mode = { "n", "i" } })

		wk.register({
			["<C-l>"] = { "<Cmd>:tabnext<CR>", "switch tab rightwards" },
			["<C-h>"] = { "<Cmd>:tabprevious<CR>", "switch tab leftwards" },
		}, { mode = { "n", "i", "t" } })

		wk.setup(opts)
	end,
}
