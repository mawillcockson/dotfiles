local M = {}

local ok, plenary = pcall(require, "plenary")
if not ok then
	error("nvim-lua/plenary.nvim is missing and should be installed: " .. tostring(plenary))
end

-- semi-docs:
-- https://github.com/nvim-lua/plenary.nvim/blob/4b7e52044bbb84242158d977a50c4cbcd85070c7/lua/plenary/scandir.lua#L135-L149
local scan_dir = plenary.scandir.scan_dir
local Path = plenary.path
local dir_sep = Path.path.sep

-- from:
-- https://github.com/nvim-lua/plenary.nvim/blob/4b7e52044bbb84242158d977a50c4cbcd85070c7/lua/plenary/path.lua#L75-L77
local is_uri = function(filename)
	return string.match(filename, "^%w+://") ~= nil
end

---zero-pads a number
---@param num number
---@param width number
---@return string
local function pad_number(num, width)
	return vim.fn.printf("%0" .. tostring(width) .. "d", num)
end

--[[ maybe useful functions and commands

nvim_buf_call({buffer}, {fun})                               *nvim_buf_call()*
                call a function with buffer as temporary current buffer

nvim_list_bufs()                                            *nvim_list_bufs()*
                Gets the current list of buffer handles

nvim_buf_delete({buffer}, {opts})                          *nvim_buf_delete()*
                Deletes the buffer. See |:bwipeout|

nvim_buf_get_name({buffer})                              *nvim_buf_get_name()*
                Gets the full file name for the buffer

nvim_buf_is_loaded({buffer})                            *nvim_buf_is_loaded()*
                Checks if a buffer is valid and loaded. See |api-buffer| for
                more info about unloaded buffers.

plenary.path.Path:mkdir{
  mode = 484, -- 0o0744 => decimal
  parents = true,
  exists_ok = true,
}

from:
https://github.com/nvim-lua/plenary.nvim/blob/4b7e52044bbb84242158d977a50c4cbcd85070c7/lua/plenary/path.lua#L544-L554
--- Copy files or folders with defaults akin to GNU's `cp`.
---@param opts table: options to pass to toggling registered actions
---@field destination string|Path: target file path to copy to
---@field recursive bool: whether to copy folders recursively (default: false)
---@field override bool: whether to override files (default: true)
---@field interactive bool: confirm if copy would override; precedes `override` (default: false)
---@field respect_gitignore bool: skip folders ignored by all detected `gitignore`s (default: false)
---@field hidden bool: whether to add hidden files in recursively copying folders (default: true)
---@field parents bool: whether to create possibly non-existing parent dirs of `opts.destination` (default: false)
---@field exists_ok bool: whether ok if `opts.destination` exists, if so folders are merged (default: true)
---@return table {[Path of destination]: bool} indicating success of copy; nested tables constitute sub dirs
plenary.path.Path:copy{}
--]]

---@type string
M.challenge_dir_pattern = "^%." .. dir_sep .. "(%d+)$"
---@type number
M.challenge_dir_min_digits = 3

