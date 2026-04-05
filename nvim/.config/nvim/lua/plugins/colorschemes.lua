return {
	{
		"catppuccin/nvim",
		lazy = false,
		name = "catppuccin",
		priority = 1000,
		opts = {
			transparent_background = true,
			flavour = "frappe",
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
			vim.cmd.colorscheme("catppuccin")
		end,
	},

	{
		"folke/tokyonight.nvim",
		lazy = true,
		opts = {
			style = "moon",
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
			},
		},
	},

	{
		"navarasu/onedark.nvim",
		lazy = true,
		opts = {
			style = "dark",
			transparent = true,
		},
	},

	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin",
		},
	},
}
