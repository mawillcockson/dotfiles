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
        if not vim.fn.executable("sqlite3") then
          vim.notify("sqlite3 not installed", vim.log.levels.WARN, {})
          return nil
        end

        local scratch_buf = false
        --local run_sql -- forward declaration: https://www.lua.org/pil/6.2.html

        local function run_sql()
          local sql = vim.api.nvim_buf_get_name(args.buf)
          local filename = vim.fn.fnamemodify(sql, ":t:r")
          local db = vim.fs.normalize(vim.fs.dirname(sql) .. "/" .. filename .. ".db")
          local cmd = {
            "sqlite3",
            db,
          }
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
            vim.keymap.set("n", "<leader>r", run_sql, { buffer = scratch_buf })
            vim.api.nvim_buf_set_option(scratch_buf, "buflisted", true)
            vim.api.nvim_buf_set_option(scratch_buf, "buftype", "nofile")
            vim.api.nvim_buf_set_option(scratch_buf, "bufhidden", "hide")

          end

          local function log(msg)
            vim.notify(vim.inspect(msg), vim.log.levels.DEBUG, {})
          end

          local visible_bufs = vim.fn.tabpagebuflist()
          if not vim.tbl_contains(visible_bufs, scratch_buf) then
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

        vim.keymap.set("n", "<leader>r", run_sql, { buffer = args.buf })
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
