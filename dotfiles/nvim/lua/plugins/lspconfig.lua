return {
	-- https://github.com/neovim/nvim-lspconfig?tab=readme-ov-file#suggested-configuration
	"neovim/nvim-lspconfig",
	-- lazy = true,
	config = function(name, opts)
		local lspconfig = require("lspconfig")
		-- not needed, as there's nothing in the base project to configure
		-- lspconfig.config(name, opts)
		lspconfig.ruff_lsp.setup{
      init_options = {
        settings = {
          -- And extra CLI arguments for ruff
          args = {},
        },
      },
    }

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
				-- vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
				-- vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
				-- vim.keymap.set('n', '<leader>wl', function()
				--   print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				-- end, opts)
				vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
				vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
				vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
				vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
				-- conform.nvim will handle formatting, falling back to the lsp
				-- optionally
				-- vim.keymap.set('n', '<leader>f', function()
				--   vim.lsp.buf.format { async = true }
				-- end, opts)
			end,
		})
	end,
}
