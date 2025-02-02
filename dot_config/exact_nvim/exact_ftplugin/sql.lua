if vim.b.did_my_ftsql then
	return
end
local utils = require("utils")
vim.b.did_my_ftsql = true

local this_bufnr = vim.api.nvim_get_current_buf()

---if file doesn't start with #! then default to sqlite3
---@return string[]?
local function default_cmd()
	local cmd = {}
	if vim.fn.executable("sqlean") == 1 then
		-- https://github.com/nalgeon/sqlite#sqlean
		cmd = { "sqlean" }
	elseif vim.fn.executable("sqlite3") == 1 then
		cmd = { "sqlite3" }
	else
		-- NOTE::IMPROVEMENT could use nu here, if stdin can be read into a
		-- variable: `nu -c 'stor open | query db $stdin`

		-- NOTE: this could be useful:
		-- https://github.com/Olical/conjure/wiki/Quick-start:-SQL-(stdio)

		error("no appropriate executable for sql file found")
	end

	local bufname = vim.api.nvim_buf_get_name(this_bufnr)
	local filename = vim.fn.fnamemodify(bufname, ":t:r")
	local db = ""
	if vim.fn.filereadable(filename) == 1 then
		-- why not `vim.fn.fnamemodify(sql, ":.:r") .. ".db"` ?
		db = vim.fs.normalize(vim.fs.dirname(bufname) .. "/" .. filename .. ".db")
	else
		db = ":memory:"
	end

	cmd[#cmd + 1] = db
	return cmd
end

local executor = utils.make_simple_buf_runner(this_bufnr, default_cmd, "non_default_cmd")

local keys = {
	open = "<leader>rr",
	close = "<leader>rc",
}

--local run_sql -- forward declaration: https://www.lua.org/pil/6.2.html
local wk = require("which-key")

wk.add({
	{
		keys.open,
		executor.runner,
		desc = "run_sql() on run buffer",
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
		desc = "execute buffer",
		buffer = executor.scratch_bufnr,
	},
	{
		keys.close,
		function()
			utils.close_buf_in_tab(executor.scratch_bufnr)
		end,
		desc = "close run buffer",
		buffer = executor.scratch_bufnr,
	},
})
