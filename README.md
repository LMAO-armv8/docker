# Smart TV + Retro Gaming image for Raspberry Pi 1 Model B/B+

A custom Raspberry Pi OS image that turns an old TV plugged into a Pi 1
(Model B or B+) into a Kodi-based smart TV box, skinned with **Estuary MOD
V2**, with **EmulationStation + RetroArch** baked in as a built-in retro
games launcher. The whole image is built automatically by GitHub Actions
using [pi-gen](https://github.com/RPi-Distro/pi-gen) and published as a
flashable `.img.gz` on every push to `main`.

It boots straight into Kodi - no desktop, no terminal - with SSH on by
default for remote access.

## Read this first: what Pi 1 hardware can actually do

A Raspberry Pi 1 is a single-core ARM11 CPU at 700MHz with no NEON and
256MB (Model B) or 512MB (Model B+) of RAM, shared with the GPU. This repo
is built to be honest about what that hardware can and can't do, rather
than overselling it:

- **Kodi is capped at version 18 "Leia".** Kodi 19+ dropped ARMv6 builds
  entirely - there is no "latest Kodi" for a Pi 1, Leia *is* the latest
  ARMv6-compatible release, and that's what `scripts/install_kodi.sh`
  installs from the official `archive.raspberrypi.org` repo.
- **NES / SNES / Game Boy Advance / Genesis are realistically playable.**
  These cores (`lr-fceumm`, `lr-snes9x2010`, `lr-gpsp`, `lr-picodrive`) were
  chosen specifically because they're light enough for ARM11.
- **PlayStation 1 (`lr-pcsx-rearmed`) is hit or miss.** Expect simple,
  2D-heavy titles to be borderline playable and demanding 3D titles to
  struggle.
- **Nintendo 64 (`lr-mupen64plus`) is included because it was requested
  ("as far as Pi 1 can handle"), but in practice expect it to be
  unplayably slow or fail to boot most titles.** There is no lightweight
  N64 core - even a Raspberry Pi 3 struggles with N64 emulation. Treat it
  as present-for-completeness, not a real feature.
- **Video playback in Kodi** works well for H.264 content up to 1080p
  (hardware-decoded), but anything requiring software decoding (HEVC/H.265,
  VP9, AV1) will not run acceptably.

If you want a noticeably better experience, the same repo structure would
work with only small changes on a Raspberry Pi 2/3 (set `__platform=rpi2`
or `rpi3` in the RetroArch/ES scripts and you get access to far more
prebuilt RetroPie cores, plus Kodi 19+).

## How it works

1. [pi-gen](https://github.com/RPi-Distro/pi-gen) (the official Raspberry
   Pi OS image builder) bootstraps a minimal Raspberry Pi OS Lite image
   (`buster` branch - the last pi-gen branch with first-class ARMv6/Pi 1
   support, and the last Raspberry Pi OS release with Kodi packages built
   for ARMv6).
2. A custom pi-gen stage (`pi-gen-stage/`, copied into pi-gen as
   `stage5-smarttv` by the CI workflow) copies this repo's `scripts/` and
   `config/` folders into the image and runs them inside the build chroot,
   in order:
   - `install_kodi.sh` - Kodi 18, the Estuary MOD V2 skin, and the YouTube
     addon.
   - `install_retroarch.sh` - RetroArch + the libretro cores listed above,
     installed via
     [RetroPie-Setup](https://github.com/RetroPie/RetroPie-Setup)'s
     documented non-interactive package interface
     (`retropie_packages.sh <module> install_bin`), the same mechanism
     RetroPie itself uses for automated builds.
   - `install_emulationstation.sh` - EmulationStation (RetroPie's fork) and
     `runcommand`, the helper that actually launches a core against a ROM.
   - `configure_system.sh` - auto-boot to Kodi (no desktop/terminal), SSH
     on by default, default `pi`/`raspberry` login, and controller support
     via `xboxdrv`.
3. The image is shrunk (`zerofree`, run automatically by pi-gen's export
   step) and gzip-compressed to `smarttv-retro-pi1.img.gz`.
4. GitHub Actions uploads that file as both a build artifact and a GitHub
   Release.

## Repository structure

```
.github/workflows/build.yml   - the CI pipeline (build + release)
pi-gen-stage/                 - glue that wires scripts/ and config/ into pi-gen
scripts/
  install_kodi.sh
  install_retroarch.sh
  install_emulationstation.sh
  configure_system.sh
config/
  kodi/                       - userdata with Estuary MOD V2 already active
  retroarch/retroarch.cfg     - global RetroArch config + controller binds
  emulationstation/           - es_systems.cfg, es_input.cfg
```

`pi-gen-stage/` exists because pi-gen requires a specific stage/step folder
shape (numbered subfolders, each with a `00-run-chroot.sh`) to know what to
run and when. The CI workflow copies it into a cloned pi-gen checkout as
`stage5-smarttv` and copies this repo's `scripts/` and `config/` folders
alongside it, so the actual install logic you'll want to read or edit lives
entirely in `scripts/` and `config/` as requested - `pi-gen-stage/` is just
thin plumbing that calls those scripts inside the chroot.

## Triggering a build

- **Automatic:** push to `main`. The workflow builds the image and
  publishes it as a new GitHub Release.
- **Manual:** open the **Actions** tab, choose "Build Raspberry Pi Smart TV
  / Retro image", click **Run workflow**. Tick "Publish a GitHub Release"
  if you want this run to also create a release; otherwise it just uploads
  a build artifact you can download from the run's summary page.

Use a **public** repository. GitHub Actions gives public repos unlimited
build minutes (still capped at 6 hours per job); on a private repo, a
single ~2-4 hour pi-gen build will eat a large chunk of the free tier's
2,000 monthly minutes.

## Downloading and flashing the image

1. Go to the repo's **Releases** page and download `smarttv-retro-pi1.img.gz`
   from the latest release (or grab it from the **Actions** run's artifacts
   if you triggered a manual build without publishing a release).
2. Flash it to a microSD card (8GB minimum, Class 10 recommended):
   - **Raspberry Pi Imager** (recommended): "Choose OS" -> "Use custom" ->
     select the downloaded `.img.gz` directly (Imager decompresses it for
     you) -> "Choose Storage" -> your SD card -> Write.
   - **balenaEtcher**: drag and drop the `.img.gz`, select your SD card,
     Flash.
   - **Command line (Linux/macOS)**:
     ```
     gunzip -c smarttv-retro-pi1.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
     ```
     Replace `/dev/sdX` with your SD card's device (double-check with
     `lsblk` first - this command overwrites the entire device).
3. Insert the card into the Pi 1, connect it to the TV via HDMI (or
   composite, if that's all your TV has - Kodi/RetroArch both work over
   composite, just lower resolution), plug in a controller, and power on.

First boot takes a couple of minutes longer than usual while the
filesystem expands to fill the SD card.

## Default credentials and first steps

- SSH user: `pi`, password: `raspberry`. **Change this immediately**
  (`passwd` over SSH) since SSH is on by default - leaving the stock
  password in place on a device reachable from your network is a real
  security risk.
- Kodi boots full-screen with Estuary MOD V2 active. The home screen
  includes "Retro Games" (launches EmulationStation) and "YouTube" as
  favourites.
- To get back to Kodi from EmulationStation, use the standard ES "Quit
  EmulationStation" option (default hotkey: hold **Start**, then **Select**,
  or press F4 if you have a keyboard attached) - the wrapper script
  (`/usr/local/bin/launch-emulationstation.sh`) detects when ES exits and
  restarts Kodi automatically.
- Copy ROMs onto the SD card under `/home/pi/RetroPie/roms/<system>/`
  (`nes`, `snes`, `gba`, `genesis`, `psx`, `n64`) over SSH/SCP, a USB
  stick, or by pulling the card and mounting it on another computer. No
  ROMs are included or downloaded by this repo - bring your own legally
  obtained files.
- Controllers: plug in (or pair, for Bluetooth pads) a generic Xbox-style
  controller. `xboxdrv` runs as a system service and exposes it as a
  standard joystick to both RetroArch and EmulationStation. If a pad isn't
  recognised correctly, EmulationStation's own input configurator (shown
  automatically the first time it doesn't recognise a device) will rebind
  it for you.

## Customizing

- Add/remove emulator cores: edit the `install_module` calls in
  `scripts/install_retroarch.sh` and the matching entries in
  `config/emulationstation/es_systems.cfg`. Core module names match
  RetroPie's own module IDs (browse them at
  [RetroPie-Setup/scriptmodules/libretrocores](https://github.com/RetroPie/RetroPie-Setup/tree/master/scriptmodules/libretrocores)).
- Change the default Kodi skin: edit `<skin>` in
  `config/kodi/guisettings.xml`.
- Change default credentials: edit `FIRST_USER_PASS` in the pi-gen config
  block inside `.github/workflows/build.yml`, and the matching `chpasswd`
  line in `scripts/configure_system.sh`.
- Target a Pi 2/3 instead for noticeably better performance: change
  `__platform=rpi1` to `rpi2`/`rpi3` in `scripts/install_retroarch.sh` and
  `scripts/install_emulationstation.sh`, switch `PI_GEN_BRANCH`/
  `PI_GEN_RELEASE` to `bullseye` or newer in `build.yml`, and you can then
  also bump Kodi past 18 since ARMv7/ARMv8 builds exist for current
  versions.

## Troubleshooting a build

- **Out of disk space on the runner:** the workflow already removes large
  preinstalled toolchains (.NET, Android SDK, GHC, etc.) before building.
  If you add a lot more software to the image and still hit this, look at
  trimming further with a tool like
  [easimon/maximize-build-space](https://github.com/easimon/maximize-build-space).
- **A `lr-*` core install logs a warning and continues:** that core has no
  prebuilt `rpi1` binary in RetroPie's binary repo at the time of the
  build, so the script fell back to compiling from source under QEMU
  emulation (slow) or, if that also failed, skipped the core entirely so
  the rest of the build isn't blocked. Check the job log for which step
  printed the warning.
- **Build exceeds the 6 hour GitHub Actions job limit:** the
  `RetroPie-Setup`/source-build fallback path is the most likely culprit,
  since compiling C/C++ under QEMU user-mode emulation is much slower than
  native compilation. Comment out a core you don't care about in
  `scripts/install_retroarch.sh` to shorten the build.

## License

MIT - see `LICENSE`. Kodi, the Estuary MOD V2 skin, the YouTube addon,
RetroArch, EmulationStation, and RetroPie-Setup are separate projects under
their own licenses, downloaded at build time from their respective
upstream sources; this repository does not redistribute their source code.
