#!/usr/bin/env python3
"""Print sanitized PB04 DNS document evidence from Elasticsearch."""
import json
import os
import ssl
import urllib.request

from pb04_dns_detector import field

query = {
    "size": 5000, "sort": [{"@timestamp": "desc"}],
    "query": {"bool": {"filter": [
        {"range": {"@timestamp": {"gte": "now-30m"}}},
    ]}},
}
request = urllib.request.Request(
    os.environ["PB04_ES_URL"].rstrip("/") + "/datn-dns-*/_search",
    data=json.dumps(query).encode(),
    headers={"Authorization": "ApiKey " + os.environ["PB04_ES_API_KEY"], "Content-Type": "application/json"},
)
with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=os.environ["PB04_ES_CA"]), timeout=20) as response:
    result = json.load(response)
selected = [hit for hit in result["hits"]["hits"] if str(field(hit["_source"], "dns.question.name") or "").endswith(".pb04-datn.test")]
print(json.dumps({"total": result["hits"]["total"], "shards": result["_shards"]["total"], "pb04_events": len(selected)}))
for hit in selected[:5]:
    event = hit["_source"]
    print(json.dumps({
        "id": hit["_id"], "index": hit["_index"], "timestamp": event.get("@timestamp"),
        "source_ip": field(event, "source.ip"), "qname": field(event, "dns.question.name"),
        "rcode": field(event, "dns.response_code"), "dns_type": field(event, "dns.type"),
        "log_source": field(event, "fields.log_source"),
    }))
