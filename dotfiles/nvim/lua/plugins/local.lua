local join_path = require("utils").join_path
local local_dir = join_path(vim.fn.stdpath("config"), "lua", "local")

local load_order = {}
local load_priority = 500
local function load_order_add(name)
	if not load_order[name] then
		load_order[name] = load_priority
		load_priority = load_priority - 1
	end
	return load_order[name]
end

local local_empty = join_path(local_dir, "empty")

return {
	{
		name = "keymaps",
		dir = local_empty,
		enabled = false,
		lazy = false,
		priority = load_order_add("keymaps"),
		config = function(_, _)
			-- handled in which-key.lua plugin spec
		end,
	},
	{
		name = "commands",
		dir = local_empty,
		lazy = true,
		event = "VeryLazy",
		priority = load_order_add("commands"),
		config = function(_, _)
			vim.notify("creating user commands", vim.log.levels.DEBUG, {})
			-- I feel that a wrapper for this function is justified since the error
			-- messages so far only mention the type, and nothing else to give context
			-- except a file and line number
			local def = vim.api.nvim_create_user_command
			def("W", "w", {})
			def("Q", "q", {})
			def("Wq", "wq", {})
			def("WQ", "wq", {})
			if vim.fn.has("win32") then
				def("StartSsh", function(_)
					--vim.api.nvim_command"cd ~"
					vim.api.nvim_command([[!nu -c "use start-ssh.nu ; start-ssh"]])
					--vim.api.nvim_command"cd-"
				end, {
					desc = "Calls the nu profile-defined start-ssh",
				})
			end

			--[[ A lesson in overdoing it:
-- This used to be much more complicated.
-- The error messages were interpretable, but the error messages generated by
-- calling the function directly point to the exact line and file already, and
-- those hopefully give enough context.
local commands = {
  {"W", "w"},
  {"Q", "q"},
  {"Wq", "wq"},
  {1, 'echom "hello!"'},
  {"WQ", "wq"},
}

for i, tbl in ipairs(commands) do
  local i = "command #"..tostring(i)
  assert(
    #tbl == 2 or #tbl == 3,
    i.." is not a table of two or three elements elements"
  )

  local name = tbl[1]
  local command = tbl[2]
  local opts = tbl[3] or {}

  assert(
    type(name) == "string",
    i..": first element must be a string"
  )
  assert(
    type(command) == "string" or type(command) == "function",
    i..": second element must be a string or function"
  )
  assert(
    type(opts) == "table",
    i..": third (optional) element must be a table"
  )

  def(name, command, opts)
end
--]]
		end,
	},
	{
		name = "autocommands",
		dir = local_empty,
		lazy = true,
		event = "VeryLazy",
		priority = load_order_add("autocommands"),
		config = function(_, _)
			vim.notify("ran autocommands", vim.log.levels.DEBUG, {})

			local custom_autocmds_group_name = "custom_autocmds"
			vim.api.nvim_create_augroup(custom_autocmds_group_name, { clear = true })
			-- inspired by:
			-- https://luabyexample.org/docs/nvim-autocmd/
			-- https://www.reddit.com/r/neovim/comments/t7k5k1/comment/hziccvb/?utm_source=share&utm_medium=web2x&context=3
			local autocmds = {
				TermOpen = {
					{
						pattern = "term://*//*:*",
						command = "setfiletype terminal | redraw | startinsert",
					},
				},
				FileType = {
					-- it's preferred to place files named after the filetype in nvim/ftplugin,
					-- at the same folder depth as init.lua
					-- This is mainly a convenience for setting common options on a lot of
					-- filetypes at once
					{
						pattern = { "text", "markdown", "gitcommit" },
						callback = function()
							vim.opt_local.spell = true
							vim.opt_local.spelllang = "en_us"
						end,
					},
				},
			}

			for event_name, opts in pairs(autocmds) do
				for _, opt in pairs(opts) do
					opt.group = custom_autocmds_group_name
					vim.api.nvim_create_autocmd(event_name, opt)
				end
			end
		end,
	},
	{
		dir = join_path(local_dir, "uis"),
		lazy = false,
		priority = load_order_add("uis"),
		config = true,
	},
}