local M = {}

local executable = function(string)
	return vim.fn.executable(string) == 1
end

local tabnew = vim.cmd.tabnew

local terms = {
	-- ordered by preference
	"nu",
	"pwsh", -- powershell before bash because otherwise on Windows, Git Bash will be run first
	"powershell",
	"bash",
	"sh",
}

local term_exe = assert(vim.tbl_filter(executable, terms)[1], "cannot find any executables for terminal!")

M.terminal = false

function M.open_and_switch()
	-- NOTE::IMPROVEMENT should definitely look at
	-- https://github.com/akinsho/toggleterm.nvim
	if (not M.terminal) or (not vim.api.nvim_buf_is_loaded(M.terminal.buf)) then
    tabnew("term://" .. term_exe)
		M.terminal = {
			win = vim.api.nvim_get_current_win(),
			buf = vim.api.nvim_get_current_buf(),
		}
    return true
	end

  -- buffer is valid and loaded

  if not vim.api.nvim_win_is_valid(M.terminal.win) then
    -- is there a window that does have the terminal buffer open in it?
    local windows = vim.fn.win_findbuf(M.terminal.buf)

		if windows[1] then
			M.terminal.win = windows[1]
		else
			tabnew()
			M.terminal.win = vim.api.nvim_get_current_win()
		end
	end

	-- might be redundant, in some cases, but it's useful to put it here for
	-- avoiding repeating it in various places
	vim.api.nvim_set_current_win(M.terminal.win)
  -- the order of the previous one, and this one, is important
	vim.api.nvim_set_current_buf(M.terminal.buf)
	vim.cmd.normal({ "i", bang = true })
	return true
end

return M
