# set starship as main prompt
eval "$(starship init zsh)"

# enable atuin
eval "$(atuin init zsh --disable-up-arrow)"

# enable vim keybinds (disabled for now)
# bindkey -v

# Set main editor
export EDITOR=/opt/homebrew/bin/nvim
export VISUAL=/opt/homebrew/bin/nvim

# ~~~~~~~ ALIASES ~~~~~~~
# use exa instead of default ls
alias ls='eza'
alias ll='eza -l -a --icons'
alias l.='ll -d .* '

# use bat instead of cat
alias cat='bat'

# g for git for quicker git commands
alias g='git'

# vim
alias vim='nvim'

# test doom alias
alias doom-test='~/doom-emacs-test/bin/doom'

# launch doom alias
alias emacs-test='emacs --with-profile doom-test'

# easier tmux attaching
function tma() {
  if [ $# -lt 1 ]
  then
    echo "Usage: $funcstack[1] <tmux session number>"
    return
  fi
  tmux attach -t $1 
}

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

##### BETA ALIASES #####
# handy function to set aws environment
function set-aws-env() {
  if [ $# -lt 1 ]
  then
    echo "Usage: $funcstack[1] <environment name>"
    return
  fi
  
  echo "Setting region to us-east-1"
  export AWS_DEFAULT_REGION=us-east-1
  
  echo "Refreshing AWS credentials"

  if [ "$1" = "prod" ]; then
    echo "Setting environment to production."
    echo "User profile: prod_data"
    export AWS_PROFILE=prod_data
    export AWS_ENV=$1
    export BETA_ENV=$1
    export BETA_PLATFORM_ENV=$1
  elif [ "$1" = "staging" ]; then
    echo "Setting environment to staging."
    echo "User profile: staging_data"
    export AWS_PROFILE=staging_data
    export AWS_ENV=$1
    export BETA_ENV=$1
    export BETA_PLATFORM_ENV=$1
  elif [ "$1" = "dev-mfg" ]; then
    echo "Setting environment to staging."
    echo "User profile: dev-mfg"
    export AWS_PROFILE=dev-mfg
    export AWS_ENV=$1
    export BETA_ENV=$1
    export BETA_PLATFORM_ENV=$1
  else
    echo "Setting environment to $1."
    echo "User profile: dev_data"
    export AWS_PROFILE=dev_data
    export AWS_ENV=$1
    export BETA_ENV=$1
    export BETA_PLATFORM_ENV=$1
  fi

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  aws sso login
  eval $(aws configure export-credentials --profile $AWS_PROFILE --format env)
}

# ~~~~~~~ CONFIG SETUP ~~~~~~~
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

# enable zsh auto complete and syntax highlight with homebrew
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# set new syntax highlight colors
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#8fee96'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#8fee96'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#8fee96'

# for direnv
eval "$(direnv hook zsh)"

# for pdm
export PATH=/Users/ckaufmann/.local/bin:$PATH

# add git-filter-repo
export PATH=/Users/ckaufmann/scripts/git-filter-repo:$PATH

# disable brew autoupdate
export HOMEBREW_NO_AUTO_UPDATE=1
export PATH="/opt/homebrew/opt/go@1.22/bin:$PATH"

# brew shell completions
autoload -Uz compinit
compinit
