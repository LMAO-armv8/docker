#!/bin/bash

sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco main" | tee -a /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco-updates main" | tee -a /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get build-dep linux linux-image-$(uname -r)
apt-get install -y build-essential software-properties-common
apt-get install python
apt-get install python3.12-venv

python3.12 -m venv myenv
source myenv/bin/activate




# sudo apt update
# sudo apt install apt-transport-https ca-certificates curl software-properties-common


# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg


# echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# sudo apt update
# sudo apt install docker-ce docker-ce-cli containerd.io

# sudo systemctl status docker
# docker --version

# sudo groupadd docker
# sudo usermod -aG docker $USER
# newgrp docker
