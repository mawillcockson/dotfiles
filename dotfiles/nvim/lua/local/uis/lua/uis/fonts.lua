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

--[[ Users of this module want to be able to
-- set default font size
-- set default term font
-- set default text font
-- set change_fonts
-- call setup_font_changing()
-- call set_text_font()
-- redefine set_term_font and set_text_font
-- reset fonts_autocmds_group_name
-- use set_term_font and set_text_font as autocommand event callbacks
--]]

local set_text_font
local set_term_font

local defaults = {
	font_size = 11,
	text_font = "ComicCode Nerd Font",
	term_font = "DejaVuSansM Nerd Font",
	font_changing_enabled = true,
	fonts_autocmds_group_name = "fonts_autocmds",
	term_pattern = "term://*//*:*",
  set_text_font = set_text_font,
  set_term_font = set_term_font,
}

function M.setup(opts)
	M.opts = vim.tbl_extend("force", defaults, opts or {})
	M.configure_font_changing(M.opts)
end

local set_text_font = function(name, size)
	local font_name = type(name) == "string" and name or M.opts.text_font
	local font_size = type(size) == "number" and size or M.opts.font_size
	local font = font_name .. ":h" .. tostring(font_size)
	vim.notify("setting font to: " .. font, vim.log.levels.INFO, {})
	-- NOTE: should consider using:
	-- pcall(function() vim.rpcnotify(1, "Gui", "Font", font) end)
	local ok, err = pcall(function()
		vim.opt.guifont = font
	end)
	if not ok then
		vim.notify("problem changing text font: " .. tostring(err), vim.log.levels.WARN)
	end
end

M.set_text_font = set_text_font

local set_term_font = function(name, size)
	local font_name = type(name) == "string" and name or M.opts.term_font
	local font_size = type(size) == "number" and size or M.opts.font_size
	local font = font_name .. ":h" .. tostring(font_size)
	vim.notify("setting font to: " .. font, vim.log.levels.DEBUG, {})
	local ok, err = pcall(function()
		vim.opt.guifont = font
	end)
	if not ok then
		vim.notify("problem changing text font: " .. tostring(err), vim.log.levels.WARN)
	end
end

M.set_term_font = set_term_font

function M.configure_font_changing(opts)
	local opts = vim.tbl_extend("force", defaults, opts or M.opts)

	vim.api.nvim_create_augroup(opts.fonts_autocmds_group_name, { clear = true })

	if type(opts.font_changing_enabled) == "nil" then
		opts.font_changing_enabled = true
	end

	if not opts.font_changing_enabled then
		return
	end

	if opts.text_font == opts.term_font then
		vim.notify("text and term fonts are the same, not setting up font switching", vim.log.levels.INFO)
		return
	end

	vim.notify("setting up terminal / text font switching", vim.log.levels.DEBUG, {})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = opts.fonts_autocmds_group_name,
		pattern = opts.term_pattern,
		callback = function(_)
			opts.set_term_font()
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = opts.fonts_autocmds_group_name,
		pattern = opts.term_pattern,
		callback = function(_)
			opts.set_text_font()
		end,
	})
end

return M
