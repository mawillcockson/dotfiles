-- used the following info:
-- https://github.com/nanotee/nvim-lua-guide
-- https://alpha2phi.medium.com/neovim-for-beginners-init-lua-45ff91f741cb
-- I prefer the interface of vim.opt over vim.o
local opt = vim.opt
local cmd = vim.cmd
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
opt.shortmess :remove "F"
-- enable mouse control in [n]ormal and [v]isual mode, in addition to
-- whatever's currently set
-- This allows resizing windows by dragging on the borders between them.
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
-- Disable builtin netrw folder browser: https://neovim.io/doc/user/pi_netrw.html#netrw-noload
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1


local DEBUG = vim.log.levels.DEBUG
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR

-- Find an appropriate number of processes to run in parallel, for things like
-- package management
local function run(tbl)
  -- remove trailing whitespace, including newlines
  local output = vim.fn.system(tbl)
  if vim.v.shell_error ~= 0 then
    vim.notify(
      "error when trying to run:\n" ..
      vim.inspect(tbl) .. "\n\n" ..
      tostring(output),
      ERROR,
      {}
    )
    assert(false)
  end
  -- does the same as: output:gsub("%s+$", "")
  return vim.trim(output)
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
require "bootstrap-plugins"
