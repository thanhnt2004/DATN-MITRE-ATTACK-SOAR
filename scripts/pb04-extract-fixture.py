#!/usr/bin/env python3
"""Extract only DATN .test DNS fields from a Packetbeat NDJSON capture."""
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
rows = []
for line in source.read_text(encoding="utf-8").splitlines():
    event = json.loads(line)
    question = event.get("dns", {}).get("question", {})
    if question.get("etld_plus_one") != "pb04-datn.test":
        continue
    rows.append({
        "@timestamp": event["@timestamp"], "source": {"ip": event["source"]["ip"]},
        "host": {"name": event.get("host", {}).get("name", "kali")},
        "dns": {"type": event["dns"]["type"], "question": {
            "name": question["name"], "etld_plus_one": question["etld_plus_one"],
            "type": question["type"]}, "response_code": event["dns"].get("response_code")},
    })
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in rows), encoding="utf-8")
print(f"fixture_events={len(rows)} target={target}")
