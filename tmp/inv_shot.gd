extends SceneTree

var _art: ArtifactRegistry = null
var _depth := 0
var _lines: Array = []

func _dump(c: Control) -> void:
	var pad := ""
	for i in _depth:
		pad += "  "
	var x := c.offset_left
	var y := c.offset_top
	var w := c.offset_right - c.offset_left
	var h := c.offset_bottom - c.offset_top
	_lines.append("%s%s  x=%d y=%d w=%d h=%d" % [pad, c.name, int(x), int(y), int(w), int(h)])
	_depth += 1
	for ch in c.get_children():
		if ch is Control:
			_dump(ch)
	_depth -= 1

func _init():
	_art = ArtifactRegistry.new()
	_art.ensure_definitions()
	call_deferred("_run")

func _run():
	var hero := HeroController.new()
	hero.hero_name = "Джит"
	hero.stats = {"attack": 6, "defense": 5, "spell_power": 8, "knowledge": 7, "specialty": 1}
	var hs := HeroSkills.new()
	hs.levels = {"nature_sense": 2, "keen_eye": 1, "navigation": 3, "geology": 0, "alchemy": 2}
	hero.skills = hs
	hero.inventory.equipped[Artifact.Slot.WEAPON] = _art.get_by_id(&"greatsword_might")
	hero.inventory.equipped[Artifact.Slot.HEAD] = _art.get_by_id(&"helm_bulwark")
	hero.inventory.equipped[Artifact.Slot.TORSO] = _art.get_by_id(&"plate_dread")
	hero.inventory.equipped[Artifact.Slot.LEGS] = _art.get_by_id(&"greaves_juggernaut")
	hero.inventory.equipped[Artifact.Slot.BOOTS] = _art.get_by_id(&"boots_titan")
	hero.inventory.equipped[Artifact.Slot.NECK] = _art.get_by_id(&"amulet_prescience")
	hero.inventory.backpack.append(_art.get_by_id(&"shield_greatwall"))
	hero.inventory.backpack.append(_art.get_by_id(&"ring_giant"))
	hero.inventory.backpack.append(_art.get_by_id(&"charm_beast"))
	hero.inventory.backpack.append(_art.get_by_id(&"trinket_epoch"))
	hero.mana_current = 25
	hero.mana_max = 40
	hero.army = HeroArmyController.new()
	hero.army.army = []

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("h_separation", 0)
	root.add_theme_constant_override("v_separation", 0)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("h_separation", 0)
	center.add_theme_constant_override("v_separation", 0)
	var center2 := CenterContainer.new()
	center2.set_anchors_preset(Control.PRESET_FULL_RECT)
	center2.add_theme_constant_override("h_separation", 0)
	center2.add_theme_constant_override("v_separation", 0)
	root.add_child(center)
	center.add_child(center2)

	var scr := ArtifactInventoryScreen.new()
	center2.add_child(scr)
	scr.set_hero(hero)

	var root_node := get_root()
	root_node.add_child(root)

	for _i in 6:
		await create_timer(0.03).timeout

	_lines.append("=== ABSOLUTE BOUNDS (screen-local) ===")
	_dump(scr)
	for l in _lines:
		print(l)
	await create_timer(0.3).timeout
	quit()
