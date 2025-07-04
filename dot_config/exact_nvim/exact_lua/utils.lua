-- utility functions that weren't in plenary.nvim (probably for very good reason)
local M = {}
M.milliseconds_per_second = 1000

-- Try to figure out if the directory separator should be a forward- or
-- backslash
-- from:
-- https://github.com/wbthomason/packer.nvim/blob/6afb67460283f0e990d35d229fd38fdc04063e0a/lua/packer/util.lua#L38-L65
if ((jit ~= nil and jit.os == "Windows") or (package.config:sub(1, 1) == [[\]])) and not vim.o.shellslash then
	M.join_path = function(...)
		return table.concat({ ... }, [[\]])
	end
else
	M.join_path = function(...)
		return table.concat({ ... }, [[/]])
	end
end

function M.run(tbl)
	-- remove trailing whitespace, including newlines
	local output = vim.fn.system(tbl)
	if vim.v.shell_error ~= 0 then
		local msg = ("error when trying to run:\n" .. vim.inspect(tbl) .. "\n\n" .. tostring(output))
		vim.notify(msg, vim.log.levels.ERROR, {})
		error(msg)
	end
	-- does the same as: output:gsub("%s+$", "")
	return vim.trim(output)
end

function M.add_to_path(array)
	if type(array) ~= "table" then
		array = { array }
	end
	array = vim.tbl_map(vim.fs.normalize, array)
	local envsep = ((vim.uv or vim.loop).os_uname().sysname:find("[wW]indows") ~= nil) and ";" or ":"
	local path = vim.split(vim.env.PATH, envsep, { plain = true })
	for _, addition in ipairs(array) do
		table.insert(path, addition)
	end
	vim.env.PATH = table.concat(path, envsep)
end

function M.calculate_nproc()
	-- Find an appropriate number of processes to run in parallel, for things like
	-- package management
	if vim.g.max_nproc then
		return vim.g.max_nproc
	end
	vim.notify("calculating number of jobs", vim.log.levels.DEBUG, {})
	local run = M.run
	vim.g.max_nproc_default = 1
	local nproc
	if vim.fn.has("win32") > 0 then
		nproc = vim.fn.getenv("NUMBER_OF_PROCESSORS")
		nproc = ((type(nproc) == "string") and (nproc ~= "") and tonumber(nproc, 10))
			or tonumber(
				run({
					"cmd",
					"/D", -- don't load autorun
					"/C",
					"echo %NUMBER_OF_PROCESSORS%",
				}),
				10
			)
		if type(nproc) == "nil" then
			vim.notify(
				"windows did not return a number when " .. "asked for the number of processors",
				vim.log.levels.WARN,
				{}
			)
			nproc = vim.g.max_nproc_default
		end
	elseif vim.fn.has("android") == 1 then
		-- android test because nu v0.94.2 could not determine the number of cpus on the system
		nproc = tonumber(run({ "nproc" }), 10)
		if type(nproc) == "nil" then
			vim.notify("andoid `nproc` did not return a sensible number for number of cpus", vim.log.levels.WARN)
			nproc = vim.g.max_nproc_default
		end
	elseif vim.fn.executable("nu") == 1 then
		nproc = tonumber(run({ "nu", "-c", "sys cpu | length | [($in), " .. tostring(1) .. "] | math max" }), 10)
		if type(nproc) == "nil" then
			vim.notify("nu did not return a sensible number for the number of cpus", vim.log.levels.WARN)
			nproc = vim.g.max_nproc_default
		end
	else
		vim.notify(
			"non-windows platforms haven't been addressed yet " .. "so using a default of: " .. vim.g.max_nproc_default,
			vim.log.levels.WARN,
			{}
		)
		nproc = vim.g.max_nproc_default
	end
	vim.notify("max concurrent jobs: " .. tostring(nproc), vim.log.levels.DEBUG, {})
	vim.g.max_nproc = nproc
	return nproc
end

function M.try_add_nodejs()
	if vim.fn.executable("node") == 1 then
		vim.notify("node already available", vim.log.levels.DEBUG)
		return true
	end

	if vim.fn.executable("fnm") ~= 1 then
		vim.notify("cannot find `fnm` in $PATH", vim.log.levels.WARN)
		return false
	end

	local ok, node_dir = pcall(M.run, {
		"fnm",
		"exec",
		"--using=default",
		"nu",
		"-c",
		"$env | get Path? PATH? | first | first",
	})
	if not ok then
		vim.notify(
			"fnm is installed but node isn't? Try `fnm install --lts`\n" .. tostring(node_dir),
			vim.log.levels.WARN
		)
		return false
	end

	M.add_to_path(node_dir)
	return true
