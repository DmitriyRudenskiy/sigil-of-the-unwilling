class_name CityScreen
extends Control

const DeceptionCheck = preload("res://scripts/systems/deception_check.gd")
const ReputationSystem = preload("res://scripts/city/reputation_system.gd")
const WeaponTechService = preload("res://scripts/systems/weapon_tech_service.gd")
const LeadershipCheck = preload("res://scripts/systems/leadership_check.gd")

signal close_requested
signal state_changed

var city: City = null
var hero: HeroController = null
var hero_cell: Vector2i = Vector2i(-1, -1)
var rng: RandomNumberGenerator = null
var map_bounds: Vector2i = Vector2i.ZERO

var _bg: Panel
var _stats_label: Label
var _buildings_label: Label
var _title_label: Label
var _message_label: Label
var _opened := false

func _ready() -> void:
	_bg = get_node("CityScreenBackground") as Panel
	var box := get_node("CityScreenBackground/CityScreenCenter/CityScreenPanel/CityScreenBox")
	_title_label = box.get_node("CityScreenTitle") as Label
	_stats_label = box.get_node("CityScreenStats") as Label
	_buildings_label = box.get_node("CityScreenBuildings") as Label
	_message_label = box.get_node("CityScreenMessage") as Label
	var buttons := box.get_node("CityScreenButtons") as HBoxContainer
	var build_farm := buttons.get_node("BuildFarm") as Button
	build_farm.pressed.connect(_on_build_farm_pressed)
	build_farm.text = GameText.city_build_farm()
	var build_mine := buttons.get_node("BuildMine") as Button
	build_mine.pressed.connect(_on_build_mine_pressed)
	build_mine.text = GameText.city_build_mine()
	var level_up := buttons.get_node("LevelUp") as Button
	level_up.pressed.connect(_on_level_up_pressed)
	level_up.text = GameText.city_level_up()
	var hire := buttons.get_node("Hire") as Button
	hire.pressed.connect(_on_hire_pressed)
	hire.text = GameText.city_hire()
	var unload := buttons.get_node("Unload") as Button
	unload.pressed.connect(_on_unload_pressed)
	unload.text = GameText.city_unload()
	var cart := buttons.get_node("Cart") as Button
	cart.pressed.connect(_on_cart_pressed)
	cart.text = GameText.city_cart()
	var recruit := buttons.get_node("Recruit") as Button
	recruit.pressed.connect(_on_recruit_pressed)
	recruit.text = GameText.city_recruit()
	var close_btn := buttons.get_node("Close") as Button
	close_btn.pressed.connect(_on_close_pressed)
	close_btn.text = GameText.city_close()

func setup(c: City, h: HeroController, h_cell: Vector2i,
		r: RandomNumberGenerator = null, m_bounds: Vector2i = Vector2i.ZERO) -> void:
	city = c
	hero = h
	hero_cell = h_cell
	rng = r
	map_bounds = m_bounds
	_message_label.text = ""
	refresh()

func open() -> void:
	if city == null:
		return
	if not _opened:
		_opened = true
		visible = true
	refresh()
	state_changed.emit()

func close() -> void:
	if not _opened:
		return
	_opened = false
	visible = false
	state_changed.emit()

func is_open() -> bool:
	return _opened

func refresh() -> void:
	if city == null or not is_instance_valid(city):
		return
	_title_label.text = GameText.city_level_title(city.display_name, city.level)

	var lines: Array[String] = []
	lines.append(GameText.city_population_detail(str(city.pop_capped()), city.free_followers()))
	lines.append(GameText.city_food_netto("%.0f" % city.food_stockpile, "%+.1f" % city.net_food()))
	lines.append(GameText.city_industry_gold("%.0f" % _storage_industry(), "%.0f" % _gold()))
	lines.append(GameText.city_prosperity_reputation("%.0f" % city.prosperity, city.reputation))
	# attribute-weight-system: вес/лимит рюкзака героя
	if hero != null and hero.strategic_resources != null:
		var w: float = hero.strategic_resources.current_weight()
		var cap: float = hero.strategic_resources.weight_cap
		lines.append("Рюкзак: %.1f / %.1f" % [w, cap])
	# social-stats-weapon-tech: тир технологий и cap отряда
	if hero != null:
		var cha: int = int(hero.stats.get("cha", 2))
		var tier: int = WeaponTechService.city_weapon_tier(city, cha)
		var cap: int = mini(LeadershipCheck.max_army_stacks(cha), GameNumbers.HERO_ARMY_MAX_STACKS)
		lines.append("Технологии: тир %d | Отряд: %d/%d" % [tier, hero.get_army().army.size() if hero.get_army() != null else 0, cap])
	_stats_label.text = "\n".join(lines)

	var b_lines: Array[String] = []
	for building in city.buildings:
		if building == null or building.def == null:
			continue
		b_lines.append(GameText.city_building_line(building.def.display_name, building.level, building.cell.x, building.cell.y))
	_buildings_label.text = (GameText.city_buildings() + ":\n" + "\n".join(b_lines)) \
		if not b_lines.is_empty() else GameText.city_buildings_none()
	if _message_label.text == "":
		_message_label.text = GameText.city_intro()

