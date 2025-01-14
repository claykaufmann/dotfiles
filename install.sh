#!/bin/zsh

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please install Homebrew to continue."
    exit 1
else
    echo "Homebrew is installed. Continuing with the script..."
fi

# brew install stow
brew install stow

# ensure in dotfiles dir (hardcoded here as I only use it anyway)
dotfiles_dir="$HOME/dotfiles"

# Change directory to dotfiles if not already
cd "$dotfiles_dir" || exit 1

# Loop through each folder, excluding .git, and run stow
for folder in *; do
    if [ -d "$folder" ] && [ "$folder" != ".git" ]; then
        echo "Running stow for folder: $folder"
        stow "$folder"
    fi
done

echo "Stow completed for appropriate folders in dotfiles directory."

# update homebrew
brew update

echo "Installing core homebrew packages"
# homebrew installs
# nerd fonts
brew install --cask font-caskaydia-cove-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-jetbrains-mono-nerd-font

# openssl installs prior
brew install openssl@3

# other essential packages I use
brew install eza nvim pyenv pyenv-virtualenv git-delta git git-extras starship tmux atuin direnv htop bat pgcli rsync tldr wget ripgrep fzf fd postgresql@14 pdm zsh-autosuggestions zsh-syntax-highlighting

# source new zshrc, getting pyenv completions
source "$HOME/.zshrc"


echo "Installing python tooling"

# install essential python build packages before installing pyenv python versions
brew install readline sqlite3 xz zlib tcl-tk

# setup pyenv
pyenv install 3.10 3.11 3.12 3.13
pyenv global 3.12

# custom nvim python venv setup for better python support in neovim
pyenv virtualenv 3.11 neovim3
pyenv activate neovim3
pip install --upgrade pip

# install useful deps for python development into generic python
pip install pynvim black ruff-lsp ruff flake8
pyenv deactivate

