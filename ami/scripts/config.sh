#!/bin/bash
set -e

usermod -aG docker ubuntu

timedatectl set-timezone Asia/Kolkata

echo "Asia/Kolkata" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo "Config applied."
