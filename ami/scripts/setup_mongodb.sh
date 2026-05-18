#!/bin/bash
set -e

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
  gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-8.0.list

apt-get update -y
apt-get install -y mongodb-org

systemctl enable mongod

sed -i 's/bindIp: 127.0.0.1/bindIp: 127.0.0.1/' /etc/mongod.conf

echo "MongoDB installed and enabled."
