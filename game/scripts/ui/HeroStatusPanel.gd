extends PanelContainer
class_name HeroStatusPanel
## legend-chronicle: состояние героя — кондиция, статы, последователи.
## Read-only: панель рисует то, что есть, и рендерит только секции с
## данными. hero-survival: секция «Кондиция» включает четыре потребности
## (🍞😴🤝💡, критический <25% — ⚠️); без needs-компонента — деградация
## до HP/маны (graceful degradation).

var _hero: HeroController = null

var _title: Label
var _cond_label: Label
var _stats_label: Label
var _followers_label: Label
## ponytail: выводим не больше N последователей (правая колонка 252px),
## остаток — «+N ещё». Если список станет длинным и начнёт жать —
## заменить на ScrollContainer.
const _MAX_FOLLOWERS_SHOWN := 6

const _NEED_ICONS: Dictionary = {
	&"hunger": "🍞",
	&"rest": "😴",
	&"social": "🤝",
	&"inspiration": "💡",
}


## ponytail: билд в _init, а не _ready — headless-тесты (run_tests.gd) идут
## синхронно, кадры не прогоняются, и _ready на добавленных нодах не срабатывает.
func _init() -> void:
	custom_minimum_size = Vector2(160, 0)
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	# ponytail: имя явное — Godot 4.7 auto-name (@VBoxContainer@N) ломает get_node.
	vbox.name = "VBox"
	add_child(vbox)

	# ponytail: имена явные — Godot 4.7 auto-name (@Label@N) ломает get_node.
	_title = Label.new()
	_title.name = "Title"
	_title.text = "🧙 Герой"
	_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_title)

	_cond_label = _make_label()
	_cond_label.name = "ConditionLabel"
	vbox.add_child(_cond_label)

	_stats_label = _make_label()
	_stats_label.name = "StatsLabel"
	vbox.add_child(_stats_label)

	_followers_label = _make_label()
	_followers_label.name = "FollowersLabel"
	vbox.add_child(_followers_label)


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func set_hero(hero: HeroController) -> void:
	_hero = hero
	refresh()


func refresh() -> void:
	# legend-chronicle: герой может быть освобождён (смерть → последовательность)
	# до обновления панели — проверить живость, а не только null.
	if _hero == null or not is_instance_valid(_hero):
		_title.text = "🧙 Герой"
		_cond_label.text = ""
		_stats_label.text = ""
		_followers_label.text = ""
		return
	var h: HeroController = _hero
	_title.text = "🧙 %s — %s" % [h.hero_name, _path_name(h.path_id)]
	_cond_label.text = _condition_text(h)
	_stats_label.text = _stats_text(h)
	_followers_label.text = _followers_text(h)


## Кондиция: HP/мана; hero-survival: потребности (needs-компонент).
func _condition_text(h: HeroController) -> String:
	var parts: Array[String] = []
	if h.max_combat_hp > 0:
		parts.append("❤️ %d/%d" % [h.combat_hp, h.max_combat_hp])
	if h.mana_max > 0:
		parts.append("✨ %d/%d" % [h.mana_current, h.mana_max])
	# hero-survival: needs всегда есть у реального героя; null-проверка —
	# деградация для моков без компонента.
	if h.needs != null:
		parts.append(_needs_text(h.needs))
	if parts.is_empty():
		return ""
	return "\n".join(parts)


func _needs_text(n: HeroNeeds) -> String:
	var parts: Array[String] = []
	for k in HeroNeeds.NEED_KEYS:
		var mark := "⚠️" if n.is_critical(k) else ""
		parts.append("%s%s %.0f%%" % [_NEED_ICONS[k], mark, n.get_need(k) * 100.0])
	return "\n".join(parts)


func _stats_text(h: HeroController) -> String:
	var s: Dictionary = h.stats
	return "⚔️ %d  🛡️ %d  📖 %d  🧪 %d" % [
		int(s.get("attack", 0)), int(s.get("defense", 0)),
		int(s.get("knowledge", 0)), int(s.get("spell_power", 0)),
	]


func _followers_text(h: HeroController) -> String:
	var fs: Array = h.followers
	if fs.is_empty():
		return "👥 Последователи: нет"
	var lines: Array[String] = []
	var shown := mini(fs.size(), _MAX_FOLLOWERS_SHOWN)
	# TraitRegistry — для подписей черт (describe() проверяет has_method("get_trait")).
	var registry = FollowerSystem.registry()
	for i in shown:
		var f = fs[i]
		lines.append("• " + f.describe(registry))
	if fs.size() > shown:
		lines.append("+%d ещё" % (fs.size() - shown))
	return "\n".join(lines)


## path_id — голый StringName (реестра имён путей нет) — показываем как есть.
func _path_name(path: StringName) -> String:
	var p := String(path)
	if p.is_empty():
		return "беспутный"
	return p
