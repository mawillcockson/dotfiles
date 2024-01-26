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
local join_path = require("utils").join_path
local lazypath = join_path(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
local did_bootstrap = false
if not vim.loop.fs_stat(lazypath) then
  vim.notify("bootstrapping lazy.nvim to: "..lazypath, INFO, {})
  did_bootstrap = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--single-branch",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end

-- plain substring search, so I don't have to worry about escaping `lazypath`
-- https://www.lua.org/manual/5.1/manual.html#pdf-string.find
if not vim.o.rtp:find(lazypath, 1, true) then
  vim.opt.rtp:prepend(lazypath)
end

vim.notify("loading lazy.nvim", INFO, {})
local ok, lazy = pcall(require, "lazy")
if not ok then
  vim.notify("lazy.nvim not installed, cannot manage plugins", ERROR, {})
  return
end

local opts = require("lazy_opts")
local spec = opts.spec
vim.notify("### before lazy.setup(), vim.go.loadplugins = " .. tostring(vim.go.loadplugins) .. " ###")
lazy.setup(opts)
-- lazy.load{spec}
-- require("lazy.core.config").setup(opts)
vim.notify "#### got here ####"

if did_bootstrap then
  lazy.sync{
    wait = true,
  }
  return --no need to run any more of the script if we're bootstrapping
else
  -- NOTE: I'd like to run lazy.restore() if a lock file is present, and
  -- lazy.sync() otherwise
  lazy.sync()
end

--[=[ old packer.nvim bootstrap
local install_path = join_path(fn.stdpath("data"), "site", "pack", "packer", "opt", "packer.nvim")
local did_bootstrap = false
if fn.empty(fn.glob(install_path)) > 0 then
  vim.notify("installing packer.nvim", INFO, {})
  did_bootstrap = fn.system{
    "git",
    "clone",
    "--depth", "1",
    "--single-branch",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
end
vim.notify("loading packer", INFO, {})
vim.cmd [[packadd packer.nvim]]

local ok, packer = pcall(require, "packer")
if not ok then
  vim.notify("packer.nvim not installed, cannot manage plugins", ERROR, {})
  return
end
--]=]

--[==[
packer.reset()
--[[ NOTE: `config` functions cannot close over any values from the surrounding scope:
---- https://github.com/wbthomason/packer.nvim/blob/afab89594f4f702dc3368769c95b782dbdaeaf0a/README.md#compiling-lazy-loaders
NOTE: If you use a function value for config or setup keys in any plugin
specifications, it must not have any upvalues (i.e. captures). We currently use
Lua's string.dump to compile config/setup functions to bytecode, which has this
limitation. Additionally, if functions are given for these keys, the functions
will be passed the plugin name and information table as arguments.
--]]
packer.startup{
  {
    {
      "wbthomason/packer.nvim",
      opt = true,
    },
    {
      "nvim-lua/plenary.nvim",
      opt = true,
      module = "plenary",
    },
    {
      "Olical/conjure",
      opt = true,
      module = "conjure",
      requires = {
        "tpope/vim-dispatch",
        "clojure-vim/vim-jack-in",
        "radenling/vim-dispatch-neovim",
      },
    },
    {
      "tpope/vim-surround",
    },
    {
      "tpope/vim-repeat",
    },
    {
      -- [[~/projects/font-resize.nvim]],
      "mawillcockson/font-resize.nvim",
      -- Mark this plugin as one that will be manually loaded, instead of
      -- automatically when Neovim launches. packer.nvim also supports
      -- configuring loading on keybinds, filetype events, etc.
      opt = true,
      -- (optional) Add a notification plugin as a dependency, for fancy font
      -- size update messages. This isn't required, and can be removed. The
      -- plugin must be able to be used as:
      --[[
        require("notify")("message", WARN, {opts = true})
      --]]
      -- That is, it must be installed and require-able with the name `notify`,
      -- and must provide a function that matches Neovim's builtin
      -- `vim.notify()` interface.
      requires = {
        {
          "rcarriga/nvim-notify",
          -- If the plugin is installed with a name other than `notify`,
          -- packer.nvim can be configured to override that name with `notify`
          --[[
          as = "notify",
          --]]
          -- When this dependency is loaded, run this function, which sets the
          -- background color of the notification popup window to the hex code
          -- for black. Change this if the background of your Neovim UI is not
          -- black. disable, but keep it here in case I do want to use it
          disable = true,
          config = function()
            require("notify").setup{
              background_colour = "#000000",
            }
          end,
        },
      },
      -- The font-resize plugin provides a setup() function that it requires to
      -- be called before the plugin will start resizing the font. packer.nvim
      -- makes available a config= option for providing a function that will be
      -- called immediately after the plugin is loaded.
      config = function()
        local tbl = {
          -- If this is set to `true`, the setup() function will configure
          -- keybinds that match the ones listed below (if the code hasn't
          -- changed)
          use_default_mappings = true,
          -- The amount by which to increase and decrease the font size each
          -- time a keybind is pressed or a :FontSizeUp / :FontSizeDown command
          -- is called
          step_size = 1,
          -- Sets whether to print a message each time the font is resized or reset
          -- NOTE: it does not matter if rcarriga/nvim-notify is installed or not, this
          -- is a global flag to enable ANY notifications or not
          -- By default, this will enable notifications only if a plugin called
          -- `notify` is available
          -- Should be set to `true` or `false` if set at all
          notifications = true,
          -- The value to reset the font to in case something goes wrong, or
          -- the reset keybind or function is used.
          -- By default, this records the value of the `guifont` option when
          -- the plugin is first loaded.
          -- If set, this should be set to a valid value to pass to the
          -- set_font_function() (e.g. "Consolas:h12")
          --[[
          default_guifont = vim.o.guifont,
          --]]
          -- The function to use to change the font. Takes a single argument
          -- that's formatted for use with `:set guifont=...`
          -- This function should raise an error instead of failing silently,
          -- as internally the updated font size isn't saved when this function
          -- call fails, enabling recovery from e.g. a too-small font size by
          -- using the :FontSizeUp command or keybind
          --[[
          set_font_function = function(guifont)
            vim.api.nvim_set_option_value("guifont", guifont, {})
          end,
          --]]
        }
        -- The hope is that this is lazy-loaded, and that neovim-qt has been
        -- detected by the time this is called.
        -- Either way, a guifont needs to be set before .setup() is called.
        if vim.g.neovim_qt then
          -- This function must be defined here, or imported here. Function
          -- defined in config= cannot close over values.
          tbl.set_font_function = function(guifont)
            -- vim.cmd('silent! exe "GuiFont! '..font..'"')
            vim.rpcnotify(0, "Gui", "Font", guifont, true)
          end
        end

        require("font-resize").setup(tbl)
      end,
      -- The keybinds that packer.nvim should watch, and load this plugin when
      -- one is pressed. These are the default keybinds that this plugin uses
      -- if `use_default_mappings` is set to `true`.
      keys = {
        -- As of August 2022, FVim and neovim-qt work with all the keybinds,
        -- and:
        ---[[ Goneovim only works with these
        "<C-=>",               -- increase
        "<C-->",               -- increase
        "<C-0>",               -- reset
        --]]
        ---[[ Neovide only works with these
        "<C-ScrollWheelUp>",   -- increase
        "<C-ScrollWheelDown>", -- decrease
        --]]
        -- The keybinds may work in the terminal, but this plugin should not be
        -- loaded in that case as the terminal should handle the font resizing,
        -- not Neovim's TUI
      },
      -- packer.nvim will watch calls to require() for these names, and will
      -- load this plugin when a matching one is encountered. This means that
      -- loading this plugin in lua only needs `require("font-resize")`, and
      -- doesn't need a preceding call to
      -- `vim.cmd[[:packadd font-resize.nvim]]`, even though this configuration
      -- marks this plugin as `opt = true` and its name is `font-resize.nvim`,
      -- not `font-resize`.
      module = "font-resize",
    },
  },
  config = {
    max_jobs = nproc,
  },
}
--]==]

--[[ only needed for packer because it doesn't have a way to call packer.sync()
--   synchronously
-- from:
-- https://github.com/nvim-lua/kickstart.nvim/blob/f2dedf6e3eafb8c702dc10c4c3418e2e2786a7c7/init.lua#L38-L49
-- When we are bootstrapping a configuration, it doesn't
-- make sense to execute the rest of the init.lua.
--
-- You'll need to restart nvim, and then it will work.
if did_bootstrap then
  if vim.g.packer_quit_after_sync then
    vim.api.nvim_create_augroup("temporary_autocmds", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = "temporary_autocmds",
      pattern = "PackerComplete",
      command = "quitall",
    })
  end
  packer.sync()
  print '=================================='
  print '    Plugins are being installed'
  print '    Wait until Packer completes,'
  print '       then restart nvim'
  print '=================================='
  print("packer git output: "..did_bootstrap)
  return
end
--]]
