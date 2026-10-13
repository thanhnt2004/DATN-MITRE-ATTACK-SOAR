#!/usr/bin/env bash
set -euo pipefail

elk_host=18.139.50.205
pfsense_ip=192.168.10.1
filebeat_version=9.5.4
stamp=$(date +%Y%m%d-%H%M%S)
ca_source=/tmp/datn-logstash-ca.crt

if [[ ! -s "$ca_source" ]]; then
  echo "Missing CA certificate: $ca_source" >&2
  exit 1
fi

for required_command in curl rsyslogd; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

if ! command -v filebeat >/dev/null 2>&1; then
  cd /tmp
  curl -fsSLO "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${filebeat_version}-amd64.deb"
  sudo dpkg -i "filebeat-${filebeat_version}-amd64.deb"
fi

sudo install -d -o root -g root -m 0755 /etc/filebeat/certs
sudo install -o root -g root -m 0644 "$ca_source" /etc/filebeat/certs/ca.crt

if [[ -f /etc/filebeat/filebeat.yml ]]; then
  sudo cp -a /etc/filebeat/filebeat.yml "/etc/filebeat/filebeat.yml.bak-$stamp"
fi

sudo tee /etc/filebeat/filebeat.yml >/dev/null <<FILEBEAT
filebeat.inputs:
  - type: filestream
    id: ubuntu-system
    enabled: true
    paths:
      - /var/log/syslog
      - /var/log/auth.log
    fields:
      log_source: ubuntu

  - type: filestream
    id: ubuntu-nginx
    enabled: true
    paths:
      - /var/log/nginx/flaskr_access.log
      - /var/log/nginx/flaskr_error.log
    fields:
      log_source: ubuntu

  - type: filestream
    id: pfsense-relay
    enabled: true
    paths:
      - /var/log/pfsense.log
    fields:
      log_source: pfsense

processors:
  - add_host_metadata: ~

output.logstash:
  hosts: ["${elk_host}:5044"]
  ssl.certificate_authorities:
    - /etc/filebeat/certs/ca.crt
FILEBEAT

if [[ -f /etc/rsyslog.d/30-pfsense.conf ]]; then
  sudo cp -a /etc/rsyslog.d/30-pfsense.conf "/etc/rsyslog.d/30-pfsense.conf.bak-$stamp"
fi

sudo tee /etc/rsyslog.d/30-pfsense.conf >/dev/null <<'RSYSLOG'
module(load="imudp")

template(name="pfSenseRaw" type="string" string="%rawmsg%\n")

ruleset(name="pfSenseRemote") {
  action(
    type="omfile"
    file="/var/log/pfsense.log"
    template="pfSenseRaw"
    fileCreateMode="0640"
    fileOwner="syslog"
    fileGroup="adm"
  )
  stop
}

input(type="imudp" port="5514" ruleset="pfSenseRemote")
RSYSLOG

sudo install -o syslog -g adm -m 0640 /dev/null /var/log/pfsense.log
sudo rsyslogd -N1
sudo systemctl restart rsyslog

if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow from "$pfsense_ip" to any port 5514 proto udp comment 'pfSense syslog relay' >/dev/null
fi

sudo filebeat test config -e
sudo filebeat test output -e
sudo systemctl enable --now filebeat

logger -p auth.notice -t datn-ingest "DATN_UBUNTU_INGEST_TEST_$stamp"
logger --udp --server 127.0.0.1 --port 5514 --tag filterlog "DATN_PFSENSE_RELAY_TEST_$stamp"
sleep 8

echo "=== SERVICES ==="
systemctl is-active rsyslog filebeat
systemctl is-enabled filebeat
echo "=== LISTENER ==="
sudo ss -lunp | grep ':5514 '
echo "=== FILEBEAT ==="
sudo filebeat version
sudo journalctl -u filebeat -n 60 --no-pager
echo "=== PFSENSE RELAY FILE ==="
sudo tail -n 10 /var/log/pfsense.log
echo "BACKUP_FILEBEAT=/etc/filebeat/filebeat.yml.bak-$stamp"
echo "BACKUP_RSYSLOG=/etc/rsyslog.d/30-pfsense.conf.bak-$stamp"
