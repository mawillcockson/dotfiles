return {
	"L3MON4D3/LuaSnip",
	branch = "master",
	version = "2.*",
	lazy = true,
	event = "VeryLazy",
	--enabled = false, -- until configuration is complete
	opts = {
		snip_env = {
			-- this extends the defaults at:
			-- https://github.com/L3MON4D3/LuaSnip/blob/878ace11983444d865a72e1759dbcc331d1ace4c/lua/luasnip/default_config.lua#L20-L99
		},
		-- from:
		-- https://github.com/tjdevries/config.nvim/blob/c48edd3572c7b68b356ef7c54c41167b1f46e47c/lua/custom/snippets.lua#L38
		history = true,
		updateevents = "TextChanged,TextChangedI",
		override_builtin = true,
		-- disabled by default because of the performance impact
		enable_autosnippets = false,
	},
	config = function(_, opts)
		local ls = require("luasnip")

		--[[ logging
    ls.log.set_loglevel("debug")
    -- test to see if logging is working
    ls.log.ping()
    --]]

		-- from:
		-- https://github.com/tjdevries/config.nvim/blob/c48edd3572c7b68b356ef7c54c41167b1f46e47c/lua/custom/snippets.lua#L6-L33
		-- silence errors with nvim < 0.10
		vim.snippet = vim.snippet or {}
		vim.snippet.expand = ls.lsp_expand

		---@diagnostic disable-next-line: duplicate-set-field
		vim.snippet.active = function(filter)
			filter = filter or {}
			filter.direction = filter.direction or 1

			if filter.direction == 1 then
				return ls.expand_or_jumpable()
			else
				return ls.jumpable(filter.direction)
			end
		end

		---@diagnostic disable-next-line: duplicate-set-field
		vim.snippet.jump = function(direction)
			if direction == 1 then
				if ls.expandable() then
					return ls.expand_or_jump()
				else
					return ls.jumpable(1) and ls.jump(1)
				end
			else
				return ls.jumpable(-1) and ls.jump(-1)
			end
		end

		vim.snippet.stop = ls.unlink_current

		local wk = require("which-key")
		wk.add({
			{ "<leader>ls", group = "LuaSnip" },
			{
				"<leader>lse",
				function()
					require("luasnip.loaders").edit_snippet_files()
				end,
				desc = "edit snippet files dialogue",
			},
			{
				"<leader>lsl",
				ls.log.open,
				desc = "open log file",
			},
			{
				"<C-k>",
				function()
					return vim.snippet.active({ direction = 1 }) and vim.snippet.jump(1)
				end,
				desc = "expand snippet or jump to next node",
				mode = "i",
			},
			{
				"<C-j>",
				function()
					return vim.snippet.active({ direction = -1 }) and vim.snippet.jump(-1)
				end,
				desc = "jump to previous node",
				mode = "i",
			},
		})

		ls.setup(opts)
		-- from:
		-- https://github.com/tjdevries/config.nvim/blob/c48edd3572c7b68b356ef7c54c41167b1f46e47c/lua/custom/snippets.lua#L44
		-- This function will also setup filesystem watchers for the files in this
		-- directory, so that the snippet files can be edited, with those edits
		-- being immediately usable.
		-- Inside these files, instead of `require()` use `ls_tracked_dopackage()`,
		-- which LuaSnip will define as a global when loading snippets. That way,
		-- any files a snippet requires will also be watched for edits.
		require("luasnip.loaders.from_lua").load({ paths = vim.api.nvim_get_runtime_file("lua/snippets/", true) })
	end,
}