func _on_build_farm_pressed() -> void:
	build_pressed(&"farm")

func _on_build_mine_pressed() -> void:
	build_pressed(&"mine")

func _on_level_up_pressed() -> void:
	level_up_pressed()

func _on_hire_pressed() -> void:
	hire_pressed()

func build_pressed(def_id: StringName) -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	var def := BuildingDefs.def_by_id(def_id)
	if def == null:
		return _fail(GameText.city_building_not_found(str(def_id)))
	var cell := city.first_free_build_cell(def, map_bounds)
	if cell == Vector2i(-1, -1):
		return _fail(GameText.city_no_cell())
	var check: CityCheck = city.can_build_building(def, cell)
	if not check.ok:
		return _fail(GameText.city_cannot_build(str(check.reason if check.reason != "" else "?")))
	var bld := city.build_building(def, cell)
	if bld == null:
		return _fail(GameText.city_build_failed())
	_set_message(GameText.city_built(def.display_name, cell.x, cell.y, _format_cost(def)))
	refresh()
	return CityCheck.success({"building": String(def_id), "level": bld.level,
		"cell": SerializationUtils.vec2i_to_dict(cell),
		"industry_left": _storage_industry()})

func level_up_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if city.level >= GameNumbers.CITY_LEVEL_MAX:
		return _fail(GameText.city_max_level())
	var check: Dictionary = ProsperitySystem.can_level_up(city)
	if not bool(check.get("ok", false)):
		return _fail(GameText.city_cannot_upgrade("; ".join(check.get("reasons", []))))
	var prev_level := city.level
	if not ProsperitySystem.try_level_up(city):
		return _fail(GameText.city_upgrade_failed())
	_set_message(GameText.city_upgraded(prev_level, city.level))
	refresh()
	return CityCheck.success({"level": city.level})

func hire_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null:
		return _fail(GameText.city_hire_no_hero())
	# social-stats-weapon-tech: найм — договорная сделка (обман)
	var dec: Dictionary = _deception("contract")
	if bool(dec.get("deceived", false)) and int(dec.get("severity", 1)) >= 3:
		ReputationSystem.apply(city, -10)
		_set_message(str(dec.get("note", "")))
		refresh()
		return _fail(GameText.city_no_followers())
	var f := FollowerSystem.recruit(city, hero, rng)
	if f == null:
		return _fail(GameText.city_no_followers())
	_set_message(GameText.city_hired(f.describe(FollowerSystem.registry())))
	refresh()
	return CityCheck.success({"follower": f.to_dict()})

func _on_unload_pressed() -> void:
	unload_pressed()

func _on_cart_pressed() -> void:
	buy_cart_pressed()

## Ранняя игра: выгрузка рюкзака в хранилище города (early-game-foundation)
func unload_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null or hero.strategic_resources == null:
		return _fail(GameText.city_hire_no_hero())
	var all: Dictionary = hero.strategic_resources.get_all()
	var moved := 0
	for id in all:
		var amount: int = int(all[id])
		if amount <= 0:
			continue
		var actual: int = hero.remove_strategic_resource(id, amount)
		if actual > 0:
			city.storage[id] = float(city.storage.get(id, 0.0)) + float(actual)
			moved += actual
	if moved == 0:
		return _fail(GameText.city_unload_empty())
	city.storage_changed.emit()
	_set_message(GameText.city_unloaded(moved))
	refresh()
	return CityCheck.success({"moved": moved})

