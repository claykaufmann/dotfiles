vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Go to Left Window", remap = true })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Go to Lower Window", remap = true })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Go to Upper Window", remap = true })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- window splitting
vim.keymap.set("n", "<leader>wv", "<C-W>v", { desc = "Split Window Below", remap = true })
vim.keymap.set("n", "<leader>ws", "<C-W>s", { desc = "Split Window Right", remap = true })

-- Exit terminal mode with Escape key
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
