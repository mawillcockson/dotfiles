-- used the following info:
-- https://github.com/nanotee/nvim-lua-guide
-- https://alpha2phi.medium.com/neovim-for-beginners-init-lua-45ff91f741cb
-- I prefer the interface of vim.opt over vim.o
local opt = vim.opt
local cmd = vim.cmd
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
cmd[[:colorscheme default]]
-- By default neovim sets shortmess+=F, one effect of which is making echo and
-- print inside filetype plugins and autocommands do nothing, and print no
-- output.
-- some nice investigation: https://vi.stackexchange.com/a/22638
opt.shortmess :remove "F"
-- enable mouse control in [n]ormal and [v]isual mode, in addition to
-- whatever's currently set
opt.mouse :append "nv"
-- NOTE::FUTURE https://github.com/neovim/neovim/pull/19111
-- this option is supposed to convert all slashes (\/) in paths to
-- forward slashes, but currently produces mixed slashes in e.g.
-- vim.pretty_print(opt.runtimepath:get())
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


local DEBUG = vim.log.levels.DEBUG
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR

-- Find an appropriate number of processes to run in parallel, for things like
-- package management
local function run(tbl)
  -- remove trailing whitespace, including newlines
  return vim.fn.system(tbl):gsub("%s+$", "")
end
vim.notify("calculating number of jobs", DEBUG, {})
vim.g.max_nproc_default = 1
local nproc
if vim.fn.has("win32") > 0 then
  nproc = tonumber(run{
    "cmd",
    "/D", -- don't load autorun
    "/C",
    "echo %NUMBER_OF_PROCESSORS%"
  }, 10)
  if type(nproc) == "nil" then
    vim.notify("windows did not return a number when "..
          "asked for the number of processors", WARN, {})
    nproc = vim.g.max_nproc_default
  end
else
  print("non-windows platforms haven't been addressed yet "..
        "so using a default of: " .. vim.g.max_nproc_default)
  nproc = vim.g.max_nproc_default
end
vim.notify("max concurrent jobs: "..tostring(nproc), INFO, {})
vim.g.max_nproc = nproc


-- On Windows, the scoop apps (neovim, neovim-qt, neovide, etc) are started
-- with the current directory set as that app's installation directory.
-- This sets the current directory to the home directory if the current
-- directory looks like the scoop installation directory.
if vim.fn.getcwd():find[[scoop[/\]apps]] then
  vim.notify("started in scoop/apps directory, changing to ~/", {}, DEBUG)
  vim.fn.chdir("~")
end


--[[
                      
    You can do it!
Bunny believes in you!

        (\_/)
        (^.^)
       c(_ _)
--]]

local sections = {
  -- these modules aren't used anywhere else, so the file can continue running
  -- even if any fail to load
  "uis",
  "keymaps",
  "commands",
  "autocommands",
}

for i, tbl in ipairs(sections) do
  local name, opts
  if type(tbl) == "string" then
    name = tbl
  elseif type(tbl) == "table" then
    name = tbl[1]
    opts = tbl[2]
  else
    print("section "..tostring(i).." is not a table or a string")
    return
  end
  opts = opts or {}
  local i_name = "#"..tostring(i).." "..tostring(name)

  assert(
    type(name) == "string"
    and (type(opts) == "table" or type(opts) == "nil"),
    "problem with section "..i_name..": first argument is section "..
    "name, second is an optional table of options"
  )

  if vim.tbl_isempty(opts) then
    opts = {required = false}
  end

  local ok, msg = pcall(require, name)
  if not ok then
    msg = "problem loading section "..i_name..": "..tostring(msg)
    if opts.required then
      vim.notify(msg, ERROR, {})
      return
    else
      vim.notify(msg, WARN, {})
    end
  end
end


-- This must come after the above, since vim.g.mapleader needs to be set before
-- lazy.nvim runs, and it's set in one of the sub files
-- add lazy.nvim directory to the runtime path(?) if it exists
vim.notify("importing join_path", DEBUG, {})
local join_path = require("utils").join_path
local lazypath = join_path(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
vim.notify("lazy.nvim installed to: "..tostring(lazypath), DEBUG, {})
local lazy_opts = require("lazy_opts")
if vim.loop.fs_stat(lazypath) then
  vim.notify("lazypath exists", DEBUG, {})
-- plain substring search, so I don't have to worry about escaping `lazypath`
-- https://www.lua.org/manual/5.1/manual.html#pdf-string.find
  if not vim.o.rtp:find(lazypath, 1, true) then
    vim.notify("adding lazypath to rtp", DEBUG, {})
    vim.opt.rtp:prepend(lazypath)
  end
  vim.notify("running lazy.nvim setup", DEBUG, {})
  vim.notify("### before lazy.setup(), vim.go.loadplugins = " .. tostring(vim.go.loadplugins) .. " ###")
  require("lazy").setup(lazy_opts)
end


---- NOTE: There's probably a better way to do filetype stuff than manual
----       autocommands on FileType events...
---- Per-filetype settings are configured in lua/autocommands.lua
--[===[ This can be used for setting the vim.opt.filetype:get() when a buffer
-- is loaded, allowing an autocmd to be defined that only needs to watch the
-- file type.
-- All of this would be better in its proper places, though.
--
vim.filetype.add{
-- vim.filetype.add() only works when the lua filetype plugin is enabled. In
-- v0.7.x this is enabled by setting vim.g.did_load_filetypes to exactly 0
-- (setting to 1 disables both vim and lua filetype plugins) and for
-- vim.g.do_filetype_lua to be set to 1 (as it's still opt-in in v0.7.x)
vim.g.did_load_filetypes = 0
vim.g.do_filetype_lua = 1
-- not needed, as is default on in neovim
--vim.cmd[[
--  :filetype on
--  :filetype indent on
--  :filetype plugin on
--]]
-- there is a help page for this api call somewhere
  -- NOTE: as of 2022, the patterns are all automatically enclosed in ^ and $
  -- file: ~\scoop\apps\neovim\current\share\nvim\runtime\lua\vim\filetype.lua
  pattern = {
    ["luapattern"] = "filetype variable is set to this",
    -- -- If a function, it takes the full path and buffer number of the file as
    -- -- arguments (along with captures from the matched pattern, if any) and
    -- -- should return a string that will be used as the buffer's filetype.
    --[[
        ["term://(.-)//(%d+):(.*)"] = function(path, bufnr, cwd, pid, command)
           -- just return the filetype "term" for all terminals
           return "term"
       end,
    --]]
    -- The above can't work because terminals aren't regular files or buffers,
    -- and don't have filetype set
  },
}
--]===]
