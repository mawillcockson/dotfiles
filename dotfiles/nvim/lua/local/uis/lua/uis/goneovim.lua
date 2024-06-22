vim.notify("configuring for Goneovim", vim.log.levels.DEBUG, {})

local ok, fonts = pcall(require, "uis.fonts")
if not ok then
	vim.notify("error loading 'fonts': " .. tostring(fonts), vim.log.levels.ERROR, {})
	return
end

fonts.setup({
	font_size = 12,
	text_font = fonts.defaults.term_font,
})
fonts.opts.set_text_font()
