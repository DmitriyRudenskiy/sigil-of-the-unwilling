extends "res://tests/test_base.gd"
## hero-survival: потребности героя (HeroNeeds), смерть от истощения через
## GameEventBus.hero_died, воскрешение в великом храме как выбор игрока
## (DeathSequence, раз в цикл).

const _HeroNeeds = preload("res://scripts/entities/HeroNeeds.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _WorldController = preload("res://scripts/world/WorldController.gd")
const _DeathSequence = preload("res://scripts/ui/DeathSequence.gd")
const _StatusPanel = preload("res://scripts/ui/HeroStatusPanel.gd")
const _Artifact = preload("res://scripts/data/Artifact.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")
const _BuildingDefs = preload("res://scripts/data/BuildingDefs.gd")
const _UniqueBuilding = preload("res://scripts/world/UniqueBuilding.gd")
const _GameSession = preload("res://scripts/core/GameSession.gd")
const _HeroMovement = preload("res://scripts/entities/HeroMovementController.gd")
const _HeroArmy = preload("res://scripts/entities/HeroArmyController.gd")
const _HeroResources = preload("res://scripts/entities/HeroResources.gd")
const _HeroMagic = preload("res://scripts/entities/HeroMagic.gd")
const _HeroSkills = preload("res://scripts/entities/HeroSkills.gd")
const _HeroTools = preload("res://scripts/entities/HeroTools.gd")
const _TimeSystem = preload("res://scripts/data/TimeSystem.gd")
const _HeroStrategic = preload("res://scripts/entities/HeroStrategicResources.gd")

## Mock DeathSequence: WorldController переиспользует внедрённый _death_seq.
class _MockDeath extends Node:
	# ponytail: visible — свойство Node, но WorldController.is_death_sequence_open()
	# читает _death_seq.visible; у вложенного класса-мока оно не наследуется на
	# рантайме — объявляем явно.
	var visible := true
	signal successor_chosen
	signal return_to_menu
	signal chronicle_requested
	signal resurrection_chosen
	var shown := false
	var res_city: _City = null
	var successor: Node = null
	func show_death(_n: String, _c: StringName, _s: Dictionary, succ: Node = null, rc: _City = null) -> void:
		shown = true
		visible = true
		res_city = rc
		successor = succ

class _MockPersistence extends RefCounted:
	var session := _GameSession.new()
	var chronicle = null
	func get_date() -> Dictionary:
		return {"month": 3, "week": 2, "day": 5}

# ==================== helpers ====================

var _uid := 100

func _next_uid() -> int:
	_uid += 1
	return _uid

func _make_hero(path := &"warrior") -> HeroController:
	var h := _Hero.new()
	# в игре суб-контроллеры ставит _ready (вход в дерево); headless-тесты
	# не обрабатывают кадры — вызываем явно.
	h._ready()
	h.hero_name = "Darkstorn"
	h.path_id = path
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	h.is_alive = true
	# movement — Node, нужен _tick_needs/revive_at/city_tick (читают
	# movement.current_cell). В headless _ready не вызывается — ставим вручную.
	# Суб-узел parent-им к hero: h.free() рекурсивно фрил его (cascade-free).
	h.movement = _HeroMovement.new()
	h.add_child(h.movement)
	return h

func _make_follower(uid: int, path: StringName) -> Follower:
	var f := _Follower.new()
	f.uid = uid
	f.path = path
	return f

func _make_city() -> _City:
	var c := _City.new()
	c.uid = _next_uid()
	c.display_name = &"Testhold"
	c.owner = &"player"
	c.center = Vector2i(5, 5)
	return c

## Город с великим храмом ур.1; resources_ok — хватает ли storage на воскрешение.
func _make_temple_city(resources_ok := true) -> _City:
	var c := _make_city()
	if resources_ok:
		c.storage[&"industry"] = float(_Succession.RESURRECTION_INDUSTRY) + 100.0
		c.storage[&"gold"] = float(_Succession.RESURRECTION_SPECIAL_AMOUNT) + 50.0
	else:
		c.storage[&"industry"] = 1.0
		c.storage[&"gold"] = 1.0
	var bld := _UniqueBuilding.new()
	bld.def = _BuildingDefs.great_temple()
	bld.level = 1
	c.buildings.append(bld)
	return c

func _make_wc(cities: Array, persistence: _MockPersistence = null) -> _WorldController:
	var wc := _WorldController.new()
	wc._rng = RandomNumberGenerator.new()
	var mgr := _CityManager.new()
	for c in cities:
		mgr.register_city(c)
	# ponytail: mgr — потомок wc, чтобы wc.free() рекурсивно фрил mgr + города
	# (города — RefCounted, авто-GC при освобождении mgr). Иначе mgr + города
	# текут как standalone-ссылки (operability gate: N>20).
	wc.add_child(mgr)
	wc._cities = mgr
	wc._succession = _Succession.new()
	wc._persistence = persistence if persistence != null else _MockPersistence.new()
	return wc

## Герой в дереве (нужно для _detach_hero/get_parent).
func _hero_in_tree(hero: HeroController) -> Node:
	var parent := Node.new()
	root.add_child(parent)
	parent.add_child(hero)
	return parent

## Освобождает Node (prеемник/corpse/death), если он валиден и — Node.
## RefCounted (city/succession/session/follower) не фрим — они авто-GC.
func _free_node(o: Variant) -> void:
	if o is Node and is_instance_valid(o):
		o.free()

# ==================== 5.1 HeroNeeds ====================

func test_needs_init_all_full() -> void:
	var n := _HeroNeeds.new()
	for k in _HeroNeeds.NEED_KEYS:
		assert_approx(n.get_need(k), 1.0, 0.0001, "need %s = 1.0" % String(k))
		assert_eq(n.zero_streak[k], 0, "streak %s = 0" % String(k))


func test_needs_field_decay() -> void:
	var n := _HeroNeeds.new()
	assert_eq(n.tick(false), &"", "field tick — alive")
	assert_approx(n.get_need(&"hunger"), 0.85, 0.0001, "hunger decay 0.15")
	assert_approx(n.get_need(&"rest"), 0.90, 0.0001, "rest decay 0.10")
	assert_approx(n.get_need(&"social"), 0.92, 0.0001, "social decay 0.08")
	assert_approx(n.get_need(&"inspiration"), 0.95, 0.0001, "inspiration decay 0.05")


func test_needs_city_recovery() -> void:
	var n := _HeroNeeds.new()
	for k in _HeroNeeds.NEED_KEYS:
		n.needs[k] = 0.5
	var c := _make_temple_city()
	c.pop = [_PopUnit.new(), _PopUnit.new(), _PopUnit.new()]  # pop >= 3
	assert_eq(n.tick(true, c), &"", "city tick — alive")
	assert_approx(n.get_need(&"hunger"), 0.55, 0.0001, "hunger 0.5 - 0.15 + 0.20")
	assert_approx(n.get_need(&"rest"), 0.52, 0.0001, "rest 0.5 - 0.10 + 0.12")
	assert_approx(n.get_need(&"social"), 0.52, 0.0001, "social 0.5 - 0.08 + 0.10 (pop>=3)")
	assert_approx(n.get_need(&"inspiration"), 0.50, 0.0001, "inspiration 0.5 - 0.05 + 0.05")


func test_needs_starving_city_hunger_drains() -> void:
	var n := _HeroNeeds.new()
	n.needs[&"hunger"] = 0.5
	var c := _make_temple_city()
	c.starving = true
	n.tick(true, c)
	assert_approx(n.get_need(&"hunger"), 0.25, 0.0001, "starving: hunger 0.5 - 0.15 - 0.10")


func test_needs_lonely_city_social_drains() -> void:
	var n := _HeroNeeds.new()
	n.needs[&"social"] = 0.5
	var c := _make_temple_city()  # pop пустой
	n.tick(true, c)
	assert_approx(n.get_need(&"social"), 0.37, 0.0001, "lonely: social 0.5 - 0.08 - 0.05")


func test_needs_zero_streak_all_causes() -> void:
	var cases := {
		&"hunger": &"starvation",
		&"rest": &"exhaustion",
		&"social": &"isolation",
		&"inspiration": &"burnout",
	}
	for need_id in cases:
		var m := _HeroNeeds.new()
		m.needs[need_id] = 0.0
		assert_eq(m.tick(false), &"", "streak 1 alive (%s)" % String(need_id))
		assert_eq(m.tick(false), &"", "streak 2 alive (%s)" % String(need_id))
		assert_eq(m.tick(false), cases[need_id], "death cause for %s" % String(need_id))


func test_needs_serialize_roundtrip_and_old_save() -> void:
	var n := _HeroNeeds.new()
	n.needs[&"rest"] = 0.33
	n.zero_streak[&"rest"] = 2
	var m := _HeroNeeds.new()
	m.deserialize(n.serialize())
	assert_approx(m.get_need(&"rest"), 0.33, 0.0001, "rest survives roundtrip")
	assert_approx(m.get_need(&"hunger"), 1.0, 0.0001, "hunger untouched")
	assert_eq(m.zero_streak[&"rest"], 0, "streak is not persisted")
	# Старый сейв (нет ключа needs) — все потребности полные.
	var old := _HeroNeeds.new()
	old.deserialize({})
	for k in _HeroNeeds.NEED_KEYS:
		assert_approx(old.get_need(k), 1.0, 0.0001, "old save: %s = 1.0" % String(k))


# ==================== 5.2 HeroController ====================

func test_hero_dies_by_needs_emits_hero_died() -> void:
	var h := _make_hero()
	h.needs.needs[&"hunger"] = 0.0
	# ponytail: лямбда захватывает примитивы по значению — держатель-дикт
	var captured: Dictionary = {"cause": &""}
	var on_died := func(cause: StringName) -> void: captured["cause"] = cause
	GameEventBus.hero_died.connect(on_died)
	h._tick_needs()
	h._tick_needs()
	assert_true(h.is_alive, "alive after 2 ticks at zero")
	h._tick_needs()
	GameEventBus.hero_died.disconnect(on_died)
	assert_false(h.is_alive, "dead after 3rd tick")
	assert_eq(captured["cause"], &"starvation", "hero_died(&\"starvation\") emitted")
	h.free()


func test_hero_city_tick_recovers() -> void:
	var h := _make_hero()
	var c := _make_temple_city()
	c.pop = [_PopUnit.new(), _PopUnit.new(), _PopUnit.new()]
	var mgr := _CityManager.new()
	mgr.register_city(c)
	h.city_manager = mgr
	h.movement.current_cell = c.center
	for k in _HeroNeeds.NEED_KEYS:
		h.needs.needs[k] = 0.5
	h._tick_needs()
	assert_approx(h.needs.get_need(&"hunger"), 0.55, 0.0001, "in-city tick recovers hunger")
	assert_approx(h.needs.get_need(&"social"), 0.52, 0.0001, "pop>=3: social recovers")
	mgr.free()
	h.free()


func test_hero_revive_at() -> void:
	var h := _make_hero()
	h.is_alive = false
	h.set_combat_hp(0)
	h.inventory.backpack.append(_Artifact.new())
	h.inventory.equipped["weapon"] = _Artifact.new()
	for k in _HeroNeeds.NEED_KEYS:
		h.needs.needs[k] = 0.2
	var c := _make_temple_city()
	c.center = Vector2i(9, 9)
	h.revive_at(c)
	assert_true(h.is_alive, "alive after revive")
	assert_eq(h.combat_hp, 20, "HP restored to max")
	for k in _HeroNeeds.NEED_KEYS:
		assert_approx(h.needs.get_need(k), 1.0, 0.0001, "needs reset: %s" % String(k))
	assert_true(h.inventory.backpack.is_empty(), "backpack wiped")
	assert_true(h.inventory.equipped.is_empty(), "equipment wiped")
	assert_eq(h.movement.current_cell, Vector2i(9, 9), "position at temple city center")
	# revive_at пишет movement.current_cell — нужен суб-узел.
	h.free()


## Полные serialize/deserialize требуют инициализированных суб-контроллеров
## (в игре их ставит WorldBootstrap).
func _setup_serializable(h: HeroController) -> void:
	# суб-узлы (movement/resources/army) — Node: parent-им к h, чтобы h.free()
	# рекурсивно фрил их (RefCounted magic/skills/tools/time — авто-GC).
	h.movement = _HeroMovement.new()
	h.army = _HeroArmy.new()
	h.resources = _HeroResources.new()
	h.add_child(h.movement)
	h.add_child(h.army)
	h.add_child(h.resources)
	h.magic = _HeroMagic.new()
	h.skills = _HeroSkills.new()
	h.tools = _HeroTools.new()
	h.time = _TimeSystem.new()
	h.strategic_resources = _HeroStrategic.new()


func test_hero_serialize_needs_roundtrip() -> void:
	var h := _make_hero()
	h.hero_name = "Тест"
	_setup_serializable(h)
	h.needs.needs[&"rest"] = 0.33
	h.resurrected_once = true
	var h2 := _Hero.new()
	_setup_serializable(h2)
	h2.deserialize(h.serialize())
	assert_approx(h2.needs.get_need(&"rest"), 0.33, 0.0001, "rest survives save/load")
	assert_approx(h2.needs.get_need(&"hunger"), 1.0, 0.0001, "hunger survives at 1.0")
	assert_true(h2.resurrected_once, "resurrected_once survives save/load")
	h.free(); h2.free()


func test_hero_deserialize_old_save_defaults() -> void:
	var h := _make_hero()
	_setup_serializable(h)
	var d := h.serialize()
	d.erase("needs")
	d.erase("resurrected_once")
	var h2 := _Hero.new()
	_setup_serializable(h2)
	h2.deserialize(d)
	for k in _HeroNeeds.NEED_KEYS:
		assert_approx(h2.needs.get_need(k), 1.0, 0.0001, "old save: %s = 1.0" % String(k))
	assert_false(h2.resurrected_once, "old save: resurrected_once = false")
	h.free(); h2.free()


# ==================== 5.3 WorldController — воскрешение ====================

func test_wc_find_resurrection_city() -> void:
	var city := _make_temple_city()
	var wc := _make_wc([city])
	var fresh := _make_hero()
	assert_eq(wc._find_resurrection_city(fresh), city, "candidate found")
	fresh.resurrected_once = true
	assert_null(wc._find_resurrection_city(fresh), "once-per-cycle guard")
	fresh.free()
	var poor := _make_temple_city(false)
	var wc2 := _make_wc([poor])
	var h2 := _make_hero()
	assert_null(wc2._find_resurrection_city(h2), "insufficient storage — no candidate")
	h2.free()
	var plain := _make_city()
	var wc3 := _make_wc([plain])
	var h3 := _make_hero()
	assert_null(wc3._find_resurrection_city(h3), "no great temple — no candidate")
	h3.free()
	wc.free(); wc2.free(); wc3.free()


## Смерть героя с преемником и городом-храмом: труп удерживается,
## последовательности показаны, кнопке передан res_city.
func _setup_death_with_resurrection() -> Dictionary:
	var city := _make_temple_city()
	var wc := _make_wc([city])
	var hero := _make_hero()
	hero.movement = _HeroMovement.new()
	hero.add_child(hero.movement)
	hero.followers.append(_make_follower(1, &"warrior"))
	var parent := _hero_in_tree(hero)
	wc._hero = hero
	var death := _MockDeath.new()
	wc._death_seq = death
	wc._on_hero_died(&"starvation")
	return {"wc": wc, "hero": hero, "city": city, "parent": parent, "death": death}


func test_wc_death_holds_corpse_shows_resurrection() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	var city: _City = s["city"]
	var death: Node = s["death"]
	assert_true(is_instance_valid(hero), "corpse not freed")
	assert_eq(wc._deceased_hero, hero, "wc holds the corpse")
	assert_eq(wc._resurrection_city, city, "resurrection city chosen")
	assert_not_null(wc._pending_successor, "pending successor planned")
	assert_null(hero.get_parent(), "corpse detached from tree")
	assert_true(death.shown, "death sequence shown")
	assert_eq(death.res_city, city, "res_city passed to sequence (button visible)")
	assert_not_null(death.successor, "successor passed to sequence")
	hero.free()
	s["parent"].free()
	death.free()
	_free_node(wc._pending_successor)
	wc.free()


func test_wc_resurrection_chosen() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	var city: _City = s["city"]
	var death: Node = s["death"]
	var successor: Node = wc._pending_successor
	var succ_emitted: Dictionary = {"v": false}  # лямбда-захват примитива по значению
	var on_succ := func(_h: Node) -> void: succ_emitted["v"] = true
	GameEventBus.hero_successor.connect(on_succ)
	wc._on_resurrection_chosen()
	GameEventBus.hero_successor.disconnect(on_succ)
	assert_true(hero.is_alive, "hero alive after resurrection")
	assert_true(hero.resurrected_once, "resurrected_once set")
	for k in _HeroNeeds.NEED_KEYS:
		assert_approx(hero.needs.get_need(k), 1.0, 0.0001, "needs reset: %s" % String(k))
	assert_eq(hero.combat_hp, hero.max_combat_hp, "HP restored")
	assert_eq(hero.movement.current_cell, city.center, "hero at temple city")
	assert_approx(city.storage[&"industry"], 100.0, 0.5, "industry paid (600→100)")
	assert_approx(city.storage[&"gold"], 50.0, 0.5, "gold paid (150→50)")
	assert_null(wc._deceased_hero, "corpse ref cleared")
	assert_null(wc._resurrection_city, "resurrection city cleared")
	assert_null(wc._pending_successor, "pending successor cleared")
	assert_false(is_instance_valid(successor), "unused successor freed")
	assert_eq(wc._hero, hero, "hero reinstalled as active")
	assert_false(wc.is_death_sequence_open(), "death sequence closed")
	assert_false(succ_emitted["v"], "hero_successor NOT emitted (cycle continues)")
	s["parent"].free()
	death.free()
	wc.free()  # hero — child wc, освобождается вместе


func test_wc_second_death_in_cycle_no_resurrection() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	var death: Node = s["death"]
	wc._on_resurrection_chosen()
	# Повторная смерть в том же цикле (resurrected_once = true).
	hero.followers.append(_make_follower(9, &"warrior"))
	wc._on_hero_died(&"exhaustion")
	assert_null(wc._deceased_hero, "no corpse hold on second death")
	assert_null(wc._resurrection_city, "no resurrection city on second death")
	assert_false(is_instance_valid(hero), "corpse freed on second death (old behavior)")
	assert_not_null(wc._pending_successor, "successor still planned")
	assert_true(is_instance_valid(wc._pending_successor), "successor alive")
	assert_eq(death.res_city, null, "sequence gets no res_city (button hidden)")
	# Successor — Node: фрим (RefCounted-у SuccessionController не трогаем).
	_free_node(wc._pending_successor)
	s["parent"].free()
	death.free()
	wc.free()


func test_wc_succession_frees_held_corpse() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	wc._execute_succession()
	assert_null(wc._deceased_hero, "corpse ref cleared by succession")
	assert_false(is_instance_valid(hero), "held corpse freed by succession")
	assert_null(wc._pending_successor, "pending successor cleared")
	assert_not_null(wc._hero, "successor installed")
	assert_true(is_instance_valid(wc._hero), "successor alive")
	s["parent"].free()
	s["death"].free()
	wc.free()  # successor — child wc


func test_wc_no_temple_corpse_freed() -> void:
	var plain := _make_city()
	var wc := _make_wc([plain])
	var hero := _make_hero()
	hero.followers.append(_make_follower(2, &"warrior"))
	var parent := _hero_in_tree(hero)
	wc._hero = hero
	var death := _MockDeath.new()
	wc._death_seq = death
	wc._on_hero_died(&"starvation")
	assert_null(wc._deceased_hero, "no corpse hold without temple")
	assert_false(is_instance_valid(hero), "corpse freed (old behavior)")
	assert_eq(death.res_city, null, "no res_city (button hidden)")
	parent.free()
	death.free()
	_free_node(wc._pending_successor)
	wc.free()


func test_wc_fresh_cycle_resurrection_again() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var city: _City = s["city"]
	var death: Node = s["death"]
	wc._on_resurrection_chosen()
	# Воскрешённый герой умирает повторно → succession (без воскрешения).
	var hero: HeroController = wc._hero
	hero.followers.append(_make_follower(9, &"warrior"))
	wc._on_hero_died(&"burnout")
	assert_null(wc._resurrection_city, "resurrected hero: no resurrection again")
	var succ: Node = wc._pending_successor
	wc._execute_succession()
	# Новый герой = свежий цикл: склад пополнен → кнопка снова доступна.
	var new_hero: HeroController = wc._hero
	new_hero.followers.append(_make_follower(10, &"warrior"))
	city.storage[&"industry"] = float(_Succession.RESURRECTION_INDUSTRY)
	city.storage[&"gold"] = float(_Succession.RESURRECTION_SPECIAL_AMOUNT)
	wc._on_hero_died(&"starvation")
	assert_eq(wc._resurrection_city, city, "fresh cycle: resurrection offered again")
	assert_eq(wc._deceased_hero, new_hero, "new hero's corpse held")
	assert_eq(death.res_city, city, "res_city passed again")
	new_hero.free()
	s["parent"].free()
	death.free()
	_free_node(wc._pending_successor)
	wc.free()


# ==================== 4.1 DeathSequence — кнопка (реальный UI) ====================

func test_deathseq_resurrection_button_flow() -> void:
	var ds := _DeathSequence.new()
	var city := _make_temple_city()
	var succ := _make_hero()
	var emitted: Dictionary = {"v": false}  # лямбда-захват примитива по значению
	ds.resurrection_chosen.connect(func() -> void: emitted["v"] = true)
	ds.show_death("Тест", &"starvation", {}, succ, city)
	var btn: Button = ds.get_node("Root/Panel/VBox/Buttons/ResurrectionButton")
	assert_true(btn.visible, "button visible with res_city + successor")
	assert_eq(btn.text, "Воскресить (500⚙ + 100💰)", "button shows the cost")
	btn.pressed.emit()
	assert_true(emitted["v"], "resurrection_chosen emitted")
	ds.free()
	succ.free()
	# Без res_city — кнопка скрыта.
	var ds2 := _DeathSequence.new()
	var succ2 := _make_hero()
	ds2.show_death("Тест", &"battle", {}, succ2, null)
	assert_false(ds2.get_node("Root/Panel/VBox/Buttons/ResurrectionButton").visible,
		"button hidden without res_city")
	ds2.free()
	succ2.free()
	# Без преемника — кнопка скрыта (вариант недоступен).
	var ds3 := _DeathSequence.new()
	ds3.show_death("Тест", &"battle", {}, null, city)
	assert_false(ds3.get_node("Root/Panel/VBox/Buttons/ResurrectionButton").visible,
		"button hidden without successor")
	ds3.free()


# ==================== 4.2 HeroStatusPanel — потребности ====================

func test_statuspanel_needs_line() -> void:
	var panel := _StatusPanel.new()
	var h := _make_hero()
	h.hero_name = "Тест"
	h.needs.needs[&"hunger"] = 0.1
	panel.set_hero(h)
	panel.refresh()
	var text := panel._cond_label.text
	assert_true(text.contains("🍞⚠️ 10%"), "critical hunger highlighted: " + text)
	assert_true(text.contains("😴 100%"), "rest at 100%: " + text)
	assert_true(text.contains("🤝 100%"), "social at 100%: " + text)
	assert_true(text.contains("💡 100%"), "inspiration at 100%: " + text)
	panel.free()
	h.free()
