#!/usr/bin/env bash
set -euo pipefail
cd /home/kali/t1105-http
exec python3 -m http.server 8088 --bind 192.168.10.102
