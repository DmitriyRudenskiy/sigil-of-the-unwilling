extends BaseTest

# T-147 (перенос мини-полос команды в тему). Технический перенос: `_mini_bar` клал
# StyleBoxFlat на узел через add_theme_stylebox_override — переопределение сильнее темы,
# поэтому кит шага 4 не имел над полосами власти. Цвета семантические (связь/верность/
# романтика), так что в теме их три варианта на ProgressBar + общий фон; код выбирает
# вариант именем, а не красит пиксел.
#
# Проверки те же, что у экрана настроек:
#   1) на полосах нет stylebox-переопределений (AC1);
#   2) полосы переведены на зарегистрированные варианты темы (AC3);
#   3) тема отдаёт ровно те float-значения, что рисовал снятый override (AC2 как «не
#      хуже»: побитово тот же стиль → тот же пиксел);
#   4) негативный контроль: незарегистрированный тип носителя не резолвит.
#
# Полосы существуют только когда у героя есть последователь, поэтому фикстура обязана
# давать героя с командой: без неё тест молча проходил бы по пустому дереву.

const _PANEL_SCENE := preload("res://scenes/ui/hero_status_panel.tscn")
const _THEME := preload("res://assets/theme/game_theme.tres")

# Значения, которые рисовал снятый override (game/scripts/ui/hero_status_panel.gd
# до переноса). Сверяются побитово: float-литералы, а не hex.
const _FILL_COLORS := {
	"MiniBarBond": Color(0.35, 0.6, 1.0),
	"MiniBarTrust": Color(0.35, 0.8, 0.45),
	"MiniBarRomance": Color(0.9, 0.45, 0.7),
}
const _BG_COLOR := Color(0.12, 0.12, 0.15)
const _VARIATIONS := ["MiniBarBond", "MiniBarTrust", "MiniBarRomance"]

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


## Панель + герой с одной последовательницей и ненулевыми связями.
## Без команды `_build_team_box` не создаёт полос — фикстура обязана её дать.
func _mk_panel_with_team() -> Control:
	var panel: Control = _PANEL_SCENE.instantiate()
	_nodes.append(panel)
	get_tree().root.add_child(panel)
	var hero := HeroController.new()
	_nodes.append(hero)
	hero.hero_name = "Тест"
	get_tree().root.add_child(hero)
	var f := Follower.new()
	f.uid = 7
	f.name = "Мира"
	f.path = &"fighter"
	f.gender = &"female"
	hero.followers_comp.add(f)
	var p: Dictionary = hero.relationships.pair(7)
	p["bond"] = 62
	p["trust"] = 80
	p["romance"] = 35
	panel.set_hero(hero)
	return panel


func _mini_bars(panel: Control) -> Array[ProgressBar]:
	var out: Array[ProgressBar] = []
	var stack: Array[Node] = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is ProgressBar:
				out.append(c as ProgressBar)
			stack.append(c)
	return out


func test_mini_bars_exist_only_with_a_team() -> void:
	var panel := _mk_panel_with_team()
	assert_int(_mini_bars(panel).size()).is_equal(3) \
		.override_failure_message("у героя с одной последовательницей должно быть три полосы")


func test_mini_bars_have_no_stylebox_overrides() -> void:
	var panel := _mk_panel_with_team()
	for bar in _mini_bars(panel):
		var ov := ThemeCarrierGuard.stylebox_overrides(bar)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message("на мини-полосе висит stylebox-переопределение: %s" % ", ".join(ov.keys()))


func test_mini_bars_take_carrier_from_theme() -> void:
	var panel := _mk_panel_with_team()
	var bars := _mini_bars(panel)
	var i := 0
	while i < bars.size() and i < _VARIATIONS.size():
		assert_str(str(bars[i].theme_type_variation)).is_equal(_VARIATIONS[i]) \
			.override_failure_message("полоса %d не переведена на вариант темы %s" % [i, _VARIATIONS[i]])
		i += 1


## Тема обязана отдавать те же float-значения, что рисовал снятый override: иначе
## перенос меняет пиксел, а обещанная нулевая визуальная дельта нарушается.
func test_theme_carries_the_removed_style_values() -> void:
	var panel := _mk_panel_with_team()
	var bars := _mini_bars(panel)
	var i := 0
	while i < bars.size() and i < _VARIATIONS.size():
		var variation := StringName(_VARIATIONS[i])
		var fill: StyleBoxFlat = bars[i].get_theme_stylebox("fill") as StyleBoxFlat
		assert_object(fill).is_not_null() \
			.override_failure_message("%s не получил fill из темы" % variation)
		assert_bool(fill.bg_color == _FILL_COLORS[variation]).is_true() \
			.override_failure_message("fill %s отличается от снятого override" % variation)
		assert_int(fill.corner_radius_top_left).is_equal(2) \
			.override_failure_message("скругление fill %s должно остаться 2" % variation)

		var bg: StyleBoxFlat = bars[i].get_theme_stylebox("background") as StyleBoxFlat
		assert_object(bg).is_not_null() \
			.override_failure_message("%s не получил background из темы" % variation)
		assert_bool(bg.bg_color == _BG_COLOR).is_true() \
			.override_failure_message("background %s отличается от снятого override" % variation)
		assert_int(bg.corner_radius_top_left).is_equal(2) \
			.override_failure_message("скругление background %s должно остаться 2" % variation)
		i += 1


# T-227 (С-2): проверки «в исходниках нет обхода темы» и «несуществующий тип не
# резолвит» переехали в res://tests/unit/ui/test_theme_source_scan.gd (скан всего
# production-кода, а не «своих» файлов) и res://tests/unit/ui/test_theme_variation_matrix.gd
# (контракт от носителя: все 70 вариантов темы, а не три экрана, которым завели файл).
# Здесь остались только проверки, привязанные к этому экрану: что ТЕМА отдаёт ровно те
# значения, которые рисовал снятый override (AC2), и что живой узел экрана не получает
# переопределений в рантайме.
