-- utility functions that weren't in plenary.nvim (probably for very good reason)
local M = {}

-- Try to figure out if the directory separator should be a forward- or
-- backslash
-- from:
-- https://github.com/wbthomason/packer.nvim/blob/6afb67460283f0e990d35d229fd38fdc04063e0a/lua/packer/util.lua#L38-L65
if (
     (jit ~= nil and jit.os == "Windows")
     or
     (package.config:sub(1,1) == [[\]])
  ) and not vim.o.shellslash
then
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
    local msg = ("error when trying to run:\n" ..
      vim.inspect(tbl) .. "\n\n" ..
      tostring(output))
    vim.notify(
      msg,
      ERROR,
      {}
    )
    error(msg)
  end
  -- does the same as: output:gsub("%s+$", "")
  return vim.trim(output)
end

return M
