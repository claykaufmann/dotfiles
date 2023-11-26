vim.g.mapleader = " "
vim.keymap.set("n", "<leader>dj", vim.cmd.Ex)

-- copy to system clipboard
vim.keymap.set("v", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+yg_')
vim.keymap.set("n", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>yy", '"+yy')

-- paste from system clipboard
vim.keymap.set("v", "<leader>p", '"+p')
vim.keymap.set("n", "<leader>P", '"+P')
vim.keymap.set("n", "<leader>p", '"+p')
vim.keymap.set("n", "<leader>P", '"+P')

-- tab navigation
vim.keymap.set("n", "<leader>1", "1gt")
vim.keymap.set("n", "<leader>2", "2gt")
vim.keymap.set("n", "<leader>3", "3gt")
vim.keymap.set("n", "<leader>4", "4gt")
vim.keymap.set("n", "<leader>5", "5gt")
vim.keymap.set("n", "<leader>6", "6gt")
vim.keymap.set("n", "<leader>7", "7gt")
vim.keymap.set("n", "<leader>8", "8gt")
vim.keymap.set("n", "<leader>9", "9gt")
vim.keymap.set("n", "<leader>n", ":tabnew<CR>")
vim.keymap.set("n", "<leader>x", ":tabclose<CR>")

-- window splits
-- close pane
vim.keymap.set("n", "<leader>wc", "<C-W>q")

-- open new split
-- vsplit
vim.keymap.set("n", "<leader>wv", "<C-W>v")
-- hsplit
vim.keymap.set("n", "<leader>ws", "<C-W>s")

-- resizing panes
-- width
vim.keymap.set("n", "<leader>w<", "<C-W><")
vim.keymap.set("n", "<leader>w>", "<C-W>>")

-- height
vim.keymap.set("n", "<leader>w-", "<C-W>-")
vim.keymap.set("n", "<leader>w+", "<C-W>+")

-- equal size of all windows
vim.keymap.set("n", "<leader>w=", "<C-W>=")

-- focus splits
vim.keymap.set("n", "<leader>wh", "<C-W>h")
vim.keymap.set("n", "<leader>wj", "<C-W>j")
vim.keymap.set("n", "<leader>wk", "<C-W>k")
vim.keymap.set("n", "<leader>wl", "<C-W>l")

-- hop to previous buffer
vim.keymap.set("n", "<leader>`", ":b#<CR>")

