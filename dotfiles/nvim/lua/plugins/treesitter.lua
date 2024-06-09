-- DONE: make the condition based off how nvim-treesitter itself searches to
-- see if a C compiler is installed, and only enable it when one is.
-- Based off of nvim-tresitter instal process:
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/v0.9.2/lua/nvim-treesitter/install.lua#L19
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/v0.9.2/lua/nvim-treesitter/shell_command_selectors.lua#L74-L80

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

-- NOTE: so far, the MSVC compiler hasn't been working, while the zig compiler
-- has. It'd be nice to get a warning that the MSVC compiler was having issues.
-- Also, the MSVC compiler has to be started in an environment when
-- vcvarsall.bat having been run, and that's annoying to remember to do, just
-- to start up nvim. The zig compiler can be easily installed through scoop, as
-- can tree-sitter-cli.
-- Also, the lua parser has some errors, so has to be :TSInstall-ed, forcing a re-install. Additionally, this can be used to install parsers at a later time:
-- :lua for _,k in ipairs{"python", "markdown", "javascript"} do vim.cmd(":TSInstall "..k) end
return {
	"nvim-treesitter/nvim-treesitter",
	enabled = has_compiler and has_tree_sitter,
	version = "*",
	build = ":TSUpdateSync",
	config = function()
		local configs = require("nvim-treesitter.configs")

		configs.setup({
			ensure_installed = {
				-- NOTE: need better automatic installation
				-- NOTE: commented out languages have either broken parsers, or don't
				-- have automatically included parsers:
				-- https://github.com/nvim-treesitter/nvim-treesitter/tree/v0.9.2#adding-parsers

				--"python", --"markdown", "javascript", "clojure", "html", "css", "scss",
				--[==[
          -- commonly used
          --[["lua",]] "python", "markdown",
          -- less common
          "toml", "html", "css", "bash", --[["powershell",]]
          -- uncommon/hopeful
          "javascript", "scss", "rust", "clojure", --[["csharp",]] "haskell",
          --]==]
			},
			sync_install = true,
			highlight = { enable = true },
			indent = { enable = true },
		})
	end,
	dependencies = {
		-- additional parsers
		{ "nushell/tree-sitter-nu" },
	},
}
