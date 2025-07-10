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

-- nvim 0.10 introduced vim.uv
local luv = vim.loop or vim.uv

local function do_bootstrap()
	-- run after VimEnter
	local headless = ((#vim.api.nvim_list_uis()) == 0)
	if vim.fn.executable("git") ~= 1 then
		local msg = "git required for lazy.nvim package manager"
		vim.notify(msg, ERROR, {})
		if headless then
			os.exit(1)
		else
			error(msg)
		end
	end

	if headless then
		vim.notify(
			[[If this gets stuck, the plugins.lua probably didn't appropriately call :quitall
Thankfully, Neovim starts a remote server session every time it starts.
On Windows, as of 2022-October, these are named pipes like
\\.\pipe\nvim.xxxx.x
The following powershell command will connect neovim-qt to the first one:
nvim-qt --server "\\.\pipe\$((gci \\.\pipe\ | Where-Object -Property Name -Like "nvim*" | Select-Object -First 1).Name)"]],
			INFO
		)
	end

	-- DONE: Need to switch to lazy.nvim
	-- https://github.com/folke/lazy.nvim#-installation
	--[=[ NOTE::DEBUG
	vim.notify("args: " .. vim.inspect(vim.cmd([[:args]])), DEBUG, {})
	vim.notify("_G.args: " .. vim.inspect(_G.arg), DEBUG, {})
	vim.notify("v:argv -> " .. vim.inspect(vim.api.nvim_get_vvar("argv")), DEBUG, {})
  --]=]
	vim.notify("searching for " .. this_filename, DEBUG, {})
	currentfile = vim.api.nvim_get_runtime_file("lua/" .. tostring(this_filename), false)
	if vim.tbl_isempty(currentfile) then
		vim.notify("could not find " .. tostring(this_filename), WARN)
		currentfile = nil
	end
	currentfile = (type(currentfile) == "table") and currentfile[1] or currentfile
	-- currentfile = luv.fs_realpath(currentfile)
	if (not currentfile) or (currentfile == "") then
		local currentfile = vim.fn.expand("%:p")
	end
	if (not currentfile) or (currentfile == "") and (_G.arg[0] ~= nil) then
		local relative_name = _G.arg[0]
		vim.notify("first arg is -> " .. tostring(_G.arg[0]), DEBUG, {})
		if relative_name and luv.fs_stat(relative_name) then
			vim.notify("using relative name -> " .. tostring(relative_name), DEBUG, {})
			currentfile = vim.fs.normalize(luv.fs_realpath(relative_name))
		end
	end
	if (not currentfile) or (currentfile == "") then
		local bufname = vim.api.nvim_buf_get_name(0)
		vim.notify("trying buffer name -> " .. tostring(bufname), DEBUG, {})
		currentfile = bufname
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
	if not vim.g.custom_lazypath then
		vim.notify("importing join_path", DEBUG, {})
		vim.g.custom_lazypath = require("utils").join_path(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
	end
	vim.notify("lazy.nvim installed to (lazypath): " .. tostring(vim.g.custom_lazypath), DEBUG, {})
	local did_bootstrap = false
	if not luv.fs_stat(vim.g.custom_lazypath) then
		vim.notify("bootstrapping lazy.nvim to: " .. vim.g.custom_lazypath, INFO, {})
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
			vim.g.custom_lazypath,
		})
	end

	-- plain substring search, so I don't have to worry about escaping `vim.g.custom_lazypath`
	-- https://www.lua.org/manual/5.1/manual.html#pdf-string.find
	if not vim.o.rtp:find(vim.g.custom_lazypath, 1, true) then
		vim.notify("adding lazypath to rtp", DEBUG, {})
		vim.opt.rtp:prepend(vim.g.custom_lazypath)
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
	local original = vim.go.loadplugins
	-- NOTE: This feels wrong, and I'm curious why I need it when I run the environment under
	-- nvim --headless -u NONE -i NONE -S $this_script "+q"
	-- Perhaps because `:help --clean` describes that -i NONE -u NONE doesn't load
	-- builtin plugins?
	--vim.go.loadplugins = true
	vim.notify("before lazy.setup(), vim.go.loadplugins = " .. tostring(vim.go.loadplugins) .. "", DEBUG, {})
	if not vim.g.lazy_loaded_early then
		vim.notify("running lazy.nvim setup", DEBUG, {})
		lazy.setup(opts)
	end
	-- lazy.load{spec}
	-- require("lazy.core.config").setup(opts)
	vim.notify("finished lazy.setup()", DEBUG, {})
	vim.go.loadplugins = original

	-- NOTE: I'd like to run lazy.restore() if a lock file is present, and
	-- lazy.install() otherwise
	if vim.g.lazy_install_plugins then
		vim.notify("importing join_path", DEBUG, {})
		local lockfile = require("utils").join_path(vim.fn.stdpath("config"), "lazy-lock.json")
		if luv.fs_stat(lockfile) then
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
