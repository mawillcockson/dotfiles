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

return M
