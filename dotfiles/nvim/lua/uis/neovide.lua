vim.notify("ran neovide", vim.log.levels.DEBUG, {})
-- https://github.com/neovide/neovide/wiki/Configuration
vim.g.neovide_refresh_rate = 60
vim.g.neovide_refresh_rate_idle = 5
vim.g.neovide_cursor_animation_length = 0
-- vim.g.neovide_scroll_animation_far_lines = 0
vim.g.neovide_input_use_logo = true
vim.g.neovide_theme = "auto"
vim.g.neovide_hide_mouse_when_typing = true
vim.g.neovide_remember_window_size = true
-- Enable 24-bit RGB color in the TUI
vim.opt.termguicolors = true

local ok, fonts = pcall(require, "uis.fonts")
if not ok then
  print("error loading 'fonts': "..tostring(fonts))
  return
end

fonts.default_font_size = 12
fonts.set_text_font()
