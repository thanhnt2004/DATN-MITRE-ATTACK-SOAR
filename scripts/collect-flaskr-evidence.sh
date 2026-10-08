#!/usr/bin/env bash
set -euo pipefail

output=/tmp/flaskr-evidence.txt
base_url=${BASE_URL:-http://127.0.0.1}

{
  echo "=== DEPLOYMENT ==="
  echo "timestamp=$(date --iso-8601=seconds)"
  echo "hostname=$(hostname)"
  echo "commit=$(git -C /opt/flaskr-upstream rev-parse HEAD)"

  echo "=== HTTP REQUESTS ==="
  for path in / /auth/login /auth/register /not-found-lab; do
    code=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' "${base_url}${path}")
    echo "$path $code"
  done

  echo "=== SERVICES ==="
  echo "flaskr_active=$(systemctl is-active flaskr.service)"
  echo "flaskr_enabled=$(systemctl is-enabled flaskr.service)"
  echo "nginx_active=$(systemctl is-active nginx.service)"
  echo "nginx_enabled=$(systemctl is-enabled nginx.service)"

  echo "=== LISTENERS ==="
  ss -lnt | grep -E ':80 |:8000 '

  echo "=== SQLITE DATA ==="
  sqlite3 /var/lib/flaskr/flaskr.sqlite '.tables'
  sqlite3 -header -column /var/lib/flaskr/flaskr.sqlite 'SELECT COUNT(*) AS users FROM user; SELECT COUNT(*) AS posts FROM post;'
  sha256sum /var/lib/flaskr/flaskr.sqlite

  echo "=== NGINX LOG ==="
  tail -n 20 /var/log/nginx/flaskr_access.log
  journalctl -u flaskr.service -n 40 --no-pager
} > "$output" 2>&1

chmod 0644 "$output"
