return {
	"mbbill/undotree",
	-- sometimes have to disable and re-enable to get it to actually pull new
	-- commits
	enabled = true,
	branch = "master",
	-- there are no plans to tag releases anymore:
	-- https://github.com/mbbill/undotree/issues/179#issuecomment-2019453136
	version = false,
	lazy = true,
	config = function(_, _)
		-- There's a few options for configuring the diff command that undotree uses
		-- 1) There's this variable:
		-- https://github.com/mbbill/undotree/blob/56c684a805fe948936cda0d1b19505b84ad7e065/plugin/undotree.vim#L132-L134
		--[[
    vim.g.undotree_DiffCommand = "git diff --no-index -- "
    --]]
		-- 2) Git for Windows also ships with a diff.exe executable, it just isn't in the path, by default.
		-- 3) Lastly, this project, which is available through scoop, ships a diff executable:
		-- https://github.com/bmatzelle/gow
		-- Option 2 seems the least obtrusive:
		if vim.fn.executable("diff") == 1 then
			-- it's already available
			return true
		end

		if vim.fn.has("win32") == 1 then
			require("utils").add_to_path("~/scoop/apps/git/current/usr/bin")
			assert(
				vim.fn.executable("diff") == 1,
				"'diff' not found where it was expected to be; try `fd -uig 'diff*' ~/scoop/apps/git/current/"
			)
		elseif vim.fn.executable("git") == 1 then
			vim.g.undotree_DiffCommand = "git diff --no-index -- "
		else
			error("cannot find 'diff' executable for mbbill/undotree")
		end
	end,
	keys = {
		{
			"<leader>u",
			-- "<cmd>UndoreeToggle<cr>",
			vim.cmd.UndotreeToggle,
			desc = "Undotree",
		},
	},
}
