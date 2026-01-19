if vim.b.did_my_ft_nix then
	return
end
vim.b.did_my_ft_nix = true
vim.treesitter.start()

local set = vim.opt_local
set.shiftwidth = 2
set.tabstop = 2
set.softtabstop = 2
set.expandtab = true
set.fileformat = "unix"
