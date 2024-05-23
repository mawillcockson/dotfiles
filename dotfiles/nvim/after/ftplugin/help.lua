if vim.fn.has("conceal") then
	local winid = vim.api.nvim_get_current_win()
	-- like ':setlocal conceallevel=0'
	vim.wo[winid][0].conceallevel = 0
end
