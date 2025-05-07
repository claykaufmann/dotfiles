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
              typeCheckingMode = "off",
              inlayHints = {
                callArgumentNames = false,
              },
              autoSearchPaths = true,
              useLibraryCodeForTypes = false,
            },
          },
        },
      },
    },
  },
}
