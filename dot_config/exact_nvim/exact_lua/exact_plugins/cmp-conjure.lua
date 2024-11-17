return {
	"PaterJason/cmp-conjure",
	branch = "master",
	version = false,
	lazy = true, -- loaded by require where needed
	config = function(name, opts)
		local cmp = require("cmp")
		local config = cmp.get_config()
		table.insert(config.sources, {
			name = "buffer",
			option = {
				sources = {
					{ name = "conjure" },
				},
			},
		})
		cmp.setup(config)
	end,
}
