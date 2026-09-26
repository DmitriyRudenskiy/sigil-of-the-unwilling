extends Control
class_name SettingsScreen

const _SettingsScript = preload("res://scripts/autoload/settings.gd")

signal applied
signal closed
signal arena_requested
signal chronicle_requested
signal model_requested(variant: String)

const C_BG := ThemeConfig.C_PANEL_DARK
const C_BORDER := ThemeConfig.C_PANEL_BORDER_ALT
const C_TEXT := ThemeConfig.C_TEXT_PRIMARY
const C_TITLE := ThemeConfig.C_TEXT_GOLD
const C_BTN_BG := ThemeConfig.C_BTN_NORMAL
const C_BTN_HOVER := ThemeConfig.C_BTN_HOVER
const C_BTN_PRESS := ThemeConfig.C_BTN_PRESSED

var _zoom_selector: OptionButton
var _fullscreen_toggle: CheckBox
var _ui_anim_toggle: CheckBox
var _particles_toggle: CheckBox
var _auto_save_toggle: CheckBox
var _mute_toggle: CheckBox
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _tween: Tween = null
var _settings: Node = null

@export var persistent := false
@export var show_additional := true

var _content_ready := false
var _additional_header: Label = null
var _additional_btns: Array[Button] = []

var _initial_state: Dictionary = {}

func setup(settings: Node) -> void:
	if settings == null:
		push_warning("SettingsScreen: settings null — ignoring setup")
		return
	_settings = settings
	if not is_inside_tree():
		return
	if _content_ready:
		_initial_state = _capture_state()
		_restore_state()
	else:
		_init_content()

func _ready() -> void:
	z_index = 50
	if not _settings:
		if persistent:
			visible = false
			return
		push_warning("SettingsScreen: /root/Settings not found — closing")
		closed.emit()
		queue_free()
		return
	_init_content()

func _init_content() -> void:
	_ensure_additional_section()
	_initial_state = _capture_state()
	_bind_nodes()
	_localize()
	_apply_style()
	_restore_state()
	_content_ready = true
	if _settings.ui_animations:
		modulate = Color.WHITE
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _localize() -> void:
	var box := get_node("Panel/Box")
	(box.get_node("Title") as Label).text = GameText.settings_title()
	(box.get_node("GraphicsHeader") as Label).text = GameText.settings_graphics()
	(box.get_node("ZoomRow/ZoomLabel") as Label).text = GameText.settings_zoom()
	(box.get_node("FullscreenToggle") as CheckBox).text = GameText.settings_fullscreen()
	(box.get_node("UIAnimToggle") as CheckBox).text = GameText.settings_ui_anim()
	(box.get_node("ParticlesToggle") as CheckBox).text = GameText.settings_particles()
	(box.get_node("AudioHeader") as Label).text = GameText.settings_audio()
	(box.get_node("MasterRow/MasterLabel") as Label).text = GameText.settings_master()
	(box.get_node("MusicRow/MusicLabel") as Label).text = GameText.settings_music()
	(box.get_node("SfxRow/SfxLabel") as Label).text = GameText.settings_sfx()
	(box.get_node("MuteToggle") as CheckBox).text = GameText.settings_mute()
	(box.get_node("GameplayHeader") as Label).text = GameText.settings_gameplay()
	(box.get_node("AutoSaveToggle") as CheckBox).text = GameText.settings_autosave()
	(box.get_node("ButtonRow/ApplyButton") as Button).text = GameText.settings_apply()
	(box.get_node("ButtonRow/ResetButton") as Button).text = GameText.settings_reset()
	(box.get_node("ButtonRow/CancelButton") as Button).text = GameText.settings_cancel()
	if _additional_header != null:
		_additional_header.text = GameText.settings_additional()
		for i in _additional_btns.size():
			_additional_btns[i].text = _additional_key_text(i)

func _additional_key_text(i: int) -> String:
	match i:
		0: return GameText.settings_button_arena()
		1: return GameText.settings_button_chronicle()
		_: return GameText.settings_button_model()

func _capture_state() -> Dictionary:
	return {
		"zoom_index": _settings.zoom_index,
		"fullscreen": _settings.fullscreen,
		"ui_animations": _settings.ui_animations,
		"particles": _settings.particles,
		"auto_save": _settings.auto_save,
		"master_volume": _settings.master_volume,
		"music_volume": _settings.music_volume,
		"sfx_volume": _settings.sfx_volume,
		"is_muted": _settings.is_muted
	}

