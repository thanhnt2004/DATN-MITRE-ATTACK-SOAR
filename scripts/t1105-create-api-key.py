#!/usr/bin/env python3
"""Create a least-privilege Windows telemetry reader for the T1105 detector."""
import base64
import json
import os
import ssl
import urllib.request
from pathlib import Path

url = os.environ['T1105_ES_URL'].rstrip('/')
ca = os.environ['T1105_ES_CA']
credentials = f"{os.environ['T1105_BOOTSTRAP_USER']}:{os.environ['T1105_BOOTSTRAP_PASSWORD']}"
body = {'name': 'datn-t1105-windows-reader', 'role_descriptors': {'windows_reader': {
    'indices': [{'names': ['datn-windows-*'], 'privileges': ['read', 'view_index_metadata']}]}}}
req = urllib.request.Request(url + '/_security/api_key', method='POST', data=json.dumps(body).encode(),
    headers={'Authorization': 'Basic ' + base64.b64encode(credentials.encode()).decode(), 'Content-Type': 'application/json'})
with urllib.request.urlopen(req, context=ssl.create_default_context(cafile=ca), timeout=30) as response:
    result = json.load(response)
os.umask(0o077)
target = Path('/opt/datn-t1105/t1105.env')
target.write_text(f"T1105_ES_URL={url}\nT1105_ES_CA={ca}\nT1105_ES_API_KEY={result['encoded']}\n"
                  f"T1105_SHUFFLE_WEBHOOK={os.environ['T1105_SHUFFLE_WEBHOOK']}\n", encoding='utf-8')
target.chmod(0o600)
print(f"api_key_id={result['id']} env_file={target}")
