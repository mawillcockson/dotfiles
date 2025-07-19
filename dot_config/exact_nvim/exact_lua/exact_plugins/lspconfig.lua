local executable = function(name)
	return vim.fn.executable(name) == 1
end

vim.api.nvim_create_user_command("DoLspConfig", function()
	require("mason")
	require("mason-lspconfig").setup({ automatic_enable = false })
	require("lspconfig")
	require("lazydev")
end, {
	desc = "run the appropriate setups in the appropriate order",
	force = true,
})

return {
	{
		"williamboman/mason.nvim",
		version = "*",
		-- lazy overrules the priority, so the priority has no meaning to lazy
		lazy = true,
		priority = 100, -- https://github.com/williamboman/mason-lspconfig.nvim/tree/v1.27.0#setup
		opts = { max_concurrent_installers = require("utils").calculate_nproc() },
		config = function(_, opts)
			require("mason").setup(opts)
			require("utils").try_add_nodejs()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		version = "*",
		lazy = true,
		priority = 99, -- https://github.com/williamboman/mason-lspconfig.nvim/tree/v1.27.0#setup
		config = true,
		dependencies = {
			---- hopefully, putting this here will make it load before mason-lspconfig.nvim
			--"williamboman/mason.nvim",
			-- Put any dependencies that a language server might have here
			-- lua_ls:
			"LuaCATS/love2d",
		},
	},
	{
		-- https://github.com/neovim/nvim-lspconfig?tab=readme-ov-file#suggested-configuration
		"neovim/nvim-lspconfig",
		lazy = true,
		priority = 98, -- https://github.com/williamboman/mason-lspconfig.nvim/tree/v1.27.0#setup
		--dependencies = { "williamboman/mason-lspconfig.nvim" },
		config = function(_, _)
			local lspconfig = require("lspconfig")
			-- not needed, as there's nothing in the base project to configure
			-- lspconfig.config(name, opts)

			local mason_registry = require("mason-registry")
			local function mason_installed(name)
				return mason_registry.get_package(name):is_installed()
			end

			if executable("ruff") or mason_installed("ruff") then
				vim.lsp.enable("ruff")
			end

			if executable("nu") then
				vim.lsp.enable("nu")
			end

			if executable("zls") and executable("zig") then
				vim.lsp.enable("zls")
			end

			if executable("emmet-language-server") or mason_installed("emmet-language-server") then
				vim.lsp.enable("emmet_language_server")
			end

			if executable("vscode-css-language-server") or mason_installed("css-lsp") then
				vim.lsp.enable("cssls")
			end

			if executable("vscode-html-language-server") or mason_installed("html-lsp") then
				vim.lsp.enable("html")
			end

			if executable("lua-language-server") or mason_installed("lua-language-server") then
				vim.lsp.enable("lua_ls")
			end

			-- typescript and javascript
			if executable("vtsls") or mason_installed("vtsls") then
				vim.lsp.enable("vtsls")
			end

			-- toml
			if executable("taplo") or mason_installed("taplo") then
				vim.lsp.enable("taplo")
			end

			local version = vim.version()
			local vim_version =
				assert(vim.version.parse(table.concat({ version.major, version.minor, version.patch }, ".")))

			local wk = require("which-key")

			if vim.version.range("<=0.9"):has(vim_version) then
				wk.add({
					{ "<C-W>d", vim.diagnostic.open_float, desc = "open floating window of diagnostics" },
					{ "<C-W><C-d>", vim.diagnostic.open_float, desc = "open floating window of diagnostics" },
					{ "[d", vim.diagnostic.goto_prev, desc = "goto previous diagnostic" },
					{ "]d", vim.diagnostic.goto_next, desc = "goto next diagnostic" },
				})
			end
			wk.add({
				{ "<leader>q", vim.diagnostic.setloclist, desc = "no idea" },
			})
			-- Use LspAttach autocommand to only map the following keys after the
			-- language server attaches to the current buffer
			local lsp_group = vim.api.nvim_create_augroup("UserLspConfig", {})
			vim.api.nvim_create_autocmd("LspAttach", {
				group = lsp_group,
				callback = function(ev)
					-- Enable completion triggered by <c-x><c-o>
					vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

					-- Buffer local mappings.
					-- See `:help vim.lsp.*` for documentation on any of the below functions
					if vim.version.range("<=0.9"):has(vim_version) then
						wk.add({ "K", vim.lsp.buf.hover, desc = "open hover", buffer = ev.buf })
					end
					wk.add(vim.iter({
						{ "gD", vim.lsp.buf.declaration, desc = "goto declaration" },
						{ "gd", vim.lsp.buf.definition, desc = "goto definition" },
						{ "<leader>gi", vim.lsp.buf.implementation, desc = "goto implementation" },
						{ "<C-k>", vim.lsp.buf.signature_help, desc = "signature_help()" },
						{ "<leader>w", group = "workspace" },
						-- conform.nvim will handle formatting, falling back to the lsp
						-- optionally
						-- {"<leader>wf", function() vim.lsp.bug.format{async=true} end,desc= "lsp format"},
						{ "<leader>wa", vim.lsp.buf.add_workspace_folder, desc = "add folder" },
						{ "<leader>wr", vim.lsp.buf.remove_workspace_folder, desc = "remove folder" },
						{
							"<leader>wl",
							function()
								vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()), vim.log.levels.INFO, {})
							end,
							desc = "list folders",
						},
						{ "<leader>D", vim.lsp.buf.type_definition, desc = "goto type definition" },
						{ "<leader>rn", vim.lsp.buf.rename, desc = "rename buffer" },
						{ "gr", vim.lsp.buf.references, desc = "goto references" },
					})
						:map(function(t)
							return vim.tbl_extend("keep", t, { buffer = ev.buf })
						end)
						:totable())
					wk.add({
						{
							"<leader>ca",
							vim.lsp.buf.code_action,
							desc = "code action (CTRL-P in VSCode)",
							buffer = ev.buf,
							mode = { "n", "v" },
						},
					})
				end,
			})
		end,
	},
	{
		"olrtg/nvim-emmet",
		keys = {
			{
				"<leader>xe",
				function()
					if executable("emmet-language-server") then
						require("nvim-emmet").wrap_with_abbreviation()
					else
						vim.notify("please install emmet-language-server using :Mason", vim.log.levels.WARN)
					end
				end,
				mode = { "n", "v" },
				ft = { "html", "css", "javascript" },
				desc = "expand emmet abbreviation",
			},
		},
	},
	-- from:
	-- https://github.com/folke/lazydev.nvim/blob/d5800897d9180cea800023f2429bce0a94ed6064/README.md?plain=1#L39
	{
		"folke/lazydev.nvim",
		dependencies = { "Bilal2453/luvit-meta", --[["neovim/nvim-lspconfig"]] },
		ft = "lua", -- only load on lua files
		opts = {
			library = {
				-- See the configuration section for more details
				-- Load luvit types when the `vim.uv` word is found
				{ path = "luvit-meta/library", words = { "vim%.uv" } },
			},
		},
	},
	{ "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
}
