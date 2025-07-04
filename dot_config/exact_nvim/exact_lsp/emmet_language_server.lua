return {
	cmd = { "emmet-language-server", "--stdi" },
	capabilities = require("utils").get_capabilities(),
	init_options = {
		extensionsPath = {
			vim.fs.joinpath(
				vim.env.XDG_CONFIG_HOME or vim.fs.normalize("~/.config", { expand_env = false }),
				"emmet-extensions"
			),
		},
	},
}
