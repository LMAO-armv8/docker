#!/bin/bash
set -e

apt-get install -y nginx
systemctl enable nginx

rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/app <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX

ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app

nginx -t
echo "Nginx installed and configured."
