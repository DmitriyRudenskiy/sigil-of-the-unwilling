#!/usr/bin/env python3
"""Validate public reference manifests and their explicit confidence/gap fields."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ALLOWED = {"confirmed", "candidate", "unknown"}
errors = []


def load(name):
    try:
        return json.loads((ROOT / name).read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{name}: {exc}")
        return {}


def check_confidence(row, label):
    if row.get("confidence") not in ALLOWED:
        errors.append(f"{label}: invalid confidence {row.get('confidence')!r}")

ats = load("ats-reference-manifest.json")
ats_entries = ats.get("entries", [])
ats_ids = [r.get("id") for r in ats_entries]
if len(ats_entries) != 318:
    errors.append(f"AtS expected 318 observed/supplemental rows, got {len(ats_entries)}")
if len(set(ats_ids)) != len(ats_ids):
    errors.append("AtS duplicate source IDs")
for i, row in enumerate(ats_entries):
    label = f"AtS entries[{i}]"
    for field in ("id", "name", "type_category", "is_building", "is_decoration", "is_event_object", "is_excluded", "has_variants", "variant_of", "version", "source", "confidence", "disposition"):
        if field not in row:
            errors.append(f"{label}: missing {field}")
    check_confidence(row, label)
    if row.get("is_event_object") and not row.get("is_excluded"):
        errors.append(f"{label}: event object lacks explicit exclusion")
    if row.get("is_event_object") and row.get("is_building"):
        errors.append(f"{label}: event object incorrectly marked a settlement building")

aoe = load("aoe4-reference-manifest.json")
aoe_entries = aoe.get("entries", [])
if len(aoe_entries) != 95:
    errors.append(f"AoE IV expected 95 discovered source-signal rows, got {len(aoe_entries)}")
for i, row in enumerate(aoe_entries):
    label = f"AoE IV entries[{i}]"
    for field in ("id", "name", "is_building", "is_excluded", "version", "source", "confidence", "campaign_disposition", "disposition", "source_variants"):
        if field not in row:
            errors.append(f"{label}: missing {field}")
    check_confidence(row, label)
    if not row.get("campaign_disposition") or not row.get("source_variants"):
        errors.append(f"{label}: missing role disposition or source variants")
if not any(g.get("id") == "AOE-GAP-001" and g.get("status") == "unknown" for g in aoe.get("coverage_gaps", [])):
    errors.append("AoE IV undiscovered-content caveat is not recorded")

terra = load("terrascape-reference-manifest.json")
for section, fields in {
    "cards": ("card_id", "card_name", "deck", "is_ra_card", "is_building", "is_merge_result", "is_monument", "monument_stage", "variant_of", "version", "source", "confidence", "disposition"),
    "additional_building_card_candidates": ("candidate_id", "card_name", "deck", "is_ra_card", "is_building", "is_merge_result", "is_monument", "monument_stage", "variant_of", "version", "source", "confidence", "disposition"),
    "merge_results": ("merge_id", "inputs", "output_id", "output_name", "output_type", "monument_stage", "version", "source", "confidence", "disposition"),
    "monuments": ("monument_id", "name", "is_monument", "monument_stage", "variant_of", "version", "source", "confidence", "disposition"),
}.items():
    rows = terra.get(section, [])
    for i, row in enumerate(rows):
        label = f"TerraScape {section}[{i}]"
        for field in fields:
            if field not in row:
                errors.append(f"{label}: missing {field}")
        check_confidence(row, label)
        if not row.get("source"):
            errors.append(f"{label}: no source reference")
        if section == "merge_results" and row.get("inputs") is None and row.get("input_confidence") != "unknown":
            errors.append(f"{label}: absent inputs must be marked unknown")

if any("Amun-Ra" in json.dumps(row, ensure_ascii=False) for row in terra.get("cards", []) + terra.get("additional_building_card_candidates", [])):
    errors.append("Unverified Amun-Ra record was added to card data")
if any(row.get("name") == "Temple of Luxor" and row.get("confidence") != "candidate" for row in terra.get("monuments", [])):
    errors.append("Temple of Luxor must remain a candidate monument")
if not any(row.get("id") == "ATS-GAP-001" and row.get("status") == "unknown" for row in ats.get("coverage_gaps", [])):
    errors.append("AtS exact-version coverage gap is not recorded")
if not all(g.get("status") == "unknown" for g in terra.get("coverage_gaps", [])):
    errors.append("TerraScape source-coverage gaps must remain explicitly unknown")

if errors:
    print("REFERENCE MANIFEST AUDIT: FAIL")
    print("\n".join(f"- {e}" for e in errors))
    raise SystemExit(1)
print("REFERENCE MANIFEST AUDIT: PASS")
print(f"AtS: {len(ats_entries)} rows; {sum(r['is_event_object'] for r in ats_entries)} event objects; {sum(r['confidence']=='confirmed' for r in ats_entries)} confirmed rows")
print(f"AoE IV: {len(aoe_entries)} discovered rows; {sum('static_defense' in r['campaign_disposition'] for r in aoe_entries)} static-defense links; exclusions and support-only rows retained")
print(f"TerraScape: {len(terra.get('cards', []))} cards, {len(terra.get('additional_building_card_candidates', []))} separate leads, {len(terra.get('merge_results', []))} merge results ({sum(r['inputs'] is not None for r in terra.get('merge_results', []))} with candidate recipes), {len(terra.get('monuments', []))} monument candidates")
print(f"TerraScape unknown coverage gaps: {len(terra.get('coverage_gaps', []))}")
