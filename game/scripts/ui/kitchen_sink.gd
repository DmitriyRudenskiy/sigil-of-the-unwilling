extends Control

# Демонстрационная сцена фазы 5 («kitchen-sink»): все компоненты темы во всех
# состояниях на одном экране. Нужна потому, что дым-проверка (tools/theme_smoke.gd)
# покрывает только живые экраны, а Slider / TabContainer / LineEdit / CheckBox /
# Tooltip нигде не снимаются — до этой сцены их визуального доказательства не было
# (владелец, 2026-10-14: «kitchen-sink — их единственное визуальное доказательство»).
#
# Правил цвета соблюдает столько же, сколько прод-код: §1.1 — ни одного литерала
# цвета/кегля в сцене, стили берутся из темы по имени (Panel/<имя>), цвета —
# ThemeConfig. Кегли и шрифт контролов НЕ финальные: шкала — билет UI-AC7,
# поэтому в углу висит видимая метка (владелец: «чтобы демо не читалось как
# приёмка типографики»).
#
# Запуск: godot --path game res://scenes/ui/kitchen_sink.tscn
# Кадры: tools/theme_smoke.gd (сцена в списке SCENES).

const THEME_PATH := "res://assets/theme/game_theme.tres"

var _theme: Theme


func _ready() -> void:
	_theme = load(THEME_PATH)
	var bg := _panel_style("panel")
	var margin := MarginContainer.new()
	bg.add_child(margin)
	for m in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	add_child(bg)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)

	_sec_buttons(grid)
	_sec_slider(grid)
	_sec_panels(grid)
	_sec_tabs(grid)
	_sec_progress(grid)
	_sec_tooltip(grid)
	_sec_lineedit(grid)
	_sec_labels(grid)
	_sec_checks(grid)
	_sec_notes(grid)


# ─── построители секций ───────────────────────────────────────────────────────

