#!/bin/bash

sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco main" | tee -a /etc/apt/sources.list
echo "deb-src http://old-releases.ubuntu.com/ubuntu disco-updates main" | tee -a /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get build-dep linux linux-image-$(uname -r)
apt-get install -y build-essential software-properties-common
python --version

