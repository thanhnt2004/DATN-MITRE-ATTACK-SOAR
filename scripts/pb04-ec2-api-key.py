#!/usr/bin/env python3
"""Create a scoped DNS reader key and PB04 environment on the EC2 host."""
import base64
import json
import os
import ssl
import urllib.request
from pathlib import Path

url = os.environ["PB04_ES_URL"].rstrip("/")
user = os.environ["PB04_BOOTSTRAP_USER"]
password = os.environ["PB04_BOOTSTRAP_PASSWORD"]
ca = os.environ["PB04_ES_CA"]
webhook = os.environ["PB04_SHUFFLE_WEBHOOK"]
auth = base64.b64encode(f"{user}:{password}".encode()).decode()
body = {
    "name": "datn-pb04-read-dns",
    "role_descriptors": {
        "pb04_reader": {
            "indices": [{"names": ["datn-dns-*"], "privileges": ["read", "view_index_metadata"]}]
        }
    },
}
request = urllib.request.Request(
    f"{url}/_security/api_key", data=json.dumps(body).encode(),
    headers={"Authorization": f"Basic {auth}", "Content-Type": "application/json"}, method="POST",
)
with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=ca), timeout=20) as response:
    result = json.load(response)
os.umask(0o077)
target = Path("/opt/datn-pb04/pb04.env")
target.write_text(
    f"PB04_ES_URL={url}\nPB04_ES_API_KEY={result['encoded']}\nPB04_ES_CA={ca}\n"
    f"PB04_SHUFFLE_WEBHOOK={webhook}\n", encoding="utf-8"
)
target.chmod(0o600)
print(f"api_key_created_id={result['id']} env_file={target}")
