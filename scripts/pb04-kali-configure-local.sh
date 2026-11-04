#!/usr/bin/env bash
set -euo pipefail
run_root() { printf '%s\n' "$PB04_SUDO_PASSWORD" | sudo -S "$@"; }
run_root cp -n /etc/packetbeat/packetbeat.yml /etc/packetbeat/packetbeat.yml.pre-pb04
run_root install -d -m 0750 -o root -g root /var/lib/packetbeat/pb04-local
run_root install -m 0640 -o root -g root /tmp/packetbeat-pb04-local.yml /etc/packetbeat/packetbeat.yml
run_root packetbeat test config -c /etc/packetbeat/packetbeat.yml
run_root systemctl enable --now packetbeat
run_root systemctl restart packetbeat
systemctl is-active packetbeat
