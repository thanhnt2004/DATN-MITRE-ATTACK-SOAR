#!/usr/bin/env python3
"""Investigate encoded PowerShell process creation from Windows telemetry."""
import argparse
import datetime as dt
import json
import os
import re
import ssl
import sys
import urllib.request
from pathlib import Path

SWITCH = re.compile(r'(?i)(?:^|\s)[-/](?:e|enc|encodedcommand)(?:\s|:|$)')


def field(value, path):
    for item in path.split('.'):
        if not isinstance(value, dict):
            return None
        value = value.get(item)
    return value


def finding(hit):
    event = hit['_source']
    channel = field(event, 'winlog.channel') or ''
    code = field(event, 'event.code') or field(event, 'winlog.event_id')
    if str(code) != '1' or channel.lower() != 'microsoft-windows-sysmon/operational':
        return None
    image = field(event, 'winlog.event_data.Image') or field(event, 'process.executable') or ''
    command = field(event, 'winlog.event_data.CommandLine') or field(event, 'process.command_line') or ''
    if image.replace('/', '\\').split('\\')[-1].lower() not in ('powershell.exe', 'pwsh.exe') or not SWITCH.search(command):
        return None
    return {
        'host': field(event, 'host.name') or field(event, 'winlog.computer_name') or 'unknown',
        'user': field(event, 'winlog.event_data.User') or field(event, 'user.name') or 'unknown',
        'process': image,
        'parent': field(event, 'winlog.event_data.ParentImage') or field(event, 'process.parent.executable') or 'unknown',
        'event_time': event.get('@timestamp', 'unknown'),
        'rule': 'Encoded PowerShell process creation', 'risk': 'medium',
        'status': 'DETECTED_NOTIFY_ONLY', 'test_id': 'T1059-AUTO',
        'document_id': hit['_id'], 'index': hit['_index'],
    }


def request(url, data, headers, context=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers={'Content-Type': 'application/json', **headers})
    with urllib.request.urlopen(req, context=context, timeout=30) as response:
        return response.status, json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=Path)
    parser.add_argument('--send', action='store_true')
    parser.add_argument('--state-file', type=Path)
    args = parser.parse_args()
    if args.fixture:
        hits = json.loads(args.fixture.read_text(encoding='utf-8'))
    else:
        ca = ssl.create_default_context(cafile=os.environ['T1059_ES_CA'])
        query = {'size': 5000, 'sort': [{'@timestamp': 'desc'}], 'query': {'range': {'@timestamp': {'gte': 'now-5m'}}}}
        _, result = request(os.environ['T1059_ES_URL'].rstrip('/') + '/datn-windows-*/_search', query,
                            {'Authorization': 'ApiKey ' + os.environ['T1059_ES_API_KEY']}, ca)
        if not result.get('_shards', {}).get('total'):
            raise RuntimeError('No searchable Windows index shards')
        hits = result['hits']['hits']
    if args.send and (not args.state_file or not os.getenv('T1059_SHUFFLE_WEBHOOK')):
        parser.error('--send requires --state-file and T1059_SHUFFLE_WEBHOOK')
    state = json.loads(args.state_file.read_text(encoding='utf-8')) if args.state_file and args.state_file.exists() else {}
    now = dt.datetime.now(dt.timezone.utc)
    state = {k: v for k, v in state.items() if now - dt.datetime.fromisoformat(v) < dt.timedelta(hours=24)}
    matches = sent = 0
    for hit in reversed(hits):
        alert = finding(hit)
        if not alert:
            continue
        matches += 1
        print(json.dumps(alert, ensure_ascii=False))
        key = alert['index'] + '/' + alert['document_id']
        if args.send and key not in state:
            # Shuffle interpolates values into a JSON body. Windows backslashes
            # can otherwise be interpreted as JSON escapes such as \t.
            message = dict(alert)
            for field_name in ('user', 'process', 'parent'):
                message[field_name] = message[field_name].replace('\\', '/')
            status, result = request(os.environ['T1059_SHUFFLE_WEBHOOK'], message, {})
            if status != 200 or not result.get('success'):
                raise RuntimeError('Shuffle did not accept notification')
            state[key] = now.isoformat()
            args.state_file.parent.mkdir(parents=True, exist_ok=True)
            tmp = args.state_file.with_suffix('.tmp')
            tmp.write_text(json.dumps(state), encoding='utf-8')
            tmp.replace(args.state_file)
            sent += 1
    print(f'events={len(hits)} findings={matches} notifications_sent={sent}')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'T1059 detector failed: {exc}', file=sys.stderr)
        sys.exit(1)
