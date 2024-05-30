local this_filename = "bootstrap-plugins.lua"
-- This file is meant to be run like `nvim -l bootstrap-plugins.lua`, a feature added in nvim 0.9x
--
-- NOTE::OUTDATED
-- This file is not automatically read at startup. Instead, an autocommand is
-- setup to watch for changes to plugins/plugin-spec.lua and do the appropriate
-- things in response to that.
--
-- Inspired by the packer.nvim readme:
-- https://github.com/wbthomason/packer.nvim/blob/afab89594f4f702dc3368769c95b782dbdaeaf0a/README.md#bootstrapping
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local DEBUG = vim.log.levels.DEBUG

local function do_bootstrap()
	-- run after VimEnter
	local headless = ((#vim.api.nvim_list_uis()) == 0)
	if not vim.fn.executable("git") then
		local msg = "git required for lazy.nvim package manager"
		vim.notify(msg, ERROR, {})
		if headless then
			os.exit(1)
		else
			error(msg)
		end
	end

	-- DONE: Need to switch to lazy.nvim
	-- https://github.com/folke/lazy.nvim#-installation
	vim.notify("args: " .. vim.inspect(vim.cmd([[:args]])), DEBUG, {})
	vim.notify("_G.args: " .. vim.inspect(_G.arg), DEBUG, {})
	vim.notify("v:argv -> " .. vim.inspect(vim.api.nvim_get_vvar("argv")), DEBUG, {})
	local currentfile = vim.fn.expand("%:p")
	if (not currentfile) or (currentfile == "") and (_G.arg[0] ~= nil) then
		local relative_name = _G.arg[0]
		vim.notify("first arg is -> " .. tostring(_G.arg[0]), DEBUG, {})
		if relative_name and vim.loop.fs_stat(relative_name) then
			vim.notify("using relative name -> " .. tostring(relative_name), DEBUG, {})
			currentfile = vim.fs.normalize(vim.loop.fs_realpath(relative_name))
		end
	end
	if (not currentfile) or (currentfile == "") then
		local bufname = vim.api.nvim_buf_get_name(0)
		vim.notify("trying buffer name -> " .. tostring(bufname), DEBUG, {})
		currentfile = bufname
	end
	if (not currentfile) or (currentfile == "") then
		vim.notify("searching for " .. this_filename, DEBUG, {})
		currentfile = vim.fs.find(this_filename, {
			upward = false,
			path = ".",
			limit = 1,
			type = "file",
		})
		currentfile = (type(currentfile) == "table") and select(1, unpack(currentfile)) or currentfile
	end
	if (type(currentfile) ~= "string") or (currentfile == "") then
		local msg = "couldn't determine the current file path -> " .. vim.inspect(currentfile)
		vim.notify(msg, ERROR, {})
		if headless then
			os.exit(1)
		else
			error(msg)
		end
	end
	vim.notify("currentfile -> " .. tostring(currentfile), DEBUG, {})
	local config_dir
	for dir in vim.fs.parents(currentfile) do
		if vim.fs.basename(dir) == "nvim" then
			config_dir = dir
			break
		end
	end
	if config_dir == nil then
		local msg = "could not find nvim home in this file's parents: " .. tostring(currentfile)
		vim.notify(msg, ERROR, {})
		if headless then
			os.exit(1)
		else
			error(msg)
		end
	end
	vim.notify("adding config_dir to runtimepath -> " .. tostring(config_dir), DEBUG, {})
	vim.opt.runtimepath:append(config_dir)
	vim.notify("importing join_path", DEBUG, {})
	local join_path = require("utils").join_path
	local lazypath = join_path(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
	vim.notify("lazy.nvim installed to (lazypath): " .. tostring(lazypath), DEBUG, {})
	local did_bootstrap = false
	if not vim.loop.fs_stat(lazypath) then
		vim.notify("bootstrapping lazy.nvim to: " .. lazypath, INFO, {})
		did_bootstrap = vim.fn.system({
			"git",
			"clone",
			"--depth=1",
			"--filter=blob:none",
			"--single-branch",
			-- This uses a trick: there's no branch named stable, but there is a tag
			-- named stable that is constantly updated to point to the latest stable
			-- commit on master
			"--branch=stable", -- latest stable release
			"https://github.com/folke/lazy.nvim.git",
			lazypath,
		})
	end

	-- plain substring search, so I don't have to worry about escaping `lazypath`
	-- https://www.lua.org/manual/5.1/manual.html#pdf-string.find
	if not vim.o.rtp:find(lazypath, 1, true) then
		vim.notify("adding lazypath to rtp", DEBUG, {})
		vim.opt.rtp:prepend(lazypath)
	end

	vim.notify("loading lazy.nvim", DEBUG, {})
	local ok, lazy = pcall(require, "lazy")
	if not ok then
		local msg = "lazy.nvim not installed, cannot manage plugins"
		vim.notify(msg, ERROR, {})
		if headless then
			os.exit(1)
		else
			error(msg)
		end
	end

	-- in case they're needed elsewhere
	local opts = require("lazy_opts")
	--local spec = opts.spec
	vim.notify("running lazy.nvim setup", DEBUG, {})
	local original = vim.go.loadplugins
	-- NOTE: This feels wrong, and I'm curious why I need it when I run the environment under
	-- nvim --headless -u NONE -i NONE -S $this_script "+q"
	-- Perhaps because `:help --clean` describes that -i NONE -u NONE doesn't load
	-- builtin plugins?
	--vim.go.loadplugins = true
	vim.notify("before lazy.setup(), vim.go.loadplugins = " .. tostring(vim.go.loadplugins) .. "", DEBUG, {})
	lazy.setup(opts)
	-- lazy.load{spec}
	-- require("lazy.core.config").setup(opts)
	vim.notify("finished lazy.setup()", DEBUG, {})
	vim.go.loadplugins = original

	-- NOTE: I'd like to run lazy.restore() if a lock file is present, and
	-- lazy.install() otherwise
	if vim.g.lazy_install_plugins then
		local lockfile = join_path(vim.fn.stdpath("config"), "lazy-lock.json")
		if vim.loop.fs_stat(lockfile) then
			vim.notify("(lazy.nvim) restoring plugins as described in lockfile -> " .. tostring(lockfile), INFO, {})
			lazy.restore({ wait = true, show = not headless })
		else
			vim.notify("lockfile not found in -> " .. tostring(vim.fn.stdpath("config")), DEBUG, {})
			vim.notify("(lazy.nvim) installing only new plugins; use :Lazy to update existing ones as well", INFO, {})
			lazy.install({ wait = true, show = not headless })
		end
	elseif did_bootstrap then
		vim.notify(
			"lazy.nvim was just bootstrapped, but vim.g.lazy_install_plugins wasn't"
				.. " set to true, so :Lazy should be run once the editor is running",
			WARN,
			{}
		)
	end
end

if vim.v.vim_did_enter then
	do_bootstrap()
else
	local augroup_name = "bootstrap_autocmds"
	vim.api.nvim_create_augroup(augroup_name, { clear = true })
	vim.api.nvim_create_autocmd("VimEnter", { group = augroup_name, callback = do_bootstrap })
end
