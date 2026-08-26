extends Control
class_name ArtifactInventoryScreen
## Inventory UI: equipped slots + backpack grid + stat summary + equip/unequip.

var _inventory: HeroInventory = null
var _equipped_slots: Dictionary = {}  # slot -> ItemSlotUI
var _backpack_slots: Array[ItemSlotUI] = []
var _modifiers_label: Label = null
var _tooltip: Label = null


func setup(inv: HeroInventory) -> void:
	_inventory = inv
	_build_layout()
	_update_all()
	_connect_signals()
	UIAnimator.animate_in(self)


func _build_layout() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()

	# Main vertical container
	var main := VBoxContainer.new()
	main.set_anchors_preset(PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	main.position = Vector2(0, 0)
	main.size = Vector2(400, 580)
	add_child(main)

	# Title
	var title := Label.new()
	title.text = "⚔ Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	main.add_child(title)

	# Separator
	var sep1 := HSeparator.new()
	main.add_child(sep1)

	# --- EQUIPPED SECTION ---
	var equipped_hbox := HBoxContainer.new()
	equipped_hbox.add_theme_constant_override("separation", 6)
	main.add_child(equipped_hbox)

	# Left column
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_FILL
	equipped_hbox.add_child(left)

	var lbl_left := Label.new()
	lbl_left.text = "Equipped"
	lbl_left.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	left.add_child(lbl_left)

	var equip_grid := GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override("h_separation", 4)
	equip_grid.add_theme_constant_override("v_separation", 4)
	equip_grid.size_flags_horizontal = SIZE_FILL
	left.add_child(equip_grid)

	# --- STATS SECTION ---
	var sep2 := HSeparator.new()
	main.add_child(sep2)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.size_flags_horizontal = SIZE_FILL
	main.add_child(stats_vbox)

	var lbl_stats := Label.new()
	lbl_stats.text = "Modifiers"
	lbl_stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_vbox.add_child(lbl_stats)

	_modifiers_label = Label.new()
	_modifiers_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_modifiers_label.add_theme_font_size_override("font_size", 14)
	_modifiers_label.size_flags_horizontal = SIZE_FILL
	stats_vbox.add_child(_modifiers_label)

	# --- BACKPACK SECTION ---
	var sep3 := HSeparator.new()
	main.add_child(sep3)

	var lbl_backpack := Label.new()
	lbl_backpack.text = "Backpack (%d/%d)" % [0, GameSettings.MAX_BACKPACK_SIZE]
	lbl_backpack.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main.add_child(lbl_backpack)

	var backpack_scroll := ScrollContainer.new()
	backpack_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	backpack_scroll.size_flags_horizontal = SIZE_FILL
	main.add_child(backpack_scroll)

	var bp_grid := GridContainer.new()
	bp_grid.columns = 4
	bp_grid.add_theme_constant_override("h_separation", 4)
	bp_grid.add_theme_constant_override("v_separation", 4)
	backpack_scroll.add_child(bp_grid)

	# Create equipped slots
	var slot_order := [
		Artifact.Slot.HEAD, Artifact.Slot.NECK,
		Artifact.Slot.TORSO, Artifact.Slot.WEAPON,
		Artifact.Slot.SHIELD, Artifact.Slot.LEGS,
		Artifact.Slot.BOOTS, Artifact.Slot.RING_L,
		Artifact.Slot.RING_R, Artifact.Slot.MISC_A,
		Artifact.Slot.MISC_B, Artifact.Slot.SPELLBOOK,
	]

	for slot in slot_order:
		var slot_ui := _create_slot_ui()
		slot_ui.clicked.connect(func(a): _on_equipped_slot_clicked(a, slot))
		slot_ui.hover_entered.connect(_on_item_hover)
		slot_ui.hover_exited.connect(_on_item_hover_exit)
		equip_grid.add_child(slot_ui)
		_equipped_slots[slot] = slot_ui

	# Create backpack slots
	_backpack_slots.clear()
	for i in GameSettings.MAX_BACKPACK_SIZE:
		var slot_ui := _create_slot_ui()
		slot_ui.clicked.connect(func(a): _on_backpack_slot_clicked(a, i))
		slot_ui.hover_entered.connect(_on_item_hover)
		slot_ui.hover_exited.connect(_on_item_hover_exit)
		bp_grid.add_child(slot_ui)
		_backpack_slots.append(slot_ui)


func _create_slot_ui() -> ItemSlotUI:
	var slot := ItemSlotUI.new()
	slot.custom_minimum_size = Vector2(56, 56)
	slot.add_theme_stylebox_override(
		"panel",
		_create_slot_style()
	)
	return slot


func _create_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13)
	style.border_color = Color(0.25, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _connect_signals() -> void:
	if _inventory == null:
		return
	_inventory.equipped_changed.connect(_update_all)
	_inventory.backpack_changed.connect(_update_all)
	_inventory.modifiers_changed.connect(_update_all)


func _update_all() -> void:
	if _inventory == null:
		return
	_update_equipped()
	_update_backpack()
	_update_modifiers()


func _update_equipped() -> void:
	for slot in _equipped_slots:
		var slot_ui: ItemSlotUI = _equipped_slots[slot]
		var art: Artifact = _inventory.get_equipped(slot)
		slot_ui.artifact = art


func _update_backpack() -> void:
	var bp := _inventory.backpack
	for i in _backpack_slots.size():
		var slot_ui: ItemSlotUI = _backpack_slots[i]
		if i < bp.size():
			slot_ui.artifact = bp[i]
		else:
			slot_ui.artifact = null


func _update_modifiers() -> void:
	if _modifiers_label == null:
		return
	var mods := _inventory.get_total_modifiers()
	var fmt := func(k: String, default: int = 0) -> String:
		var val: int = int(mods.get(k, default))
		return ("+%d" % val) if val > 0 else (("%d" % val) if val != 0 else "0")
	var fmt_pct := func(k: String, default: float = 0.0) -> String:
		var val: float = mods.get(k, default)
		return ("%+.1f%%" % val) if val != 0 else "0%"

	_modifiers_label.text = (
		"ATK %s  DEF %s  SP %s\n"
		"KNW %s  LCK %s  MOR %s\n"
		"HP %s (%s)  SPD %s\n"
		"Gems %s  Growth %s"
	) % [
		fmt("attack"), fmt("defense"), fmt("spell_power"),
		fmt("knowledge"), fmt("luck"), fmt("morale"),
		fmt("stack_hp"), fmt_pct("stack_hp_percent"), fmt("stack_speed"),
		fmt("daily_gems"), fmt_pct("castle_growth_percent"),
	]


# --- Event Handlers ---

func _on_backpack_slot_clicked(artifact: Artifact, _idx: int) -> void:
	if artifact == null or _inventory == null:
		return
	# Try to equip
	_inventory.equip(artifact)
	_update_all()


func _on_equipped_slot_clicked(artifact: Artifact, slot: Artifact.Slot) -> void:
	if artifact == null or _inventory == null:
		return
	# Unequip -> move to backpack
	_inventory.unequip(slot)
	_update_all()


func _on_item_hover(artifact: Artifact) -> void:
	if artifact == null:
		return
	var mods := artifact.get_modifiers()
	var lines := [artifact.display_name, "(%s)" % _rarity_name(artifact.rarity)]
	if artifact.is_two_handed:
		lines.append("TWO-HANDED")
	for k in mods:
		lines.append("%s: %s" % [k, mods[k]])
	
	var tooltip := Label.new()
	tooltip.text = "\n".join(lines)
	tooltip.add_theme_font_size_override("font_size", 13)
	tooltip.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip.custom_minimum_size = Vector2i(160, 40)
	tooltip.position = Vector2(get_viewport().mouse_position.x + 12, get_viewport().mouse_position.y - 30)
	tooltip.z_index = 100
	add_child(tooltip)
	_tooltip = tooltip


func _on_item_hover_exit() -> void:
	if _tooltip != null:
		_tooltip.queue_free()
		_tooltip = null


func _rarity_name(rarity: Artifact.Rarity) -> String:
	match rarity:
		Artifact.Rarity.MINOR: return "Minor"
		Artifact.Rarity.MAJOR: return "Major"
		Artifact.Rarity.RELIC: return "Relic"
	return "?"
