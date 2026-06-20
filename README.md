# Smart TV + Retro Gaming image for Raspberry Pi 1 Model B/B+

A custom Raspberry Pi OS image that turns an old TV plugged into a Pi 1
(Model B or B+) into a Kodi-based smart TV box with an **Android TV-style
Kodi skin (Arctic Zephyr 2)**, **Steam Deck-style EmulationStation theme**,
**App Store for add-ons**, **Midori web browser**, **dynamic wallpapers**,
**animated silent boot**, and **onboard RJ45 Ethernet** — plus
**EmulationStation + RetroArch** for retro gaming. Built automatically by
GitHub Actions using [pi-gen](https://github.com/RPi-Distro/pi-gen) and
published as a flashable `.img.gz`.

It boots straight into Kodi — no desktop, no scrolling Linux boot logs — with
SSH on by default for remote access.

## Read this first: what Pi 1 hardware can actually do

A Raspberry Pi 1 is a single-core ARM11 CPU at 700MHz with no NEON and
256MB (Model B) or 512MB (Model B+) of RAM, shared with the GPU. This repo
is built to be honest about what that hardware can and can't do:

- **Kodi is capped at version 18 "Leia".** Kodi 19+ dropped ARMv6 builds
  entirely — Leia is the latest ARMv6-compatible release.
- **No full Android OS, SteamOS, or Chromium** — we skin Kodi/ES to mimic
  those UIs; Midori is the web browser (lighter than Chromium).
- **NES / SNES / GBA / Genesis** are realistically playable on ARM11.
- **PS1 is hit or miss; N64 is mostly unplayable** — included for
  completeness only.
- **Video playback** works well for H.264 up to 1080p (hardware-decoded).

## Features

| Feature | Details |
|---------|---------|
| Kodi UI | Arctic Zephyr 2 skin (Android TV look) + rotating wallpapers |
| Retro UI | Art Book Next theme, steam-deck color scheme |
| App Store | `App Store` favourite → install pinned Leia add-ons |
| YouTube | Pre-installed with Python 2 deps + playback patch |
| Web browser | Midori (launch from Kodi home) |
| Boot experience | Plymouth animated splash, no kernel log spam |
| LAN | Onboard RJ45 (`eth0`) DHCP; fallback IP `192.168.1.50` |
| Swap | 4GB swap created on first boot (needs 8GB+ SD, 16GB recommended) |
| SSH | `pi` / `raspberry` (change immediately) |

## How it works

1. pi-gen bootstraps Raspberry Pi OS Lite (`buster`, last ARMv6 branch).
2. Custom stage runs, in order:
   - `install_kodi.sh` — Kodi 18, AZ2 skin, YouTube + deps, App Store
   - `install_retroarch.sh` — RetroArch + libretro cores via RetroPie-Setup
   - `install_emulationstation.sh` — ES + Art Book Next theme
   - `configure_system.sh` — LAN, swap, Plymouth, wallpapers, browser, Kodi auto-boot
3. Image exported as `smarttv-retro-pi1.img.gz`.

## SD card requirements

- **Minimum 8GB** (4GB swap + rootfs + ROMs)
- **16GB Class 10 recommended** — swap on SD wears the card; use a good card

## First boot

1. Flash image, plug **Ethernet (RJ45)** into your router, connect HDMI, power on.
2. First boot: filesystem expands, **4GB swap** is created (~1–2 extra minutes).
3. You see the **animated Plymouth boot splash** (no scrolling Linux text).
4. Kodi starts with Arctic Zephyr 2 and rotating backgrounds.

### Kodi home favourites

- **Retro Games** → EmulationStation (Steam Deck-style theme)
- **YouTube** → YouTube add-on
- **App Store** → install more Leia add-ons
- **Web Browser** → Midori (stops Kodi, opens browser, returns on exit)

### Network

- DHCP on `eth0` when plugged into a router.
- Check link: `smarttv-network-status` (over SSH).
- Static fallback if no DHCP: `192.168.1.50/24`.

### Add-ons

- Pre-installed add-ons live in `/usr/share/kodi/addons/` (system path).
- Install more from Kodi **App Store** or SSH:
  ```
  smarttv-install-addon plugin.video.youtube
  ```
- Add-on check log: `/var/log/kodi-addon-check.log`.

### Debug boot (show Linux logs again)

Create an empty file on the boot partition:
```
/boot/debug-boot
```

### Custom wallpapers

Drop JPEG/PNG files in:
```
/home/pi/smarttv-wallpapers/custom/
```
They rotate every 15 minutes with the built-in set.

## Repository structure

```
.github/workflows/build.yml
pi-gen-stage/
scripts/          install_*.sh, kodi_install_addon.sh, setup_swap.sh, ...
config/           kodi/, emulationstation/, network/, systemd/, plymouth/
addons/           plugin.program.smarttvstore/
```

## Building the image

### GitHub Actions (default)

Push to `main` or `raspi-smarttv-retro`, or run the workflow manually from the
**Actions** tab. Enable **Publish a GitHub Release** on manual runs to upload
`smarttv-retro-pi1.img.gz` to Releases.

### Cloud server / VM (same pipeline as Actions)

Use [`scripts/build-server.sh`](scripts/build-server.sh) on **Ubuntu 22.04**
(AWS Lightsail, EC2, DigitalOcean, etc.). It runs the same pi-gen steps as
[`.github/workflows/build.yml`](.github/workflows/build.yml).

**Server requirements:** 50GB+ disk, 4GB+ RAM, sudo, outbound internet.

```bash
# One-time setup
sudo apt-get install -y git gh
gh auth login    # needs repo + Contents: write

git clone https://github.com/YOUR_USER/raspi-smarttv-retro.git
cd raspi-smarttv-retro
git checkout raspi-smarttv-retro
chmod +x scripts/build-server.sh

# Build only → ./smarttv-retro-pi1.img.gz in repo root (~2–4 hours)
./scripts/build-server.sh

# Build + publish to GitHub Releases (same as Actions release step)
PUBLISH_RELEASE=1 ./scripts/build-server.sh

# Faster rebuild on the same server (reuse pi-gen checkout)
KEEP_PI_GEN=1 SKIP_APT_HOST=1 ./scripts/build-server.sh
```

**Optional environment variables:**

| Variable | Default | Purpose |
|----------|---------|---------|
| `PUBLISH_RELEASE` | `0` | Set to `1` to upload `.img.gz` via `gh release create` |
| `GITHUB_REPO` | from `git remote` | e.g. `owner/raspi-smarttv-retro` |
| `BUILD_TAG` | `build-server-YYYYMMDD-HHMMSS` | GitHub Release tag name |
| `KEEP_PI_GEN` | `0` | Reuse existing `pi-gen/` directory |
| `SKIP_APT_HOST` | `0` | Skip host package install on rebuild |

**Note:** Use Ubuntu **22.04** — pi-gen qcow2 + NBD is unreliable on 24.04+.
Build under `~/` on the server, not a slow network mount.

## Customizing

- Kodi skin: edit `<skin>` in `config/kodi/guisettings.xml`
- ES theme: edit `config/emulationstation/es_settings.cfg`
- Emulator cores: `scripts/install_retroarch.sh` + `es_systems.cfg`
- Credentials: `FIRST_USER_PASS` in `build.yml` + `configure_system.sh`

## Troubleshooting

- **YouTube won't play:** may need Google API keys in add-on settings; check
  `/var/log/kodi-addon-check.log`.
- **No network:** run `smarttv-network-status`; ensure RJ45 cable linked.
- **Add-on dependency errors:** `smarttv-install-addon <id>` over SSH.
- **Boot shows text:** remove `/boot/debug-boot` if present; Plymouth may
  have failed — check `journalctl -b`.
- **Build failures:** see existing pi-gen / RetroPie QEMU build notes below.

### Build troubleshooting

- **Out of disk space on runner:** workflow already cleans runner disk.
- **Missing rpi1 core binary:** build continues without that core.
- **Build exceeds 6 hours:** comment out heavy cores in `install_retroarch.sh`.

## License

MIT — see `LICENSE`. Kodi, skins, add-ons, RetroArch, EmulationStation, and
RetroPie-Setup are separate projects under their own licenses.
