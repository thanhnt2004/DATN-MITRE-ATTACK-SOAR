#!/usr/bin/env bash
set -euo pipefail
run_root() { printf '%s\n' "$PB04_SUDO_PASSWORD" | sudo -S "$@"; }
run_root install -d -m 0755 -o root -g root /etc/packetbeat/certs
run_root install -m 0644 -o root -g root /tmp/pb04-logstash-ca.crt /etc/packetbeat/certs/ca.crt
run_root install -m 0640 -o root -g root /tmp/packetbeat-pb04-logstash.yml /etc/packetbeat/packetbeat.yml
run_root packetbeat test config -c /etc/packetbeat/packetbeat.yml
run_root systemctl restart packetbeat
systemctl is-active packetbeat
