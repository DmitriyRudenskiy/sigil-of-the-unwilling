class_name ArmyPanel
extends PanelContainer
## 8 слотов армии: иконка + число.

const C_SLOT_BG := Color(0.35, 0.24, 0.15)
const C_BORDER := Color(0.62, 0.47, 0.22)
const C_TEXT := Color(0.95, 0.89, 0.72)

var _slots: Array[Panel] = []


func _ready() -> void:
	var aps := StyleBoxFlat.new()
	aps.bg_color = Color(0.3, 0.2, 0.12)
	aps.set_corner_radius_all(4)
	aps.set_border_width_all(2)
	aps.border_color = C_BORDER
	add_theme_stylebox_override("panel", aps)

	var ag := GridContainer.new()
	ag.columns = 2
	ag.add_theme_constant_override("h_separation", 6)
	ag.add_theme_constant_override("v_separation", 6)
	add_child(ag)

	for i in 8:
		var slot := Panel.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = Vector2(0, 40)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ss := StyleBoxFlat.new()
		ss.bg_color = C_SLOT_BG
		ss.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", ss)
		var sh := HBoxContainer.new()
		sh.name = "HBox"
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		sh.add_theme_constant_override("separation", 6)
		slot.add_child(sh)
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(24, 24)
		sh.add_child(ic)
		var ct := Label.new()
		ct.name = "Count"
		ct.text = "0"
		ct.add_theme_font_size_override("font_size", 14)
		ct.add_theme_color_override("font_color", C_TEXT)
		sh.add_child(ct)
		ag.add_child(slot)
		_slots.append(slot)


func update_army(army: Array[UnitStack]) -> void:
	for i in range(8):
		var hbox: HBoxContainer = _slots[i].get_node("HBox")
		var ic: TextureRect = hbox.get_node("Icon")
		var ct: Label = hbox.get_node("Count")
		if i < army.size():
			var stack = army[i]
			var key: String = stack.get_key()
			if key == "":
				key = stack.get_display_name().to_lower().replace(" ", "_")
			var portrait := UnitSprites.find_portrait_small(key)
			if portrait != "":
				ic.texture = load(portrait)
			else:
				ic.texture = null
			ct.text = str(stack.count)
		else:
			ic.texture = null
			ct.text = "0"
