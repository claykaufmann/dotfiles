return {
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    priority = 1000,
    opts = {
      transparent_background = true,
      flavour = "frappe",
    },
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

  -- {
  --   "uloco/bluloco.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   dependencies = { "rktjmp/lush.nvim" },
  --   config = function()
  --     -- your optional config goes here, see below.LazyVim
  --     require("bluloco").setup({
  --       style = "dark", -- "auto" | "dark" | "light"
  --       transparent = false,
  --       italics = false,
  --       terminal = vim.fn.has("gui_running") == 1, -- bluoco colors are enabled in gui terminals per default.
  --       guicursor = true,
  --     })
  --
  --     vim.opt.termguicolors = true
  --     vim.cmd("colorscheme bluloco")
  --   end,
  -- },
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
