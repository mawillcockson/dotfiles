print("setting keymaps")
local vim_opt = vim.opt
local vim_o = vim.o
local vim_g = vim.g
local vim_v = vim.v
local map = vim.keymap.set
local searchcount = vim.fn.searchcount
local line = vim.fn.line
local nvim_command = vim.api.nvim_command
-- What is the internal representation of the <C-e> sequence?
local c_e = vim.api.nvim_replace_termcodes("<C-e>", true, false, true)

-- NOTE::BUG mapping just the leader to something, and then mapping something
-- to e.g. <Leader>a makes the original just-<Leader> mapping delay as it waits
-- to see if just <Leader> was intended, or if another key is about to be
-- pressed. (:help map-ambiguous)
-- Is there a way to set this timeout to zero, and rely on being able to press
-- and hold <Leader> key sequences? Would that make multi-key sequences like
-- <Leader>ab require holding <Leader>, then a, and while still holding down
-- both, pressing b? Or would it work more like Windows numpad keycombos of
-- pressing and holding Alt, then typing in a code on the keypad without having
-- to hold any of the number keys down, finished by releasing Alt.
-- Holding the <Leader> is the same as holding any other key: the action is
-- repeated. So if it's mapped to anything, holding isn't an option.
--
-- This repository might have some hints on how to work around this delay:
-- https://github.com/max397574/better-escape.nvim

-- <Space> as <Leader>
vim_g.mapleader = " "
vim_g.maplocalleader = " "
-- <Space> isn't technically mapped, so unmapping does nothing (:help <Space>)
--pcall(unmap, {"n", "v", "i"}, " ")
-- Best we can do is map it to a no-op
map("n", "<Space>", "<Nop>")
map("n", "<BS>", "<Nop>")
map("i", "<C-^>", "<C-[><C-^>", {
	desc = "also enable switching to alternate files in insert mode"
		.. " (this does overwrite a default mapping, but I never use it)",
})
map("t", "<C-v>", function()
	vim.api.nvim_put({ vim.fn.getreg("+") }, "", true, true)
end, { desc = "enable easy pasting in terminals" })
map("n", "<Leader>h", function()
	-- from:
	-- https://www.reddit.com/r/neovim/comments/wrj7eu/comment/ikswlfo/?utm_source=share&utm_medium=web2x&context=3
	local num_matches = searchcount({ recompute = false }).total or 0
	if num_matches < 1 then
		vim.notify("nothing to highlight", vim.log.levels.WARN, {})
		return
	end
	vim_opt.hlsearch = not vim_o.hlsearch
end, {
	desc = "toggles highlighting of search results in Normal mode",
})
map("n", "<Leader>s", "<Cmd>set spell!<CR>", { desc = "toggle spellchecking underlines" })
map("n", "j", function()
	-- what count was given with j? defaults to 1 (e.g. 10j to move 10 lines
	-- down, j the same as 1j)
	local count1 = vim_v.count1
	-- how far from the end of the file is the current cursor position?
	local distance = line("$") - line(".")
	-- if the number of times j should be pressed is greater than the number of
	-- lines until the bottom of the file
	if count1 > distance then
		-- if the cursor isn't on the last line already
		if distance > 0 then
			-- press j to get to the bottom of the file
			-- NOTE: Is there a way to call :normal! besides this?
			nvim_command("normal! " .. distance .. "j")
		end
		-- then press Ctrl+E for the rest of the count
		nvim_command("normal! " .. (count1 - distance) .. c_e)
	-- if the count is smaller and the cursor isn't on the last line
	elseif distance > 0 then
		-- press j as much as requested
		nvim_command("normal! " .. count1 .. "j")
	else
		-- otherwise press Ctrl+E the requested number of times
		nvim_command("normal! " .. count1 .. c_e)
	end
end, {
	desc = "continue scrolling past end of file with j",
})
map("t", "<C-^>", [[<C-\><C-n><C-^>]], {
	desc = "when in Terminal input mode, pressing Ctrl+Shift+6 will go "
		.. "to Terminal-Normal mode, then switch to the alternate buffer",
})
map("n", "<C-y>", "<Cmd>%y+<CR>", {
	desc = "copy whole file",
})
map({ "n", "i", "t" }, "<C-l>", "<Cmd>:tabnext<CR>", {
	desc = "switch tab rightwards",
})
map({ "n", "i", "t" }, "<C-h>", "<Cmd>:tabprevious<CR>", {
	desc = "switch tab leftwards",
})

--[[ another lesson in overdoing it
local keymaps = {
  {
    "n",
    "<Leader>h",
    function()
      -- from:
-- https://www.reddit.com/r/neovim/comments/wrj7eu/comment/ikswlfo/?utm_source=share&utm_medium=web2x&context=3
      local num_matches = searchcount{recompute = false}.total or 0
      if num_matches < 1 then
        vim.notify("nothing to highlight", vim.log.levels.WARN, {})
        return
      end
      vim_opt.hlsearch = not vim_o.hlsearch
    end,
    {
      desc = "toggles highlighting of search results in Normal mode",
    },
  },
}

for i, keymap in pairs(keymaps) do
  local ok, msg = pcall(assert, #keymap == 3 or #keymap == 4, "keymaps are mode, keycombo, function, [opts]")
  if not ok then
    print("error with keymap "..tostring(i)..": "..tostring(msg))
  else
    -- makes the file re-runnable
    -- NOTE: overwriting keymaps works fine, is this necessary?
    pcall(unmap, keymap[1], keymap[2])
    if #keymap == 3 then
      map(keymap[1], keymap[2], keymap[3])
    else
      map(keymap[1], keymap[2], keymap[3], keymap[4])
    end
  end
end
--]]
