#!/usr/bin/env bash
set -euo pipefail
resolver="${1:?resolver}"
domain="${2:?domain}"
count="${3:?count}"
case "$count" in ''|*[!0-9]*) echo 'query_count must be numeric' >&2; exit 2;; esac
if (( count < 1 || count > 100 )); then echo 'query_count must be 1..100' >&2; exit 2; fi
if [[ "$domain" != *.test ]]; then echo 'domain must end in .test' >&2; exit 2; fi
run_id="$(date -u +%Y%m%d%H%M%S)"
echo "pb04_start_utc=$(date -u +%FT%TZ) resolver=$resolver domain=$domain count=$count run_id=$run_id"
for (( i=1; i<=count; i++ )); do
  label="$(printf 'pb04%s%02d%036d' "$run_id" "$i" "$i")"
  dig "@$resolver" "$label.$domain" TXT +time=1 +tries=1 +noall >/dev/null 2>&1 || true
  sleep 0.2
done
echo "pb04_end_utc=$(date -u +%FT%TZ) queries_sent=$count"
