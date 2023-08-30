#!/bin/bash

# Git Configuration
export GIT_USERNAME="LMAO-armv8"
export GIT_EMAIL="chaitanya4g9@sasi.ac.in"

git config --global user.name "${GIT_USERNAME}"
git config --global user.email "${GIT_EMAIL}"

# TimeZone Configuration
export TZ="Asia/Kolkata"
ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
