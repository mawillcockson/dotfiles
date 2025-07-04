return {
	capabilities = require("utils").get_capabilities(),
	root_dir = require("lspconfig.util").root_pattern("zls.json", "build.zig"),
}
