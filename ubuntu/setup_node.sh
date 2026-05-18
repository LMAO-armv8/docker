#!/bin/bash

su - ubuntu -c '

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"

source "$NVM_DIR/nvm.sh"

nvm install --lts

nvm alias default lts/*

node -v
npm -v
'
