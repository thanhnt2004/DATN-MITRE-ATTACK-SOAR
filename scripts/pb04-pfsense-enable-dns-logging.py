#!/usr/bin/env python3
"""Enable pfSense Unbound query logs and remote DNS events, preserving other form fields."""
import os
import re
import requests
from bs4 import BeautifulSoup

BASE = "http://192.168.10.1"
session = requests.Session()
session.trust_env = False


def page(path):
    response = session.get(BASE + path, timeout=15)
    response.raise_for_status()
    return BeautifulSoup(response.text, "html.parser")


def form_values(form):
    values = []
    for tag in form.select("input[name],select[name],textarea[name]"):
        name = tag["name"]
        kind = tag.get("type", "").lower()
        if kind in ("submit", "button", "reset", "file"):
            continue
        if kind in ("checkbox", "radio") and not tag.has_attr("checked"):
            continue
        if tag.name == "select":
            selected = tag.select_one("option[selected]") or tag.select_one("option")
            value = selected.get("value", "") if selected else ""
        elif tag.name == "textarea":
            value = tag.get_text()
        else:
            value = tag.get("value", "")
        values.append((name, value))
    return values


def set_one(values, key, value):
    return [(name, old) for name, old in values if name != key] + [(key, value)]


login = page("/")
csrf = login.select_one('input[name="__csrf_magic"]')
if not csrf:
    raise SystemExit("Login CSRF token not found")
response = session.post(BASE + "/index.php", data={
    "__csrf_magic": csrf.get("value", ""),
    "usernamefld": os.environ["PFSENSE_USER"],
    "passwordfld": os.environ["PFSENSE_PASSWORD"],
    "login": "Sign In",
}, timeout=20)
if "usernamefld" in response.text:
    raise SystemExit("pfSense login failed")
print("login=ok")

unbound = page("/services_unbound.php")
options = unbound.select_one('textarea[name="custom_options"]')
form = options.find_parent("form") if options else None
if not form:
    raise SystemExit("Unbound form not found")
values = form_values(form)
current = next((value for name, value in values if name == "custom_options"), "")
if "log-queries: yes" not in current:
    if current.strip():
        raise SystemExit("Existing custom Unbound options need manual merge; no changes made")
    values = set_one(values, "custom_options", "server:\nlog-queries: yes\n")
    values.append(("save", "Save"))
    response = session.post(BASE + "/services_unbound.php", data=values, timeout=30)
    response.raise_for_status()
unbound = page("/services_unbound.php")
print("unbound_query_logging=" + str("log-queries: yes" in (unbound.select_one('textarea[name="custom_options"]').get_text() or "")).lower())
apply_button = unbound.select_one('button[name="apply"],input[name="apply"]')
if apply_button:
    apply_csrf = apply_button.find_previous('input', attrs={"name": "__csrf_magic"})
    if not apply_csrf:
        raise SystemExit("Unbound Apply Changes CSRF token not found")
    response = session.post(BASE + "/services_unbound.php", data={
        "__csrf_magic": apply_csrf.get("value", ""), "apply": apply_button.get("value", "Apply Changes"),
    }, timeout=40)
    response.raise_for_status()
unbound = page("/services_unbound.php")
print("unbound_apply_pending=" + str(bool(unbound.select_one('button[name="apply"],input[name="apply"]'))).lower())

logging = page("/status_logs_settings.php")
form = logging.select_one("form")
if not form:
    raise SystemExit("Remote logging form not found")
values = form_values(form)
if not any(name == "enable" for name, _ in values):
    raise SystemExit("Remote syslog is not enabled; no changes made")
if not any(name == "resolver" for name, _ in values):
    values.append(("resolver", "yes"))
    values.append(("save", "Save"))
    response = session.post(BASE + "/status_logs_settings.php", data=values, timeout=30)
    response.raise_for_status()
logging = page("/status_logs_settings.php")
resolver = logging.select_one('input[name="resolver"]')
print("remote_dns_events=" + str(bool(resolver and resolver.has_attr("checked"))).lower())
