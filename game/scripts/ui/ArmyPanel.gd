class_name ArmyPanel
extends PanelContainer

const C_SLOT_BG := ThemeConfig.C_SLOT_BG
const C_BORDER := ThemeConfig.C_PANEL_BORDER
const C_TEXT := ThemeConfig.C_TEXT_PRIMARY

var _slots: Array[Panel] = []

func _ready() -> void:
	var aps := StyleBoxFlat.new()
	aps.bg_color = ThemeConfig.C_PANEL_MID
	aps.set_corner_radius_all(4)
	aps.set_border_width_all(2)
	aps.border_color = C_BORDER
	add_theme_stylebox_override("panel", aps)

	var grid := get_node("Grid") as GridContainer

	for i in 8:
		var slot := grid.get_node("Slot%d" % i) as Panel
		var ss := StyleBoxFlat.new()
		ss.bg_color = C_SLOT_BG
		ss.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", ss)

		var ct := slot.get_node("HBox/Count") as Label
		ct.add_theme_color_override("font_color", C_TEXT)

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
