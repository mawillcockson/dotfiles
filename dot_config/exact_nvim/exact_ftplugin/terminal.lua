if vim.b.did_my_ft_terminal then
	return
end
vim.b.did_my_ft_terminal = true

-- from:
-- https://github.com/tjdevries/config.nvim/blob/46eeb5887442f468adc20766290b9694c511165d/plugin/terminal.lua#L7-L9
local set = vim.opt_local

set.number = false
set.relativenumber = false
set.scrolloff = 0
local buffer = vim.api.nvim_get_current_buf()

-- NOTE::IMPROVEMENT this is kind of a kludgy way to do this
local wk = require("which-key")
wk.add({
	-- kick back to normal mode, to process further keypresses
	{
		"<C-b>",
		[[<C-\><C-n><C-b>]],
		desc = "first key in a tmux-like key sequence",
		remap = true,
		mode = { "t" },
		buffer = buffer,
		-- probably does nothing, but could be useful to ensure this always works
		-- as expected in the future: if sequence mappings are made to work in
		-- terminal mode, then <C-b> could cause it to hang for a second, to see if
		-- I'll continue, and not kick back to normal mode, where <C-b><C-b> is
		-- defined. I'll define another mapping for terminal mode, just in case
		nowait = true,
	},
	{
		"<C-b><C-b>",
		"<Cmd>normal! i<CR><C-b>",
		desc = "send <C-b> in terminal",
		-- this is the default, but I'm being explicit that, if this weren't here,
		-- the last <C-b> in the rhs would trigger an infinite loop with the <C-b>
		-- defined above
		remap = false,
		mode = { "n" },
		buffer = buffer,
	},
	{ "<C-b><C-b>", "<C-b>", desc = "send <C-b> in terminal", mode = { "t" }, buffer = buffer },
})
