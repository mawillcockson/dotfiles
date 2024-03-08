return {
  "stevearc/conform.nvim",
  version = "*",
  config = function(name, opts)
    require("conform").setup{
      formatters_by_ft = {
        lua = { "stylua" },
        -- nvim-lint can handle mypy:
        -- https://github.com/mfussenegger/nvim-lint
        python = function(bufnr)
          if require("conform").get_formatter_info("ruff_format", bufnr).available then
            return { "ruff_format" }
          else
            return { "isort", "black" }
          end
        end,
        json = { "jq" },
        sh = { "shellcheck" },
        sql = { "sqlfluff" },
      },
    }
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()",
    vim.keymap.set({"n", "v"}, "<leader>cf", function()
        require("conform").format{
          timeout_ms = 1000,
          lsp_fallback = true,
        }
      end, { desc = "run conform.nvim for formatting the current buffer" })
  end,
}
