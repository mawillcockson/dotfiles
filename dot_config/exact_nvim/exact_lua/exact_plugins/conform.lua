return {
	"stevearc/conform.nvim",
	branch = "master",
	version = "*",
	lazy = true,
	keys = {
		{
			"<leader>cf",
			function()
				require("conform").format({
					timeout_ms = 1000,
					lsp_format = "fallback",
				})
			end,
			mode = { "n", "v" },
			desc = "run conform.nvim for formatting the current buffer",
		},
	},
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			-- nvim-lint can handle mypy:
			-- https://github.com/mfussenegger/nvim-lint
			python = function(bufnr)
				if require("conform").get_formatter_info("ruff_format", bufnr).available then
					return { "ruff_format", "ruff_organize_imports" }
				else
					return { "usort", "black" }
				end
			end,
			json = { "jq" },
			sh = { "shfmt", "shellcheck" },
			sql = { "sqlfluff" },
			zig = { "zigfmt" },
			elm = { "elm_format" },
			dart = { "dart_format" },
			html = { "prettier" },
			css = { "prettier" },
			javascript = { "prettier" },
		},
	},
	config = function(name, opts)
		require("conform").setup(opts)
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
