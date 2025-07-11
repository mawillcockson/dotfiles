if vim.b.did_my_ft_nu then
	return
end
vim.b.did_my_ft_nu = true
vim.treesitter.start()
