#!/bin/bash

sudo sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
sudo echo "deb-src http://old-releases.ubuntu.com/ubuntu disco main" | tee -a /etc/apt/sources.list
sudo echo "deb-src http://old-releases.ubuntu.com/ubuntu disco-updates main" | tee -a /etc/apt/sources.list
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install --no-install-recommends apt-utils dialog 2>&1
sudo apt-get install -y build-essential software-properties-common
sudo apt-get install -y python3 python-is-python3 pip

python --version
pip --version

mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm ~/miniconda3/miniconda.sh
~/miniconda3/bin/conda init bash
~/miniconda3/bin/conda init zsh
source ~/.bashrc
conda create -n myenv python=3.12 pip wheel


# python3.12 -m venv myenv
# source myenv/bin/activate




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
