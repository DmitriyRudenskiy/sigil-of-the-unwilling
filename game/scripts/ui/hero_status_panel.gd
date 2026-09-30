extends PanelContainer
class_name HeroStatusPanel

## team-romance-roleplay 5.1: игрок выбрал последователя для разговора.
signal talk_requested(uid: int)

var _hero: HeroController = null

var _title: Label
var _cond_label: Label
var _stats_label: Label
var _followers_label: Label
var _team_box: VBoxContainer
var _need_icons: Dictionary = {}
const _MAX_FOLLOWERS_SHOWN := 6

var _wired := false

func _wire() -> void:
	if _wired:
		return
	_wired = true
	_title = get_node("VBox/Title") as Label
	_cond_label = get_node("VBox/ConditionLabel") as Label
	_stats_label = get_node("VBox/StatsLabel") as Label
	_followers_label = get_node("VBox/FollowersLabel") as Label
	# ui-icons: иконки потребностей (needs/rest|social|inspiration.png)
	var needs_box := get_node_or_null("VBox/Needs") as HBoxContainer
	if needs_box != null:
		for k in NeedType.all_ids():
			var tr := needs_box.get_node_or_null(NeedType.to_name(k).capitalize()) as TextureRect
			if tr != null:
				tr.texture = ThemeConfig.icon_texture(ThemeConfig.ICON_DIR_NEEDS + NeedType.to_name(k) + ".png")
				_need_icons[k] = tr
	_title.add_theme_font_size_override("font_size", 14)
	_cond_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_font_size_override("font_size", 12)
	_followers_label.add_theme_font_size_override("font_size", 12)
	# team-romance-roleplay 5.1: секция «Команда» (динамическая, без правки .tscn)
	var vbox := get_node("VBox") as VBoxContainer
	_team_box = VBoxContainer.new()
	_team_box.name = "TeamBox"
	_team_box.add_theme_constant_override("separation", 6)
	var idx: int = vbox.get_children().find(_followers_label)
	vbox.add_child(_team_box)
	vbox.move_child(_team_box, idx + 1)

func _ready() -> void:
	_wire()
	if _title != null:
		_title.text = GameText.hero_default_title()

func set_hero(hero: HeroController) -> void:
	_wire()
	_hero = hero
	refresh()

func refresh() -> void:
	_wire()
	if _hero == null or not is_instance_valid(_hero):
		_title.text = GameText.hero_default_title()
		_cond_label.text = ""
		_stats_label.text = ""
		_followers_label.text = ""
		for k in _need_icons:
			(_need_icons[k] as TextureRect).modulate = Color(0.4, 0.4, 0.4)
		return
	var h: HeroController = _hero
	_title.text = GameText.hero_title(h.hero_name, _path_name(h.path_id))
	_cond_label.text = _condition_text(h)
	_stats_label.text = _stats_text(h)
	_followers_label.text = _followers_text(h)
	for k in _need_icons:
		var critical := h.needs != null and h.needs.is_critical(k)
		(_need_icons[k] as TextureRect).modulate = Color(1.0, 0.3, 0.25) if critical else Color.WHITE
	_build_team_box(h)

func _condition_text(h: HeroController) -> String:
	var parts: Array[String] = []
	if h.max_combat_hp > 0:
		parts.append(GameText.hero_combat_hp(h.combat_hp, h.max_combat_hp))
	if h.magic.mana_max > 0:
		parts.append(GameText.hero_mana(h.magic.mana_current, h.magic.mana_max))
	if h.needs != null:
		parts.append(_needs_text(h.needs))
	if parts.is_empty():
		return ""
	return "\n".join(parts)

func _needs_text(n: HeroNeeds) -> String:
	var parts: Array[String] = []
	for k in NeedType.all_ids():
		var mark := "⚠️" if n.is_critical(k) else ""
		var icon := ThemeConfig.need_icon(NeedType.to_name(k))
		parts.append("%s%s %.0f%%" % [icon, mark, n.get_need(k) * 100.0])
	return "\n".join(parts)

