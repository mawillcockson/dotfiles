local executable = vim.fn.executable

local function load_in_correct_order(_)
	require("mason")
	require("mason-lspconfig").setup_handlers({
		-- The first entry (without a key) will be the default handler
		-- and will be called for each installed server that doesn't have
		-- a dedicated handler.
		function(server_name) -- default handler (optional)
			require("lspconfig")[server_name].setup({})
		end,
		-- Next, you can provide a dedicated handler for specific servers.
		-- Only language servers that have been installed through mason.nvim can be
		-- configured here. All manually installed ones should be configured below:
		-- For instance, a handler override for the `lua_ls`:
		["lua_ls"] = function(_)
			-- this is being handled by lazydev.nvim
			require("lspconfig").lua_ls.setup({})
		end,
	})
	require("lspconfig")
	require("lazydev")
end

vim.api.nvim_create_user_command("DoLspConfig", load_in_correct_order, {
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
		opts = { max_concurrent_installers = require("utils").calculate_nproc() or vim.g.max_nproc_default or 1 },
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
		config = function(_, _)
			-- This section should only be used for configuring language servers that
			-- haven't been downloaded using mason. This should be configured above.

			-- NOTE::DIRECTION
			-- I would like for this to autoconfigure available clients on an as-needed basis.
			-- I would also like for no LSPs to be configured or started unless a
			-- command or key-combination (if the latter, preferably with a prompt)
			-- is entered.
			-- I think it's also a good idea to do the same when configuring the
			-- completion plugin: by default, it's inactive, and only when a
			-- key-combination is pressed, or a command is run, is it activated.
			-- I don't think each command would have to print out where it's located.
			-- Regipgrep helps with that.
			-- I do think the commands should detect if something's missing and point
			-- to where to enable or install it.
			-- Going through all the plugins that are loaded by default (`start` plugins, `lazy = false`) and finding out ways to make them only load when desired, would be nice.
			-- - Conjure (in clojure.lua) should only be loaded for fennel and clojure filetypes
			-- There should be a way to detect if the lsps are available, and then
			-- each one can be configured. I think breaking each out into its own
			-- file would be good.
			-- If they can be set to run their configuration right before they're
			-- needed, that would be perfect.
			-- Also, the ftplugins should each have a buffer-local variable to
			-- prevent editing the same file from overwriting any changes made to
			-- variables for that specific file
			local lspconfig = require("lspconfig")
			-- not needed, as there's nothing in the base project to configure
			-- lspconfig.config(name, opts)

			if executable("ruff") then
				lspconfig.ruff.setup({
					init_options = {
						settings = {},
					},
				})
			end

			if executable("nu") then
				lspconfig.nushell.setup({})
			end

			if executable("zls") and executable("zig") then
				lspconfig.zls.setup({ root_dir = require("lspconfig.util").root_pattern("zls.json", "build.zig") })
			end

			if
				executable("emmet-language-server") == 1
				or require("mason-registry").get_package("emmet-language-server"):is_installed()
			then
				lspconfig.emmet_language_server.setup({})
			end

			-- from:
			-- https://github.com/hrsh7th/nvim-cmp/blob/f17d9b4394027ff4442b298398dfcaab97e40c4f/README.md?plain=1#L126-L131
			local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			if ok then
				local capabilities = cmp_nvim_lsp.default_capabilities()
				for _, name in ipairs({ "ruff", "nu", "zls", "emmet-language-server", "lua_ls" }) do
					lspconfig[name].capabilities = capabilities
				end
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
						-- {"gi", vim.lsp.buf.implementation,desc= "goto implementation" },
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
		dependencies = {
			"williamboman/mason.nvim",
		},
		keys = {
			{
				"<leader>xe",
				function()
					if executable("emmet-language-server") == 1 then
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
		dependencies = { "Bilal2453/luvit-meta" },
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
