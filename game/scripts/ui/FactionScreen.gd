class_name FactionScreen
extends CanvasLayer
## quests-reputation-system 4.2: экран фракций — 6 фракций, уровень,
## модификаторы (цены/наём), история изменений.

const FactionReputation = preload("res://scripts/systems/FactionReputation.gd")
const HeroFactions = preload("res://scripts/data/hero_factions.gd")

var _panel: Panel
var _list: VBoxContainer
var _history: RichTextLabel

func _init() -> void:
	layer = 120
	visible = false
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 520)
	_panel.size = Vector2(620, 520)
	_panel.position = -_panel.size / 2
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Фракции и репутация"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var hist_title := Label.new()
	hist_title.text = "История изменений"
	vbox.add_child(hist_title)

	_history = RichTextLabel.new()
	_history.custom_minimum_size = Vector2(0, 120)
	_history.scroll_following = true
	vbox.add_child(_history)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(close_btn)

func show_factions(rep_state: Dictionary, history: Array) -> void:
	for child: Control in _list.get_children():
		child.queue_free()
	for faction_id: String in HeroFactions.FACTIONS:
		var f: Dictionary = HeroFactions.FACTIONS[faction_id]
		var value: int = int(rep_state.get(faction_id, 0))
		var row := VBoxContainer.new()
		var head := Label.new()
		head.text = "%s — %d (%s)" % [str(f["name"]), value, FactionReputation.band_name(value)]
		head.add_theme_font_size_override("font_size", 16)
		row.add_child(head)
		var mods := Label.new()
		var price: float = FactionReputation.price_multiplier(value)
		var hire: String = "доступен" if FactionReputation.can_hire(value) else "нет"
		mods.text = "Цены: ×%.2f · Найм: %s" % [price, hire]
		mods.add_theme_font_size_override("font_size", 13)
		row.add_child(mods)
		_list.add_child(row)
	_history.clear()
	for entry in history:
		var parts: PackedStringArray = str(entry).split("|")
		if parts.size() == 3:
			var delta: int = int(parts[1])
			var sign: String = "+" if delta > 0 else ""
			_history.append_text("%s %s%s — %s\n" % [HeroFactions.faction_name(parts[0]), sign, parts[1], parts[2]])
	visible = true