## Ранняя игра: рыночная телега — расширение рюкзака (early-game-foundation)
func buy_cart_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null or hero.strategic_resources == null:
		return _fail(GameText.city_hire_no_hero())
	if not _has_market():
		return _fail(GameText.city_cart_no_market())
	var message := ""
	var cost: float = GameNumbersHero.BACKPACK_CART_COST
	# social-stats-weapon-tech: покупка телеги — важная сделка (обман)
	var dec: Dictionary = _deception("purchase")
	if bool(dec.get("deceived", false)):
		var sev: int = int(dec.get("severity", 1))
		var surcharge: float = float(GameNumbers.DECEPTION_SEVERITIES[sev].get("surcharge", 0.15))
		cost = cost * (1.0 + surcharge)
		if sev >= 3 and city != null:
			ReputationSystem.apply(city, -10)  # кабальный договор
		message += " %s" % str(dec.get("note", ""))
	elif bool(dec.get("revealed", false)):
		message += " %s" % str(dec.get("note", ""))
	else:
		cost = cost * (1.0 - float(dec.get("discount", 0.0)))
	if _storage_industry() < cost:
		return _fail(GameText.city_cart_no_funds(cost))
	city.storage[&"industry"] = _storage_industry() - cost
	city.storage_changed.emit()
	hero.strategic_resources.capacity_bonus += GameNumbersHero.BACKPACK_CART_BONUS
	_set_message((GameText.city_cart_bought(hero.strategic_resources.total_cap()) + message).strip_edges())
	refresh()
	return CityCheck.success({"cap": hero.strategic_resources.total_cap()})

## Ранняя игра: военная рекрутка (early-game-foundation)
func _on_recruit_pressed() -> void:
	recruit_pressed()

func recruit_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null:
		return _fail(GameText.city_hire_no_hero())
	var bld: UniqueBuilding = null
	for b in city.buildings:
		if b != null and b.def != null and not b.def.military_chain.is_empty():
			bld = b
			break
	if bld == null:
		return _fail(GameText.city_recruit_no_building())
	var check: CityCheck = CityService.recruit_military(city, bld, hero)
	if not check.ok:
		return _fail(GameText.city_cannot_recruit(str(check.reason)))
	city.storage_changed.emit()
	_set_message(GameText.city_recruited(String(check.payload.get("unit", "")),
		int(check.payload.get("count", 0)), int(check.payload.get("tier", 1))))
	refresh()
	return check

func _has_market() -> bool:
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"market":
			return true
	return false


func _on_close_pressed() -> void:
	close_requested.emit()

func _fail(message: String) -> CityCheck:
	_set_message(message)
	return CityCheck.fail(message)

## social-stats-weapon-tech: бросок обмана по статам героя; мелкая торговля не проверяется
func _deception(kind: String) -> Dictionary:
	if hero == null:
		return {"deceived": false, "severity": 0, "note": "", "discount": 0.0, "revealed": false}
	var s: Dictionary = hero.stats
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	var base: int = int(GameNumbers.DECEPTION_BASE.get(kind, 10))
	return DeceptionCheck.roll(r,
		int(s.get("int", 2)), int(s.get("wis", 2)),
		int(s.get("cha", 2)), int(s.get("luk", 2)),
		base, 14)

func _set_message(text: String) -> void:
	_message_label.text = text

func _storage_industry() -> float:
	if city == null:
		return 0.0
	return float(city.storage.get(&"industry", 0.0))

func _gold() -> float:
	if city == null or city.resource_ctx == null:
		return 0.0
	return city.resource_ctx.amount(&"gold")

func _format_cost(def: UniqueBuilding.Def) -> String:
	if def == null or def.levels.is_empty():
		return ""
	var req: UniqueBuilding.LevelReq = def.levels[0]
	var parts: Array[String] = []
	if req.industry > 0.0:
		parts.append(GameText.city_cost_industry("%.0f" % req.industry))
	if req.special_amount > 0.0:
		parts.append(GameText.city_cost_special(str(req.special_resource), "%.0f" % req.special_amount))
	if req.followers > 0:
		parts.append(GameText.city_cost_followers(req.followers))
	return ", ".join(parts) if not parts.is_empty() else GameText.city_cost_free()
