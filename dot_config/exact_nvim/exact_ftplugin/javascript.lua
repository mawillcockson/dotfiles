if vim.b.did_my_ft_js then
	return
end
vim.b.did_my_ft_js = true
vim.treesitter.start()

local set = vim.opt_local
set.shiftwidth = 2
set.tabstop = 2
set.softtabstop = 2
set.expandtab = true
