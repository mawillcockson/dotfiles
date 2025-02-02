-- utility functions that weren't in plenary.nvim (probably for very good reason)
local M = {}

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
---@return string[]?
function M.parse_shebang(bufnr)
	if vim.api.nvim_buf_get_text(bufnr, 0, 0, 0, 2, {})[1] ~= "#!" then
		vim.notify("shebang not found in " .. vim.api.nvim_buf_get_name(bufnr), vim.log.levels.WARN)
		return nil
	end

	-- NOTE::IMPROVEMENT may get overloaded if the file is one long line without
	-- linebreaks
	local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1]
	vim.notify("first_line -> " .. vim.inspect(first_line), vim.log.levels.INFO)
	assert(first_line, "buffer missing first line")
	assert(first_line:sub(1, 2) == "#!", "first two characters of first line ARE NOT #!, somehow??")
	local pattern = M.shebang_pattern()
	local result = pattern:match(first_line)
	table.insert(result, 1, result.prog)
	result.prog = nil
	return result
end

function M.shebang_pattern()
	local locale = vim.lpeg.locale()
	local C = vim.lpeg.C
	local Cg = vim.lpeg.Cg
	local Ct = vim.lpeg.Ct
	local P = vim.lpeg.P
	local S = vim.lpeg.S

	local space = locale.space ^ 1
	local nl = P("\r\n") + P("\n")
	local word = (locale.alnum + locale.punct + S("_")) ^ 1
	local prog = Cg(word, "prog")
	local arg = C(word)
	local line_end = (space ^ 0) * (nl ^ 0)

	return P("#!")
		* (P("/usr/bin/env") ^ -1 * (space ^ 0))
		* Ct(prog * ((space * arg) ^ 0) * ((space * arg * line_end) ^ 0))
end

---Tests the shebang pattern
---@param pattern vim.lpeg.Pattern?
function M.test_shebang_pattern(pattern)
	local _pattern = pattern or M.shebang_pattern()

	assert(vim.deep_equal(_pattern:match("#!/usr/bin/env mariadb --help"), { prog = "mariadb", "--help" }))
	assert(vim.deep_equal(_pattern:match("#! mariadb --help"), { prog = "mariadb", "--help" }))
	assert(vim.deep_equal(_pattern:match("#!/bin/bash -e -u"), { prog = "/bin/bash", "-e", "-u" }))
	assert(vim.deep_equal(_pattern:match("#!/bin/bash"), { prog = "/bin/bash" }))
	assert(vim.deep_equal(_pattern:match("#! mariadb"), { prog = "mariadb" }))
	assert(vim.deep_equal(_pattern:match("#!/usr/bin/env mariadb"), { prog = "mariadb" }))
end

return M
