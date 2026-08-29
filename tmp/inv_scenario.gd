extends SceneTree
## Сценарий «Auto-Game» для инвентаря героя.
## Проверяет три вещи:
##   1. Перелистывание страниц рюкзака (prev/next).
##   2. Назначение предмета в правильный слот (экипировка).
##   3. Все возможные комбинации размещения (артефакт × слот).
##
## Запуск: godot --headless -s tmp/inv_scenario.gd
## Выход 0 — всё ок, 1 — есть фейлы.

const NEW_ARTS := [&"greatsword_might", &"longbow_hawk", &"staff_void",
	&"helm_bulwark", &"hood_wraith", &"circlet_aurora",
	&"plate_dread", &"leather_stalker", &"robes_astronomer",
	&"greaves_juggernaut", &"wraps_peregrine", &"skirt_conjunction",
	&"boots_titan", &"boots_zephyr", &"soles_mercury",
	&"shield_greatwall", &"buckler_ripple", &"ward_arcane",
	&"amulet_prescience", &"charm_beast", &"trinket_epoch",
	&"ring_giant", &"ring_lexicon", &"tome_infinity"]

var _reg: ArtifactRegistry = null
var _checks := 0
var _fails := 0


func _report(ok: bool, msg: String) -> void:
	_checks += 1
	if ok:
		print("  \u2705 %s" % msg)
	else:
		_fails += 1
		print("  \u274C %s" % msg)


func _id_ok(id: StringName) -> bool:
	return _reg.get_by_id(id) != null
