#!/usr/bin/env bash
set -euo pipefail

elk_root=/opt/elk
pipeline="$elk_root/logstash/pipeline/logstash.conf"
compose="$elk_root/docker-compose.yml"
cert_dir="$elk_root/logstash/certs"
stamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$elk_root/backups/$stamp"
elk_public_ip=18.139.50.205

sudo install -d -m 0750 -o 1000 -g 1000 "$cert_dir"
sudo install -d -m 0750 -o root -g root "$backup_dir"
sudo cp -a "$pipeline" "$backup_dir/logstash.conf"
sudo cp -a "$compose" "$backup_dir/docker-compose.yml"

if [[ ! -s "$cert_dir/ca.crt" || ! -s "$cert_dir/logstash.crt" || ! -s "$cert_dir/logstash.pkcs8.key" ]]; then
  sudo openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -subj '/CN=DATN Log Ingest CA' \
    -keyout "$cert_dir/ca.key" \
    -out "$cert_dir/ca.crt"

  sudo openssl req -newkey rsa:2048 -nodes \
    -subj '/CN=datn-logstash' \
    -addext "subjectAltName=IP:$elk_public_ip,DNS:datn-logstash" \
    -keyout "$cert_dir/logstash.key" \
    -out "$cert_dir/logstash.csr"

  sudo openssl x509 -req -sha256 -days 825 \
    -in "$cert_dir/logstash.csr" \
    -CA "$cert_dir/ca.crt" \
    -CAkey "$cert_dir/ca.key" \
    -CAcreateserial \
    -copy_extensions copy \
    -out "$cert_dir/logstash.crt"

  sudo openssl pkcs8 -topk8 -nocrypt \
    -in "$cert_dir/logstash.key" \
    -out "$cert_dir/logstash.pkcs8.key"
fi

sudo chown 1000:1000 "$cert_dir/ca.crt" "$cert_dir/logstash.crt" "$cert_dir/logstash.pkcs8.key"
sudo chown 1000:1000 "$cert_dir"
sudo chmod 0644 "$cert_dir/ca.crt" "$cert_dir/logstash.crt"
sudo chmod 0640 "$cert_dir/logstash.pkcs8.key"
sudo chmod 0600 "$cert_dir/ca.key" "$cert_dir/logstash.key" 2>/dev/null || true

sudo tee "$pipeline" >/dev/null <<'LOGSTASH'
input {
  beats {
    id => "datn-beats-tls"
    port => 5044
    ssl_enabled => true
    ssl_certificate => "/usr/share/logstash/certs/logstash.crt"
    ssl_key => "/usr/share/logstash/certs/logstash.pkcs8.key"
  }
}

filter {
}

output {
  if [fields][log_source] == "ubuntu" {
    elasticsearch {
      hosts => ["http://elasticsearch:9200"]
      index => "datn-ubuntu-%{+YYYY.MM.dd}"
    }
  } else if [fields][log_source] == "pfsense" {
    elasticsearch {
      hosts => ["http://elasticsearch:9200"]
      index => "datn-pfsense-%{+YYYY.MM.dd}"
    }
  } else if [fields][log_source] == "windows" or [agent][type] == "winlogbeat" {
    elasticsearch {
      hosts => ["http://elasticsearch:9200"]
      index => "datn-windows-%{+YYYY.MM.dd}"
    }
  } else {
    elasticsearch {
      hosts => ["http://elasticsearch:9200"]
      index => "datn-other-%{+YYYY.MM.dd}"
    }
  }

  stdout {
    codec => rubydebug
  }
}
LOGSTASH

if ! sudo grep -q '/usr/share/logstash/certs:ro' "$compose"; then
  sudo sed -i '/\.\/logstash\/pipeline:\/usr\/share\/logstash\/pipeline:ro/a\      - ./logstash/certs:/usr/share/logstash/certs:ro' "$compose"
fi

cd "$elk_root"
sudo docker compose config >/dev/null
sudo docker compose up -d logstash

for _ in $(seq 1 30); do
  if sudo docker logs datn-logstash --tail 80 2>&1 | grep -q 'Pipelines running'; then
    break
  fi
  sleep 2
done

sudo docker ps --filter name=datn-logstash --format '{{.Names}} {{.Status}}'
sudo docker logs datn-logstash --tail 80 2>&1
echo "BACKUP_PIPELINE=$backup_dir/logstash.conf"
echo "BACKUP_COMPOSE=$backup_dir/docker-compose.yml"
echo "CA_CERT=$cert_dir/ca.crt"