func _bind_nodes() -> void:
	var box := get_node("Panel/Box")
	_zoom_selector = box.get_node("ZoomRow/ZoomSelector") as OptionButton
	for i in _settings.ZOOM_LEVELS.size():
		_zoom_selector.add_item("%0.2f" % _settings.ZOOM_LEVELS[i], i)
	_zoom_selector.selected = _settings.zoom_index
	_zoom_selector.item_selected.connect(_on_zoom_selected)

	_fullscreen_toggle = box.get_node("FullscreenToggle") as CheckBox
	_fullscreen_toggle.button_pressed = _settings.fullscreen
	_ui_anim_toggle = box.get_node("UIAnimToggle") as CheckBox
	_ui_anim_toggle.button_pressed = _settings.ui_animations
	_particles_toggle = box.get_node("ParticlesToggle") as CheckBox
	_particles_toggle.button_pressed = _settings.particles

	_master_slider = box.get_node("MasterRow/MasterSlider") as HSlider
	_master_slider.value = float(_settings.master_volume)
	_master_slider.set_meta("value_label", box.get_node("MasterRow/MasterValue"))
	_master_slider.value_changed.connect(_on_master_changed)

	_music_slider = box.get_node("MusicRow/MusicSlider") as HSlider
	_music_slider.value = float(_settings.music_volume)
	_music_slider.set_meta("value_label", box.get_node("MusicRow/MusicValue"))
	_music_slider.value_changed.connect(_on_music_changed)

	_sfx_slider = box.get_node("SfxRow/SfxSlider") as HSlider
	_sfx_slider.value = float(_settings.sfx_volume)
	_sfx_slider.set_meta("value_label", box.get_node("SfxRow/SfxValue"))
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	_mute_toggle = box.get_node("MuteToggle") as CheckBox
	_mute_toggle.button_pressed = _settings.is_muted
	_mute_toggle.toggled.connect(_on_mute_toggled)

	_auto_save_toggle = box.get_node("AutoSaveToggle") as CheckBox
	_auto_save_toggle.button_pressed = _settings.auto_save

	(box.get_node("ButtonRow/ApplyButton") as Button).pressed.connect(_on_apply)
	(box.get_node("ButtonRow/ResetButton") as Button).pressed.connect(_on_reset)
	(box.get_node("ButtonRow/CancelButton") as Button).pressed.connect(_on_cancel)
	if _additional_btns.size() == 3:
		_additional_btns[0].pressed.connect(_on_additional_arena)
		_additional_btns[1].pressed.connect(_on_additional_chronicle)
		_additional_btns[2].pressed.connect(_on_additional_model)

func _ensure_additional_section() -> void:
	if not show_additional or _additional_header != null:
		return
	var box := get_node("Panel/Box") as VBoxContainer
	if box == null:
		return
	var header := Label.new()
	header.name = "AdditionalHeader"
	var row := HBoxContainer.new()
	row.name = "AdditionalRow"
	for i in 3:
		var btn := Button.new()
		btn.name = "AdditionalBtn_%d" % i
		row.add_child(btn)
		_additional_btns.append(btn)
	var anchor := box.get_node_or_null("AutoSaveToggle")
	var idx: int = box.get_child_count()
	if anchor != null:
		idx = box.get_children().find(anchor)
	box.add_child(header)
	box.add_child(row)
	box.move_child(header, idx)
	box.move_child(row, idx + 1)
	_additional_header = header

func _on_additional_arena() -> void:
	arena_requested.emit()

func _on_additional_chronicle() -> void:
	chronicle_requested.emit()

func _on_additional_model() -> void:
	model_requested.emit("warrior")

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	(get_node("Panel") as PanelContainer).add_theme_stylebox_override("panel", style)

	var box := get_node("Panel/Box")
	for btn_name in ["ApplyButton", "ResetButton", "CancelButton"]:
		_style_button(box.get_node("ButtonRow/" + btn_name) as Button)
	for btn in _additional_btns:
		_style_button(btn)

func _style_button(btn: Button) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = C_BTN_BG
	sn.set_corner_radius_all(6)
	sn.set_border_width_all(1)
	sn.border_color = ThemeConfig.C_BTN_BORDER
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate()
	sh.bg_color = C_BTN_HOVER
	btn.add_theme_stylebox_override("hover", sh)

	var sp := sn.duplicate()
	sp.bg_color = C_BTN_PRESS
	btn.add_theme_stylebox_override("pressed", sp)

func _restore_state() -> void:
	_zoom_selector.selected = _settings.zoom_index
	_fullscreen_toggle.button_pressed = _settings.fullscreen
	_ui_anim_toggle.button_pressed = _settings.ui_animations
	_particles_toggle.button_pressed = _settings.particles
	_auto_save_toggle.button_pressed = _settings.auto_save
	_master_slider.value = float(_settings.master_volume)
	_music_slider.value = float(_settings.music_volume)
	_sfx_slider.value = float(_settings.sfx_volume)
	_mute_toggle.button_pressed = _settings.is_muted

func _on_zoom_selected(index: int) -> void:
	_settings.zoom_index = index

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

func _on_mute_toggled(pressed: bool) -> void:
	_settings.is_muted = pressed
	_settings._apply_audio()

func _on_apply() -> void:
	_settings.fullscreen = _fullscreen_toggle.button_pressed
	_settings.ui_animations = _ui_anim_toggle.button_pressed
	_settings.particles = _particles_toggle.button_pressed
	_settings.auto_save = _auto_save_toggle.button_pressed
	_settings.save()
	_settings.apply_display_mode()
	applied.emit()
	_do_close()

func _on_reset() -> void:
	_settings.reset_to_defaults()
	_restore_state()

func _on_cancel() -> void:
	_settings.zoom_index = _initial_state.zoom_index
	_settings.fullscreen = _initial_state.fullscreen
	_settings.ui_animations = _initial_state.ui_animations
	_settings.particles = _initial_state.particles
	_settings.auto_save = _initial_state.auto_save

	_settings.set_master_volume(_initial_state.master_volume)
	_settings.set_music_volume(_initial_state.music_volume)
	_settings.set_sfx_volume(_initial_state.sfx_volume)
	_settings.is_muted = _initial_state.is_muted
	_settings._apply_audio()

	_do_close()

func _do_close() -> void:
	closed.emit()
	if persistent:
		visible = false
	elif is_inside_tree():
		queue_free()
