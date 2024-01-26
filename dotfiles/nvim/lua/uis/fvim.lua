vim.notify("configuring for FVim", vim.log.levels.DEBUG, {})

local ok, fonts = pcall(require, "uis.fonts")
if not ok then
  print("error loading 'fonts': "..tostring(fonts))
  return
end

-- from https://github.com/yatli/fvim/blob/b836b56bd0a0a16cf0921afcb468269b3648603b/README.md?plain=1#L57-L71
-- Using non-NF ComicCode really messes with FVim (2022-07-29)
if vim.g.fvim_os == "windows" or vim.g.fvim_render_scale > 1.0 then
  fonts.default_font_size = 14
else
  fonts.default_font_size = 18
end

-- Font tweaks
vim.cmd[[
  FVimFontAntialias v:true
  FVimFontAutohint v:true
  FVimFontHintLevel 'full'
  FVimFontLigature v:false
]]
-- can be 'default', '14.0', '-1.0' etc.
vim.cmd[[FVimFontLineHeight '+7.5']]
vim.cmd[[FVimFontSubpixel v:true]]
-- Disable built-in Nerd font symbols
vim.cmd[[FVimFontNoBuiltinSymbols v:true]]

-- Try to snap the fonts to the pixels, reduces blur in some situations (e.g.
-- 100% DPI).
vim.cmd[[FVimFontAutoSnap v:true]]

-- Font weight tuning, possible valuaes are 100..900
vim.cmd[[
  FVimFontNormalWeight 100
  FVimFontBoldWeight 700
]]

-- Font debugging -- draw bounds around each glyph
--vim.cmd[[FVimFontDrawBounds v:true]]

fonts.set_text_font()

local fvim_autocmds_group_name = "fvim_autocmds"
vim.api.nvim_create_augroup(fvim_autocmds_group_name, { clear = true })

vim.api.nvim_create_autocmd("UIEnter", {
  group = fvim_autocmds_group_name,
  pattern = "*",
  -- FVim screen doesn't show anything after loading; a call to :redraw gets
  -- the screen to show up
  command = "redraw",
  once = true,
})
