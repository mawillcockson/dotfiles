local function load_in_correct_order()
end

return {
	{
		"williamboman/mason.nvim",
		version = "*",
		lazy = true,
		priority = 100, -- https://github.com/williamboman/mason-lspconfig.nvim/tree/v1.27.0#setup
		config = true,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		version = "*",
		lazy = true,
		priority = 99, -- https://github.com/williamboman/mason-lspconfig.nvim/tree/v1.27.0#setup
		config = true,
	},
	{
		-- https://github.com/neovim/nvim-lspconfig?tab=readme-ov-file#suggested-configuration
		"neovim/nvim-lspconfig",
		lazy = true,
		priority = 98, -- https://github.com/williamboman/mason-lspconfig.nvim/tree/v1.27.0#setup
		dependencies = {
			-- for lua_ls, so it has access to all the builtins of love2d
			"LuaCATS/love2d",
		},
		config = function(name, opts)
			-- NOTE::DIRECTION
			-- I would like for this to autoconfigure available clients on an as-needed basis.
			-- I would also like for no LSPs to be configured or started unless a
			-- command or key-combination (if the latter, preferably with a prompt)
			-- is entered.
			-- I think it's also a good idea to do the same when configuring the
			-- completion plugin: by default, it's inactive, and only when a
			-- key-combination is pressed, or a command is run, is it activated.
			local lspconfig = require("lspconfig")
			-- not needed, as there's nothing in the base project to configure
			-- lspconfig.config(name, opts)
			lspconfig.ruff_lsp.setup({
				init_options = {
					settings = {
						-- And extra CLI arguments for ruff
						args = {},
					},
				},
			})

			lspconfig.lua_ls.setup({
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

			lspconfig.nushell.setup({})

			vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
			vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)
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
					local opts = { buffer = ev.buf }
					vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
					vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
					vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
					-- vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
					vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
					vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts)
					vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts)
					vim.keymap.set("n", "<leader>wl", function()
						print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
					end, opts)
					vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
					vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
					vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
					vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
					-- conform.nvim will handle formatting, falling back to the lsp
					-- optionally
					-- vim.keymap.set('n', '<leader>f', function()
					--   vim.lsp.buf.format { async = true }
					-- end, opts)
				end,
			})
		end,
	},
}