func _stats_text(h: HeroController) -> String:
	var s: Dictionary = h.stats
	var base: String = GameText.hero_stats(
		int(s.get("attack", 0)), int(s.get("defense", 0)),
		int(s.get("knowledge", 0)), int(s.get("spell_power", 0)),
	)
	# attribute-weight-system: вес экипировки / лимит
	if h.inventory != null:
		var eq_w: float = LoadCalculator.equipment_weight(h.inventory)
		var cap: float = LoadCalculator.carry_cap(float(int(s.get("defense", 2))))
		var mark: String = " ⚠" if eq_w > cap else ""
		base += "\nВес: %.1f / %.1f%s" % [eq_w, cap, mark]
	# social-stats-weapon-tech: социальные статы рядом с боевыми
	var soc := "Инт %d | Муд %d | Хар %d | Уд %d" % [
		int(s.get("int", 2)), int(s.get("wis", 2)),
		int(s.get("cha", 2)), int(s.get("luk", 2)),
	]
	base += "\n" + soc
	return base

func _followers_text(h: HeroController) -> String:
	var fs: Array = h.followers
	if fs.is_empty():
		return GameText.hero_followers_none()
	var lines: Array[String] = []
	var shown := mini(fs.size(), _MAX_FOLLOWERS_SHOWN)
	var registry = FollowerSystem.registry()
	for i in shown:
		var f = fs[i]
		lines.append("• " + f.describe(registry))
	if fs.size() > shown:
		lines.append(GameText.hero_followers_more(fs.size() - shown))
	return "\n".join(lines)

func _path_name(path: StringName) -> String:
	var p := String(path)
	if p.is_empty():
		return GameText.hero_no_path()
	return p

# ═══════════════════════════════════════════
#  team-romance-roleplay 5.1: секция «Команда»
# ═══════════════════════════════════════════

func _build_team_box(h: HeroController) -> void:
	if _team_box == null:
		return
	for c in _team_box.get_children():
		c.queue_free()
	if h.followers.is_empty() or h.relationships == null:
		return
	for f in h.followers:
		if f == null:
			continue
		var p: Dictionary = h.relationships.pair(int(f.uid))
		var bond := int(p.get("bond", 0))
		var trust := int(p.get("trust", 50))
		var romance := int(p.get("romance", 0))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var info := Label.new()
		info.text = "%s %s [%s] — %s" % [
			_stage_icon(bond, romance), f.name,
			"Ж" if f.gender == &"female" else "М", String(f.path),
		]
		info.add_theme_font_size_override("font_size", 11)
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 3)
		bars.add_child(_mini_bar(bond, Color(0.35, 0.6, 1.0)))
		bars.add_child(_mini_bar(trust, Color(0.35, 0.8, 0.45)))
		bars.add_child(_mini_bar(romance, Color(0.9, 0.45, 0.7)))
		var talk := Button.new()
		talk.text = "💬 Поговорить"
		talk.tooltip_text = "Связь %d · Верность %d · Романтика %d" % [bond, trust, romance]
		talk.add_theme_font_size_override("font_size", 11)
		talk.pressed.connect(_on_talk_pressed.bind(int(f.uid)))
		row.add_child(info)
		row.add_child(bars)
		row.add_child(talk)
		_team_box.add_child(row)

func _mini_bar(value: int, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(float(value), 0.0, 100.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(44, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.15)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _stage_icon(bond: int, romance: int) -> String:
	match RelationshipSystem.romance_stage(romance):
		RelationshipSystem.ROM_MARRIED: return "💍"
		RelationshipSystem.ROM_ENGAGED: return "💐"
		RelationshipSystem.ROM_RELATIONSHIP: return "❤️"
		RelationshipSystem.ROM_FLIRT: return "😏"
	match RelationshipSystem.stage_of(bond):
		RelationshipSystem.STAGE_CLOSE_FRIEND: return "🤝"
		RelationshipSystem.STAGE_FRIEND: return "🙂"
	return "👤"

func _on_talk_pressed(uid: int) -> void:
	talk_requested.emit(uid)
