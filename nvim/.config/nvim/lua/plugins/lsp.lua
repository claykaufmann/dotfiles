return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			basedpyright = {
				settings = {
					basedpyright = {
						disableOrganizeImports = true,
						analysis = {
							diagnosticMode = "openFilesOnly",
							typeCheckingMode = "basic",
							inlayHints = {
								callArgumentNames = false,
							},
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							stubPath = "/Users/ckaufmann/misc/python-type-stubs",
						},
						disableTaggedHints = true,
					},
				},
			},
		},
	},
}
