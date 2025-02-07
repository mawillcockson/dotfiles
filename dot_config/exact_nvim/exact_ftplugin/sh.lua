if vim.b.did_my_ftsh then
	return
end
local utils = require("utils")
vim.b.did_my_ftsh = true

local this_bufnr = vim.api.nvim_get_current_buf()

---if file doesn't start with #! then default to sqlite3
---@return string[]?
local function default_cmd()
	if vim.fn.executable("sh") == 1 then
		cmd = { "sh" }
	else
		error("no appropriate executable for sh file found")
	end

	local bufname = vim.api.nvim_buf_get_name(this_bufnr)

	cmd[#cmd + 1] = bufname
	return cmd
end

local executor = utils.make_simple_buf_runner(this_bufnr, default_cmd, "never", "#!")

local keys = {
	open = "<leader>rr",
	close = "<leader>rc",
}

local wk = require("which-key")
wk.add({
	{
		keys.open,
		executor.runner,
		desc = "execute buffer like a bin script and place output in scratch buffer",
		buffer = this_bufnr,
	},
	{
		keys.close,
		function()
			utils.close_buf_in_tab(executor.scratch_bufnr)
		end,
		desc = "close run buffer",
		buffer = this_bufnr,
	},
})

wk.add({
	{
		keys.open,
		executor.runner,
		desc = "execute associated script",
		buffer = executor.scratch_bufnr,
	},
	{
		keys.close,
		function()
			utils.close_buf_in_tab(executor.scratch_bufnr)
		end,
		desc = "close this run buffer",
		buffer = executor.scratch_bufnr,
	},
})
