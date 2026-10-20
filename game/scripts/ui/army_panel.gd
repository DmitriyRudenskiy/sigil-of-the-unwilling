class_name ArmyPanel
extends PanelContainer

const C_TEXT := ThemeConfig.C_TEXT_PRIMARY

var _slots: Array[Panel] = []

# Стили корня и слотов — носители темы ArmyPanel / ArmySlot, назначенные в сцене
# (T-147): у PanelContainer и Panel законный носитель "panel" есть, коду рисовать
# нечего. Остался только цвет текста — это цвета, их забирает T-148.
func _ready() -> void:
	var grid := get_node("Grid") as GridContainer

	for i in 8:
		var slot := grid.get_node("Slot%d" % i) as Panel
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
