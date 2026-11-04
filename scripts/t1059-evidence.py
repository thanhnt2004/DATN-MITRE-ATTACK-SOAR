#!/usr/bin/env python3
"""Summarize recent Windows telemetry without printing command or script bodies."""
import json
import os
import ssl
import urllib.request
from collections import Counter

query = {'size': 5000, 'query': {'range': {'@timestamp': {'gte': 'now-10m'}}}}
req = urllib.request.Request(os.environ['T1059_ES_URL'].rstrip('/') + '/datn-windows-*/_search',
    data=json.dumps(query).encode(), headers={'Authorization': 'ApiKey ' + os.environ['T1059_ES_API_KEY'],
    'Content-Type': 'application/json'})
with urllib.request.urlopen(req, context=ssl.create_default_context(cafile=os.environ['T1059_ES_CA']), timeout=30) as response:
    result = json.load(response)
counts = Counter()
for hit in result['hits']['hits']:
    src = hit['_source']
    channel = src.get('winlog', {}).get('channel', '')
    code = str(src.get('event', {}).get('code', src.get('winlog', {}).get('event_id', '')))
    counts[(channel, code)] += 1
print(json.dumps({'total': result['hits']['total'], 'events_by_channel_code': [
    {'channel': k[0], 'event_code': k[1], 'count': v} for k, v in sorted(counts.items())]}))
