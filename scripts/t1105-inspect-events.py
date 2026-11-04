#!/usr/bin/env python3
import json, os, ssl, urllib.request
query = {'size': 3000, 'sort': [{'@timestamp': 'desc'}], 'query': {'range': {'@timestamp': {'gte': 'now-15m'}}}}
req = urllib.request.Request(os.environ['T1059_ES_URL'].rstrip('/') + '/datn-windows-*/_search', data=json.dumps(query).encode(), headers={'Authorization':'ApiKey '+os.environ['T1059_ES_API_KEY'], 'Content-Type':'application/json'})
with urllib.request.urlopen(req, context=ssl.create_default_context(cafile=os.environ['T1059_ES_CA']), timeout=30) as r:
    data = json.load(r)
for h in data['hits']['hits']:
    s=h['_source']; w=s.get('winlog', {}); d=w.get('event_data', {}); code=str(s.get('event', {}).get('code', w.get('event_id', '')))
    if code == '11' and 't1105-lab-sample.txt' in str(d.get('TargetFilename', '')).lower() or code == '3' and d.get('DestinationIp') == '192.168.10.102':
        print(json.dumps({'id':h['_id'],'index':h['_index'],'timestamp':s.get('@timestamp'),'event_code':code,'channel':w.get('channel'),'host':s.get('host',{}).get('name'),'data':{k:d.get(k) for k in ('Image','ProcessGuid','DestinationIp','DestinationPort','TargetFilename','User')}},ensure_ascii=False))
