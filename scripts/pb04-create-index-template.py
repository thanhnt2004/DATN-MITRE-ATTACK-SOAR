#!/usr/bin/env python3
"""Install an Elasticsearch index template for DATN DNS telemetry."""
import base64
import json
import os
import ssl
import urllib.request

url = os.environ["PB04_ES_URL"].rstrip("/")
user = os.environ["PB04_BOOTSTRAP_USER"]
password = os.environ["PB04_BOOTSTRAP_PASSWORD"]
ca = os.environ["PB04_ES_CA"]
auth = base64.b64encode(f"{user}:{password}".encode()).decode()
body = {
    "index_patterns": ["datn-dns-*"], "priority": 250,
    "template": {"mappings": {"properties": {
        "@timestamp": {"type": "date"},
        "source": {"properties": {"ip": {"type": "ip"}}},
        "destination": {"properties": {"ip": {"type": "ip"}}},
        "dns": {"properties": {
            "type": {"type": "keyword"}, "response_code": {"type": "keyword"},
            "question": {"properties": {
                "name": {"type": "keyword", "ignore_above": 512},
                "etld_plus_one": {"type": "keyword"},
                "type": {"type": "keyword"},
            }},
        }},
        "fields": {"properties": {"log_source": {"type": "keyword"}}},
        "host": {"properties": {"name": {"type": "keyword"}}},
    }}},
}
request = urllib.request.Request(
    f"{url}/_index_template/datn-dns-pb04", data=json.dumps(body).encode(),
    headers={"Authorization": "Basic " + auth, "Content-Type": "application/json"}, method="PUT",
)
with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=ca), timeout=20) as response:
    result = json.load(response)
print(f"template_acknowledged={result.get('acknowledged', False)}")
