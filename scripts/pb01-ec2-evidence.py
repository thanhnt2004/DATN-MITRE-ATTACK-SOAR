#!/usr/bin/env python3
"""Print sanitized Elasticsearch document evidence for recent PB01 SSH failures."""
import json
import os
import ssl
import urllib.request

from pb01_password_spraying import normalize

query = {
    "size": 100,
    "sort": [{"@timestamp": "desc"}],
    "query": {"bool": {"filter": [{"range": {"@timestamp": {"gte": "now-30m"}}}],
                       "must": [{"match_phrase": {"message": "Failed password"}}]}},
}
request = urllib.request.Request(
    os.environ["PB01_ES_URL"].rstrip("/") + "/datn-ubuntu-*/_search",
    data=json.dumps(query).encode(),
    headers={"Authorization": "ApiKey " + os.environ["PB01_ES_API_KEY"], "Content-Type": "application/json"},
)
context = ssl.create_default_context(cafile=os.environ["PB01_ES_CA"])
with urllib.request.urlopen(request, context=context, timeout=20) as response:
    result = json.load(response)
for hit in result["hits"]["hits"]:
    row = normalize(hit["_source"])
    if row and row["ip"] == "192.168.10.102":
        print(json.dumps({"id": hit["_id"], "index": hit["_index"], "timestamp": row["when"].isoformat(),
                          "source_ip": row["ip"], "user": row["user"], "host": row["host"]}))
