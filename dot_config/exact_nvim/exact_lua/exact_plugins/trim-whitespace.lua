return {
	"johnfrankmorgan/whitespace.nvim",
	lazy = true,
	config = true,
	keys = {
		{
			"<leader>rw",
			function()
				require("whitespace").trim()
			end,
			desc = "trim whitespace in the file",
		},
	},
}
