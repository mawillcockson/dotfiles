if vim.b.did_my_ft_md then
	return
end
vim.b.did_my_ft_md = true
vim.treesitter.start()

local set = vim.opt_local
if vim.fn.has("nvim-0.10.0") then
	set.conceallevel = 2
end