---assumes that Neovim's current directory is a freeCodeCamp.org project, and
---looks up the current challenge / step directory (which is assumed to be just
---a number), and copies the existing files to a new directory, and then
---removed and buffers targeting the old files
function M.freeCodeCampNext()
	-- Figure out what the current project and challenge is.
	-- Assumes that projects are completed in ascending order of numerical prefix.
	local max_num = 0
	local current_challenge_dir = ""

	for _, dir in ipairs(scan_dir(".", { only_dirs = true, depth = 1, search_pattern = M.challenge_dir_pattern })) do
		local num = dir:match(M.challenge_dir_pattern)
		assert(num, "expected directory to be a decimal number, but it was not: " .. dir)
		local as_number = tonumber(num, 10)
		if as_number >= max_num then
			max_num = as_number
			current_challenge_dir = num
		end
	end

	local current_challenge_number = max_num

	local function make_challenge_dir_name(num)
		return Path:new(".", pad_number(num, M.challenge_dir_min_digits))
	end

	-- find the files in the current_challenge_number
	vim.notify("current_challenge_number -> " .. tostring(current_challenge_number), vim.log.levels.DEBUG)
	local old_challenge_dir = Path:new(current_challenge_dir):absolute()
	vim.notify("old_challenge_dir -> " .. tostring(old_challenge_dir), vim.log.levels.DEBUG)

	local current_files = vim.tbl_map(function(path)
		return Path:new(path)
	end, scan_dir(old_challenge_dir, { depth = 1 }))
	vim.notify("current_files -> " .. vim.inspect(current_files), vim.log.levels.DEBUG)

	-- list all open buffers and their file names
	local buffer_nums = vim.api.nvim_list_bufs()
	local buffers = {}
	for _, bufnr in ipairs(vim.tbl_filter(vim.api.nvim_buf_is_loaded, buffer_nums)) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		-- ignore buffers created without a name, terminals, and buffers without a backing file
		if name ~= "" and (not is_uri(name)) and Path:new(name):exists() then
			assert(
				type(buffers[name]) == "nil",
				"name -> " .. tostring(name) .. " <- already found?\n" .. vim.inspect(buffers)
			)
			buffers[name] = bufnr
		end
	end

	-- make the next challenge directory
	local next_challenge_dir = Path:new(make_challenge_dir_name(current_challenge_number + 1))
	vim.notify("making new directory -> " .. tostring(next_challenge_dir), vim.log.levels.DEBUG)
	-- we're creating it for the first time now, so it'd be weird if it suddenly
	-- appeared in between now and since we last checked just a few mmilliseconds
	-- ago
	next_challenge_dir:mkdir({ exists_ok = false })

	-- for all the files in the old challenge directory
	for _, path in ipairs(current_files) do
		-- find the basename of the file
		local filename = vim.fs.basename(tostring(path))
		assert(#filename > 0, "filename can't be 0 characters")
		local new_path = next_challenge_dir / filename
		local escaped = vim.fn.fnameescape(tostring(new_path))
		assert(#escaped > 0, "escaped filename can't be 0 characters -> " .. tostring(new_path))

		local bufnr = buffers[path:absolute()]
		vim.notify(
			"there's " .. (bufnr and "" or "not ") .. "a buffer open for " .. tostring(path),
			vim.log.levels.DEBUG
		)

		-- if the file is open in a buffer
		if type(bufnr) == "number" then
			-- run a function in the buffer
			vim.api.nvim_buf_call(bufnr, function()
				-- save the buffer to the old location
				vim.cmd.w()
				-- save the buffer to the new location
				vim.cmd.saveas(escaped)
			end)
		else
			assert(path:copy({
				destination = new_path,
				recursive = false,
				interactive = false,
			})[new_path] == true, "copy not a success")
		end
	end

	-- check which buffer numbers are new:
	-- when using :saveas, the current buffer keeps the same number and changes
	-- filename, while the old file is assigned a new buffer number
	local old_buffer_nums = {}
	for _, num in ipairs(buffer_nums) do
		old_buffer_nums[num] = true
	end
	local new_buffer_nums = {}
	for _, num in ipairs(vim.api.nvim_list_bufs()) do
		new_buffer_nums[num] = true
	end
	local difference = {}
	for num, _ in pairs(new_buffer_nums) do
		if old_buffer_nums[num] == nil then
			difference[#difference + 1] = num
		end
	end

	vim.notify("deleting these buffers -> " .. vim.inspect(vim.tbl_map(function(bufnr)
		return { bufnr = bufnr, name = vim.api.nvim_buf_get_name(bufnr) }
	end, difference)), vim.log.levels.DEBUG)
	if not vim.tbl_isempty(difference) then
		vim.cmd.bd(unpack(difference))
	end
end

---setup freeCodeCamp-specific functionality
---@param opts {keys: {next: string|nil}}|nil
function M.setup(opts)
	vim.notify("ran freeCodeCamp setup", vim.log.levels.DEBUG, {})

	opts = vim.tbl_deep_extend("keep", opts or {}, { keys = { next = nil } })

	vim.api.nvim_create_user_command("FreeCodeCampNext", M.freeCodeCampNext, {})

	local wk = require("which-key")
	if opts.keys.next ~= nil then
		wk.add({
			{ opts.keys.next, M.freeCodeCampNext, desc = "freeCodeCamp: make the next challenge step files" },
		})
	end
end

return M
