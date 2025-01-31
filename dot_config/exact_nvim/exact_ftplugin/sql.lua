if vim.b.did_my_ftsql then
	return
end
vim.b.did_my_ftsql = true

local this_bufnr = vim.api.nvim_get_current_buf()

---use first line of sql file to determine what executable to pick
---@param first_line string
---@return string[]?, boolean
local function choose_executable(first_line)
	if first_line and vim.startswith(first_line, "#!") then
		local executable = vim.re.gsub(first_line, [["#!" "/usr/bin/env"? " "]], "")
		if executable then
			return vim.split(executable, "%s", { trimempty = true }), false
		end
	end

	-- if file doesn't start with #! then default to sqlite3

	if vim.fn.executable("sqlean") == 1 then
		-- https://github.com/nalgeon/sqlite#sqlean
		return { "sqlean" }, true
	end
	if vim.fn.executable("sqlite3") == 1 then
		return { "sqlite3" }, true
		-- NOTE: Need to write a Python script that can read SQL from a stdin
		-- pipe, and execute the script it receives upon a particular database.
		-- Note sure how to execute the script, but I guess it can be given as
		-- command-line arguments to the python executable, with the database
		-- path being the other argument, so the script can find the correct
		-- database file to connect to
		-- Also, this:
		-- https://github.com/Olical/conjure/wiki/Quick-start:-SQL-(stdio)
		--[[
        elseif vim.fn.executable("python3") == 1 then
          executable = {"python3", "-m", "sqlite3"}
        elseif vim.fn.executable("python") == 1 then
          executable = {"python", "-m", "sqlite3"}
        --]]
	end

	vim.notify("no appropriate executable for sql file found", vim.log.levels.WARN, {})
	return nil, false
end

local keys = {
	open = "<leader>rr",
	close = "<leader>rc",
}

local function is_buf_visible(bufnr)
	return vim.tbl_contains(vim.fn.tabpagebuflist(), bufnr)
end

---number | nil
local scratch_buf = nil
--local run_sql -- forward declaration: https://www.lua.org/pil/6.2.html
local wk = require("which-key")

local function close_buf(bufnr)
	if type(bufnr) ~= "number" then
		return
	end
	local winnrs = vim.tbl_filter(function(winnr)
		return vim.api.nvim_win_get_buf(winnr) == bufnr
	end, vim.api.nvim_tabpage_list_wins(0))
	vim.tbl_map(vim.api.nvim_win_hide, winnrs)
end

local function run_sql()
	local sql = vim.api.nvim_buf_get_name(this_bufnr)
	local filename = vim.fn.fnamemodify(sql, ":t:r")
	local buf_content = vim.api.nvim_buf_get_lines(this_bufnr, 0, 1, false)
	local first_line = buf_content[1]
	local cmd, is_sqlite = choose_executable(first_line)
	if not cmd then
		return nil
	end
	local db = nil
	if vim.fn.filereadable(filename) == 1 and is_sqlite then
		-- why not `vim.fn.fnamemodify(sql, ":.:r") .. ".db"` ?
		db = vim.fs.normalize(vim.fs.dirname(sql) .. "/" .. filename .. ".db")
	elseif is_sqlite then
		db = ":memory:"
	end
	if is_sqlite then
		cmd[#cmd + 1] = db
	end
	--[[ use the shortcut in system() to give a valid buffer id
  -- get the whole file as a table of lines
  local input = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  --]]
	local input = buf_content
	if not is_sqlite then
		input = vim.list_slice(input, 2, nil)
	end

	vim.notify("cmd -> " .. vim.inspect(cmd), vim.log.levels.INFO)
	local output = vim.fn.systemlist(cmd, input)
	if vim.v.shell_error ~= 0 then
		vim.notify("database error: " .. tostring(vim.v.shell_error), vim.log.levels.ERROR, {})
	end

	if not scratch_buf then
		scratch_buf = vim.api.nvim_create_buf(true, true)
		-- https://vi.stackexchange.com/a/21390
		wk.add({
			{ keys.open, run_sql, desc = "run_sql()" },
			{
				keys.close,
				function()
					close_buf(scratch_buf)
				end,
				desc = "close run buffer",
				buffer = scratch_buf,
			},
		})
		vim.api.nvim_set_option_value("buflisted", true, { buf = scratch_buf })
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = scratch_buf })
		vim.api.nvim_set_option_value("bufhidden", "hide", { buf = scratch_buf })
	end

	if not is_buf_visible(scratch_buf) then
		-- :split followed by :buffer
		vim.cmd.sbuffer(scratch_buf)
	end

	local buf_name = table.concat(cmd, " ")
	buf_name = (
		buf_name
		.. (is_sqlite and db and (" " .. vim.fn.shellescape(db)) or "")
		.. " < "
		.. vim.fn.shellescape(vim.fn.fnamemodify(sql, ":."))
	)
	vim.api.nvim_buf_set_name(scratch_buf, buf_name)

	output = vim.tbl_map(function(line)
		return line:gsub("\r$", "")
	end, output)
	vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, true, output)
end

wk.add({
	{
		keys.open,
		run_sql,
		desc = "run_sql() on run buffer",
		buffer = this_bufnr,
	},
	{
		keys.close,
		function()
			close_buf(scratch_buf)
		end,
		desc = "close run buffer",
		buffer = this_bufnr,
	},
})
