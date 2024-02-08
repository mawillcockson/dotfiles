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
      command = "redraw | startinsert",
    },
  },
  FileType = {
    {
      pattern = {"text", "markdown", "gitcommit"},
      callback = function()
        vim.opt_local.spell = true
        vim.opt_local.spelllang = "en_us"
      end,
    },
    {
      pattern = "lua",
      callback = function()
        vim.opt_local.sw = 2
        vim.opt_local.ts = 2
      end,
    },
    {
      pattern = "python",
      command = "set sw=4 ts=4 expandtab",
    },
    {
      pattern = "html",
      command = "set sw=2 ts=2 sts=2 expandtab",
    }
  },
}

for event_name, opts in pairs(autocmds) do
  for i, opt in pairs(opts) do
    opt.group = custom_autocmds_group_name
    vim.api.nvim_create_autocmd(event_name, opt)
  end
end