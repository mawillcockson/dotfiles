return {
	-- [[~/projects/font-resize.nvim]],
	"mawillcockson/font-resize.nvim",
	branch = "main",
	version = false, -- use latest commit from the above branch
	-- Mark this plugin as one that won't be automatically loaded when Neovim
	-- launches. lazy.nvim also supports configuring loading on keybinds,
	-- filetype events, etc.
	lazy = true,
	-- (optional) Add a notification plugin as a dependency, for fancy font
	-- size update messages. This isn't required, and can be removed. The
	-- plugin must be able to be used as:
	--[[
    require("notify")("message", WARN, {opts = true})
  --]]
	-- That is, it must be installed and require-able with the name `notify`,
	-- and must provide a function that matches Neovim's builtin
	-- `vim.notify()` interface.
	dependencies = {
		{
			"rcarriga/nvim-notify",
			-- If the plugin is installed with a name other than `notify`,
			-- lazy.nvim can be configured to override that name with `notify`
			--[[
      as = "notify",
      --]]
			-- disable, but keep it here in case I do want to use it
			enabled = false,
			-- When this dependency is loaded, this will be passed to
			-- `require("font-resize").setup()`, and sets the background color of the
			-- notification popup window to the hex code for black. Change this if
			-- the background of your Neovim UI is not black.
			opts = {
				background_colour = "#000000",
			},
		},
	},
	-- The font-resize plugin provides a setup() function that it requires to be
	-- called before the plugin will start resizing the font. lazy.nvim makes
	-- available an opt= option for providing a table that will be provided to
	-- .setup() when it runs the function as part of loading the plugin when any
	-- of the specified conditions cause it to be loaded.
	opts = {
		-- If this is set to `true`, the setup() function will configure
		-- keybinds that match the ones listed below (if the code hasn't
		-- changed)
		use_default_mappings = true,
		-- The amount by which to increase and decrease the font size each
		-- time a keybind is pressed or a :FontSizeUp / :FontSizeDown command
		-- is called
		step_size = 1,
		-- Sets whether to print a message each time the font is resized or reset
		-- NOTE: it does not matter if rcarriga/nvim-notify is installed or not, this
		-- is a global flag to enable ANY notifications or not
		-- By default, this will enable notifications only if a plugin called
		-- `notify` is available
		-- Should be set to `true` or `false` if set at all
		notifications = true,
		-- The value to reset the font to in case something goes wrong, or
		-- the reset keybind or function is used.
		-- By default, this records the value of the `guifont` option when
		-- the plugin is first loaded.
		-- If set, this should be set to a valid value to pass to the
		-- set_font_function() (e.g. "Consolas:h12")
		--[[
      default_guifont = vim.o.guifont,
      --]]
		-- The function to use to change the font. Takes a single argument
		-- that's formatted for use with `:set guifont=...`
		-- This function should raise an error instead of failing silently,
		-- as internally the updated font size isn't saved when this function
		-- call fails, enabling recovery from e.g. a too-small font size by
		-- using the :FontSizeUp command or keybind
		--[[
      set_font_function = function(guifont)
        vim.api.nvim_set_option_value("guifont", guifont, {})
      end,
      --]]
		-- The hope is that this is lazy-loaded, and that neovim-qt has been
		-- detected by the time this is called.
		-- Either way, a guifont needs to be set before .setup() is called.
		-- This function must be defined here, or imported here. Function
		-- defined in config= cannot close over values.
		set_font_function = vim.g.neovim_qt
				and function(guifont)
					-- vim.cmd('silent! exe "GuiFont! '..font..'"')
					vim.rpcnotify(0, "Gui", "Font", guifont, true)
				end
			or nil,
	},
	-- The keybinds that lazy.nvim should watch, and load this plugin when
	-- one is pressed. These are the default keybinds that this plugin uses
	-- if `use_default_mappings` is set to `true`.
	keys = {
		-- As of August 2022, FVim and neovim-qt work with all the keybinds,
		-- and:
		---[[ Goneovim only works with these
		"<C-=>", -- increase
		"<C-->", -- increase
		"<C-0>", -- reset
		--]]
		---[[ Neovide only works with these
		"<C-ScrollWheelUp>", -- increase
		"<C-ScrollWheelDown>", -- decrease
		--]]
		-- The keybinds may work in the terminal, but this plugin should not be
		-- loaded in that case as the terminal should handle the font resizing,
		-- not Neovim's TUI
	},
}
