#!/bin/zsh

# stow dotfiles (all folders in this repo
folders=$(find . -mindepth 1 -maxdepth 1 -type d)

# Loop through each folder and run 'stow <folder_name>'
for folder in $folders
do
    # Extract folder name without './' prefix
    folder_name=$(basename "$folder")
    
    # Run 'stow <folder_name>'
    stow "$folder_name"
done

# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew update

# homebrew installs
# nerd fonts
brew tap homebrew/cask-fonts
brew install --cask font-caskaydia-cove-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-jetbrains-mono-nerd-fontbrew install eza 

brew install eza nvim pyenv pyenv-virtualenv neofetch git-delta git git-extras starship tmux

# setup pyenv
pyenv install 3.10 3.11 3.12
pyenv global 3.12

# install zsh extras
rm -rf ~/.zsh/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions

rm -rf ~/.zsh/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting

# custom nvim python venv setup for better langservers
pyenv virtualenv 3.11 neovim3
pyenv activate neovim3
pip install pynvim black lsp-ruff ruff flake8
pyenv deactivate

