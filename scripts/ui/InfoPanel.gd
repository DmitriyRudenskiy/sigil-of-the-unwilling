class_name InfoPanel
extends VBoxContainer
## Дата, герои/города, сетка кнопок, статус.

signal end_turn_pressed
signal options_requested

const C_TEXT := Color(0.95, 0.89, 0.72)
const C_GOLD := Color(1.0, 0.85, 0.4)
const C_SLOT_BG := Color(0.35, 0.24, 0.15)

var _date_label: Label
var _time_label: Label
var _status_label: Label
var _hero_slots: Array[Panel] = []
var _town_slots: Array[Panel] = []

var day := 1
var week := 1
var month := 1


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build_date()
	_build_time()
	_build_hero_town_lists()
	_build_action_buttons()
	_build_status()


func _build_date() -> void:
	_date_label = Label.new()
	_date_label.text = _fmt_date()
	_date_label.add_theme_font_size_override("font_size", 14)
	_date_label.add_theme_color_override("font_color", C_TEXT)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_date_label)


func _build_time() -> void:
	_time_label = Label.new()
	_time_label.text = "🕐 06:00"
	_time_label.add_theme_font_size_override("font_size", 12)
	_time_label.add_theme_color_override("font_color", C_TEXT)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_time_label)


func set_time(hour: float) -> void:
	var h := int(floor(hour))
	var m := int(round((hour - floor(hour)) * 60))
	_time_label.text = "🕐 %02d:%02d" % [h, m]
	# Color coding: green for morning, yellow for noon, orange for evening, dark blue for night
	if hour >= 21.0:
		_time_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.8))
	elif hour >= 17.0:
		_time_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	elif hour >= 11.0:
		_time_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	else:
		_time_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))


func _build_hero_town_lists() -> void:
	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 6)
	add_child(lists)

	for col_idx in 2:
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		lists.add_child(vb)

		var arr := HBoxContainer.new()
		arr.alignment = BoxContainer.ALIGNMENT_CENTER
		var ab := Button.new()
		ab.text = "▲"
		ab.custom_minimum_size = Vector2(24, 18)
		ab.add_theme_font_size_override("font_size", 10)
		arr.add_child(ab)
		vb.add_child(arr)

		for i in 4:
			var s := _empty_slot(44)
			vb.add_child(s)
			if col_idx == 0:
				_hero_slots.append(s)
			else:
				_town_slots.append(s)

		var arr2 := HBoxContainer.new()
		arr2.alignment = BoxContainer.ALIGNMENT_CENTER
		var ab2 := Button.new()
		ab2.text = "▼"
		ab2.custom_minimum_size = Vector2(24, 18)
		ab2.add_theme_font_size_override("font_size", 10)
		arr2.add_child(ab2)
		vb.add_child(arr2)


func _build_action_buttons() -> void:
	var bg := GridContainer.new()
	bg.columns = 4
	bg.add_theme_constant_override("h_separation", 4)
	bg.add_theme_constant_override("v_separation", 4)
	add_child(bg)

	var btns := [
		["res://assets/ui/icons/treasure.png", "Замок", "🏰"],
		["res://assets/ui/icons/flag.png", "Флаг", "🚩"],
		["res://assets/ui/icons/battle_flag.png", "Лагерь", "⛺"],
		["res://assets/ui/icons/horse.png", "Конюшня", "🐎"],
		["res://assets/ui/icons/ship.png", "Корабль", "🚢"],
		["res://assets/ui/icons/swords.png", "Кузница", "⚒️"],
		["res://assets/ui/icons/scout.png", "Разведка", "🔍"],
		["res://assets/ui/icons/army.png", "Армия", "🪖"],
		["res://assets/ui/icons/scroll.png", "Журнал", "📜"],
		["res://assets/ui/icons/hourglass.png", "Конец хода", "⏳"],
		["res://assets/ui/icons/gold.png", "Королевство", "🏰"],
		["res://assets/ui/icons/expand.png", "Опции", "⚙️"],
	]
	for b in btns:
		var btn := Button.new()
		btn.tooltip_text = b[1]
		btn.custom_minimum_size = Vector2(52, 42)
		if b[1] == "Конец хода":
			btn.pressed.connect(func(): end_turn_pressed.emit())
			btn.modulate = C_GOLD
		elif b[1] == "Опции":
			btn.pressed.connect(func(): options_requested.emit())
		_apply_icon(btn, b[0], b[2])
		bg.add_child(btn)


func _build_status() -> void:
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", C_TEXT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)


func _apply_icon(btn: Button, icon_path: String, fallback: String) -> void:
	if FileAccess.file_exists(icon_path):
		btn.icon = load(icon_path)
		btn.text = ""
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
	else:
		btn.text = fallback


func set_status(text: String) -> void:
	_status_label.text = text


func set_status_colored(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func advance_day() -> void:
	day += 1
	if day > 7:
		day = 1
		week += 1
	if week > 4:
		week = 1
		month += 1
	_date_label.text = _fmt_date()


func add_city(city_name: String) -> void:
	for i in _town_slots.size():
		var slot := _town_slots[i]
		if slot.get_child_count() == 0:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			slot.add_child(hb)
			var ic := Label.new()
			ic.text = "🏰"
			ic.add_theme_font_size_override("font_size", 18)
			hb.add_child(ic)
			var nm := Label.new()
			nm.text = city_name
			nm.add_theme_font_size_override("font_size", 12)
			nm.add_theme_color_override("font_color", C_TEXT)
			nm.clip_text = true
			hb.add_child(nm)
			return


func fill_hero_slot(idx: int, hero: HeroController) -> void:
	if idx >= _hero_slots.size():
		return
	var slot := _hero_slots[idx]
	for c in slot.get_children():
		c.queue_free()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	slot.add_child(hb)
	var av := hero.get_avatar_texture()
	if av != null:
		var tr := TextureRect.new()
		tr.texture = av
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(40, 40)
		hb.add_child(tr)
	else:
		var em := Label.new()
		em.text = "🧙"
		em.add_theme_font_size_override("font_size", 22)
		hb.add_child(em)
	var nm := Label.new()
	nm.text = hero.hero_name
	nm.add_theme_font_size_override("font_size", 13)
	nm.add_theme_color_override("font_color", C_GOLD)
	nm.clip_text = true
	hb.add_child(nm)


func _empty_slot(h: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = C_SLOT_BG
	s.set_corner_radius_all(3)
	s.set_border_width_all(1)
	s.border_color = Color(0.2, 0.13, 0.08)
	p.add_theme_stylebox_override("panel", s)
	return p


func _fmt_date() -> String:
	return "Месяц: %d, Неделя: %d, День: %d" % [month, week, day]
