#!/usr/bin/env python3
"""Correlate a lab download using Sysmon process, network and file events."""
import datetime as dt
import json
import os
import ssl
import sys
import urllib.request
from pathlib import Path

TARGET = r'c:\datn-t1105\incoming\t1105-lab-sample.txt'
EXPECTED_SHA256 = '613DBDF3F2E76FF5773E8A5C6D09D6278A907F985108E33DB7C62E772635A754'
STATE = Path('/opt/datn-t1105/state.json')

def call(url, data, headers, context=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers={'Content-Type':'application/json', **headers})
    with urllib.request.urlopen(req, context=context, timeout=30) as response:
        return response.status, json.load(response)

def event_time(hit):
    return dt.datetime.fromisoformat(hit['_source']['@timestamp'].replace('Z', '+00:00'))

def main():
    ca=ssl.create_default_context(cafile=os.environ['T1105_ES_CA'])
    query={'size':5000,'sort':[{'@timestamp':'desc'}], 'query':{'range':{'@timestamp':{'gte':'now-10m'}}}}
    _, result=call(os.environ['T1105_ES_URL'].rstrip('/')+'/datn-windows-*/_search',query,{'Authorization':'ApiKey '+os.environ['T1105_ES_API_KEY']},ca)
    if not result.get('_shards',{}).get('total'):
        raise RuntimeError('No searchable Windows shards')
    groups={}
    for hit in result['hits']['hits']:
        s=hit['_source']; w=s.get('winlog',{}); d=w.get('event_data',{})
        code=str(s.get('event',{}).get('code',w.get('event_id','')))
        host=s.get('host',{}).get('name') or w.get('computer_name')
        guid=d.get('ProcessGuid')
        if w.get('channel','').lower() != 'microsoft-windows-sysmon/operational' or not host or not guid:
            continue
        key=(host.lower(),guid.lower()); group=groups.setdefault(key,{'host':host,'guid':guid,'files':[],'nets':[],'procs':[]})
        if code=='11' and str(d.get('TargetFilename','')).lower()==TARGET:
            group['files'].append(hit)
        elif code=='3' and d.get('DestinationIp')=='192.168.10.102' and str(d.get('DestinationPort'))=='8088':
            group['nets'].append(hit)
        elif code=='1':
            group['procs'].append(hit)
    state=json.loads(STATE.read_text(encoding='utf-8')) if STATE.exists() else {}
    now=dt.datetime.now(dt.timezone.utc)
    state={k:v for k,v in state.items() if now-dt.datetime.fromisoformat(v)<dt.timedelta(hours=24)}
    findings=sent=0
    for group in groups.values():
        for fh in group['files']:
            matches=[nh for nh in group['nets'] if abs((event_time(fh)-event_time(nh)).total_seconds())<=60]
            if not matches:
                continue
            nh=min(matches,key=lambda x:abs((event_time(fh)-event_time(x)).total_seconds()))
            f=fh['_source']['winlog']['event_data']; n=nh['_source']['winlog']['event_data']
            alert={'technique':'T1105','host':group['host'],'user':str(f.get('User','unknown')).replace('\\','/'),
                'remote_ip':'192.168.10.102','remote_port':8088,'target_display':f['TargetFilename'].replace('\\','/'),
                'process_display':str(f.get('Image','unknown')).replace('\\','/'),'process_guid':group['guid'],
                'file_event_id':fh['_id'],'network_event_id':nh['_id'],'index':fh['_index'],
                'event_time':fh['_source']['@timestamp'],'expected_sha256':EXPECTED_SHA256,
                'decision':'LAB_AUTO_QUARANTINE','status':'DETECTED_PENDING_QUARANTINE','test_id':'T1105-LAB-AUTO'}
            findings+=1; print(json.dumps(alert,ensure_ascii=False))
            key=fh['_index']+'/'+fh['_id']
            if key in state: continue
            status, reply=call(os.environ['T1105_SHUFFLE_WEBHOOK'],alert,{})
            if status!=200 or not reply.get('success'): raise RuntimeError('Shuffle webhook did not accept')
            state[key]=now.isoformat(); STATE.parent.mkdir(parents=True,exist_ok=True)
            tmp=STATE.with_suffix('.tmp'); tmp.write_text(json.dumps(state),encoding='utf-8'); tmp.replace(STATE)
            sent+=1
    print(f"events={len(result['hits']['hits'])} findings={findings} notifications_sent={sent}")

if __name__=='__main__':
    try: main()
    except Exception as e:
        print('T1105 failed: '+str(e),file=sys.stderr); sys.exit(1)
