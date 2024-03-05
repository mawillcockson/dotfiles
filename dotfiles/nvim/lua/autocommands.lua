print "ran autocommands"

local custom_autocmds_group_name = "custom_autocmds"
vim.api.nvim_create_augroup(custom_autocmds_group_name, { clear = true })
-- inspired by:
-- https://luabyexample.org/docs/nvim-autocmd/
-- https://www.reddit.com/r/neovim/comments/t7k5k1/comment/hziccvb/?utm_source=share&utm_medium=web2x&context=3
local autocmds = {
  TermOpen = {
    {
      pattern = "term://*//*:*",
      command = "redraw | startinsert",
    },
  },
  FileType = {
    {
      pattern = {"text", "markdown", "gitcommit"},
      callback = function()
        vim.opt_local.spell = true
        vim.opt_local.spelllang = "en_us"
      end,
    },
    {
      pattern = "lua",
      callback = function()
        vim.opt_local.sw = 2
        vim.opt_local.ts = 2
      end,
    },
    {
      pattern = "python",
      command = "set sw=4 ts=4 expandtab",
    },
    {
      pattern = "html",
      command = "set sw=2 ts=2 sts=2 expandtab",
    },
    {
      pattern = "sql",
      callback = function(args)
        local executable = {}
        if vim.fn.executable("sqlean") then
          -- https://github.com/nalgeon/sqlite#sqlean
          executable = {"sqlean"}
        elseif vim.fn.executable("sqlite3") then
          executable = {"sqlite3"}
        -- NOTE: Need to write a Python script that can read SQL from a stdin
        -- pipe, and execute the script it receives upon a particular database.
        -- Note sure how to execute the script, but I guess it can be given as
        -- command-line arguments to the python executable, with the database
        -- path being the other argument, so the script can find the correct
        -- database file to connect to
        --[[
        elseif vim.fn.executable("python3") then
          executable = {"python3", "-m", "sqlite3"}
        elseif vim.fn.executable("python") then
          executable = {"python", "-m", "sqlite3"}
        --]]
        else
          vim.notify("sqlite3 not installed", vim.log.levels.WARN, {})
          return nil
        end

        local keys = {
          open = "<leader>rr",
          close = "<leader>rc",
        }

        local function is_buf_visible(bufnr)
          return vim.tbl_contains(vim.fn.tabpagebuflist(), bufnr)
        end

        local scratch_buf = false
        --local run_sql -- forward declaration: https://www.lua.org/pil/6.2.html

        local function close_buf(bufnr)
          local winnrs = vim.tbl_filter(
            function(winnr)
              return vim.api.nvim_win_get_buf(winnr) == bufnr
            end,
            vim.api.nvim_tabpage_list_wins(0)
          )
          vim.tbl_map(vim.api.nvim_win_hide, winnrs)
        end

        local function run_sql()
          local sql = vim.api.nvim_buf_get_name(args.buf)
          local filename = vim.fn.fnamemodify(sql, ":t:r")
          local db = vim.fs.normalize(vim.fs.dirname(sql) .. "/" .. filename .. ".db")
          -- copy executable table
          local cmd = {unpack(executable)}
          cmd[#cmd + 1] = db
          --[[ use the shortcut in system() to give a valid buffer id
          -- get the whole file as a table of lines
          local input = vim.api.nvim_buf_get_lines(0, 0, -1, true)
          --]]
          local input = args.buf

          local output = vim.fn.systemlist(cmd, input)
          if vim.v.shell_error ~= 0 then
            vim.notify("sqlite error: " .. tostring(vim.v.shell_error), vim.log.levels.ERROR, {})
          end

          if scratch_buf == false then
            scratch_buf = vim.api.nvim_create_buf(true, true)
            -- https://vi.stackexchange.com/a/21390
            vim.keymap.set("n", keys.open, run_sql, { buffer = scratch_buf })
            vim.keymap.set("n", keys.close, function() close_buf(scratch_buf) end, { buffer = scratch_buf })
            vim.api.nvim_buf_set_option(scratch_buf, "buflisted", true)
            vim.api.nvim_buf_set_option(scratch_buf, "buftype", "nofile")
            vim.api.nvim_buf_set_option(scratch_buf, "bufhidden", "hide")

          end

          if not is_buf_visible(scratch_buf) then
            -- :split followed by :buffer
            vim.cmd.sbuffer(scratch_buf)
          end

          vim.api.nvim_buf_set_name(scratch_buf,
            "sqlite3 " ..
            vim.fn.shellescape(vim.fn.fnamemodify(sql, ":.:r") .. ".db")
            .. " < " .. vim.fn.shellescape(vim.fn.fnamemodify(sql, ":."))
          )

          output = vim.tbl_map(
            function(line)
              return line:gsub("\r$", "")
            end,
            output)
          vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, true, output)
        end

        vim.keymap.set("n", keys.open, run_sql, { buffer = args.buf })
        vim.keymap.set("n", keys.close, function() close_buf(scratch_buf) end, { buffer = args.buf })
      end
    },
  },
}

for event_name, opts in pairs(autocmds) do
  for i, opt in pairs(opts) do
    opt.group = custom_autocmds_group_name
    vim.api.nvim_create_autocmd(event_name, opt)
  end
end
