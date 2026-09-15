extends PanelContainer
class_name HeroStatusPanel

var _hero: HeroController = null

var _title: Label
var _cond_label: Label
var _stats_label: Label
var _followers_label: Label
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
	_title.add_theme_font_size_override("font_size", 14)
	_cond_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_font_size_override("font_size", 12)
	_followers_label.add_theme_font_size_override("font_size", 12)

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
		return
	var h: HeroController = _hero
	_title.text = GameText.hero_title(h.hero_name, _path_name(h.path_id))
	_cond_label.text = _condition_text(h)
	_stats_label.text = _stats_text(h)
	_followers_label.text = _followers_text(h)

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
