#!/bin/bash

# Timezone
timedatectl set-timezone Asia/Kolkata

# Create deploy user
useradd -m -s /bin/bash ubuntu || true

# Docker permissions
usermod -aG docker ubuntu
