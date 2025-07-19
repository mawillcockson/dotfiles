-- DONE: make the condition based off how nvim-treesitter itself searches to
-- see if a C compiler is installed, and only enable it when one is.
-- Based off of nvim-treesitter install process:
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/v0.9.2/lua/nvim-treesitter/install.lua#L19
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/v0.9.2/lua/nvim-treesitter/shell_command_selectors.lua#L74-L80

local filename = select(1, ...)
if filename == nil or filename == "" then
	filename = "plugins/treesitter.lua"
end

local default_compilers = { vim.fn.getenv("CC"), "cc", "gcc", "clang", "cl", "zig" }

---@return bool|nil
local has_compiler = vim.tbl_filter(function(c) ---@param c string
	return c ~= vim.NIL and vim.fn.executable(c) == 1
end, default_compilers)[1]

local has_tree_sitter = vim.fn.executable("tree-sitter") == 1

vim.notify(
	"has_compiler -> " .. tostring(has_compiler) .. "\n" .. "has tree-sitter -> " .. tostring(has_tree_sitter),
	vim.log.levels.DEBUG,
	{}
)
vim.notify("$PATH -> " .. os.getenv("PATH"), vim.log.levels.DEBUG)

local enable = has_compiler and has_tree_sitter
if not enable then
	vim.notify("disabling tree-sitter since compiler and tree-sitter-cli aren't both present", vim.log.levels.WARN)
end

-- NOTE: so far, the MSVC compiler hasn't been working, while the zig compiler
-- has. It'd be nice to get a warning that the MSVC compiler was having issues.
-- Also, the MSVC compiler has to be started in an environment when
-- vcvarsall.bat having been run, and that's annoying to remember to do, just
-- to start up nvim. The zig compiler can be easily installed through scoop, as
-- can tree-sitter-cli.
-- Also, the lua parser has some errors, so has to be :TSInstall-ed, forcing a re-install. Additionally, this can be used to install parsers at a later time:
-- :lua for _,k in ipairs{"python", "markdown", "javascript"} do vim.cmd(":TSInstall "..k) end
return {
	{
		"nvim-treesitter/nvim-treesitter",
		enabled = enable,
		lazy = false,
		branch = "main",
		-- This probably needs to track main, as releases are rarely cut
		version = false,
		-- When a new version of the plugin is released, rebuild the included parsers:
		-- https://github.com/nvim-treesitter/nvim-treesitter/wiki/Installation#lazynvim
		build = ":TSUpdateSync",
		dependencies = {
			-- additional parsers
		},
		cmd = { "TSInstallMine", "TSUpdateSync" },
		opts = {
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {},
				},
				move = { enable = true, set_jumps = true },
			},
		},
		config = function(_, opts)
			local ts = require("nvim-treesitter")
			ts.setup(opts)
			-- also load extension modules, and trigger any custom config functions,
			-- using pcall() so that the following user commands are created and
			-- tree-sitter can be updated, even if the plugins fail to load because
			-- tree-sitter is out of date
			pcall(require, "nvim-treesitter-textobjects")

			vim.api.nvim_create_user_command("TSUpdateSync", function()
				ts.update("all", { max_jobs = require("utils").calculate_nproc() }):wait(300000)
			end, {})

			vim.api.nvim_create_user_command("TSInstallMine", function()
				vim.notify("attempting to install the treesitter parsers I use", vim.log.levels.INFO)
				vim.notify("if one fails, comment it out in: " .. filename, vim.log.levels.INFO)
				ts.install({
					-- essentials
					"bash",
					"diff",
					"git_config",
					"git_rebase",
					"gitattributes",
					--"gitcommit", -- NOTE::FUTURE takes a long time
					"gitignore",
					"lua",
					"luadoc",
					"markdown",
					"markdown_inline",
					"nu",
					"powershell",
					"vim",
					"vimdoc",
					-- frequently used
					"css",
					"html",
					"javascript",
					"jsdoc",
					-- infrequent
					"caddy",
					"fennel",
					"janet_simple",
					"jq",
					"make",
					"mermaid",
					"python",
					"sql",
					-- data / config
					"csv",
					"ini",
					"json",
					"json5",
					"jsonc",
					"nginx",
					"ssh_config",
					"tmux",
					"toml",
					"tsv",
					"xml",
					"yaml",
					-- good to know about
					--[[
					"awk",
					"comment",
					"cpp",
					"dockerfile",
					"http",
					"rust",
					"scala",
					"scss",
					"tsx",
					"typescript",
					"zig",
          --]]
				}, { max_jobs = require("utils").calculate_nproc() }):wait(300000)
			end, {})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		lazy = true,
		branch = "main",
		version = false,
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
}
