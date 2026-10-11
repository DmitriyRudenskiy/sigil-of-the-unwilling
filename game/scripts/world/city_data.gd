class_name CityData
extends RefCounted

signal population_changed
signal boroughs_changed
signal buildings_changed
signal storage_changed
signal relocation_completed(new_center: Vector2i)

enum Faction { DEFAULT, NECROPHAGE, ALLAYI, CULTISTS }

const SERIALIZATION_VERSION := 5

var uid := 0
var display_name := ""
var center := Vector2i(-1, -1)
## city-hex-layout D2: ядро города, ромб 2×2 (кэш; источник — center + CityFactory.core_cells_for)
var core_cells: Array[Vector2i] = []
var owner: StringName = &"none"
var is_capital := false
var faction: int = Faction.DEFAULT

var reputation := 0
var prosperity := 50.0
var level := 1
var specialization: StringName = &""
var stronghold_level := 1
var starving := false
var scale_tier := 0
var auto_resource_mult := 1.0
var upkeep_mult := 1.0
var _legacy_food_stockpile := 0.0
var food_supply_this_turn := 0.0
var food_demand_this_turn := 0.0
var food_stockpile: float:
	get:
		return resource_ctx.amount(&"food") if resource_ctx != null else _legacy_food_stockpile
	set(value):
		var target := maxf(value, 0.0)
		if resource_ctx == null:
			_legacy_food_stockpile = target
			return
		var delta := target - resource_ctx.amount(&"food")
		if delta > 0.0:
			resource_ctx.add(&"food", delta, "city_food_stockpile")
		elif delta < 0.0:
			resource_ctx.remove(&"food", -delta, "city_food_stockpile")
## social-systems-delta: найм кузнеца (д20 + cha vs 14) — флаг для этапа 3 (железо).
var smith_hired := false

var pop: Array[PopUnit] = []
var boroughs: Array[Borough] = []
var buildings: Array[UniqueBuilding] = []
var campaign_buildings: Array[Dictionary] = []
var campaign_group_state: Dictionary = {}
var special_sites: Dictionary = {}
var storage: Dictionary = {}
var roads: Dictionary = {}
var resource_ctx: ResourceContext = null

var tile_yield_fn: Callable = func(_cell: Vector2i) -> Dictionary: return {}
var is_buildable_fn: Callable = func(_cell: Vector2i) -> bool: return true

var _uid_seq := 0


var _yield_calc := CityYieldCalculator.new()

func invalidate_yield() -> void:
	_yield_calc.invalidate()

func ensure_resource_ctx(defs: Array = []) -> ResourceContext:
	if resource_ctx == null:
		resource_ctx = ResourceContext.new()
		resource_ctx.setup(defs)
		if _legacy_food_stockpile > 0.0:
			resource_ctx.add(&"food", _legacy_food_stockpile, "legacy_food_stockpile_migration")
			_legacy_food_stockpile = 0.0
	return resource_ctx
