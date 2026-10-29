import re
import sys
from collections import Counter

path = sys.argv[1]
lines = open(path, encoding="utf-8-sig").read().splitlines()

in_entries = False
depth = 0
block = []
entries = []
for line in lines:
    if not in_entries:
        if '["entries"]' in line and line.rstrip().endswith("{"):
            in_entries = True
        continue
    opens = line.count("{")
    closes = line.count("}")
    if depth == 0 and line.strip() == "{":
        block = [line]
        depth = 1
        continue
    if depth:
        block.append(line)
        depth += opens - closes
        if depth == 0:
            entries.append(block)
            block = []
    elif line.strip() == "},":
        break

def scalar(text, key):
    m = re.search(r'^\["' + re.escape(key) + r'"\] = (.+),$', text, re.M)
    if not m:
        return None
    value = m.group(1)
    if value.startswith('"'):
        return value[1:-1]
    if value in ("true", "false"):
        return value == "true"
    try:
        return float(value)
    except ValueError:
        return value

def ready(text):
    m = re.search(r'\["ready"\] = \{(.*?)\n\},', text, re.S)
    if not m:
        return {}
    return {k: v == "true" for k, v in re.findall(r'\["([^"\]]+)"\] = (true|false),', m.group(1))}

parsed = []
for raw in entries:
    text = "\n".join(raw)
    parsed.append({
        "kind": scalar(text, "kind"), "t": scalar(text, "t"),
        "clock": scalar(text, "clock"), "rec": scalar(text, "rec"),
        "spell": scalar(text, "spell"), "profile": scalar(text, "profile"),
        "mode": scalar(text, "mode"), "combat": scalar(text, "inCombat"),
        "reck": scalar(text, "reck"), "avatar": scalar(text, "avatar"),
        "enrage": scalar(text, "enrage"), "targets": scalar(text, "targets"),
        "rend": scalar(text, "rend"), "cs": scalar(text, "cs"),
        "executeUsable": scalar(text, "executeUsable"), "executePhase": scalar(text, "executePhase"),
        "sdAura": scalar(text, "sdAura"), "sdOverlay": scalar(text, "sdOverlay"),
        "sdCount": scalar(text, "sdCount"), "sdGlow": scalar(text, "sdGlow"),
        "mow": scalar(text, "mow"), "mowProc": scalar(text, "mowProc"),
        "ready": ready(text),
    })

recs = [e for e in parsed if e["kind"] == "recommendation"]
casts = [e for e in parsed if e["kind"] == "cast"]
print("entries", len(parsed), "recommendations", len(recs), "casts", len(casts))
print("profiles", Counter(e["profile"] for e in parsed))
print("modes", Counter(e["mode"] for e in recs))
print("target counts", Counter(e["targets"] for e in recs))
print("recommendations", Counter(e["rec"] for e in recs).most_common())
print("casts", Counter(e["spell"] for e in casts).most_common())
print("first events")
for e in parsed[:80]:
    print(e["clock"], e["t"], e["kind"], e["rec"] or e["spell"], "combat", e["combat"], "reck", e["reck"], "enrage", e["enrage"])
print("none samples")
for e in recs:
    if e["rec"] == "none":
        print(e["clock"], e["t"], "combat", e["combat"], "reck", e["reck"], "avatar", e["avatar"], "ready", [k for k,v in e["ready"].items() if v])
print("odyn ready but another recommendation")
for e in recs:
    if e["ready"].get("odynsFury") and e["rec"] != "Odyn's Fury":
        print(e["clock"], e["t"], e["rec"], "reck", e["reck"], "avatar", e["avatar"], "enrage", e["enrage"], "ready", [k for k,v in e["ready"].items() if v])
print("timeline around none")
for e in parsed:
    if e["t"] is not None and 20 <= e["t"] <= 32:
        print(e["clock"], e["t"], e["kind"], e["rec"] or e["spell"])
if any(e["profile"] == "Arms - Slayer" for e in parsed):
    active = [e for e in recs if e["combat"] and e["rec"] != "none"]
    print("arms execute usable recommendations", Counter(e["rec"] for e in active if e["executeUsable"]).most_common())
    print("arms confirmed SD recommendations", Counter(e["rec"] for e in active if e["sdAura"] or e["sdOverlay"] or (e["sdCount"] or 0) > 0).most_common())
    print("arms MOW recommendations", Counter(e["rec"] for e in active if e["mowProc"]).most_common())
    print("arms low rend recommendations", Counter(e["rec"] for e in active if e["rend"] is not None and e["rend"] <= 5).most_common())
    print("arms zero rend recommendations", Counter(e["rec"] for e in active if e["rend"] == 0).most_common())
    cooldown_times = [e["t"] for e in active if e["rec"] in ("Avatar", "Colossus Smash", "Bladestorm")]
    print("arms cooldown recommendation windows")
    shown = set()
    for anchor in cooldown_times:
        window = tuple((e["t"], e["rec"], e["rend"], e["cs"], e["executeUsable"], e["sdOverlay"]) for e in active if anchor - 3 <= e["t"] <= anchor + 6)
        if window in shown:
            continue
        shown.add(window)
        print("window", anchor)
        for row in window:
            print(row)
