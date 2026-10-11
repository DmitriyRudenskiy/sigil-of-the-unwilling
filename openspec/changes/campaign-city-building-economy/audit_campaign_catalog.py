#!/usr/bin/env python3
"""Verify shipped campaign catalog admission against versioned public manifests."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
PROJECT = ROOT.parents[2]
CATALOG_PATH = PROJECT / "game/assets/data/campaign_building_catalog.json"
MANIFESTS = {
    "against_the_storm": json.loads((ROOT / "ats-reference-manifest.json").read_text()),
    "terrascape": json.loads((ROOT / "terrascape-reference-manifest.json").read_text()),
    "age_of_empires_iv": json.loads((ROOT / "aoe4-reference-manifest.json").read_text()),
}
CATALOG = json.loads(CATALOG_PATH.read_text())
PLACEHOLDER = re.compile(r"\b(?:TODO|TBD|placeholder|unknown|candidate|n/?a)\b", re.IGNORECASE)


def confirmed_rows(game):
    manifest = MANIFESTS[game]
    rows = manifest.get("entries", []) if game != "terrascape" else manifest.get("merge_results", [])
    return {row["id"] if game == "against_the_storm" else row["id"] if game == "age_of_empires_iv" else row["merge_id"]: row
            for row in rows if row.get("confidence") == "confirmed"}


def check_no_null(value, path="catalog"):
    if value is None:
        raise AssertionError(f"null runtime value at {path}")
    if isinstance(value, dict):
        for key, child in value.items():
            check_no_null(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            check_no_null(child, f"{path}[{index}]")


def check_no_placeholder(value, path="catalog.buildings"):
    if isinstance(value, str):
        assert value.strip(), f"empty runtime string at {path}"
        assert not PLACEHOLDER.search(value), f"placeholder runtime value at {path}: {value!r}"
    elif isinstance(value, dict):
        for key, child in value.items():
            check_no_placeholder(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            check_no_placeholder(child, f"{path}[{index}]")


def main():
    assert CATALOG.get("schema_version") == 1
    buildings = CATALOG.get("buildings")
    exclusions = CATALOG.get("excluded_confirmed")
    assert isinstance(buildings, list) and buildings
    assert isinstance(exclusions, list)
    check_no_null(CATALOG)
    check_no_placeholder(buildings)
    ids = [building["id"] for building in buildings]
    assert len(ids) == len(set(ids)), "duplicate canonical building id"
    required = {
        "id", "source_refs", "roles", "footprint", "placement", "costs", "upkeep", "jobs",
        "resident_capacity", "construction_turns", "recipes", "services", "group_affinities",
        "adjacency", "merge", "prerequisites", "training", "defense", "state_effects",
    }
    admitted, excluded = {}, {}
    allowed_resources = set(CATALOG["metadata"]["resource_mask"])
    for index, building in enumerate(buildings):
        missing = required - building.keys()
        assert not missing, f"buildings[{index}] missing {sorted(missing)}"
        for ref in building["source_refs"]:
            game = ref["game"]
            if game == "sigil_of_the_unwilling":
                continue
            assert game in MANIFESTS, f"unsupported reference game {game}"
            key = ref["entry"].split("@", 1)[0]
            row = confirmed_rows(game).get(key)
            assert row is not None, f"runtime catalog references non-confirmed row {game}:{key}"
            admitted.setdefault((game, key), set()).add(building["id"])
        for key in ("costs", "upkeep"):
            assert set(building[key]) <= allowed_resources, f"{building['id']} uses resources outside MVP mask"
        for recipe in building["recipes"]:
            assert set(recipe["inputs"]) <= allowed_resources and set(recipe["outputs"]) <= allowed_resources
        for action in building["training"]:
            assert set(action["costs"]) <= allowed_resources
    for row in exclusions:
        assert row["reason"].strip(), f"exclusion {row.get('entry')} has no reason"
        assert row["source_urls"], f"exclusion {row.get('entry')} has no provenance URL"
        key = row["entry"].split("@", 1)[0]
        game = row["game"]
        assert game in MANIFESTS
        assert key in confirmed_rows(game), f"exclusion is not a confirmed source row: {game}:{key}"
        excluded[(game, key)] = row["reason"]
    for game in MANIFESTS:
        for key in confirmed_rows(game):
            in_buildings = (game, key) in admitted
            in_exclusions = (game, key) in excluded
            assert in_buildings != in_exclusions, f"{game}:{key} must be admitted or excluded exactly once"
    assert not set(admitted).intersection(excluded), "source row both admitted and excluded"
    print("CAMPAIGN BUILDING CATALOG AUDIT: PASS")
    print(f"runtime records: {len(buildings)} (including five internal MVP baseline buildings)")
    print(f"confirmed external rows: {len(admitted)} admitted, {len(excluded)} reasoned exclusions")
    print("candidate/unknown source rows: 0; null or placeholder runtime values: 0")


if __name__ == "__main__":
    main()
