" Plugins
call plug#begin('~/.vim/plugged')
" NERDtree
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'

" Lualine status line
Plug 'nvim-lualine/lualine.nvim'

" for file icons (keeping ryan oasis in case something breaks)
" Plug 'ryanoasis/vim-devicons'
Plug 'nvim-tree/nvim-web-devicons' " (for coloured icons)

" git in the gutter!
Plug 'airblade/vim-gitgutter'

" handles keeping workspaces or something
Plug 'rbgrouleff/bclose.vim'

Plug 'kdheepak/tabline.nvim'

" telescope and dependencies
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }

" start screen
Plug 'mhinz/vim-startify'

" fugitive for git
Plug 'tpope/vim-fugitive'

" snippets/lsp
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" comments
Plug 'tpope/vim-commentary'

" theming
Plug 'dracula/vim'

" Transparency
Plug 'tribela/vim-transparent'

" preview css colors in window
Plug 'norcalli/nvim-colorizer.lua'

" rainbow parenthesis
Plug 'luochen1990/rainbow'

" more syntax highlights
Plug 'cespare/vim-toml'
Plug 'gabrielelana/vim-markdown'
call plug#end()

" If for some reason my workaround copy and paste keybinds dont work, can use
" this, sets all yanks to use system clipboard
" set clipboard=unnamedplus

" Set leader to Space
let mapleader = " "

" Set shell
" this should be a template in chezmoi eventually, depending on specific shell
" of OS
set shell=zsh

" theme
colorscheme dracula
let g:rainbow_active = 1 "set to 0 if you want to enable it later via :RainbowToggle

" mappings
" general vim
" set escape to be jk
inoremap jk <Esc>

" copy and paste to system clipboard
" " Copy to clipboard
vnoremap  <leader>y  "+y
nnoremap  <leader>Y  "+yg_
nnoremap  <leader>y  "+y
nnoremap  <leader>yy  "+yy

" " Paste from clipboard
nnoremap <leader>p "+p
nnoremap <leader>P "+P
vnoremap <leader>p "+p
vnoremap <leader>P "+P

" set esc to exit search highlight
" noh - no highlight
map <esc> :noh <CR>

" nerdtree
nmap <leader>ot :NERDTreeToggle<CR>
nmap <C-q> :qa<CR>
let NERDTreeMapQuit=''

" tab nav
noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>n :tabnew<CR>
noremap <leader>x :tabclose<CR>

" Splits
" close split
noremap <leader>wc <C-W>q

" ~~~~ Opening new splits ~~~~
" vertical split
noremap <leader>wv <C-W>v

" horizontal split
noremap <leader>ws <C-W>s

" ~~~~ Resizing windows ~~~~
" ~~ Width ~~
" shrink current window width
noremap <leader>w< <C-W><

" increase current window width
noremap <leader>w> <C-W>>

" ~~ Height ~~
" shrink window height
noremap <leader>w- <C-W>-

" increase window height
noremap <leader>w+ <C-W>+

" equal the size of all windows
noremap <leader>w= <C-W>=

" ~~~~ focusing new splits ~~~~
noremap <leader>wh <C-W>h
noremap <leader>wj <C-W>j
noremap <leader>wk <C-W>k
noremap <leader>wl <C-W>l
noremap <leader><leader> <C-W>w

" error nav
nmap <leader>e[ <Plug>(coc-diagnostic-prev)
nmap <leader>e <Plug>(coc-diagnostic-next)

" Startify Mappings
noremap <C-S> :tabdo NERDTreeClose<CR> :SSave<CR>
noremap <C-H> :NERDTreeClose<CR> :Startify<CR>

" ~~~~~~ LSP VIA COC ~~~~~~
" DEFINE NECESSARY EXTENSIONS HERE
let g:coc_global_extensions = [
  \ 'coc-snippets',
  \ 'coc-pairs',
  \ 'coc-tsserver',
  \ 'coc-eslint', 
  \ 'coc-prettier', 
  \ 'coc-json', 
  \ 'coc-toml',
  \ 'coc-pyright',
  \ 'coc-texlab',
  \ 'coc-cl',
  \ ]

" coc keybinds for completion
" Use tab for trigger completion with characters ahead and navigate.
" NOTE: There's always complete item selected by default, you may want to enable
" no select by `"suggest.noselect": true` in your configuration file.
" this is currently set as true, so I need to use <tab> to actually select a
" completion
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice.
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" for the above setup
function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

nmap <leader>cd <Plug>(coc-definition)
nmap <leader>cy <Plug>(coc-type-definition)
nmap <leader>ci <Plug>(coc-implementation)
nmap <leader>cr <Plug>(coc-references)

" NERDTree
let g:NERDTreeGitStatusWithFlags = 1
let g:NERDTreeIgnore = ['^node_modules$']
let g:NERDTreeHighlightCursorline=0
let g:NERDTreeMinimalUI=1
let g:NERDTreeShowHidden=1
let g:NERDTreeGitStatusIndicatorMapCustom = {
                \ 'Modified'  :'✹',
                \ 'Staged'    :'✚',
                \ 'Untracked' :'✭',
                \ 'Renamed'   :'➜',
                \ 'Unmerged'  :'═',
                \ 'Deleted'   :'✖',
                \ 'Dirty'     :'✗',
                \ 'Ignored'   :'☒',
                \ 'Clean'     :'✔︎',
                \ 'Unknown'   :'?',
                \ }

" Exit Vim if NERDTree is the only window left.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() |
    \ quit | endif

" Startify
let g:startify_bookmarks = ['~/.config/nvim/init.vim', '~/.config/fish/config.fish', '~/.config/qtile/config.py', '~/Projects/']
let g:startify_session_dir = '~/.config/nvim/sessions'
let g:startify_session_autload = 0
let g:startify_session_persistence = 0
let g:startify_lists =[
      \ { 'type': 'bookmarks',  'header': ['  Bookmarks']   },
      \ { 'type': 'sessions',   'header': ['  Sessions']    },
      \ { 'type': 'dir',      'header': ['  MRU '.getcwd()] },
      \ ] 
let g:startify_session_before_save = [ 'silent! tabdo NERDTreeClose' ]
let g:startify_change_to_vcs_root = 1
let g:startify_fortune_use_unicode = 1

" vim-gitgutter
let g:gitgutter_sign_added = '✚'
let g:gitgutter_sign_modified = '✹'
let g:gitgutter_sign_removed = '✖'
let g:gitgutter_sign_removed_first_line = ''
let g:gitgutter_sign_modified_removed = ''

" Mouse
set mouse=nicr
set mouse=a

" More responsive signs on gitgutter
set updatetime=250

" line numbers
set number relativenumber
set nocursorline
set scrolloff=15

" indents
set autoindent
set expandtab
set tabstop=2 shiftwidth=2
set smarttab

" search
set ignorecase
set smartcase
set hlsearch
set incsearch

set showmatch

" telescope
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" Gvim
set guifont=Fira\ Code
let g:neovide_transparency=0.8
" Neovide
" Smooth Scrolling
" let g:NEOVIDE_MULTIGRID=true
" Transparency
let g:neovide_transparency=0.8
let g:neovide_refresh_rate=144

" for bufferline
set termguicolors

