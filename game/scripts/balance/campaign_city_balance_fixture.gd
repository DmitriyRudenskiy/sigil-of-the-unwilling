class_name CampaignCityBalanceFixture
extends RefCounted

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CityFactory := preload("res://scripts/world/city_factory.gd")

const STARTING_RESOURCES := {"food": 30.0, "wood": 20.0, "iron": 10.0}
const STARTING_HOUSING := 20
const CARRIED_FOOD := 0
const PROVISION_CAPACITY := 10
const RESIDENT_GROUPS := [
	{"race": "gnomes", "group": "engineers_builders", "count": 3},
	{"race": "halflings", "group": "farmers_brewers", "count": 3},
	{"race": "tieflings", "group": "alchemists_flame", "count": 3},
	{"race": "elves", "group": "weavers_crafters", "count": 3},
	{"race": "humans", "group": "merchants_diplomats", "count": 3},
	{"race": "half_orcs", "group": "hunters_trackers", "count": 3},
	{"race": "dwarves", "group": "metallurgists_technicians", "count": 2},
]

## Isolated R2/R7 balance start; deliberately does not call CityFactory.apply_starting_kit().
static func create() -> Dictionary:
	var city := City.new()
	city.display_name = "MVP Balance City"
	city.center = ArenaRingSystem.center()
	city.core_cells = CityFactory.core_cells_for(city.center)
	city.owner = &"player"
	city.is_capital = true
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	var registry := ResourceRegistry.new()
	var defs := registry.get_campaign_resource_defs(true)
	registry.free()
	city.ensure_resource_ctx(defs).setup(defs, true)
	city.resource_ctx.deserialize(STARTING_RESOURCES)
	city.resource_ctx.clear_ledger()

	var group_counts := {}
	for group in RESIDENT_GROUPS:
		group_counts[String(group.group)] = int(group.count)
		for _resident_index in range(int(group.count)):
			var resident := PopUnit.new()
			resident.uid = city._uid_seq
			city._uid_seq += 1
			resident.state = PopUnit.State.WORKER
			resident.born_turn = 0
			resident.ancestry_id = String(group.race)
			resident.archetype_id = String(group.group)
			city.pop.append(resident)

	var catalog := CampaignBuildingCatalog.load_catalog()
	var housing_definition: Dictionary = {}
	for definition in catalog.get("buildings", []):
		if String(definition.get("id", "")) == "campaign_housing":
			housing_definition = definition.duplicate(true)
			break
	for house_index in range(2):
		var house := housing_definition.duplicate(true)
		house.merge({
			"uid": city._uid_seq,
			"cell": cells[4 + house_index],
			"state": "active",
			"construction_turns_remaining": 0,
			"assigned_workers": 0,
			"paid_costs": {},
			"fixture_starting": true,
		}, true)
		city.campaign_buildings.append(house)
		city._uid_seq += 1

	var party := [
		{"id": "mvp_fighter", "class": "fighter", "level": 1},
		{"id": "mvp_ranger", "class": "ranger", "level": 1},
	]
	var hero := HeroController.new()
	hero.hero_class = "fighter"
	hero.movement_comp.set_current_cell(city.center)
	hero.strategic_resources.set_all({&"food": CARRIED_FOOD})

	var city_manager := CityManager.new()
	city_manager.is_campaign = true
	city_manager.register_city(city, true)
	return {
		"city": city,
		"city_manager": city_manager,
		"hero": hero,
		"party": party,
		"party_members": party.size(),
		"provision_capacity": PROVISION_CAPACITY,
		"resident_count": city.pop.size(),
		"housing_capacity": STARTING_HOUSING,
		"resident_groups": group_counts,
		"city_cells": cells,
		"assumptions": {
			"resident_states": "all 20 residents start as available workers",
			"group_split": group_counts.duplicate(true),
			"carried_food": CARRIED_FOOD,
			"party_members": party.size(),
			"party_classes": ["fighter", "ranger"],
			"provision_capacity": PROVISION_CAPACITY,
			"resident_count": city.pop.size(),
			"party_starts_in_city": true,
			"starting_housing": "two free canonical campaign_housing instances",
		},
	}

static func dispose(fixture: Dictionary) -> void:
	for key in ["hero", "city_manager"]:
		var node: Variant = fixture.get(key)
		if node is Node and is_instance_valid(node):
			node.free()

static func legacy_city_signature() -> Dictionary:
	var city := CityFactory.create_village(Vector2i(20, 20), "Legacy Balance Check")
	return {
		"workers": city.count_state(PopUnit.State.WORKER),
		"followers": city.count_state(PopUnit.State.FOLLOWER),
		"food": city.food_stockpile,
		"gold": city.resource_ctx.amount(&"gold"),
		"industry": float(city.storage.get(&"industry", 0.0)),
	}