func _section(grid: GridContainer, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := _label(title, "LabelStrong")
	box.add_child(head)
	grid.add_child(box)
	return box


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.theme_type_variation = "LabelSecondary"
	return l


# Панель с именованным стилем темы: тот же путь, что у прод-кода
# (artifact_inventory_screen._style) — §1.1 «только стиль темы по имени».
func _panel_style(style_name: String, min_size := Vector2(0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _theme.get_stylebox(style_name, "Panel")
	if sb != null:
		p.add_theme_stylebox_override("panel", sb)
	if min_size != Vector2.ZERO:
		p.custom_minimum_size = min_size
	return p


func _captioned(row: Node, caption: String, control: Control, min_size := Vector2(112, 40)) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	control.custom_minimum_size = min_size
	cell.add_child(control)
	cell.add_child(_caption(caption))
	row.add_child(cell)


# ─── §4.1 Button: четыре состояния + focus/disabled/danger ───────────────────

func _sec_buttons(grid: GridContainer) -> void:
	var box := _section(grid, "Button (§4.1)")
	var row := _row(box)
	var live := Button.new()
	live.text = "Normal"
	_captioned(row, "живая", live)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _theme.get_stylebox(st, "Button"))
		p.custom_minimum_size = Vector2(112, 40)
		var lbl := _label(st, "LabelSecondary")
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_child(lbl)
		cell.add_child(p)
		cell.add_child(_caption("стиль " + st))
		row.add_child(cell)
	var row2 := _row(box)
	var pressed := Button.new()
	pressed.text = "Pressed"
	pressed.button_pressed = true
	_captioned(row2, "button_pressed", pressed)
	var off := Button.new()
	off.text = "Disabled"
	off.disabled = true
	_captioned(row2, "disabled", off)
	var danger := Button.new()
	danger.text = "Danger"
	danger.add_theme_stylebox_override("normal", _theme.get_stylebox("button_red", "Panel"))
	_captioned(row2, "danger (C_SIGN)", danger)
	var focused := Button.new()
	focused.text = "Focus"
	focused.add_theme_stylebox_override("focus", _theme.get_stylebox("focus", "Button"))
	_captioned(row2, "К-1: focus", focused)


# ─── §4.6 Slider (К-3) ───────────────────────────────────────────────────────

func _sec_slider(grid: GridContainer) -> void:
	var box := _section(grid, "Slider (§4.6, К-3)")
	var row := _row(box)
	var s := HSlider.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.max_value = 100
	s.value = 60
	s.tooltip_text = "60"
	_captioned(row, "normal + tooltip", s)
	var dis := HSlider.new()
	dis.max_value = 100
	dis.value = 30
	dis.editable = false
	_captioned(row, "disabled", dis)


# ─── §4.2 Panel / Slot (К-7, К-8, К-9, К-5) ─────────────────────────────────

func _sec_panels(grid: GridContainer) -> void:
	var box := _section(grid, "Panel / Slot (§4.2, К-5/7/8/9)")
	var row := _row(box)
	for st in ["panel", "window", "slot", "slot_thin"]:
		_captioned(row, st, _panel_style(st, Vector2(112, 40)))
	var row2 := _row(box)
	for st in ["army_slot", "army_slot_hover", "army_slot_selected", "army_slot_disabled"]:
		_captioned(row2, st.replace("army_slot", "army").lstrip("_"),
			_panel_style(st, Vector2(112, 40)))


# ─── §4.7 TabContainer (К-6) ─────────────────────────────────────────────────

func _sec_tabs(grid: GridContainer) -> void:
	var box := _section(grid, "TabContainer (§4.7, К-6)")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(360, 96)
	for i in 3:
		var page := PanelContainer.new()
		page.add_theme_stylebox_override("panel", _theme.get_stylebox("slot_thin", "Panel"))
		page.add_child(_label("страница %d — поле §3" % (i + 1), "LabelBody"))
		tabs.add_child(page)
		tabs.set_tab_title(i, "Вкладка %d" % (i + 1))
	tabs.set_tab_disabled(2, true)
	box.add_child(tabs)


# ─── §4.3 ProgressBar ────────────────────────────────────────────────────────

func _sec_progress(grid: GridContainer) -> void:
	var box := _section(grid, "ProgressBar (§4.3)")
	var row := _row(box)
	for spec in [["normal", 65.0], ["low", 15.0], ["full", 100.0]]:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(112, 24)
		bar.max_value = 100
		bar.value = spec[1]
		bar.show_percentage = false
		_captioned(row, str(spec[0]), bar)
	var dis := ProgressBar.new()
	dis.custom_minimum_size = Vector2(112, 24)
	dis.value = 0
	dis.max_value = 100
	dis.show_percentage = false
	_captioned(row, "empty", dis)


# ─── §4.8 Тултип (К-6) ──────────────────────────────────────────────────────

func _sec_tooltip(grid: GridContainer) -> void:
	var box := _section(grid, "Tooltip (§4.8, К-6)")
	var row := _row(box)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "TooltipPanel"
	var body := _label("Значение: 60 (TooltipLabel)", "TooltipLabel")
	panel.add_child(body)
	panel.custom_minimum_size = Vector2(280, 44)
	row.add_child(panel)


# ─── §4.4 LineEdit (К-6) ────────────────────────────────────────────────────

func _sec_lineedit(grid: GridContainer) -> void:
	var box := _section(grid, "LineEdit (§4.4, К-6)")
	var row := _row(box)
	var normal := LineEdit.new()
	normal.placeholder_text = "плейсхолдер"
	_captioned(row, "normal", normal, Vector2(168, 40))
	var ro := LineEdit.new()
	ro.text = "read-only"
	ro.editable = false
	_captioned(row, "read-only", ro, Vector2(168, 40))
	# §4.4: голый текст ошибки на C_PANEL запрещён — только на подложке chip
	var chip := _panel_style("chip")
	var chip_text := Label.new()
	chip_text.text = "ошибка: слишком мало"
	chip_text.theme_type_variation = "ChipError"
	chip.add_child(chip_text)
	_captioned(row, "error-chip (§4.4)", chip, Vector2(220, 40))


# ─── §4.5 CheckBox (К-6, К-2) ───────────────────────────────────────────────

func _sec_checks(grid: GridContainer) -> void:
	var box := _section(grid, "CheckBox (§4.5, К-6)")
	var row := _row(box)
	var off := CheckBox.new()
	off.text = "unchecked"
	row.add_child(off)
	var on := CheckBox.new()
	on.text = "checked"
	on.button_pressed = true
	row.add_child(on)
	var dis := CheckBox.new()
	dis.text = "disabled"
	dis.disabled = true
	row.add_child(dis)
	var ind := CheckBox.new()
	ind.text = "indeterminate"
	ind.button_pressed = true
	row.add_child(ind)
	# §4.5 indeterminate = тире C_GOLD; ассета тира в репо нет (К-2), поэтому
	# состояние показано отсутствующим, а не подделано галочкой.
	row.add_child(_caption("тире: ассета нет (К-2)"))


# ─── §2 Label-вариации (кегли — не приёмка) ─────────────────────────────────

func _sec_labels(grid: GridContainer) -> void:
	var box := _section(grid, "Label-вариации (§2)")
	var row := _row(box)
	for v in ["LabelTitle", "LabelHeading", "LabelBody", "LabelNumber", "LabelSecondary"]:
		var l := _label(v, v)
		row.add_child(l)


func _sec_notes(grid: GridContainer) -> void:
	var box := _section(grid, "Служебное")
	box.add_child(_label("кегли и шрифт контролов — до UI-AC7", "LabelError"))
	box.add_child(_label("это не приёмка типографики (Т-1, Т-4, Т-5 — билет UI-AC7)",
		"LabelSecondary"))
	box.add_child(_label("индикатор: фаза 5 = П-1/2/3, К-1/3/5/6/7/8/9", "LabelSecondary"))
