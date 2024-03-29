-- This file is not automatically read at startup. Instead, an autocommand is
-- setup to watch for changes to plugins/plugin-spec.lua and do the appropriate
-- things in response to that.
--
-- Inspired by the packer.nvim readme:
-- https://github.com/wbthomason/packer.nvim/blob/afab89594f4f702dc3368769c95b782dbdaeaf0a/README.md#bootstrapping
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

if not vim.fn.executable "git" then
  vim.notify("git required for lazy.nvim package manager", ERROR, {})
  return
end


-- DONE: Need to switch to lazy.nvim
-- https://github.com/folke/lazy.nvim#-installation
vim.notify("importing join_path", DEBUG, {})
local join_path = require("utils").join_path
local lazypath = join_path(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
vim.notify(
  "lazy.nvim installed to (lazypath): "..tostring(lazypath),
  DEBUG, {}
)
local did_bootstrap = false
if not vim.loop.fs_stat(lazypath) then
  vim.notify("bootstrapping lazy.nvim to: "..lazypath, INFO, {})
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

vim.notify("loading lazy.nvim", INFO, {})
local ok, lazy = pcall(require, "lazy")
if not ok then
  vim.notify("lazy.nvim not installed, cannot manage plugins", ERROR, {})
  return
end

-- in case they're needed elsewhere
local opts = require("lazy_opts")
local spec = opts.spec
vim.notify("running lazy.nvim setup", DEBUG, {})
local original = vim.go.loadplugins
-- NOTE: This feels wrong, and I'm curious why I need it when I run the environment under
-- nvim --headless -u NONE -i NONE -S $this_script "+q"
vim.go.loadplugins = true
vim.notify("before lazy.setup(), vim.go.loadplugins = " .. tostring(vim.go.loadplugins) .. "", DEBUG, {})
lazy.setup(opts)
-- lazy.load{spec}
-- require("lazy.core.config").setup(opts)
vim.notify("finished lazy.setup()", DEBUG, {})
vim.go.loadplugins = original

-- NOTE: I'd like to run lazy.restore() if a lock file is present, and
-- lazy.sync() otherwise
if vim.g.lazy_install_plugins then
  vim.notify("(lazy.nvim) installing only new plugins; use :Lazy to update existing ones as well", INFO, {})
  lazy.install{ wait = true }
elseif did_bootstrap then
  vim.notify("lazy.nvim was just bootstrapped, but vim.g.lazy_install_plugins wasn't"..
  " set to true, so :Lazy should be run once the editor is running", WARN, {})
end
