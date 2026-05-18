<div align="center">

```
██████╗ ██████╗  ██████╗ ██████╗      █████╗ ███╗   ███╗██╗
██╔══██╗██╔══██╗██╔═══██╗██╔══██╗    ██╔══██╗████╗ ████║██║
██████╔╝██████╔╝██║   ██║██║  ██║    ███████║██╔████╔██║██║
██╔═══╝ ██╔══██╗██║   ██║██║  ██║    ██╔══██║██║╚██╔╝██║██║
██║     ██║  ██║╚██████╔╝██████╔╝    ██║  ██║██║ ╚═╝ ██║██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝     ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝
```

**Build once. Deploy anywhere. Zero manual setup.**

[![Build Lightsail AMI](https://github.com/LMAO-armv8/docker/actions/workflows/build-ami.yml/badge.svg)](https://github.com/LMAO-armv8/docker/actions/workflows/build-ami.yml)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)
![Node](https://img.shields.io/badge/Node.js-LTS-339933?logo=nodedotjs&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-47A248?logo=mongodb&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-latest-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-1.24-009639?logo=nginx&logoColor=white)

</div>

---

## What is this?

A fully automated pipeline that builds a **production-ready AWS AMI** using GitHub Actions + Packer, then launches it as an EC2 instance — with everything pre-installed. No manual setup. No post-boot configuration. Just SSH in and deploy your app.

```
Push to project2
      │
      ▼
GitHub Actions
      │
      ▼
Packer builds EC2 instance
      │  installs everything
      ▼
Snapshot → AMI saved to AWS
      │
      ▼
Run launch-ec2.sh
      │
      ▼
Server live in ~3 minutes
```

---

## What's baked into the AMI

| Tool | Version | Purpose |
|------|---------|---------|
| **Ubuntu** | 24.04 LTS | Base OS — minimal, no bloat |
| **Node.js** | LTS (via NVM) | Next.js runtime |
| **NPM** | Latest | Package manager |
| **PM2** | Latest | Process manager — survives reboots |
| **Docker** | Latest | Container runtime |
| **Docker Compose** | v2 plugin | Supabase self-hosted |
| **MongoDB** | 8.0 | Primary database |
| **Nginx** | 1.24 | Reverse proxy + SSL termination |
| **UFW** | — | Firewall — ports 22, 80, 443 only |
| **fail2ban** | — | Brute force protection |
| **Swap** | 2GB | Memory buffer |
| **Timezone** | Asia/Kolkata | IST |

---

## Repo structure

```
.
├── .github/
│   └── workflows/
│       └── build-ami.yml        # GitHub Actions — builds AMI on push
│
├── ami/
│   ├── build.pkr.hcl            # Packer template
│   └── scripts/
│       ├── install_packages.sh  # Base packages + Docker
│       ├── setup_node.sh        # Node.js via NVM
│       ├── setup_mongodb.sh     # MongoDB 8.0
│       ├── setup_nginx.sh       # Nginx + default proxy config
│       ├── setup_security.sh    # UFW + fail2ban
│       ├── setup_swap.sh        # 2GB swap
│       ├── config.sh            # Timezone + docker group
│       ├── setup_pm2.sh         # PM2 process manager
│       └── cleanup.sh           # Strip cache, logs, SSH host keys
│
├── setup-oidc.sh                # One-time AWS OIDC + IAM setup
└── launch-ec2.sh                # Launch EC2 from latest AMI
```

---

## Quick start

### 1. One-time AWS setup

Run in **AWS CloudShell** — sets up OIDC auth so GitHub Actions can build AMIs without storing AWS keys:

```bash
chmod +x setup-oidc.sh
./setup-oidc.sh
```

Copy the printed role ARN → add to GitHub:

```
github.com/LMAO-armv8/docker → Settings → Secrets → Actions

  AWS_ROLE_ARN = arn:aws:iam::YOUR_ACCOUNT_ID:role/github-packer-role
```

### 2. Build the AMI

Push any change to the `ami/` folder on branch `project2`, or trigger manually:

```
GitHub → Actions → Build Lightsail AMI → Run workflow
```

Build takes **~12 minutes**. AMI ID is printed in the Actions summary.

### 3. Launch a server

Run in **AWS CloudShell** — auto-picks your latest AMI:

```bash
chmod +x launch-ec2.sh
./launch-ec2.sh
```

Done. SSH command is printed at the end.

---

## First boot checklist

```bash
ssh -i prod-key.pem ubuntu@YOUR_IP

# Verify everything
source ~/.bashrc
node --version && npm --version
docker --version
mongod --version
nginx -v
pm2 --version
swapon --show

# Lock down MongoDB (do this first)
mongosh
> use admin
> db.createUser({ user: "admin", pwd: "STRONG_PASSWORD", roles: ["root"] })
> exit

# Enable MongoDB auth
sudo nano /etc/mongod.conf
# Under security: add → authorization: enabled
sudo systemctl restart mongod

# Deploy your Next.js app
git clone https://github.com/you/your-app
cd your-app && npm install && npm run build
pm2 start npm --name "nextjs" -- start
pm2 save

# SSL
sudo certbot --nginx -d yourdomain.com
```

---

## Rebuild the AMI

To update your base image (e.g. new Node version, new packages):

1. Edit the relevant script in `ami/scripts/`
2. Push to `project2`
3. GitHub Actions builds a new AMI automatically
4. Run `launch-ec2.sh` to spin up a fresh server from the new image

Old AMIs are kept in EC2 → AMIs — clean them up manually if needed.

---

## Architecture

```
GitHub Actions (CI)
└── Packer
    └── Spins up t3.small build instance
        ├── install_packages.sh   → apt packages + Docker
        ├── setup_node.sh         → NVM + Node LTS
        ├── setup_mongodb.sh      → MongoDB 8.0
        ├── setup_nginx.sh        → Nginx + proxy config
        ├── setup_security.sh     → UFW + fail2ban
        ├── setup_swap.sh         → 2GB swap
        ├── config.sh             → timezone + users
        ├── setup_pm2.sh          → PM2
        └── cleanup.sh            → strip bloat + SSH keys
            └── Snapshot → AMI (shared with Lightsail account)

CloudShell
└── launch-ec2.sh
    ├── Fetch latest prod-lightsail-* AMI
    ├── Create security group (22, 80, 443)
    ├── Create key pair
    ├── Launch t3.medium
    ├── Wait for running
    └── Attach Elastic IP → print SSH command
```

---

## Ports

| Port | Open to | Purpose |
|------|---------|---------|
| 22 | 0.0.0.0/0 | SSH |
| 80 | 0.0.0.0/0 | HTTP → redirects to HTTPS |
| 443 | 0.0.0.0/0 | HTTPS |
| 27017 | localhost only | MongoDB |
| 3000 | localhost only | Next.js (proxied via Nginx) |

---

## Instance sizing

| Plan | RAM | vCPU | Cost | Use |
|------|-----|------|------|-----|
| t3.small | 2GB | 2 | ~$15/mo | Build instance (Packer) |
| t3.medium | 4GB | 2 | ~$30/mo | Prod — Next.js + MongoDB |
| t3.large | 8GB | 2 | ~$60/mo | Prod — with Supabase self-hosted |

---

<div align="center">

Built with ☕ — push, wait 12 minutes, SSH in.

</div>
