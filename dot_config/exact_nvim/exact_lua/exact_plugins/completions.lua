-- some parts taken from:
-- https://github.com/LazyVim/LazyVim/blob/704c29110d578186f0ca3eac67b753ddf52541fc/lua/lazyvim/plugins/coding.lua
return {
	{
		"hrsh7th/nvim-cmp",
		version = false, -- last release is way too old
		opts = function(_, opts)
			local cmp = require("cmp")
			-- from:
			-- https://github.com/folke/lazydev.nvim/blob/d5800897d9180cea800023f2429bce0a94ed6064/README.md?plain=1#L57
			opts.sources = opts.sources or {}
			vim.list_extend(opts.sources, {
				{
					name = "lazydev",
					group_index = 0, -- set group index to 0 to skip loading LuaLS completions
				},
				{ name = "nvim_lsp" },

				-- { name = 'vsnip' }, -- For vsnip users.
				{ name = "luasnip" }, -- For luasnip users.
				-- { name = 'ultisnips' }, -- For ultisnips users.
				-- { name = 'snippy' }, -- For snippy users.
				{ name = "buffer" },
			})
			opts.snippet = opts.snippet or {}
			-- from:
			-- https://github.com/hrsh7th/nvim-cmp/blob/f17d9b4394027ff4442b298398dfcaab97e40c4f/README.md?plain=1#L68
			opts.snippet.expand = function(args)
				require("luasnip").lsp_expand(args.body)
			end
			opts.window = opts.window or {}
			-- opts.window.completion = cmp.config.window.bordered()
			-- opts.window.documentation = cmp.config.window.bordered()
			opts.mapping = cmp.mapping.preset.insert({
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
				["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
				["<C-Space>"] = cmp.mapping.complete(),
				-- ["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
				["<C-3>"] = function(fallback)
					cmp.abort()
					fallback()
				end,
			})

			-- To use git you need to install the plugin petertriho/cmp-git and uncomment lines below
			-- Set configuration for specific filetype.
			--[[ cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'git' },
    }, {
      { name = 'buffer' },
    })
 })
 require("cmp_git").setup() ]]
			--

			-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
			cmp.setup.cmdline({ "/", "?" }, {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "buffer" },
				},
			})

			-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{ name = "cmdline" },
				}),
				matching = { disallow_symbol_nonprefix_matching = false },
			})
		end,
	},

	"hrsh7th/cmp-nvim-lsp",
	"hrsh7th/cmp-buffer",
	"hrsh7th/cmp-path",
	-- "hrsh7th/cmp-cmdline",
}
