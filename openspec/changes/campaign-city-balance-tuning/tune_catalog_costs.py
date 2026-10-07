#!/usr/bin/env python3
"""Apply auditable campaign-role construction prices to the 98 runtime buildings."""

import argparse
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[3] / "game/assets/data/campaign_building_catalog.json"
MVP_RESOURCES = {"food", "wood", "iron"}
CANONICAL_OVERRIDES = {
    "campaign_farm": {"wood": 4},
    "campaign_sawmill": {"wood": 5},
    "campaign_iron_mine": {"wood": 6},
    "campaign_housing": {"wood": 6},
    "campaign_barracks": {"wood": 8, "iron": 2},
}


def _service_units(building):
    return sum(max(0, round(float(value))) for value in building.get("services", {}).values())


def construction_cost(building):
    building_id = building["id"]
    roles = set(building.get("roles", []))
    services = building.get("services", {})
    duration_premium = int(building.get("construction_turns", 1)) > 1

    if building_id in CANONICAL_OVERRIDES:
        return dict(CANONICAL_OVERRIDES[building_id]), "canonical_mvp_override"

    if "military_training" in roles:
        if "static_defense" in roles:
            cost = {"wood": 10, "iron": 3}
            rule = "training_plus_defense"
        else:
            cost = {"wood": 8, "iron": 2}
            rule = "training"
    elif "static_defense" in roles:
        strength = max(0, round(float(building.get("defense", {}).get("active", 0))))
        if strength <= 1:
            cost, rule = {"wood": 3, "iron": 1}, "defense_tier_1"
        elif strength == 2:
            cost, rule = {"wood": 4, "iron": 1}, "defense_tier_2"
        else:
            cost, rule = {"wood": 6, "iron": 2}, "defense_tier_3"
    elif "food_production" in roles or "wood_production" in roles or "iron_production" in roles:
        jobs = max(0, int(building.get("jobs", 0)))
        outputs = {
            resource
            for recipe in building.get("recipes", [])
            for resource, amount in recipe.get("outputs", {}).items()
            if float(amount) > 0
        }
        labor_tiers = max(1, (jobs + 1) // 2)
        wood = 2 + 2 * labor_tiers + (2 if len(outputs) > 1 else 0)
        cost = {"wood": wood}
        if len(outputs) > 1:
            cost["iron"] = 1
        rule = "production_capacity_and_output_count"
        service_units = _service_units(building)
        if service_units:
            cost["food"] = service_units
            cost["wood"] += service_units
            rule += "+service_capacity"
        if "housing" in roles and int(building.get("resident_capacity", 0)) > 0:
            cost["wood"] += 4
            cost["iron"] = cost.get("iron", 0) + 1
            rule += "+housing_capacity"
    elif "housing" in roles:
        capacity = max(0, int(building.get("resident_capacity", 0)))
        cost = {"wood": 6 + max(0, (capacity - 10) // 5)}
        if "administration" in roles:
            cost["wood"] += 2
            cost["iron"] = 1
        rule = "housing_capacity"
        service_units = _service_units(building)
        if service_units:
            cost["food"] = service_units
            cost["wood"] += service_units
            rule += "+service_capacity"
    elif services:
        units = _service_units(building)
        cost = {"food": max(1, units), "wood": max(1, units)}
        if units >= 2:
            cost["iron"] = 1
        rule = "service_capacity"
    else:
        raise ValueError(f"no campaign pricing rule for {building_id}: {sorted(roles)}")

    if duration_premium:
        cost["wood"] = cost.get("wood", 0) + 1
        cost["iron"] = cost.get("iron", 0) + 1
        rule += "+two_turn_premium"
    return cost, rule


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="write the explicit prices to the runtime catalog")
    args = parser.parse_args()

    catalog = json.loads(CATALOG.read_text())
    buildings = catalog.get("buildings", [])
    if len(buildings) != 98:
        raise SystemExit(f"expected 98 runtime buildings, found {len(buildings)}")

    rules = {}
    for building in buildings:
        cost, rule = construction_cost(building)
        if not cost or set(cost) - MVP_RESOURCES or any(int(v) <= 0 for v in cost.values()):
            raise SystemExit(f"invalid campaign cost for {building['id']}: {cost}")
        building["costs"] = cost
        rules[rule] = rules.get(rule, 0) + 1

    if args.apply:
        CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"applied": args.apply, "buildings": len(buildings), "rule_counts": rules}, indent=2))


if __name__ == "__main__":
    main()
