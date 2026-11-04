#!/usr/bin/env python3
"""Add the PB04 DNS index route to the existing live Logstash pipeline."""
from pathlib import Path
import shutil

path = Path("/opt/elk/logstash/pipeline/logstash.conf")
original = path.read_text(encoding="utf-8")
marker = '  if [fields][log_source] == "ubuntu" {'
insert = '''  if [fields][log_source] == "pb04-dns" {
    mutate { add_field => { "[@metadata][target_index]" => "datn-dns" } }
  } else if [fields][log_source] == "ubuntu" {'''
if '"pb04-dns"' in original:
    print("pb04_route=already_present")
elif original.count(marker) != 1:
    raise SystemExit("Expected one Ubuntu routing anchor; live pipeline was not changed")
else:
    backup = path.parent.parent / "logstash.conf.pre-pb04"
    if not backup.exists():
        shutil.copy2(path, backup)
    updated = original.replace(marker, insert, 1)
    temporary = path.with_suffix(".conf.pb04-tmp")
    temporary.write_text(updated, encoding="utf-8")
    shutil.copymode(path, temporary)
    temporary.replace(path)
    print(f"pb04_route=added backup={backup}")