# Рекурсивный поиск узла по имени в поддереве.
func _find_by_name(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for c in root.get_children():
		var found := _find_by_name(c, name)
		if found != null:
			return found
	return null

# Видимые индексы рюкзака на текущей странице (по имени BpIcon_<idx>).
func _visible_page(inv: Node) -> Array:
	var idxs := []
	for i in 6:
		var slot = _find_by_name(inv, "BackpackSlot_%d" % i)
		var found := -1
		if slot != null:
			for c in slot.get_children():
				if c is TextureRect and c.name.begins_with("BpIcon_"):
					found = int(c.name.split("_")[1])
		idxs.append(found)
	return idxs


func _init() -> void:
	_reg = ArtifactRegistry.new()
	_reg.ensure_definitions()
	call_deferred("_run")


func _run() -> void:
	print("=== INV SCENARIO: full-inventory hero ===")

	# --- Проверка, что все новые артефакты зарегистрированы ---
	print("\n[0] Регистрация 24 артефактов")
	for id in NEW_ARTS:
		_report(_id_ok(id), "registered %s" % id)

	# --- Герой с полным инвентарём ---
	print("\n[1] Герой с полным инвентарём")
	var hero := HeroController.new()
	hero.hero_name = "Джит"
	hero.stats = {"attack": 6, "defense": 5, "spell_power": 8, "knowledge": 7, "specialty": 1}
	hero.inventory.equipped[Artifact.Slot.WEAPON] = _reg.get_by_id(&"greatsword_might")
	hero.inventory.equipped[Artifact.Slot.HEAD] = _reg.get_by_id(&"helm_bulwark")
	hero.inventory.equipped[Artifact.Slot.TORSO] = _reg.get_by_id(&"plate_dread")
	hero.inventory.equipped[Artifact.Slot.LEGS] = _reg.get_by_id(&"greaves_juggernaut")
	hero.inventory.equipped[Artifact.Slot.BOOTS] = _reg.get_by_id(&"boots_titan")
	hero.inventory.equipped[Artifact.Slot.SHIELD] = _reg.get_by_id(&"shield_greatwall")
	hero.inventory.equipped[Artifact.Slot.NECK] = _reg.get_by_id(&"amulet_prescience")
	hero.inventory.equipped[Artifact.Slot.RING_L] = _reg.get_by_id(&"ring_giant")
	hero.inventory.equipped[Artifact.Slot.RING_R] = _reg.get_by_id(&"ring_lexicon")
	hero.inventory.equipped[Artifact.Slot.MISC_A] = _reg.get_by_id(&"charm_beast")
	hero.inventory.equipped[Artifact.Slot.MISC_B] = _reg.get_by_id(&"trinket_epoch")
	# Рюкзак полон (16) — новые артефакты, которые ещё не нагеры.
	for id in NEW_ARTS:
		var art: Artifact = _reg.get_by_id(id)
		if hero.inventory.backpack.size() >= GameSettings.MAX_BACKPACK_SIZE:
			break
		hero.inventory.backpack.append(art)
	print("    equipped=%d backpack=%d" % [
		hero.inventory.equipped.values().count(func(v): return v != null),
		hero.inventory.backpack.size()])

	# --- Размещение сцены (как в inv_shot.gd) ---
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("h_separation", 0)
	root.add_theme_constant_override("v_separation", 0)
	var c1 := CenterContainer.new()
	c1.set_anchors_preset(Control.PRESET_FULL_RECT)
	c1.add_theme_constant_override("h_separation", 0)
	c1.add_theme_constant_override("v_separation", 0)
	var c2 := CenterContainer.new()
	c2.set_anchors_preset(Control.PRESET_FULL_RECT)
	c2.add_theme_constant_override("h_separation", 0)
	c2.add_theme_constant_override("v_separation", 0)
	root.add_child(c1)
	c1.add_child(c2)
	var scr := ArtifactInventoryScreen.new()
	c2.add_child(scr)
	scr.set_hero(hero)
	var root_node := get_root()
	root_node.add_child(root)
	for _i in 6:
		await create_timer(0.03).timeout

	# --- 1. Перелистывание страниц ---
	print("\n[2] Перелистывание рюкзака (prev/next)")
	# Рюкзак = 16 предметов -> max_page = floor((16-6)/6) = 1 (страницы 0 и 1).
	var expected: Dictionary = {
		0: [0, 1, 2, 3, 4, 5],
		1: [6, 7, 8, 9, 10, 11],
	}
	# Страница 0 по умолчанию.
	var inv = _find_by_name(scr, "Inventory")
	var right = _find_by_name(scr, "Right")
	_report(inv != null and _visible_page(inv) == expected[0], "page0 -> bp[0..5]")
	scr._backpack_scroll_by(1)
	_report(scr.bp_page == 1 and _visible_page(inv) == expected[1], "next -> page1 bp[6..11]")
	scr._backpack_scroll_by(1)
	_report(scr.bp_page == 1, "next clamped at max_page (no over-scroll)")
	scr._backpack_scroll_by(-1)
	_report(scr.bp_page == 0 and _visible_page(inv) == expected[0], "back -> page0")
	scr._backpack_scroll_by(-1)
	_report(scr.bp_page == 0, "prev clamped at 0 (no under-scroll)")

	# --- 2. Назначение предмета в правильный слот ---
	print("\n[3] Назначение предмета в правильный слот")
	var eq_slots := [
		[&"longbow_hawk", Artifact.Slot.WEAPON],
		[&"hood_wraith", Artifact.Slot.HEAD],
		[&"leather_stalker", Artifact.Slot.TORSO],
		[&"wraps_peregrine", Artifact.Slot.LEGS],
		[&"boots_zephyr", Artifact.Slot.BOOTS],
		[&"buckler_ripple", Artifact.Slot.SHIELD],
		[&"circlet_aurora", Artifact.Slot.HEAD],
		[&"staff_void", Artifact.Slot.WEAPON],
		[&"ring_giant", Artifact.Slot.RING_L],
		[&"amulet_prescience", Artifact.Slot.NECK],
	]
	for entry in eq_slots:
		var aid: StringName = entry[0]
		var slot: Artifact.Slot = entry[1]
		hero.inventory.backpack.clear()
		# Очистить слот, в который экипируем, чтобы не было конфликта.
		for s in hero.inventory.equipped:
			hero.inventory.equipped[s] = null
		hero.inventory.backpack.append(_reg.get_by_id(aid))
		scr._on_equip()
		var got: Artifact = hero.inventory.equipped.get(slot, null)
		_report(got != null and got.id == aid,
			"%s -> equip into %s" % [aid, Artifact.Slot.keys()[int(slot)]])
		# Накладка на кукле появилась.
		var has_ov := false
		if right != null:
			for ch in right.get_children():
				# _rebuild_equipped даёт накладке имя Equip_<int(slot)> (из eq.equipped.keys()).
				if ch is TextureRect and ch.name == "Equip_%s" % int(slot):
					has_ov = true
		_report(has_ov, "%s -> overlay Equip_%s on doll" % [aid, Artifact.Slot.keys()[int(slot)]])

	# Магическая книга не экипируется в инвентарь (slот SPELLBOOK отсутствует в equipped).
	hero.inventory.backpack.clear()
	for s in hero.inventory.equipped:
		hero.inventory.equipped[s] = null
	hero.inventory.backpack.append(_reg.get_by_id(&"tome_infinity"))
	scr._on_equip()
	_report(hero.inventory.equipped.get(Artifact.Slot.SPELLBOOK, null) == null,
		"spellbook stays in backpack (no SPELLBOOK equipped slot)")

	# --- 3. Все возможные комбинации размещения (артефакт × слот) ---
	print("\n[4] Все комбинации: артефакт × слот (can_equip_to_slot)")
	var fresh := HeroInventory.new()
	var all_slots: Array = Artifact.Slot.values()
	for id in NEW_ARTS:
		var art: Artifact = _reg.get_by_id(id)
		var slot: Artifact.Slot = art.slot
		for s in all_slots:
			var expected_ok := false
			if art.is_ring():
				expected_ok = (s == Artifact.Slot.RING_L or s == Artifact.Slot.RING_R)
			elif slot == Artifact.Slot.SPELLBOOK:
				expected_ok = false
			else:
				expected_ok = (s == slot)
			var actual := fresh.can_equip_to_slot(art, s)
			_report(actual == expected_ok,
				"%s -> %s : %s" % [id, Artifact.Slot.keys()[int(s)], "ok" if expected_ok else "no"])

	# --- 4b. Двуручное оружие снимает щит ---
	print("\n[5] Двуручное оружие снимает щит")
	fresh.equipped.clear()
	for s in Artifact.Slot.values():
		if s == Artifact.Slot.SPELLBOOK:
			continue
		fresh.equipped[s] = null
	fresh.equipped[Artifact.Slot.SHIELD] = _reg.get_by_id(&"shield_greatwall")
	fresh.backpack.clear()
	fresh.backpack.append(_reg.get_by_id(&"greatsword_might"))
	var ok2h := fresh.equip(_reg.get_by_id(&"greatsword_might"))
	_report(ok2h and fresh.equipped[Artifact.Slot.WEAPON] != null,
		"equip 2H weapon -> WEAPON slot")
	_report(fresh.equipped[Artifact.Slot.SHIELD] == null,
		"2H weapon displaced the shield")
	_report(fresh.backpack.has(_reg.get_by_id(&"shield_greatwall")),
		"displaced shield went to backpack")

	# --- Итог ---
	print("\n=== RESULT: %d checks, %d failures ===" % [_checks, _fails])
	await create_timer(0.2).timeout
	quit(1 if _fails > 0 else 0)
