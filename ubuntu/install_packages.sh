#!/bin/bash

sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco main" | tee -a /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco-updates main" | tee -a /etc/apt/sources.list
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y install --no-install-recommends apt-utils dialog 2>&1
apt-get install -y build-essential software-properties-common
apt-get install -y python3 python-is-python3 pip wget

python --version
pip --version
whoami
