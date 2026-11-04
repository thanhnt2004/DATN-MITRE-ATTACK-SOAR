#!/usr/bin/env python3
"""Provision a read-only Elasticsearch key and the PB01 service environment."""
import base64
import json
import os
import ssl
import urllib.request
from pathlib import Path

url = os.environ["PB01_ES_URL"].rstrip("/")
user = os.environ["PB01_BOOTSTRAP_USER"]
password = os.environ["PB01_BOOTSTRAP_PASSWORD"]
webhook = os.environ["PB01_SHUFFLE_WEBHOOK"]
ca = os.environ["PB01_ES_CA"]
auth = base64.b64encode(f"{user}:{password}".encode()).decode()
body = {
    "name": "datn-pb01-read-auth-logs",
    "role_descriptors": {
        "pb01_reader": {
            "indices": [{"names": ["datn-ubuntu-*", "datn-windows-*"], "privileges": ["read", "view_index_metadata"]}]
        }
    },
}
request = urllib.request.Request(
    f"{url}/_security/api_key", data=json.dumps(body).encode(),
    headers={"Authorization": f"Basic {auth}", "Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=ca), timeout=20) as response:
    result = json.load(response)
encoded_key = result["encoded"]
target = Path("/opt/datn-pb01/pb01.env")
os.umask(0o077)
target.write_text(
    f"PB01_ES_URL={url}\nPB01_ES_API_KEY={encoded_key}\nPB01_ES_CA={ca}\n"
    f"PB01_SHUFFLE_WEBHOOK={webhook}\n", encoding="utf-8"
)
target.chmod(0o600)
print(f"api_key_created_id={result['id']} env_file={target}")
