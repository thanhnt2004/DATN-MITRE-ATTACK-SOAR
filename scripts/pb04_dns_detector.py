#!/usr/bin/env python3
"""PB04 T1071.004 DNS communication detector for Packetbeat DNS events."""

import argparse
import datetime as dt
import ipaddress
import json
import os
import ssl
import sys
import urllib.request
from collections import defaultdict, deque
from pathlib import Path

WINDOW = dt.timedelta(minutes=2)
DEDUP = dt.timedelta(minutes=5)


def field(event, dotted):
    value = event
    for part in dotted.split("."):
        if not isinstance(value, dict):
            return None
        value = value.get(part)
    return value


def normalize(event):
    if field(event, "dns.type") != "answer":
        return None
    ip = field(event, "source.ip")
    name = field(event, "dns.question.name")
    domain = field(event, "dns.question.etld_plus_one") or field(event, "dns.question.registered_domain")
    when = event.get("@timestamp")
    if not all((ip, name, domain, when)):
        return None
    try:
        address = ipaddress.ip_address(ip)
        timestamp = dt.datetime.fromisoformat(when.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None
    if address.is_loopback or address.is_unspecified or not name.lower().endswith(domain.lower()):
        return None
    return {
        "ip": str(address), "name": name.lower().rstrip("."), "domain": domain.lower().rstrip("."),
        "when": timestamp, "rcode": str(field(event, "dns.response_code") or "").upper(),
        "qtype": str(field(event, "dns.question.type") or "").upper(),
        "host": str(field(event, "host.name") or "unknown"),
    }


def score_window(rows):
    count = len(rows)
    unique = len({row["name"] for row in rows})
    long_rate = sum(len(row["name"]) >= 60 for row in rows) / count
    nxdomain_rate = sum(row["rcode"] == "NXDOMAIN" for row in rows) / count
    txt_rate = sum(row["qtype"] == "TXT" for row in rows) / count
    score = 25 * (count >= 20) + 25 * (unique >= 20) + 20 * (long_rate >= 0.8)
    score += 15 * (nxdomain_rate >= 0.8) + 15 * (txt_rate >= 0.8)
    return score, unique, long_rate, nxdomain_rate, txt_rate


def detect(events, allow_ips=(), allow_domains=()):
    allowed_ips = set(allow_ips)
    allowed_domains = {item.lower().rstrip(".") for item in allow_domains}
    groups = defaultdict(list)
    for event in events:
        row = normalize(event)
        if row and row["ip"] not in allowed_ips and row["domain"] not in allowed_domains:
            groups[(row["ip"], row["domain"])].append(row)
    findings = []
    for (ip, domain), rows in sorted(groups.items()):
        window = deque()
        best = None
        for row in sorted(rows, key=lambda item: item["when"]):
            window.append(row)
            while row["when"] - window[0]["when"] > WINDOW:
                window.popleft()
            if len(window) < 20:
                continue
            score, unique, long_rate, nxdomain_rate, txt_rate = score_window(window)
            if score < 80 or unique < 20 or long_rate < 0.8:
                continue
            sample = sorted({item["name"] for item in window})[:3]
            candidate = {
                "playbook_id": "PB04", "technique": "T1071.004", "source_ip": ip,
                "registered_domain": domain, "query_count": len(window), "distinct_qname_count": unique,
                "long_qname_rate": round(long_rate, 2), "nxdomain_rate": round(nxdomain_rate, 2),
                "txt_rate": round(txt_rate, 2), "risk_score": score,
                "hosts": sorted({item["host"] for item in window}), "sample_queries": sample,
                "event_start": window[0]["when"].isoformat(), "event_end": window[-1]["when"].isoformat(),
                "decision": "REVIEW_DOMAIN_BLOCK" if score >= 90 else "INVESTIGATE",
                "status": "DETECTED_NOTIFY_ONLY",
            }
            if best is None or candidate["query_count"] > best["query_count"]:
                best = candidate
        if best:
            findings.append(best)
    return findings


def load_elastic(url, index, api_key, ca):
    query = {
        "size": 5000, "sort": [{"@timestamp": "desc"}],
        "query": {"bool": {"filter": [
            {"range": {"@timestamp": {"gte": "now-3m"}}},
            {"exists": {"field": "dns.question.name"}},
        ]}},
    }
    request = urllib.request.Request(
        f"{url.rstrip('/')}/{index}/_search", data=json.dumps(query).encode(),
        headers={"Authorization": "ApiKey " + api_key, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=ca), timeout=30) as response:
        result = json.load(response)
    if result.get("_shards", {}).get("total", 0) == 0:
        raise RuntimeError("No searchable Elasticsearch shards for PB04 index")
    return [hit["_source"] for hit in result["hits"]["hits"]]


def send(url, finding, test_id, attack_source, atomic_guid):
    payload = {
        **finding, "test_id": test_id, "attack_source": attack_source,
        "atomic_guid": atomic_guid or "N/A", "hosts_text": ", ".join(finding["hosts"]),
        "sample_queries_text": ", ".join(finding["sample_queries"]),
    }
    request = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        reply = json.load(response)
        return response.status, bool(reply.get("success"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--index", default="datn-dns-*")
    parser.add_argument("--allow-ip", action="append", default=[])
    parser.add_argument("--allow-domain", action="append", default=[])
    parser.add_argument("--state-file", type=Path)
    parser.add_argument("--send", action="store_true")
    parser.add_argument("--test-id", default="PB04-AUTO")
    parser.add_argument("--attack-source", default="Observed telemetry")
    parser.add_argument("--atomic-guid", default="")
    args = parser.parse_args()
    if args.fixture:
        events = [json.loads(line) for line in args.fixture.read_text(encoding="utf-8").splitlines() if line.strip()]
    else:
        for key in ("PB04_ES_URL", "PB04_ES_API_KEY", "PB04_ES_CA"):
            if not os.getenv(key):
                parser.error(f"{key} is required in live mode")
        events = load_elastic(os.environ["PB04_ES_URL"], args.index, os.environ["PB04_ES_API_KEY"], os.environ["PB04_ES_CA"])
    if args.send and (not args.state_file or not os.getenv("PB04_SHUFFLE_WEBHOOK")):
        parser.error("--send requires --state-file and PB04_SHUFFLE_WEBHOOK")
    findings = detect(events, args.allow_ip, args.allow_domain)
    state = json.loads(args.state_file.read_text(encoding="utf-8")) if args.state_file and args.state_file.exists() else {}
    now = dt.datetime.now(dt.timezone.utc)
    sent = 0
    for finding in findings:
        print(json.dumps({key: value for key, value in finding.items() if key not in ("sample_queries",)}, ensure_ascii=False))
        if args.send:
            key = finding["source_ip"] + "|" + finding["registered_domain"]
            previous = dt.datetime.fromisoformat(state[key]) if key in state else None
            if previous and now - previous < DEDUP:
                print("notification_suppressed=duplicate_window")
                continue
            status, accepted = send(os.environ["PB04_SHUFFLE_WEBHOOK"], finding, args.test_id, args.attack_source, args.atomic_guid)
            print(json.dumps({"http_status": status, "accepted": accepted}))
            if accepted:
                state[key] = now.isoformat()
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
        print(f"PB04 failed: {exc}", file=sys.stderr)
        sys.exit(1)