end

---Return the executable for the program using my preferences
---@param bufnr integer
---@param shebang string?
---@return string[]?
function M.parse_shebang(bufnr, shebang)
	if shebang == nil then
		shebang = "#!"
	end
	shebang = tostring(shebang)

	if vim.api.nvim_buf_get_text(bufnr, 0, 0, 0, #shebang, {})[1] ~= shebang then
		vim.notify("shebang (" .. shebang .. ") not found in " .. vim.api.nvim_buf_get_name(bufnr), vim.log.levels.WARN)
		return nil
	end

	-- NOTE::IMPROVEMENT may get overloaded if the file is one long line without
	-- linebreaks
	local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1]
	vim.notify("first_line -> " .. vim.inspect(first_line), vim.log.levels.DEBUG)
	assert(first_line, "buffer missing first line")
	assert(
		first_line:sub(1, #shebang) == shebang,
		"first two characters of first line ARE NOT " .. shebang .. ", somehow??"
	)
	local pattern = M.shebang_pattern(shebang)
	local result = pattern:match(first_line)
	table.insert(result, 1, result.prog)
	result.prog = nil
	return result
end

---Make an LPeg pattern to parse shebang lines using my preferences
---@param shebang string?
---@return vim.lpeg.Pattern
function M.shebang_pattern(shebang)
	if shebang == nil then
		shebang = "#!"
	end

	local locale = vim.lpeg.locale()
	local C = vim.lpeg.C
	local Cg = vim.lpeg.Cg
	local Ct = vim.lpeg.Ct
	local P = vim.lpeg.P
	local S = vim.lpeg.S

	local space = locale.space ^ 1
	local sspace = locale.space ^ 0
	local nl = P("\r\n") + P("\n")
	local word = (locale.alnum + locale.punct + S("_")) ^ 1
	local prog = Cg(word, "prog")
	local arg = C(word)
	local line_end = (space ^ 0) * (nl ^ 0)

	return P(shebang) * ((P("/usr/bin/env") * space) ^ -1) * sspace * Ct(prog * ((space * arg) ^ 0)) * line_end
end

---Tests the shebang pattern
---@param pattern vim.lpeg.Pattern?
function M.test_shebang_pattern(pattern)
	local _pattern = pattern or M.shebang_pattern()

	assert(vim.deep_equal(_pattern:match("#!/usr/bin/env mariadb --help"), { prog = "mariadb", "--help" }))
	assert(vim.deep_equal(_pattern:match("#!/usr/bin/env mariadb"), { prog = "mariadb" }))
	assert(vim.deep_equal(_pattern:match("#!/usr/bin/envmariadb --help"), { prog = "/usr/bin/envmariadb", "--help" }))
	assert(vim.deep_equal(_pattern:match("#! mariadb --help"), { prog = "mariadb", "--help" }))
	assert(vim.deep_equal(_pattern:match("#! mariadb"), { prog = "mariadb" }))
	assert(vim.deep_equal(_pattern:match("#!mariadb"), { prog = "mariadb" }))
	assert(vim.deep_equal(_pattern:match("#!mariadb --help"), { prog = "mariadb", "--help" }))
	assert(vim.deep_equal(_pattern:match("#!/bin/bash -e -u"), { prog = "/bin/bash", "-e", "-u" }))
	assert(vim.deep_equal(_pattern:match("#!/bin/bash"), { prog = "/bin/bash" }))
end

---creates function for passing to vim.system()
---@param bufnr integer
---@return function(error: string, data: string): nil
function M.make_buffer_writer(bufnr)
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local bufnr_name = "(" .. tostring(bufnr) .. ") " .. tostring(bufname)
	local notify = vim.schedule_wrap(vim.notify)
	---write to buffer
	---@param text string
	local write_to_buf = function(text)
		vim.schedule(function()
			for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
				local append_result = vim.fn.appendbufline(bufnr, "$", line)
				assert(append_result == 0, "error writing to buffer " .. bufnr_name)
			end
		end)
	end
	notify("will be writing to buffer " .. bufnr_name, vim.log.levels.INFO)
	local leftover = ""
	---writes input data chunk to buffer
	---@param error string?
	---@param data string?
	return function(error, data)
		if error then
			local msg = "error writing to buffer " .. bufnr_name .. ": " .. tostring(error)
			notify(msg, vim.log.levels.ERROR)
			error(msg)
		end

		notify("will be writing data -> " .. tostring(data), vim.log.levels.INFO)

		if data == nil then
			if #leftover > 0 then
				write_to_buf(leftover)
				leftover = ""
			end
			return
		end

		if #leftover + #data <= 0 then
			notify("no leftover or data for " .. bufnr_name, vim.log.levels.INFO)
			return
		end
		data = table.concat({ leftover, data })
		notify("all to write -> " .. tostring(data), vim.log.levels.INFO)
		local has_nl, endi = data:find("\n", 1, true)
		notify("has_nl -> " .. tostring(has_nl), vim.log.levels.INFO)
		while has_nl do
			local up_to_nl = data:sub(1, endi - 1)
			notify("up_to_nl -> " .. tostring(up_to_nl), vim.log.levels.INFO)
			assert(endi, "end index was nil")
			write_to_buf(up_to_nl)
			data = data:sub(endi)
			notify("after trimming up to nl -> " .. tostring(data), vim.log.levels.INFO)
			has_nl, endi = data:find("\n", 1, true)
			notify("final has_nl -> " .. tostring(has_nl), vim.log.levels.INFO)
		end
		leftover = data
		notify("leftover -> " .. tostring(leftover), vim.log.levels.INFO)
	end
end

---closes a buffer in every window in the current tabpage
---@param bufnr integer
function M.close_buf_in_tab(bufnr)
	assert(
		type(bufnr) == "number",
		"bufnr must be an integer, as returned from nvim_get_current_buf(), not "
			.. type(bufnr)
			.. " ("
			.. tostring(bufnr)
			.. ")"
	)

	local winnrs = vim.tbl_filter(function(winnr)
		return vim.api.nvim_win_get_buf(winnr) == bufnr
	end, vim.api.nvim_tabpage_list_wins(0))
	vim.tbl_map(vim.api.nvim_win_hide, winnrs)
end

function M.is_buf_visible_in_current_tab(bufnr)
	return vim.tbl_contains(vim.fn.tabpagebuflist(), bufnr)
end

---@alias SkipFirstLine
---| '"always"' # always skip the first line
---| '"non_default_cmd"' # only skip the first line if starts with a #!
---| '"default_cmd"' # only skip the first line if it does not start with a #!
---| '"never"' # never skip the first line

---Returns a function that "executes" the buffer similar to executing a #!
---script, and writes the output into a scratch buffer as soon as possible
---@param bufnr integer
---@param default_cmd function(): string[]
---@param skip_first_line SkipFirstLine
---@return {scratch_bufnr: integer?, runner: fun(): nil}
function M.make_streaming_buf_runner(bufnr, default_cmd, skip_first_line)
	assert(false, "not implemented")
	--[=[
	local writer = M.make_buffer_writer(returns.scratch_bufnr)
	local systemobj = vim.system(
		cmd,
		{ stdin = input, text = true, stdout = writer, stderr = writer, timeout = 3 * M.milliseconds_per_second }
	)
	writer(nil, "writing to scratchbuf works")
	local output = systemobj:wait(3 * M.milliseconds_per_second)
	if output.code ~= 0 then
		vim.notify("database error: " .. tostring(output.stderr), vim.log.levels.ERROR, {})
	end
	vim.notify("output -> " .. vim.inspect(output), vim.log.levels.INFO)
  --]=]
end

---Returns a function that "executes" the buffer similar to executing a #!
---script, cllects the stderr and stdout, then writes those into a scratch
---buffer
---@param bufnr integer
---@param default_cmd function(): string[]
---@param skip_first_line SkipFirstLine?
---@param shebang string?
---@return {scratch_bufnr: integer?, runner: fun(): nil}
function M.make_simple_buf_runner(bufnr, default_cmd, skip_first_line, shebang)
	if skip_first_line == nil then
		skip_first_line = "non_default_cmd"
	end

	if shebang == nil then
		shebang = "#!"
	end

	local returns = {
		scratch_bufnr = nil,
		runner = nil,
	}

	returns.runner = function()
		local cmd = M.parse_shebang(bufnr, shebang)
		vim.notify("parse_shebang -> " .. vim.inspect(cmd), vim.log.levels.DEBUG)
		local is_default_cmd = false
		if not cmd then
			cmd = default_cmd()
			assert(type(cmd) == "table" and (not vim.tbl_isempty(cmd)), "default command must be a list of strings")
			is_default_cmd = true
		end
		vim.notify("cmd -> " .. vim.inspect(cmd), vim.log.levels.DEBUG)

		-- NOTE::IMPROVEMENT this should stream
		-- get the whole file as a table of lines
		local input = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

		vim.notify("input before maybe skip -> " .. vim.inspect(input), vim.log.levels.DEBUG)
		vim.notify("skip_first_line -> " .. tostring(skip_first_line), vim.log.levels.DEBUG)
		vim.notify("is_default_cmd -> " .. tostring(is_default_cmd), vim.log.levels.DEBUG)
		if
			skip_first_line == "always"
			or (skip_first_line == "default_cmd" and is_default_cmd)
			or (skip_first_line == "non_default_cmd" and not is_default_cmd)
		then
			-- skip the first line, which that starts with #!, because # may not be a
			-- comment character for the executable
			input = vim.list_slice(input, 2, #input)
		end
		vim.notify("input after maybe skip -> " .. vim.inspect(input), vim.log.levels.DEBUG)

		if not returns.scratch_bufnr then
			returns.scratch_bufnr = vim.api.nvim_create_buf(true, true)
			assert(returns.scratch_bufnr ~= 0, "error creaing scratch buffer")
			-- https://vi.stackexchange.com/a/21390
			vim.api.nvim_set_option_value("buflisted", true, { buf = returns.scratch_bufnr })
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = returns.scratch_bufnr })
			vim.api.nvim_set_option_value("bufhidden", "hide", { buf = returns.scratch_bufnr })
		end

		if not M.is_buf_visible_in_current_tab(returns.scratch_bufnr) then
			-- :split followed by :buffer
			vim.cmd.sbuffer(returns.scratch_bufnr)
		end

		local buf_name = (table.concat(cmd, " ") .. " < " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":."))
		vim.api.nvim_buf_set_name(returns.scratch_bufnr, buf_name)

		local output = vim.system(cmd, {
			stdin = input,
			text = true,
			timeout = 3 * M.milliseconds_per_second,
		}):wait(3 * M.milliseconds_per_second)
		if output.code ~= 0 then
			vim.notify("database error: " .. tostring(output.stderr), vim.log.levels.ERROR, {})
		end
		vim.notify("output -> " .. vim.inspect(output), vim.log.levels.DEBUG)
		local combined = vim.iter({ output.stderr, output.stdout })
			:filter(function(e)
				return e ~= ""
			end)
			:map(function(e)
				return vim.split(e, "\n", { plain = true })
			end)
			:flatten()
		while combined:rpeek() == "\n" or combined:rpeek() == "" do
			combined = combined:rskip(1)
		end
		local buflines = vim.api.nvim_buf_line_count(returns.scratch_bufnr)
		vim.notify("buflines -> " .. tostring(buflines), vim.log.levels.DEBUG)
		-- may be nil
		local last_i = 0
		for i, line in combined:enumerate() do
			vim.notify("i -> " .. tostring(i), vim.log.levels.DEBUG)
			last_i = i
			vim.notify("setting line " .. tostring(i - 1), vim.log.levels.DEBUG)
			vim.api.nvim_buf_set_lines(returns.scratch_bufnr, i - 1, i, false, { line })
		end
		-- if output was shorter than file, truncate rest of file
		if last_i < buflines then
			vim.notify("truncating buffer from " .. tostring(last_i) .. " to -1", vim.log.levels.DEBUG)
			vim.api.nvim_buf_set_lines(returns.scratch_bufnr, last_i, -1, true, {})
		end
	end

	return returns
end

-- from:
-- https://github.com/hrsh7th/nvim-cmp/blob/f17d9b4394027ff4442b298398dfcaab97e40c4f/README.md?plain=1#L126-L131
function M.get_capabilities()
	local cmp_nvim_lsp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
	local capabilities = cmp_nvim_lsp_ok and cmp_nvim_lsp.default_capabilities()
		or vim.lsp.protocol.make_client_capabilities()
	capabilities.textDocument.completion.completionItem.snippetSupport = true
	return capabilities
end

return M
