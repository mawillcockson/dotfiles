---[==[
-- this has to come first, so that it can override all the vim.notify calls in
-- this init.lua
--
-- NOTE::FUTURE if noice.nvim or some other notification plugin is used, it
-- will need to be integrated here so that, if it's unavailable (e.g. hasn't
-- been installed on this particular machine yet), then this override will fall
-- back to a very simple level filter that reduces how much text is printed at
-- startup, unless -V is used on the command-line
local original_notify = vim.notify
vim.g.vim_filter_log_level = vim.g.vim_filter_log_level or vim.log.levels.INFO
vim.notify = function(msg, level, opts)
	if type(msg) ~= "string" then
		error("first argument to vim.notify() must be a string, not '" .. type(msg) .. "'", 2)
	end
	if type(level) ~= "number" then
		error("second argument to vim.notify() must be a number, not '" .. type(level) .. "'", 2)
	end
	if (vim.o.verbose ~= 0) or (level >= vim.g.vim_filter_log_level) then
		original_notify(msg, level, opts)
	end
end
--]==]

vim.g.mapleader = " "
vim.g.maplocalleader = " "

---[=[ NOTE::PERF this is here for a little extra speed in case lazy.nvim
-- doesn't need to be bootstrapped
pcall(function()
	local join_path = require("utils").join_path
	vim.g.custom_lazypath = join_path(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
	-- plain substring search, so I don't have to worry about escaping `vim.g.custom_lazypath`
	-- https://www.lua.org/manual/5.1/manual.html#pdf-string.find
	if not vim.o.rtp:find(vim.g.custom_lazypath, 1, true) then
		vim.notify("adding lazypath to rtp", vim.log.levels.DEBUG, {})
		vim.opt.rtp:prepend(vim.g.custom_lazypath)
	end
	vim.notify("hoping lazy.nvim is already installed?", vim.log.levels.DEBUG, {})
	require("lazy").setup(require("lazy_opts"))
	vim.notify("lazy.nvim was already installed! :D", vim.log.levels.DEBUG, {})
	vim.g.lazy_loaded_early = true
end)
--]=]

-- used the following info:
-- https://github.com/nanotee/nvim-lua-guide
-- https://alpha2phi.medium.com/neovim-for-beginners-init-lua-45ff91f741cb
-- I prefer the interface of vim.opt over vim.o
local opt = vim.opt
-- Case in-sensitive search, unless there's a capital letter
-- https://stackoverflow.com/a/2288438
opt.ignorecase = true
opt.smartcase = true
opt.autoindent = true
opt.smartindent = true
opt.expandtab = true
opt.relativenumber = true
opt.number = true
opt.ts = 4
opt.sw = 4
opt.sts = 4
-- is there a way to set this for every file?
-- does `vim.go.ff = "unix"` work?
opt.ff = "unix"
-- NOTE::IMPROVEMENT::DONE I would like to have highlighting off by default,
-- and pressing <Space> while in NORMAL mode should toggle this setting, to
-- make flipping it on temporarily work
-- In lua/keymaps.lua, a keymap is set to toggle this on <Space> in Normal mode
opt.hlsearch = false
opt.undofile = true
-- NOTE::INFO colorscheme set in the config for various plugins
--cmd[[:colorscheme default]]
-- By default neovim sets shortmess+=F, one effect of which is making echo and
-- print inside filetype plugins and autocommands do nothing, and print no
-- output.
-- some nice investigation: https://vi.stackexchange.com/a/22638
opt.shortmess = "aoOstTC"
-- enable mouse control in [n]ormal and [v]isual mode, in addition to
-- whatever's currently set
-- This allows resizing windows by dragging on the borders between them.
opt.mouse:append("nv")
-- NOTE::FUTURE https://github.com/neovim/neovim/pull/19111
-- this option is supposed to convert all slashes (\/) in paths to
-- forward slashes, but currently produces mixed slashes in e.g.
-- vim.notify(vim.inspect(opt.runtimepath:get()), vim.log.levels.DEBUG, {})
--opt.shellslash = true
-- When scrolling, scroll the file when the cursor comes within 3 lines,
-- instead of the first or last line
opt.scrolloff = 3
-- On all platforms, make a bare :cd command the same as :cd ~
-- Use :pwd to check the current working directory.
opt.cdhome = true
-- Only needed for Python plugins, and I don't plan on using any.
vim.g.loaded_python3_provider = 0
-- Same for Ruby, Node.js, and Perl
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
-- Disable builtin netrw folder browser: https://neovim.io/doc/user/pi_netrw.html#netrw-noload
-- Also done in lazy_opts.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
-- <Space> as <Leader>
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- <Space> isn't technically mapped, so unmapping does nothing (:help <Space>)
--pcall(unmap, {"n", "v", "i"}, " ")

-- NOTE::FUTURE enables new (currently experimental; 2024-05) lua loader
vim.loader.enable()

-- PATH handling
local path_additions = { "~/apps/eget-bin" }
if vim.fn.executable("fnm") then
	local node_dir = require("utils").run({ "fnm", "exec", "--using=default", "nu", "-c", "$env | get Path? PATH? | first | first" })
	path_additions[#path_additions + 1] = node_dir
end
path_additions = vim.tbl_map(vim.fs.normalize, path_additions)
local envsep = (vim.uv.os_uname().sysname:find("[wW]indows") ~= nil) and ";" or ":"
local path = vim.split(vim.env.PATH, envsep, { plain = true })
for _, addition in ipairs(path_additions) do
	table.insert(path, addition)
end
vim.env.PATH = table.concat(path, envsep)

-- On Windows, the scoop apps (neovim, neovim-qt, neovide, etc) are started
-- with the current directory set as that app's installation directory.
-- This sets the current directory to the home directory if the current
-- directory looks like the scoop installation directory.
if vim.fn.getcwd():find([[scoop[/\]apps]]) then
	vim.notify("started in scoop/apps directory, changing to ~/", vim.log.levels.DEBUG, {})
	vim.fn.chdir("~")
end

require("bootstrap-plugins")

--[[
                      
    You can do it!
Bunny believes in you!

        (\_/)
        (^.^)
       c(_ _)
--]]
