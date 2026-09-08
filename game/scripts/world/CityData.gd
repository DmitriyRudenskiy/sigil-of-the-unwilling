class_name CityData
extends RefCounted
## R2: чистое состояние города (сплит City.gd: данные / операции / фасад).
## Сигналы живут здесь; City (фасад) наследует их и свойства напрямую,
## операции — в статических CityService.

signal population_changed
signal boroughs_changed
signal buildings_changed
signal storage_changed
signal relocation_completed(new_center: Vector2i)

enum Faction { DEFAULT, NECROPHAGE, ALLAYI, CULTISTS }

const SERIALIZATION_VERSION := 2

# ─── Идентификация ─────────────────────────────────────────────
var uid := 0
var display_name := ""
var center := Vector2i(-1, -1)
var owner: StringName = &"none"
var is_capital := false
var faction: int = Faction.DEFAULT

# ─── Состояние ─────────────────────────────────────────────────
var reputation := 0
var prosperity := 50.0
var level := 1
var specialization: StringName = &""
var stronghold_level := 1
var food_stockpile := 0.0
var starving := false
var scale_tier := 0
var auto_resource_mult := 1.0
var upkeep_mult := 1.0

# ─── Коллекции ─────────────────────────────────────────────────
var pop: Array[PopUnit] = []
var boroughs: Array[Borough] = []
var buildings: Array[UniqueBuilding] = []
var special_sites: Dictionary = {}
var storage: Dictionary = {}
var roads: Dictionary = {}
var resource_ctx: ResourceContext = null

# ─── Колбэки (внедряются извне) ────────────────────────────────
var tile_yield_fn: Callable = func(_cell: Vector2i) -> Dictionary: return {}
var is_buildable_fn: Callable = func(_cell: Vector2i) -> bool: return true

# ─── Внутреннее ────────────────────────────────────────────────
var _uid_seq := 0

# R2: кэш доходности/занятых клеток — CityYieldCalculator (SRP).
var _yield_calc := CityYieldCalculator.new()


func invalidate_yield() -> void:
	_yield_calc.invalidate()


func ensure_resource_ctx(defs: Array = []) -> ResourceContext:
	if resource_ctx == null:
		resource_ctx = ResourceContext.new()
		resource_ctx.setup(defs)
	return resource_ctx
