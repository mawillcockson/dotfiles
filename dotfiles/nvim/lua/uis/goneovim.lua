vim.notify("configuring for Goneovim", vim.log.levels.DEBUG, {})

local ok, fonts = pcall(require, "uis.fonts")
if not ok then
  print("error loading 'fonts': "..tostring(fonts))
  return
end

fonts.default_font_size = 12
fonts.default_text_font = fonts.default_term_font
fonts.set_text_font()
