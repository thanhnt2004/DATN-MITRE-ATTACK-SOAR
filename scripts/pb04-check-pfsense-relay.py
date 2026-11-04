#!/usr/bin/env python3
"""Verify that a pfSense DNS query log reached datn-pfsense-* via the Ubuntu relay."""
import base64
import json
import os
import ssl
import urllib.request

url = os.environ["PB04_ES_URL"].rstrip("/")
user = os.environ["PB04_BOOTSTRAP_USER"]
password = os.environ["PB04_BOOTSTRAP_PASSWORD"]
ca = os.environ["PB04_ES_CA"]
marker = os.environ.get("PB04_DNS_MARKER", "pb04-pfsense-probe-20261103")
auth = base64.b64encode(f"{user}:{password}".encode()).decode()
query = {
    "size": 10,
    "query": {"bool": {"filter": [{"range": {"@timestamp": {"gte": "now-15m"}}}],
                       "must": [{"match_phrase": {"message": marker}}]}},
}
request = urllib.request.Request(
    f"{url}/datn-pfsense-*/_search", data=json.dumps(query).encode(),
    headers={"Authorization": "Basic " + auth, "Content-Type": "application/json"},
)
with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=ca), timeout=20) as response:
    result = json.load(response)
print(json.dumps({"total": result["hits"]["total"], "shards": result["_shards"]["total"]}))
for hit in result["hits"]["hits"]:
    source = hit["_source"]
    print(json.dumps({"id": hit["_id"], "index": hit["_index"], "timestamp": source.get("@timestamp"),
                      "marker_present": marker in str(source.get("message", "")),
                      "log_source": source.get("fields", {}).get("log_source")}, ensure_ascii=False))
