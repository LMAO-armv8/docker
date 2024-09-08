#!/bin/bash

sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco main" | tee -a /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco-updates main" | tee -a /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get build-dep linux linux-image-$(uname -r)
apt-get install -y build-essential software-properties-common
add-apt-repository ppa:deadsnakes/ppa
apt update
apt install python3.11
ln -sf /usr/local/bin/python3.11 /usr/local/bin/python
ln -sf /usr/local/bin/python3.11 /usr/local/bin/python3
update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
update-alternatives --config python
update-alternatives --config python3
python --version
python3 --version

