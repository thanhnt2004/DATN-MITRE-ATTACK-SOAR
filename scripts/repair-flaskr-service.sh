#!/usr/bin/env bash
set -euo pipefail

sed -i 's|^WorkingDirectory=.*|WorkingDirectory=/var/lib/flaskr|' /etc/systemd/system/flaskr.service
if ! grep -q '^Environment=HOME=' /etc/systemd/system/flaskr.service; then
  sed -i '/^Environment=PYTHONUNBUFFERED=1$/a Environment=HOME=/var/lib/flaskr' /etc/systemd/system/flaskr.service
fi
install -d -o www-data -g www-data -m 0750 /var/lib/flaskr/.gunicorn
systemctl daemon-reload
systemctl restart flaskr.service
systemctl --no-pager --full status flaskr.service
