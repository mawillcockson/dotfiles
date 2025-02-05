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
			nu = { "nufmt" },
			sql = { "sql_formatter" },
			zig = { "zigfmt" },
			elm = { "elm_format" },
			dart = { "dart_format" },
			html = { "prettier" },
			css = { "prettier" },
			javascript = { "prettier" },
		},
	},
	config = function(_, opts)
		local conform = require("conform")
		conform.setup(opts)
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

		local utils = require("utils")
		local default_options = {
			keywordCase = "upper",
			dataTypeCase = "lower",
		}
		local executable_to_lang = {
			psql = "postgresql",
			mariadb = "mariadb",
			sqlite = "sqlite",
		}
		conform.formatters.sql_formatter = function(bufnr)
			local shebang = utils.parse_shebang(bufnr, "--#!")
			local executable = nil
			if shebang == nil then
				executable = "sqlite"
			end
			local dialect = executable_to_lang[executable]
			local options = vim.tbl_extend("keep", { dialect = dialect }, default_options)
			return {
				args = { "--config", vim.json.encode(options) },
			}
		end
	end,
}
