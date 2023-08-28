#!/bin/bash

sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
deb-src http://archive.ubuntu.com/ubuntu disco main
deb-src http://archive.ubuntu.com/ubuntu disco-updates main
apt-get update
apt-get -y upgrade
apt-get build-dep linux linux-image-$(uname -r)
apt-get install -y build-essential
apt-get install -y software-properties-common
apt-get install -y byobu curl git htop man unzip vim wget
apt-get install -y git aria2 openjdk-8-jdk
apt-get install -y libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm clang
apt-get install -y python3 python2
git clone https://gitlab.com/OrangeFox/misc/scripts
cd scripts
bash setup/android_build_env.sh
bash setup/install_android_sdk.sh
rm -rf /var/lib/apt/lists/*

# python and pip version
python --version; pip --version

# Install Some pip packages
pip install \
	twrpdtgen telegram-send backports.lzma docopt \
	extract-dtb protobuf pycrypto docopt zstandard \
	setuptools future requests humanize clint lz4 \
	pycryptodome

# pip git packages
pip install \
	git+https://github.com/samloader/samloader.git
