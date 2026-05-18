#!/bin/bash
set -e

export HOME=/home/ubuntu
export NVM_DIR="$HOME/.nvm"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

source "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default lts/*

node -v
npm -v

echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc"
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc"
