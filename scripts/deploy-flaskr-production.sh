#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

repo_dir=/opt/flaskr-upstream
venv_dir=/opt/flaskr-venv
data_dir=/var/lib/flaskr
instance_dir="$venv_dir/var/flaskr-instance"
site_config=/etc/nginx/sites-available/flaskr-app
flask_commit=d086db856be187255b8ec61ef409357393020f32

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git nginx python3-pip python3-venv sqlite3

git clone --filter=blob:none --sparse https://github.com/pallets/flask.git "$repo_dir"
git -C "$repo_dir" sparse-checkout set examples/tutorial
git -C "$repo_dir" fetch --depth 1 origin "$flask_commit"
git -C "$repo_dir" checkout --detach "$flask_commit"

python3 -m venv "$venv_dir"
"$venv_dir/bin/pip" install --disable-pip-version-check --no-cache-dir "$repo_dir/examples/tutorial" gunicorn

install -d -o www-data -g www-data -m 0750 "$data_dir"
install -d -o root -g www-data -m 0750 "$instance_dir"
secret_key=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
printf 'SECRET_KEY = "%s"\nDATABASE = "%s/flaskr.sqlite"\n' "$secret_key" "$data_dir" > "$instance_dir/config.py"
chown root:www-data "$instance_dir/config.py"
chmod 0640 "$instance_dir/config.py"

runuser -u www-data -- "$venv_dir/bin/flask" --app flaskr init-db
chown www-data:www-data "$data_dir/flaskr.sqlite"
chmod 0640 "$data_dir/flaskr.sqlite"

cat > /etc/systemd/system/flaskr.service <<'SYSTEMD'
[Unit]
Description=Flaskr production web application
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/lib/flaskr
Environment=PATH=/opt/flaskr-venv/bin
Environment=PYTHONUNBUFFERED=1
Environment=HOME=/var/lib/flaskr
ExecStart=/opt/flaskr-venv/bin/gunicorn --workers 2 --threads 2 --timeout 30 --bind 127.0.0.1:8000 --access-logfile - --error-logfile - --capture-output --log-level info flaskr:create_app()
Restart=on-failure
RestartSec=3
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/flaskr
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
SYSTEMD

cat > "$site_config" <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    server_tokens off;
    client_max_body_size 1m;
    access_log /var/log/nginx/flaskr_access.log;
    error_log /var/log/nginx/flaskr_error.log warn;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 30s;
    }
}
NGINX

ln -sfn "$site_config" /etc/nginx/sites-enabled/flaskr-app
rm -f /etc/nginx/sites-enabled/default
systemctl daemon-reload
systemctl enable --now flaskr.service
nginx -t
systemctl reload nginx
curl --fail --silent --show-error http://127.0.0.1/ >/dev/null

echo "DEPLOY_OK"
echo "COMMIT=$(git -C "$repo_dir" rev-parse HEAD)"
