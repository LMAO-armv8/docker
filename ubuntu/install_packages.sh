#!/bin/bash

sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
echo "deb-src http://archive.ubuntu.com/ubuntu disco main" | tee -a /etc/apt/sources.list
echo "deb-src http://archive.ubuntu.com/ubuntu disco-updates main" | tee -a /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get build-dep linux linux-image-$(uname -r)
apt-get install -y build-essential
apt-get install -y byobu curl git htop man unzip vim wget tmate neofetch
apt-get install -y git aria2 openjdk-8-jdk
apt-get install -y libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm clang
apt-get install -y python3 python-is-python3 pip

