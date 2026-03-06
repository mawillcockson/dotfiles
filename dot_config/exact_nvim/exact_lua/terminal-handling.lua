local M = {}

local executable = function(string)
	return vim.fn.executable(string) == 1
end

local terms = {
	-- ordered by preference
	"nu",
	"pwsh", -- powershell before bash because otherwise on Windows, Git Bash will be run first
	"powershell",
	"bash",
	"sh",
}

local term_exe = assert(vim.tbl_filter(executable, terms)[1], "cannot find any executables for terminal!")

---@alias Terminal {win: integer, buf: integer}
---@alias Terminals Terminal[]
M.terminals = {}

M.augroup_name = "terminal_autogroup"
vim.api.nvim_create_augroup(M.augroup_name, { clear = false })
---remove a terminal from M.terminals
---@param buf integer
---@return Terminals
local function remove_by_buf(buf)
	local removed = {}
	M.terminals = vim.iter(M.terminals)
		:filter(function(term)
			if term.buf == buf then
				table.insert(removed, term)
				return false
			end
			return true
		end)
		:totable()
	return removed
end
---Add an autocommand to the buffer, to remove it from M.terminals when it's closed
---@param term Terminal
---@return nil
local function remove_term_after_close(term)
	vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload", "BufWipeout" }, {
		group = M.augroup_name,
		buffer = term.buf,
		desc = "when the terminal is closed, automatically remove the buffer from the list of terminals that can be Ctrl-E'd to",
		callback = function(ctx)
			vim.notify(
				string.format("removing terminal buffer %d due to autocmd %s", ctx.buf, ctx.event),
				vim.log.levels.DEBUG
			)
			remove_by_buf(ctx.buf)
			vim.api.nvim_del_autocmd(ctx.id)
		end,
		once = true,
	})
end
---appends a new terminal to the list of terminals
---@param term Terminal
---@return Terminals
local function add_terminal(term)
	table.insert(M.terminals, 1, term)
	remove_term_after_close(term)
	return M.terminals
end

---@alias splitTypes "horizontal" | "vertical" | nil
---@param split splitTypes
---@return nil
function M.new_terminal(split)
	if split == "horizontal" then
		vim.cmd("botright split")
	elseif split == "vertical" then
		vim.cmd("botright vsplit")
	elseif type(split) == "nil" then
		vim.cmd.tabnew()
	else
		vim.notify(
			[[split can be "horizontal", "vertical", or nil (indicating a new tab); instead got ]] .. tostring(split),
			vim.log.levels.ERROR
		)
		return error("incorrect split type: " .. tostring(split), 2)
	end
	vim.cmd.e("term://" .. term_exe)
	add_terminal({
		win = vim.api.nvim_get_current_win(),
		buf = vim.api.nvim_get_current_buf(),
	})
end

---finds the first loaded terminal buffer
---@param terminals Terminals
---@return integer | boolean
local function first_loaded_buf(terminals)
	for _, term in ipairs(terminals) do
		if vim.api.nvim_buf_is_loaded(term.buf) then
			return term.buf
		end
	end
	return false
end

---find first terminal with a valid window
---@param terminals Terminals
---@return integer | boolean
local function first_valid_win(terminals)
	for _, term in ipairs(terminals) do
		if vim.api.nvim_win_is_valid(term.win) then
			return term.win
		end
	end
	return false
end

---updates the window for the terminal with buffer buf
---@param old_buf integer
---@param new_win integer
---@return Terminals
local function update_win_for_buf(old_buf, new_win)
	M.terminals = vim.iter(M.terminals)
		:map(function(term)
			if term.buf == old_buf then
				return { buf = old_buf, win = new_win }
			end
			return term
		end)
		:totable()
	return M.terminals
end

function M.open_and_switch()
	-- NOTE::IMPROVEMENT should definitely look at
	-- https://github.com/akinsho/toggleterm.nvim
	local buf = first_loaded_buf(M.terminals)
	if (#M.terminals <= 0) or not buf then
		vim.cmd.tabnew("term://" .. term_exe)
		-- vim.cmd.startinsert() is not necessary, as and autocommand in the
		-- local.lua plugin spec does this for every TermOpen
		local term = {
			win = vim.api.nvim_get_current_win(),
			buf = vim.api.nvim_get_current_buf(),
		}
		add_terminal(term)
		return term
	end

	-- a buffer is valid and loaded

	local win = first_valid_win(M.terminals)
	if not win then
		-- is there a window that does have a terminal buffer open in it?
		local windows = vim.iter(M.terminals)
			:map(function(term)
				buf = term.buf
				return vim.fn.win_findbuf(term.buf)
			end)
			:flatten()

		if windows[1] then
			win = windows[1]
		else
			vim.cmd.tabnew()
			win = vim.api.nvim_get_current_win()
			assert(type(buf) == "number", "buffer should be valid, but isn't: " .. tostring(buf))
			update_win_for_buf(buf, win)
		end
	end

	-- might be redundant, in some cases, but it's useful to put it here for
	-- avoiding repeating it in various places
	vim.api.nvim_set_current_win(win)
	-- the order of the previous one, and this one, is important
	vim.api.nvim_set_current_buf(buf)
	vim.cmd.normal({ "i", bang = true })
	return true
end

return M
