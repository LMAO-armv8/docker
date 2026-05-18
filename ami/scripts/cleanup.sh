#!/bin/bash
set -e

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
rm -rf /var/log/*.log
rm -rf /var/log/apt/*

rm -f /etc/ssh/ssh_host_*

history -c
cat /dev/null > /root/.bash_history
cat /dev/null > /home/ubuntu/.bash_history

echo "Cleanup done."
