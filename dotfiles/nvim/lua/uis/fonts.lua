vim.notify("ran fonts", vim.log.levels.DEBUG, {})
--[[ Set font in various environments
-- https://github.com/equalsraf/neovim-qt/issues/213#issuecomment-266204953
-- https://stackoverflow.com/questions/35285300/how-to-change-neovim-font/51424640#51424640
-- https://www.reddit.com/r/neovim/comments/9n7sja/liga_source_code_pro_is_not_a_fixed_pitch_font/

It would be cool to have one font in the text files and a different font in the
terminal sessions, but I don't think this is easily feasible, and my chosen
font of ComicCode for text files doesn't seem to work well on Windows, and
doesn't look good in the default GUI front-end of neovim-qt.

I did it anyways.
--]]
local M = {}

M.default_font_size = default_font_size or 11
M.default_text_font = default_text_font or "ComicCode NF"
M.default_term_font = default_term_font or "DejaVuSansM Nerd Font"
if type(change_fonts) == "boolean" then
  M.change_fonts = change_fonts
else
  M.change_fonts = true
end

function M.set_text_font(name, size)
  local font_name = type(name) == string and name or M.default_text_font
  local font_size = type(size) == "number" and size or M.default_font_size
  local font = font_name..":h"..tostring(font_size)
  print("setting font to: "..font)
  -- NOTE: should consider using:
  -- pcall(function() vim.rpcnotify(1, "Gui", "Font", font) end)
  pcall(function() vim.opt.guifont = font end)
end

function M.set_term_font(size)
  local font_name = type(name) == string and name or M.default_term_font
  local font_size = type(size) == "number" and size or M.default_font_size
  local font = font_name..":h"..tostring(font_size)
  print("setting font to: "..font)
  pcall(function() vim.opt.guifont = font end)
end

M.fonts_autocmds_group_name = "fonts_autocmds"
M.term_pattern = "term://*//*:*"

function M.setup_font_changing()
  if not M.change_fonts then return end

  vim.api.nvim_create_augroup(M.fonts_autocmds_group_name, { clear = true })

  if M.default_text_font ~= M.default_term_font then
    -- only change the fonts if they're different
    print "setting up terminal / text font switching"
    vim.api.nvim_create_autocmd("BufEnter",
      {
        group = M.fonts_autocmds_group_name,
        pattern = M.term_pattern,
        callback = M.set_term_font,
    })

    vim.api.nvim_create_autocmd("BufLeave",
      {
        group = M.fonts_autocmds_group_name,
        pattern = M.term_pattern,
        callback = M.set_text_font,
    })
  end
end

return M
