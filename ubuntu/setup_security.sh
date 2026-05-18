#!/bin/bash

ufw default deny incoming
ufw default allow outgoing

ufw allow 22
ufw allow 80
ufw allow 443

ufw --force enable

systemctl enable fail2ban
systemctl start fail2ban
