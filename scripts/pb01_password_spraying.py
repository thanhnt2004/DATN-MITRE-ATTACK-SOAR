#!/usr/bin/env python3
"""PB01 T1110.003 detector. Reads Elastic auth events or an offline JSONL fixture."""

import argparse
import base64
import datetime as dt
import ipaddress
import json
import os
import re
import ssl
import sys
import urllib.request
from pathlib import Path

WINDOW = dt.timedelta(minutes=5)
USER_RE = re.compile(r"(?:Failed password for (?:invalid user )?|authentication failure.*?user=)([\w.@-]+)", re.I)
IP_RE = re.compile(r"\b(?:from |rhost=)((?:\d{1,3}\.){3}\d{1,3})\b", re.I)


def elastic_search(url, index, user, password, ca_file, api_key=None):
    now = dt.datetime.now(dt.timezone.utc)
    query = {
        "size": 1000,
        "sort": [{"@timestamp": "desc"}],
        "query": {"bool": {
            "filter": [{"range": {"@timestamp": {"gte": (now - WINDOW).isoformat()}}}],
            "should": [
                {"term": {"event.code": "4625"}},
                {"term": {"winlog.event_id": 4625}},
                {"match_phrase": {"message": "Failed password"}},
                {"match_phrase": {"message": "authentication failure"}},
            ],
            "minimum_should_match": 1,
        }},
    }
    auth = f"ApiKey {api_key}" if api_key else "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()
    request = urllib.request.Request(
        f"{url.rstrip('/')}/{index}/_search",
        data=json.dumps(query).encode(),
        headers={"Authorization": auth, "Content-Type": "application/json"},
    )
    context = ssl.create_default_context(cafile=ca_file) if ca_file else ssl.create_default_context()
    with urllib.request.urlopen(request, context=context, timeout=20) as response:
        result = json.load(response)
    if result.get("_shards", {}).get("total", 0) == 0:
        raise RuntimeError("Elasticsearch returned zero searchable shards; verify reader permissions and index pattern")
    return [hit["_source"] for hit in result["hits"]["hits"]]


def get_value(event, *paths):
    for path in paths:
        value = event
        for key in path.split("."):
            value = value.get(key) if isinstance(value, dict) else None
        if value is not None and value != "":
            return value
    return None


def normalize(event):
    code = str(get_value(event, "event.code", "winlog.event_id") or "")
    message = str(event.get("message") or "")
    if code != "4625" and not re.search(r"Failed password|authentication failure", message, re.I):
        return None
    ip = get_value(event, "source.ip", "client.ip", "winlog.event_data.IpAddress")
    user = get_value(event, "user.name", "winlog.event_data.TargetUserName")
    if not ip:
        match = IP_RE.search(message)
        ip = match.group(1) if match else None
    if not user:
        match = USER_RE.search(message)
        user = match.group(1) if match else None
    try:
        parsed_ip = ipaddress.ip_address(str(ip))
    except ValueError:
        return None
    if parsed_ip.is_loopback or parsed_ip.is_unspecified or not user or user == "-":
        return None
    timestamp = event.get("@timestamp")
    if not timestamp:
        return None
    when = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    return {"ip": str(parsed_ip), "user": str(user).lower(), "when": when, "host": str(get_value(event, "host.name") or "unknown")}


def detect(events, threshold=5, allowlist=()):
    rows = [row for event in events if (row := normalize(event)) is not None]
    allowed = set(allowlist)
    findings = []
    for ip in sorted({row["ip"] for row in rows} - allowed):
        stream = sorted((row for row in rows if row["ip"] == ip), key=lambda row: row["when"])
        for pos, first in enumerate(stream):
            window = [row for row in stream[pos:] if row["when"] - first["when"] <= WINDOW]
            users = sorted({row["user"] for row in window})
            if len(users) >= threshold:
                findings.append({
                    "technique": "T1110.003", "source_ip": ip,
                    "distinct_user_count": len(users), "failed_authentication_count": len(window),
                    "users": users, "hosts": sorted({row["host"] for row in window}),
                    "event_start": first["when"].isoformat(), "event_end": window[-1]["when"].isoformat(),
                    "status": "DETECTED_NOTIFY_ONLY",
                })
                break
    return findings


def send_webhook(url, finding, test_id, attack_source, atomic_guid):
    payload = {**finding, "playbook_id": "PB01", "test_id": test_id,
               "source": "Elastic authentication logs", "attack_source": attack_source,
               "atomic_guid": atomic_guid or "N/A",
               "hosts_text": ", ".join(finding["hosts"]) or "unknown"}
    request = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return {"http_status": response.status, "accepted": json.load(response).get("success", False)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, help="Offline JSONL events for validation")
    parser.add_argument("--index", default="datn-ubuntu-*,datn-windows-*")
    parser.add_argument("--threshold", type=int, default=5)
    parser.add_argument("--allow-ip", action="append", default=[])
    parser.add_argument("--test-id", default="PB01-LIVE")
    parser.add_argument("--attack-source", default="unspecified")
    parser.add_argument("--atomic-guid", default="")
    parser.add_argument("--send", action="store_true", help="Send a qualifying finding to Shuffle")
    parser.add_argument("--state-file", type=Path, help="JSON state used to suppress repeat notifications for five minutes")
    args = parser.parse_args()
    if args.fixture:
        events = [json.loads(line) for line in args.fixture.read_text(encoding="utf-8").splitlines() if line.strip()]
    else:
        if not os.getenv("PB01_ES_URL"):
            parser.error("PB01_ES_URL is required for live mode")
        if not os.getenv("PB01_ES_API_KEY") and (not os.getenv("PB01_ES_USER") or not os.getenv("PB01_ES_PASSWORD")):
            parser.error("PB01_ES_API_KEY or PB01_ES_USER/PB01_ES_PASSWORD is required for live mode")
        events = elastic_search(os.environ["PB01_ES_URL"], args.index, os.getenv("PB01_ES_USER"), os.getenv("PB01_ES_PASSWORD"), os.getenv("PB01_ES_CA"), os.getenv("PB01_ES_API_KEY"))
    findings = detect(events, args.threshold, args.allow_ip)
    if args.send and not os.getenv("PB01_SHUFFLE_WEBHOOK"):
        parser.error("PB01_SHUFFLE_WEBHOOK is required with --send")
    if args.send and not args.state_file:
        parser.error("--state-file is required with --send to suppress duplicate notifications")
    state = json.loads(args.state_file.read_text(encoding="utf-8")) if args.state_file and args.state_file.exists() else {}
    now = dt.datetime.now(dt.timezone.utc)
    sent = 0
    for finding in findings:
        print(json.dumps({k: v for k, v in finding.items() if k != "users"}, ensure_ascii=False))
        if args.send:
            previous = dt.datetime.fromisoformat(state[finding["source_ip"]]) if finding["source_ip"] in state else None
            if previous and now - previous < WINDOW:
                print("notification_suppressed=duplicate_window")
                continue
            response = send_webhook(os.environ["PB01_SHUFFLE_WEBHOOK"], finding, args.test_id, args.attack_source, args.atomic_guid)
            print(json.dumps(response))
            if response["accepted"]:
                state[finding["source_ip"]] = now.isoformat()
                sent += 1
    if args.state_file and sent:
        args.state_file.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.state_file.with_suffix(args.state_file.suffix + ".tmp")
        temporary.write_text(json.dumps(state), encoding="utf-8")
        temporary.replace(args.state_file)
    print(f"events={len(events)} findings={len(findings)} notifications_sent={sent}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"PB01 failed: {exc}", file=sys.stderr)
        sys.exit(1)
