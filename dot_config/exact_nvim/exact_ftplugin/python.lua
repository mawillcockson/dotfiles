if vim.b.did_my_ft_py then
	return
end
vim.b.did_my_ft_py = true
vim.treesitter.start()

local set = vim.opt_local
set.shiftwidth = 4
set.tabstop = 4
set.expandtab = true
