#!/usr/bin/env bash
set -euo pipefail

base_url=${BASE_URL:-http://127.0.0.1}
cookie_jar=$(mktemp)
demo_password=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')
trap 'rm -f "$cookie_jar"' EXIT

curl --fail --silent --show-error --request POST \
  --data-urlencode 'username=system-demo' \
  --data-urlencode "password=$demo_password" \
  "$base_url/auth/register" >/dev/null

curl --fail --silent --show-error --cookie-jar "$cookie_jar" --request POST \
  --data-urlencode 'username=system-demo' \
  --data-urlencode "password=$demo_password" \
  "$base_url/auth/login" >/dev/null

curl --fail --silent --show-error --cookie "$cookie_jar" --request POST \
  --data-urlencode 'title=DATN Web Server Ready' \
  --data-urlencode 'body=Flaskr is running behind Nginx and pfSense. Logs are enabled.' \
  "$base_url/create" >/dev/null

echo "SEED_OK"
