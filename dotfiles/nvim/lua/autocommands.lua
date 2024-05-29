print "ran autocommands"

local custom_autocmds_group_name = "custom_autocmds"
vim.api.nvim_create_augroup(custom_autocmds_group_name, { clear = true })
-- inspired by:
-- https://luabyexample.org/docs/nvim-autocmd/
-- https://www.reddit.com/r/neovim/comments/t7k5k1/comment/hziccvb/?utm_source=share&utm_medium=web2x&context=3
local autocmds = {
  TermOpen = {
    {
      pattern = "term://*//*:*",
      command = "setfiletype terminal | redraw | startinsert",
    },
  },
  FileType = {
    -- it's preferred to place files named after the filetype in nvim/ftplugin,
    -- at the same folder depth as init.lua
    -- This is mainly a convenience for setting common options on a lot of
    -- filetypes at once
    {
      pattern = {"text", "markdown", "gitcommit"},
      callback = function()
        vim.opt_local.spell = true
        vim.opt_local.spelllang = "en_us"
      end,
    },
  },
}

for event_name, opts in pairs(autocmds) do
  for _, opt in pairs(opts) do
    opt.group = custom_autocmds_group_name
    vim.api.nvim_create_autocmd(event_name, opt)
  end
end
