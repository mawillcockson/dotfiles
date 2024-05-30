vim.notify("configuring for neovim-qt", vim.log.levels.DEBUG, {})
-- neovim-qt has proven quite challenging to identify during startup:
-- - it doesn't define :GuiFont and such until after startup
-- - it doesn't give a name for itself in vim.api.nvim_list_chans() until after
--   startup
-- - https://github.com/equalsraf/neovim-qt/issues/219 links to other issues:
-- https://github.com/equalsraf/neovim-qt/issues/94
-- https://github.com/equalsraf/neovim-qt/issues/95
-- 
-- https://github.com/neovim/neovim/issues/3646
--
-- Possible solutions:
-- - NOTE::FUTURE wait for has("gui_running") to return something truthy
-- - Set an autocommand for:
-- - - ChanInfo
-- - - ChanOpen
--
-- Currently using autocmd

-- forward declaration since this function references itself
local update_for_neovim_qt
update_for_neovim_qt = function()
  vim.notify("unknown gui was probably neovim-qt, setting global", vim.log.levels.DEBUG, {})
  vim.g.neovim_qt = true

  local ok, fonts = pcall(require, "uis.fonts")
  if not ok then
    vim.notify("error loading 'fonts': "..tostring(fonts), vim.log.levels.DEBUG, {})
    return
  end

  -- redefine font-setting functions using the rpcnotify() calls used in the
  -- share/nvim-qt/runtime/plugin/nvim_gui_shim.vim
  fonts.set_term_font = function(_, size)
    local font_size = type(size) == "number" and size or fonts.default_font_size
    local guifont = fonts.default_term_font .. ":h"..tostring(font_size)
    pcall(vim.rpcnotify, 0, "Gui", "Font", guifont, true)
  end
  fonts.set_text_font = function(name, size)
    local font_name = type(name) == string and name or fonts.default_text_font
    local font_size = type(size) == "number" and size or fonts.default_font_size
    local guifont = font_name..":h"..tostring(font_size)
    pcall(vim.rpcnotify, 0, "Gui", "Font", guifont, true)
  end

  --[[ this should be set when the plugin is loaded, not here, otherwise the
  ---- plugin sees that guifont isn't set, and throws an error and picks a
  ---- potentially different default font
  local font_resize_ok, font_resize = pcall(require, "font-resize")
  if font_resize_ok then
    -- don't use pcall() here, font-resize.nvim expects this function to fail
    -- loudly
    font_resize.config.set_font_function = function(guifont)
      vim.rpcnotify(0, "Gui", "Font", guifont, true)
    end
  end
  --]]

  fonts.default_text_font = fonts.default_term_font

  vim.notify("clearing augroup: " .. fonts.fonts_autocmds_group_name, vim.log.levels.DEBUG, {})
  vim.api.nvim_create_augroup(fonts.fonts_autocmds_group_name, {clear = true})

  if fonts.default_term_font == fonts.default_text_font then
    vim.notify(
      "the term and text fonts are the same, "..
      "so no point in running autocmds to change between the two"
    , vim.log.levels.DEBUG, {})
    fonts.set_text_font()
    return
  end

  vim.notify("adding new BufEnter", vim.log.levels.DEBUG, {})
  vim.api.nvim_create_autocmd("BufEnter",
    {
      group = fonts.fonts_autocmds_group_name,
      pattern = fonts.term_pattern,
      callback = fonts.set_term_font,
  })

  vim.notify("adding new BufLeave", vim.log.levels.DEBUG, {})
  vim.api.nvim_create_autocmd("BufLeave",
    {
      group = fonts.fonts_autocmds_group_name,
      pattern = fonts.term_pattern,
      callback = fonts.set_text_font,
  })

  vim.notify("adding new ChanInfo", vim.log.levels.DEBUG, {})
  vim.api.nvim_create_autocmd("ChanInfo",
    {
      group = fonts.fonts_autocmds_group_name,
      pattern = "*",
      callback = update_for_neovim_qt,
  })

  vim.notify("setting text font to " .. fonts.default_text_font, vim.log.levels.DEBUG, {})
  fonts.set_text_font()
end

return update_for_neovim_qt
