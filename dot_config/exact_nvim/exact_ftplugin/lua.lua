if vim.b.did_my_ft_lua then
	return
end
vim.b.did_my_ft_lua = true
vim.treesitter.start()

local set = vim.opt_local
set.sw = 2
set.ts = 2
