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
			require("lspconfig").lua_ls.setup({
				on_init = function(client)
					local is_nvim = false
					for _, workspace_folder in ipairs(client.workspace_folders) do
						if workspace_folder.name:find("dotfiles/nvim", 1, true) then
							is_nvim = true
							break
						end
					end
					if not is_nvim then
						return
					end

					-- https://github.com/neovim/nvim-lspconfig/blob/6e5c78ebc9936ca74add66bda22c566f951b6ee5/doc/server_configurations.md?plain=1#L6275-L6300
					client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
						-- I can disable various features only when editing nvim-related
						-- files, if I need to
						runtime = {
							version = "LuaJIT",
						},
						workspace = {
							checkThirdParty = false,
							library = {
								vim.env.VIMRUNTIME,
							},
							-- or pull in all of 'runtimepath'. NOTE: this is a lot slower
							-- library = vim.api.nvim_get_runtime_file("", true),
						},
					})
				end,
				settings = {
					Lua = {
						workspace = {
							-- I'd love for this to use the `userThirdParty` key, but it doesn't seem to work
							library = { vim.fn.stdpath("data") .. "/lazy/love2d" },
						},
					},
				},
			})
		end,
	})
	require("lspconfig")
	require("nvim-emmet")
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

			local executable = vim.fn.executable

			if executable("ruff-lsp") then
				lspconfig.ruff_lsp.setup({
					init_options = {
						settings = {
							-- And extra CLI arguments for ruff
							args = {},
						},
					},
				})
			end

			if executable("nu") then
				lspconfig.nushell.setup({})
			end

			if executable("zls") and executable("zig") then
				lspconfig.zls.setup({ root_dir = require("lspconfig.util").root_pattern("zls.json", "build.zig") })
			end

			if executable("emmet-language-server") then
				lspconfig.emmet_language_server.setup({})
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
		config = function()
			local els = require("mason-registry").get_package("emmet-language-server")
			if not els:is_installed() then
        vim.notify("installing emmet-language-server", vim.log.levels.INFO)
				els:install()
			end
		end,
		keys = {
			{
				"<leader>xe",
				function()
					require("nvim-emmet").wrap_with_abbreviation()
				end,
				mode = { "n", "v" },
				ft = { "html", "css", "javascript" },
				desc = "expand emmet abbreviation",
			},
		},
	},
}
