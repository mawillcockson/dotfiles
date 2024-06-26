local M = {}

function M.setup(opts)
	vim.notify("ran uis", vim.log.levels.DEBUG, {})
	--[[
This tries to figure out what environment this is being run from, and calls the
options specific to that environment.

Generally, the only options that should be included in this package are
settings for a specific environment, like enabling smooth scrolling and such.
All general settings should go in init.lua, if possible.
--]]

	-- This can be helpful
	-- vim.notify(vim.inspect(vim.api.nvim_list_uis()), vim.log.level.DEBUG, {})

	-- NOTE: has('gui_running') now works, and triggers based on which GUI is
	-- connected may also work, now:
	-- https://github.com/neovim/neovim/blob/040f1459849ab05b04f6bb1e77b3def16b4c2f2b/runtime/doc/news.txt#L214-L215

	local function any(func, tbl)
		for _, i in pairs(tbl) do
			if func(i) then
				return true
			end
		end
		return false
	end

	local fonts = require("uis.fonts")
	local change_fonts = true

	if vim.g.fvim_loaded then
		require("uis.fvim")
	elseif vim.g.neovide then
		require("uis.neovide")

	-- found here:
	-- https://github.com/akiyosi/goneovim/issues/14#issuecomment-444482888
	elseif vim.g.gonvim_running then
		require("uis.goneovim")
	elseif any(function(e)
		return e.chan == 1
	end, vim.api.nvim_list_uis()) then
		-- Apparently text uis have a channel of 0, and guis have a chan of not 0
		if vim.env.WT_SESSION then
			require("uis.tui_windows_terminal")
		else
			vim.notify("unknown gui connected", vim.log.levels.WARN, {})
		end
	elseif vim.fn.has("ttyin") ~= 0 then
		-- if nvim was run in the terminal, the ttyin feature is supported. Also,
		-- this is likely only set in that scenario, since front-ends like neovim-qt
		-- may(?) start nvim in --headless mode and use the RPC protocol.

		-- changing fonts is pointless when the controling terminal sets everything
		change_fonts = false
		vim.o.termguicolors = true
	else
		vim.notify("unknown editor environment", vim.log.levels.WARN, {})
		change_fonts = false
	end

	fonts.setup({ font_changing_enabled = change_fonts })

	local modules = {
		["fvim"] = "fvim",
		["goneovim"] = "goneovim",
		["neovide"] = "neovide",
		["neovim-qt"] = "neovim_qt",
		["builtin tui"] = "tui_windows_terminal",
		["default"] = "default",
	}

	vim.api.nvim_create_user_command("UisConfig", function(tbl)
		if tbl.args == "" or type(modules[tbl.args]) == "nil" then
			error("Must be called with one of: " .. table.concat(vim.tbl_keys(modules), ", "), 2)
		end

		local module_name = "uis." .. tostring(modules[tbl.args])
		local ok, err = pcall(require, module_name)
		if not ok then
			vim.notify("problem loading '" .. module_name .. "' package: " .. tostring(err), vim.log.levels.ERROR)
		end
	end, {
		nargs = 1,
		complete = function(arg_lead, _, _)
			local keys = vim.tbl_keys(modules)
			if arg_lead == "" then
				return keys
			end
			return vim.iter(keys)
				:filter(function(key)
					return vim.startswith(key, arg_lead)
				end)
				:totable()
		end,
		desc = "Runs the module for configuring Neovim for a particular ui frontend",
		force = true,
	})

	local uis_autocmds_group_name = "uis_autocmds"
	vim.api.nvim_create_augroup(uis_autocmds_group_name, { clear = true })

	local function update_from_chan(_)
		-- I think this is passed a table describing the event:
		-- :help ChanInfo
		-- :help nvim_get_chan_info()
		-- But I don't use it, because neovim-qt populates its data in
		-- vim.api.nvim_list_chans() by this time
		for _, info in pairs(vim.api.nvim_list_chans()) do
			if type(info) ~= "table" then
				return
			end
			if type(info.client) == "table" and info.client.name == "nvim-qt" then
				local ok, neovim_qt = pcall(require, "uis.neovim_qt")
				if not ok then
					local msg = "error loading neovim_qt: " .. tostring(neovim_qt)
					vim.notify(msg, vim.log.levels.ERROR, {})
					error(msg)
				elseif type(neovim_qt) ~= "function" then
					local msg = "expected neovim_qt to be a function, got '" .. type(neovim_qt) .. "'"
					vim.notify(msg, vim.log.levels.ERROR, {})
					error(msg)
				end
				vim.notify("running neovim_qt", vim.log.levels.DEBUG, {})
				return pcall(neovim_qt)
			end
		end
	end

	vim.api.nvim_create_autocmd("ChanInfo", {
		group = uis_autocmds_group_name,
		pattern = "*",
		callback = update_from_chan,
		-- this means it won't be run if neovim-qt disconnects and reconnects, but
		-- I'm unlikely to do that
		once = true,
	})
end

return M
