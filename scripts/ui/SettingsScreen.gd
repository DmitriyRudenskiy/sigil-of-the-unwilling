extends Control
class_name SettingsScreen
## Settings screen: Graphics, Audio, Gameplay sections.
## Built procedurally; opened from menu, adventure, or battle.

const _SettingsScript = preload("res://scripts/core/Settings.gd")

signal applied
signal closed

const C_BG := Color(0.08, 0.06, 0.04, 0.95)
const C_BORDER := Color(0.5, 0.38, 0.18)
const C_TEXT := Color(0.95, 0.89, 0.72)
const C_TITLE := Color(1.0, 0.85, 0.4)
const C_BTN_BG := Color(0.15, 0.35, 0.75)
const C_BTN_HOVER := Color(0.2, 0.45, 0.9)
const C_BTN_PRESS := Color(0.1, 0.25, 0.6)

var _zoom_selector: OptionButton
var _fullscreen_toggle: CheckBox
var _ui_anim_toggle: CheckBox
var _particles_toggle: CheckBox
var _auto_save_toggle: CheckBox
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _tween: Tween = null
var _settings: Node = null

func setup(settings: Node) -> void:
	_settings = settings

func _ready() -> void:
	z_index = 50
	if not _settings:
		# РФ7-5: не зависать без /root/Settings — закрыть экран и снять паузу
		push_warning("SettingsScreen: /root/Settings not found — closing")
		closed.emit()
		queue_free()
		return
	_build()
	if _settings.ui_animations:
		modulate = Color.WHITE
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.15)


func _build() -> void:
	# Full-screen overlay
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Panel container centered
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2i(520, 520)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# Title
	var title := Label.new()
	title.text = "⚙️ Настройки"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	# Sections
	_build_graphics_section(vb)
	_build_audio_section(vb)
	_build_gameplay_section(vb)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var apply_btn := _make_button("Применить и закрыть", _on_apply)
	btn_row.add_child(apply_btn)

	var reset_btn := _make_button("Сбросить по умолчанию", _on_reset)
	btn_row.add_child(reset_btn)

	var cancel_btn := _make_button("Отмена", _on_cancel)
	btn_row.add_child(cancel_btn)

	# Restore state
	_restore_state()


func _build_graphics_section(parent: Control) -> void:
	_add_section_header(parent, "🖥️ Графика")

	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Зум камеры:"
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.custom_minimum_size = Vector2(130, 0)
	row.add_child(lbl)

	_zoom_selector = OptionButton.new()
	for i in _settings.ZOOM_LEVELS.size():
		_zoom_selector.add_item("%0.2f" % _settings.ZOOM_LEVELS[i], i)
	_zoom_selector.selected = _settings.zoom_index
	_zoom_selector.item_selected.connect(_on_zoom_selected)
	row.add_child(_zoom_selector)

	_fullscreen_toggle = _make_check("Полноэкранный режим", _settings.fullscreen)
	parent.add_child(_fullscreen_toggle)

	_ui_anim_toggle = _make_check("Анимации UI", _settings.ui_animations)
	parent.add_child(_ui_anim_toggle)

	_particles_toggle = _make_check("Частицы", _settings.particles)
	parent.add_child(_particles_toggle)


func _build_audio_section(parent: Control) -> void:
	_add_section_header(parent, "🔊 Звук")

	_master_slider = _create_volume_row(parent, "Master", _settings.master_volume)
	_master_slider.value_changed.connect(_on_master_changed)

	_music_slider = _create_volume_row(parent, "Музыка", _settings.music_volume)
	_music_slider.value_changed.connect(_on_music_changed)

	_sfx_slider = _create_volume_row(parent, "Эффекты", _settings.sfx_volume)
	_sfx_slider.value_changed.connect(_on_sfx_changed)


func _build_gameplay_section(parent: Control) -> void:
	_add_section_header(parent, "🎮 Игра")

	_auto_save_toggle = _make_check("Автосохранение при выходе", _settings.auto_save)
	parent.add_child(_auto_save_toggle)


# --- Helpers ---

func _add_section_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_TITLE)
	parent.add_child(lbl)


func _make_check(text: String, value: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = value
	cb.add_theme_color_override("font_color", C_TEXT)
	return cb


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 36)
	btn.add_theme_font_size_override("font_size", 14)

	var sn := StyleBoxFlat.new()
	sn.bg_color = C_BTN_BG
	sn.set_corner_radius_all(6)
	sn.set_border_width_all(1)
	sn.border_color = Color(0.3, 0.5, 0.9)
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate()
	sh.bg_color = C_BTN_HOVER
	btn.add_theme_stylebox_override("hover", sh)

	var sp := sn.duplicate()
	sp.bg_color = C_BTN_PRESS
	btn.add_theme_stylebox_override("pressed", sp)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(callback)
	return btn


func _create_volume_row(parent: Control, label_text: String, value: int) -> HSlider:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.custom_minimum_size = Vector2(90, 0)
	container.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = float(value)
	slider.custom_minimum_size = Vector2(200, 0)
	container.add_child(slider)

	var val := Label.new()
	val.text = "%d%%" % value
	val.add_theme_color_override("font_color", C_TEXT)
	val.custom_minimum_size = Vector2(40, 0)
	container.add_child(val)

	# Store label reference on the slider for access
	slider.set_meta("value_label", val)

	parent.add_child(container)
	return slider


func _restore_state() -> void:
	_zoom_selector.selected = _settings.zoom_index
	_fullscreen_toggle.button_pressed = _settings.fullscreen
	_ui_anim_toggle.button_pressed = _settings.ui_animations
	_particles_toggle.button_pressed = _settings.particles
	_auto_save_toggle.button_pressed = _settings.auto_save
	_master_slider.value = float(_settings.master_volume)
	_music_slider.value = float(_settings.music_volume)
	_sfx_slider.value = float(_settings.sfx_volume)


# --- Callbacks ---

func _on_zoom_selected(index: int) -> void:
	_settings.zoom_index = index
	_settings.save()


func _on_master_changed(value: float) -> void:
	_master_slider.get_meta("value_label").text = "%d%%" % int(value)
	_settings.master_volume = int(value)
	_settings._apply_audio()


func _on_music_changed(value: float) -> void:
	_music_slider.get_meta("value_label").text = "%d%%" % int(value)
	_settings.music_volume = int(value)
	_settings._apply_audio()


func _on_sfx_changed(value: float) -> void:
	_sfx_slider.get_meta("value_label").text = "%d%%" % int(value)
	_settings.sfx_volume = int(value)
	_settings._apply_audio()


func _on_apply() -> void:
	# Commit all toggles
	_settings.fullscreen = _fullscreen_toggle.button_pressed
	_settings.ui_animations = _ui_anim_toggle.button_pressed
	_settings.particles = _particles_toggle.button_pressed
	_settings.auto_save = _auto_save_toggle.button_pressed
	_settings.save()
	_settings.apply_display_mode()
	applied.emit()
	closed.emit()
	queue_free()


func _on_reset() -> void:
	_settings.reset_to_defaults()
	_restore_state()


func _on_cancel() -> void:
	closed.emit()
	queue_free()
