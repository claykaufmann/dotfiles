# set starship as main prompt
eval "$(starship init zsh)"

# enable atuin
eval "$(atuin init zsh)"

# enable vim keybinds (disabled for now)
# bindkey -v

# Set main editor
export EDITOR=/opt/homebrew/bin/nvim
export VISUAL=/opt/homebrew/bin/nvim

# ~~~~~~~ ALIASES ~~~~~~~
# use exa instead of default ls
alias ls='exa'
alias ll='exa -l -a --icons'
alias l.='ll -d .* '

# g for git for quicker git commands
alias g='git'

# kitty ssh fixes
alias kssh="kitty +kitten ssh"

# vim
alias vim='nvim'

# test doom alias
alias doom-test='~/doom-emacs-test/bin/doom'

# launch doom alias
alias emacs-test='emacs --with-profile doom-test'

# chezmoi alias
alias che='chezmoi'

# ~~~~~~~ CONFIG SETUP ~~~~~~~
# ~~~ pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# export PATH="$PYENV_ROOT/bin:$PATH"

# # activate pyenv/virtualenv
# eval "$(pyenv init -)"
# eval "$(pyenv virtualenv-init -)"

# ~~~ nvm
export NVM_DIR="$HOME/.nvm"

# load nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 

# load bash completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ~~~ poetry
export PATH="/Users/claykaufmann/.local/bin:$PATH"

# ~~~ emacs path modification
export PATH="$HOME/.emacs.d/bin:$PATH"

# ~~~ llvm/c
# export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/Applications/CMake.app/Contents/bin":"$PATH"

# ~~~ yarn path modification
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node-modules/.bin:$PATH"

# ~~~ EMACS PATH EXTRAS ~~~
export PATH="/opt/homebrew/Cellar/emacs-plus@28/28.1/bin:$PATH"

# ~~~ DOOM PATHS ~~~
export PATH="$HOME/doom-emacs/bin:$PATH"

export VIRTUAL_ENV_DISABLE_PROMPT=true

# enable zsh auto complete and syntax highlight
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# set new syntax highlight colors
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#8fee96'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#8fee96'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#8fee96'


