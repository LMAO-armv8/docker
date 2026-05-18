#!/bin/bash
set -e

export HOME=/home/ubuntu
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

npm install -g pm2

pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 > /tmp/pm2_startup.sh

echo "PM2 installed: $(pm2 --version)"
