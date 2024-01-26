print "ran uis"
--[[
This is called from init.lua and tries to figure out what environment this is
being run from, and calls the options specific to that environment.

Generally, the only options that should be included here are settings for a
specific environment, like enabling smooth scrolling and such.
--]]

-- This can be helpful
-- vim.pretty_print(vim.api.nvim_list_uis())

-- NOTE: has('gui_running') now works, and triggers based on which GUI is
-- connected may also work, now:
-- https://github.com/neovim/neovim/blob/040f1459849ab05b04f6bb1e77b3def16b4c2f2b/runtime/doc/news.txt#L214-L215

local function any(func, tbl)
  for _, i in pairs(tbl) do
    if func(i) then
      return true
    end
  end
  return false
end

local ok, fonts = pcall(require, "uis.fonts")
if not ok then
  print("error loading 'fonts': "..tostring(fonts))
  return
end

if vim.g.fvim_loaded then
  pcall(require, "uis.fvim")

elseif vim.g.neovide then
  pcall(require, "uis.neovide")

-- found here:
-- https://github.com/akiyosi/goneovim/issues/14#issuecomment-444482888
elseif vim.g.gonvim_running then
  pcall(require, "uis.goneovim")

elseif any(function(e) return e.chan == 1 end, vim.api.nvim_list_uis()) then
  -- Apparently text uis have a channel of 0, and guis have a chan of not 0
  print("unkown gui connected")

elseif vim.fn.has("ttyin") ~= 0 then
  -- if nvim was run in the terminal, the ttyin feature is supported. Also,
  -- this is likely only set in that scenario, since front-ends like neovim-qt
  -- may(?) start nvim in --headless mode and use the RPC protocol.
  
  -- changing fonts is pointless when the controling terminal sets everything
  fonts.change_fonts = false
  vim.o.termguicolors = true

else
  print("unknown editor environment")
  fonts.change_fonts = false
end

fonts.setup_font_changing()

local uis_autocmds_group_name = "uis_autocmds"
vim.api.nvim_create_augroup(uis_autocmds_group_name, { clear = true })

local function update_from_chan(_)
  -- I think this is passed a table describing the event:
  -- :help ChanInfo
  -- :help nvim_get_chan_info()
  -- But I don't use it, because neovim-qt populates its data in
  -- vim.api.nvim_list_chans() by this time
  for _, info in pairs(vim.api.nvim_list_chans()) do
    if type(info) ~= "table" then return end
    if type(info.client) == "table"
       and info.client.name == "nvim-qt"
    then
      local ok, neovim_qt = pcall(require, "uis.neovim_qt")
      if not ok then
        print("error loading neovim_qt: "..tostring(neovim_qt))
        return
      elseif type(neovim_qt) ~= "function" then
        print("expected neovim_qt to be a function, got '"..type(neovim_qt).."'")
        return
      end
      print "running neovim_qt"
      return pcall(neovim_qt)
    end
  end
end

vim.api.nvim_create_autocmd("ChanInfo",
  {
    group = uis_autocmds_group_name,
    pattern = "*",
    callback = update_from_chan,
    -- this means it won't be run if neovim-qt disconnects and reconnects, but
    -- I'm unlikely to do that
    once = true,
})
