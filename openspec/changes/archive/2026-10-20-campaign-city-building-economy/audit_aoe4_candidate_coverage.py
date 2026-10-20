#!/usr/bin/env python3
"""Check AoE IV candidate dispositions; optionally verify against pinned JSON data."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent
CANDIDATES = ROOT / "aoe4-military-defense-candidates.md"
TRAINING = ROOT / "aoe4-training-class-crosswalk.md"
DEFENSE = ROOT / "aoe4-static-defense-crosswalk.md"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--buildings", type=Path, help="pinned buildings/all.json")
parser.add_argument("--units", type=Path, help="pinned units/all.json")
args = parser.parse_args()
if bool(args.buildings) != bool(args.units):
    parser.error("--buildings and --units must be supplied together")

candidate_rows: dict[str, str] = {}
for line in CANDIDATES.read_text(encoding="utf-8").splitlines():
    match = re.match(r"\|\s*(AOE-C-\d+)\s*\|\s*([^|]+)", line)
    if match:
        candidate_id, name = match.group(1), match.group(2).strip()
        if candidate_id in candidate_rows:
            print(f"duplicate candidate ID: {candidate_id}", file=sys.stderr)
            sys.exit(1)
        candidate_rows[candidate_id] = name

training_text = TRAINING.read_text(encoding="utf-8")
producer_section = training_text.split("## Remaining source-signal names", 1)[0]
producer_names = {
    match.group(1).strip()
    for line in producer_section.splitlines()
    if (match := re.match(r"\|\s*([^|]+)\s*\|\s*`", line))
}
explicit_rows = set(re.findall(r"\|\s*(AOE-C-\d+)\s+[^|]+\|", training_text))
defense_text = DEFENSE.read_text(encoding="utf-8")
defense_rows = set(re.findall(r"\|\s*(AOE-C-\d+)\s+[^|]+\|", defense_text))
covered = {
    candidate_id
    for candidate_id, name in candidate_rows.items()
    if name in producer_names or candidate_id in explicit_rows or candidate_id in defense_rows
}
missing = sorted(set(candidate_rows) - covered)
if missing:
    for candidate_id in missing:
        print(f"unclassified: {candidate_id} {candidate_rows[candidate_id]}", file=sys.stderr)
    sys.exit(1)

if args.buildings and args.units:
    building_bytes = args.buildings.read_bytes()
    unit_bytes = args.units.read_bytes()
    buildings = json.loads(building_bytes)["data"]
    units = json.loads(unit_bytes)["data"]
    source_names = {row["name"] for row in buildings}
    absent = sorted(set(candidate_rows.values()) - source_names)
    if absent:
        print(f"candidate names absent from pinned data: {absent}", file=sys.stderr)
        sys.exit(1)

    building_civ_pairs = {
        (row.get("baseId"), civ)
        for row in buildings
        for civ in row.get("civs", [])
    }
    base_names: dict[str, set[str]] = {}
    for row in buildings:
        base_names.setdefault(row.get("baseId", ""), set()).add(row["name"])
    producer_pairs: set[tuple[str, str]] = set()
    for unit in units:
        classes = set(unit.get("classes", []))
        if "human" not in classes or "land_military" not in classes:
            continue
        for producer in unit.get("producedBy", []):
            for civ in unit.get("civs", []):
                if (producer, civ) in building_civ_pairs:
                    producer_pairs.add((producer, civ))
    discovered_producers = {
        name for producer, _civ in producer_pairs for name in base_names[producer]
    }
    if discovered_producers != producer_names:
        print(
            "producer crosswalk mismatch; "
            f"missing={sorted(discovered_producers - producer_names)}, "
            f"extra={sorted(producer_names - discovered_producers)}",
            file=sys.stderr,
        )
        sys.exit(1)

    class_defenses = {
        row["name"]
        for row in buildings
        if "defensive_structure" in row.get("classes", [])
        or any("defensive" in label.lower() for label in row.get("displayClasses", []))
    }
    weapon_buildings = {row["name"] for row in buildings if row.get("weapons")}
    signals = discovered_producers | class_defenses | weapon_buildings
    if not signals <= set(candidate_rows.values()):
        print(f"source signal absent from candidate ledger: {sorted(signals - set(candidate_rows.values()))}", file=sys.stderr)
        sys.exit(1)
    print(
        "Pinned source audit: "
        f"buildings={len(buildings)}, civs={len({c for row in buildings for c in row.get('civs', [])})}, "
        f"human-land producer names/records={len(discovered_producers)}/{len(producer_pairs)}, "
        f"defensive class names={len(class_defenses)}, weapon-profile names={len(weapon_buildings)}, "
        f"candidate names present={len(candidate_rows)}/{len(candidate_rows)}, "
        f"building SHA-256={hashlib.sha256(building_bytes).hexdigest()}"
    )

print(
    f"AoE IV candidate disposition coverage: {len(covered)}/{len(candidate_rows)}; "
    f"producer names: {len(producer_names)}; explicit support/exclusion rows: {len(explicit_rows)}; "
    f"defense crosswalk rows: {len(defense_rows)}"
)
