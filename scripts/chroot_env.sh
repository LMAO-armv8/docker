#!/bin/bash
# Environment for scripts running inside the pi-gen QEMU chroot.
# systemctl without SYSTEMD_OFFLINE=1 can talk to the build host's systemd
# and leave processes holding the bind-mounted /dev tree busy at stage end.

export SYSTEMD_OFFLINE=1
export DEBIAN_FRONTEND=noninteractive

is_pi_gen_build() {
  [[ -f /usr/sbin/policy-rc.d ]]
}
