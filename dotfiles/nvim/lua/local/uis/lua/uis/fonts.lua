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

function M.setup(opts)
	M.default_font_size = opts.default_font_size or 11
	M.default_text_font = opts.default_text_font or "ComicCode Nerd Font"
	M.default_term_font = opts.default_term_font or "DejaVuSansM Nerd Font"
	if type(opts.change_fonts) == "boolean" then
		M.change_fonts = opts.change_fonts
	else
		M.change_fonts = true
	end

	M.fonts_autocmds_group_name = "fonts_autocmds"
	M.term_pattern = "term://*//*:*"

	return M
end

function M.set_text_font(name, size)
	local font_name = type(name) == "string" and name or M.default_text_font
	local font_size = type(size) == "number" and size or M.default_font_size
	local font = font_name .. ":h" .. tostring(font_size)
	vim.notify("setting font to: " .. font, vim.log.levels.INFO, {})
	-- NOTE: should consider using:
	-- pcall(function() vim.rpcnotify(1, "Gui", "Font", font) end)
	pcall(function()
		vim.opt.guifont = font
	end)
end

function M.set_term_font(name, size)
	local font_name = type(name) == "string" and name or M.default_term_font
	local font_size = type(size) == "number" and size or M.default_font_size
	local font = font_name .. ":h" .. tostring(font_size)
	vim.notify("setting font to: " .. font, vim.log.levels.DEBUG, {})
	pcall(function()
		vim.opt.guifont = font
	end)
end

function M.configure_font_changing(opts)
	vim.api.nvim_create_augroup(M.fonts_autocmds_group_name, { clear = true })

	if type(opts.enabled) == "nil" then
		opts.enabled = true
	end

	if not opts.enabled then
		return
	end

	if M.default_text_font == M.default_term_font then
		vim.notify("text and term fonts are the same, not setting up font switching", vim.log.levels.INFO)
		return
	end

	vim.notify("setting up terminal / text font switching", vim.log.levels.DEBUG, {})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = M.fonts_autocmds_group_name,
		pattern = M.term_pattern,
		callback = function(_)
			if type(opts.set_term_font) == "function" then
				opts.set_term_font()
			else
				M.set_term_font()
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = M.fonts_autocmds_group_name,
		pattern = M.term_pattern,
		callback = function(_)
			if type(opts.set_text_font) == "function" then
				opts.set_text_font()
			else
				M.set_text_font()
			end
		end,
	})
end

return M
