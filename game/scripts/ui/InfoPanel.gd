class_name InfoPanel
extends VBoxContainer
## Дата, герои/города, сетка кнопок, статус.
## Скелет (VBox → дата/время, колонки слотов, GridContainer кнопок, статус)
## вертается в сцене `InfoPanel.tscn`; данные подтягиваются в рантайме.
## Стили (слоты) — из общей темы (D3).

const THEME_PATH := "res://assets/theme/game_theme.tres"
const C_TEXT := Color(0.95, 0.89, 0.72)
const C_GOLD := Color(1.0, 0.85, 0.4)

var _date_label: Label
var _time_label: Label
var _status_label: Label
var _hero_slots: Array[Panel] = []
var _town_slots: Array[Panel] = []

var _theme: Theme = null

signal end_turn_pressed
signal options_requested

var day := 1
var week := 1
var month := 1


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_theme = load(THEME_PATH)
	_apply_theme()
	_connect_skeleton()
	_build_action_buttons()


func _apply_theme() -> void:
	if _theme == null:
		return
	var sb := _theme.get_stylebox("slot", "Panel")
	if sb == null:
		return
	for slot in _get_slot_nodes():
		slot.add_theme_stylebox_override("panel", sb)


func _get_slot_nodes() -> Array:
	var out: Array[Panel] = []
	for i in 4:
		var h := get_node_or_null("columns/hero_col/hero_slot_%d" % i)
		if h is Panel:
			out.append(h)
	var t: Array[Panel] = []
	for i in 4:
		var v := get_node_or_null("columns/town_col/town_slot_%d" % i)
		if v is Panel:
			t.append(v)
	return out + t


func _connect_skeleton() -> void:
	_date_label = get_node_or_null("date_label") as Label
	_time_label = get_node_or_null("time_label") as Label
	_status_label = get_node_or_null("status_label") as Label
	_hero_slots = []
	_town_slots = []
	for i in 4:
		var h := get_node_or_null("columns/hero_col/hero_slot_%d" % i)
		if h is Panel:
			_hero_slots.append(h)
		var t := get_node_or_null("columns/town_col/town_slot_%d" % i)
		if t is Panel:
			_town_slots.append(t)
	# Кнопки ▲/▼ и «Конец хода»/«Опции» — см. _build_action_buttons.


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


func _build_action_buttons() -> void:
	var bg := get_node_or_null("actions") as GridContainer
	if bg == null:
		return
	# Очистить старые кнопки (на случай повторного _ready).
	for child in bg.get_children():
		child.queue_free()

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


func set_date(m: int, w: int, d: int) -> void:
	month = max(1, m)
	week = max(1, min(4, w))
	day = max(1, min(7, d))
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
	var av: Texture2D = hero.get_avatar_texture()
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


func _apply_icon(btn: Button, icon_path: String, fallback: String) -> void:
	if FileAccess.file_exists(icon_path):
		btn.icon = load(icon_path)
		btn.text = ""
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
	else:
		btn.text = fallback


func _fmt_date() -> String:
	return "Месяц: %d, Неделя: %d, День: %d" % [month, week, day]
