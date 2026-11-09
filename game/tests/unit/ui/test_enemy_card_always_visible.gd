extends BaseTest

## dnd-battle-ladder 4.1 (M1): карточка врага — AC/HP/способности видны всегда.
##
## До среза `target_card` был чисто тултипом прицеливания:
## `BattleController._on_attack_target_updated(null)` прятал окно, и между
## наведениями игрок не видел ни AC, ни HP врага. Требование «видны всегда»
## относилось именно к этому окну, а не к карточке героя.
##
## Часть кейсов собрана на UI-сцене с вручную построенным состоянием (тот же приём,
## что у `test_battle_ui_hud_zones.gd`): `battle.tscn` в изолированном прогоне стартует
## с пустым `defender_units` — армии расставляет кампейн-флоу, — и на пустом состоянии
## проверялась бы только пустота. Юнит без `stack` даёт пустое имя и нулевой счёт,
## поэтому имя там сознательно не утверждается: утверждается то, для чего окно и
## существует, — AC и HP.
##
## Синтетического состояния мало (урок T-241): все восемь прежних кейсов были зелёны,
## а в живом бою окно не показывалось до первого наведения мыши — `_ready` зовёт
## `show_default_enemy_card` до того, как армии расставлены. Отсюда кейс
## `test_card_is_filled_on_the_first_frame_of_a_started_battle`: он идёт через
## `start_battle`, то есть через тот же путь, что и игрок.
##
## Строка «Удача» не проверяется и не показывается: носителя у неё в бою нет
## (`BattleRules.resolve_ladder(luck_mod)` не вызывается ни одним местом с ненулевым
## модификатором), а M1 запрещает число без источника.

const _BATTLE_UI := preload("res://scenes/ui/battle_ui.tscn")
const _CONTROLLER := "res://scripts/systems/battle_controller.gd"


func _ui() -> CanvasLayer:
	var ui: CanvasLayer = _BATTLE_UI.instantiate()
	auto_free(ui)
	add_child(ui)
	return ui


func _enemy(alive: bool) -> BattleState.BattleUnit:
	var stats := UnitStats.new()
	stats.defense = 7
	stats.hp = 20
	var stack := UnitStack.new()
	stack.stats = stats
	stack.count = 3
	var unit := BattleState.BattleUnit.new()
	unit.side = BattleState.Side.DEFENDER
	unit.alive = alive
	unit.stack = stack
	return unit


func _state(units: Array[BattleState.BattleUnit]) -> BattleState:
	var state := BattleState.new()
	state.defender_units = units
	return state


func _label(ui: CanvasLayer, key: String) -> Label:
	return ui.get_node("target_card/tc_box/" + key) as Label


func test_empty_field_hides_card_instead_of_lying() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([]))
	assert_bool(ui.get_node("target_card").visible).is_false()


func test_card_visible_without_any_aiming() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([_enemy(true)]))
	assert_bool(ui.get_node("target_card").visible).is_true().override_failure_message(
		"карточка скрыта при живом враге — M1 («AC/HP видны всегда») не выполнен"
	)


func test_caption_does_not_lie_before_aiming() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([_enemy(true)]))
	assert_str(_label(ui, "tc_caption").text).is_equal("Противник")


func test_ac_row_is_live_and_filled() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([_enemy(true)]))
	var defense: Label = _label(ui, "tc_def_row/tc_def")
	assert_bool(defense.visible).is_true().override_failure_message(
		"строка AC скрыта при defense=7 — окно не может называться «AC виден всегда»"
	)
	assert_str(defense.text).is_equal("7")
	assert_str(_label(ui, "tc_hp_row/tc_hp").text).is_not_empty()


func test_first_alive_enemy_is_shown() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([_enemy(false), _enemy(true)]))
	assert_bool(ui.get_node("target_card").visible).is_true()


func test_dead_side_hides_card() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([_enemy(false)]))
	assert_bool(ui.get_node("target_card").visible).is_false().override_failure_message(
		"противника нет, а окно показывает последнего мёртвого"
	)


func test_aiming_relabels_card_to_target() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_default_enemy_card(_state([_enemy(true)]))
	ui.show_target_card(_enemy(true), "Цель")
	assert_str(_label(ui, "tc_caption").text).is_equal("Цель")


## Контроллер — единственный производитель этого окна; без этих трёх вызовов
## карточка жила бы только на времени наведения мыши.
##
## Счёт по исходнику — только ретвейн количества мест вызова (ловит снятый
## вызов), он НЕ доказывает, что карточка появляется в бою: до T-241 здесь
## стояло `>= 2`, оба вызова были на месте, а в живом бою окно оставалось
## скрытым — `_ready` зовёт его на пустом состоянии. Настоящее доказательство
## — кейс ниже, он идёт через `start_battle`.
func test_controller_wires_the_card_to_battle_events() -> void:
	var src: String = FileAccess.get_file_as_string(_CONTROLLER)
	assert_int(src.count("_ui.show_default_enemy_card(_state)")).is_greater_equal(3) \
		.override_failure_message(
			"мест вызова стало меньше трёх: `_ready`, снятие прицеливания и старт боя"
		)


## Живой путь: бой стартует ПОСЛЕ `_ready` (world_battle_coordinator.gd:154 →
## battle_flow.gd:18), поэтому готовности сцены мало — окно обязана показывать
## сама постановка армий. До T-241 этот кейс не исполнялся ни в одном тесте,
## и кадр боя встречал игрока с пустым правым краем.
func _battle_started() -> Node:
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	auto_free(battle)
	add_child(battle)
	await await_millis(300)
	var atk: Array[UnitStack] = [Units.make_fixed_stack("swordsmen", 6)]
	var dfn: Array[UnitStack] = [Units.make_fixed_stack("goblins", 7)]
	assert_bool(atk[0] != null and dfn[0] != null).is_true() \
		.override_failure_message("регистр юнитов не отдал стеки — бой не начать")
	battle.start_battle(atk, dfn, {}, {}, {}, {}, 7, null, "snow")
	await get_tree().process_frame
	return battle


func test_card_is_filled_on_the_first_frame_of_a_started_battle() -> void:
	var battle: Node = await _battle_started()
	var state: BattleState = battle.get("_state")
	var living: int = 0
	for u in state.defender_units:
		if u != null and u.alive:
			living += 1
	assert_bool(living > 0).is_true() \
		.override_failure_message("вражеская сторона не жива — проверка ниже была бы пустой")
	var ui: CanvasLayer = battle.get_node("BattleUI") as CanvasLayer
	assert_bool(ui.get_node("target_card").visible).is_true().override_failure_message(
		"бой идёт, %d живых врагов, а карточка скрыта — M1 выполнялся только на синтетическом состоянии" % living
	)
	assert_str(_label(ui, "tc_caption").text).is_equal("Противник")
	assert_str(_label(ui, "tc_name").text).is_not_empty()
	assert_str(_label(ui, "tc_hp_row/tc_hp").text).is_not_empty()


## ── T-326: геометрия подписи (правый край — внутри пластины) ──────────────────
##
## Почему это здесь, а не в новом файле: носитель проверки — `scripts/ui/battle_ui.gd`,
## его группа в `docs/mvp/TEST-MAP.md` и так осколота (12 файлов), и
## Рэтчет карты тестов (`scripts/testmap.py --check`) снят сменой remove-doc-gates —
## новый файл больше не отвечает на него `merge_files +1`.
##
## Повод. UX-review «Карты кампании» (2026-11-02,
## `docs/mvp/matrix/2026-11-02/ux-map-screen-copy.md`, расхождение 2) прочитал в
## ячейке G10 «…еле…» и «…особности — задача», то есть обрезку с многоточием и
## «коробочку отсутствующего глифа». На живом кадре (`tools/shot_scene.gd`:
## `main.tscn` + `campaign_hud_plain`, отдельно `battle.tscn` + `battle_hud_full`)
## обе строки печатаются целиком, и многоточие им взяться негде: Godot подрезает
## строку только при `clip_text` или `autowrap`, а у `tc_caption` (`battle_ui.gd:306`)
## и у `AbilityTodoNote` (`campaign_hud.gd:904`) не включено ни то ни другое — ни в
## коде, ни в теме. Обрезанным оказался кроп ревью (цитата обрывается на середине
## слова), а «коробочкой» — декоративная «С» титульного шрифта на кегле 16. Саму
## строку полосы даёт заглушка макета 10 D-281 (`campaign.todo_abilities`,
## `locale/ru.po:1173`), и её сводит не эта запись, а T-244.
## Симптом закрыт как «не воспроизводится». Осталась мера, которую не держал никто:
## ширина подписи под ширину пластины. Заодно фиксируется выключенная подрезка —
## чтобы через полгода не гадали, откуда в этой полосе возьмётся «…».

## Внутренний rect пластины: то, что оставляет детям StyleBox `PanelCard`.
func _inner_rect(card: Control) -> Rect2:
	var r := card.get_global_rect()
	var sb: StyleBox = card.get_theme_stylebox("panel")
	assert_bool(sb != null).is_true().override_failure_message(
		"у пластины нет StyleBox «panel» — мерить «влезает ли подпись» нечем")
	if sb == null:
		return r
	return r.grow_individual(
		-sb.content_margin_left, -sb.content_margin_top,
		-sb.content_margin_right, -sb.content_margin_bottom)


## Правый край строки — внутри пластины; подрезка и перенос — выключены.
func _assert_row_fits(ui: CanvasLayer, key: String, what: String) -> void:
	var lbl := _label(ui, key)
	var inner := _inner_rect(ui.get_node("target_card") as Control)
	assert_bool(not lbl.clip_text).is_true().override_failure_message(
		"%s: включён clip_text — строка начнёт обрезаться, а не печататься целиком" % what)
	assert_int(lbl.autowrap_mode).is_equal(TextServer.AUTOWRAP_OFF) \
		.override_failure_message("%s: включён autowrap — перенос меняет высоту карточки" % what)
	var got := lbl.get_global_rect()
	assert_bool(got.size.x > 0.0).is_true().override_failure_message(
		"%s не разложен (rect %s) — строка невидима, мерить нечего" % [what, got])
	assert_bool(got.end.x <= inner.end.x + 0.5).is_true().override_failure_message(
		"%s: подпись %.0f..%.0f вылезает за пластину (внутренний край %.0f, текст «%s»)" % [
			what, got.position.x, got.end.x, inner.end.x, lbl.text])


## Юнит с dnd-профилем — носителем строки способностей (`battle_ui.gd:334`): без
## профиля строка скрыта, и кейс про неё мерил бы пустоту.
func _profiled_unit() -> BattleState.BattleUnit:
	var unit := _enemy(true)
	var profile := DnDCombatantProfile.new("goblins", "Гоблин")
	profile.level = 1
	unit.dnd_profile = profile
	return unit


## Обе подписи окна: «Цель» — путь контроллера (`battle_controller.gd:107`),
## «Противник» — путь наведения мыши (`battle_ui.gd:358`).
func test_both_captions_fit_their_plate() -> void:
	for caption: String in ["Цель", "Противник"]:
		var ui: CanvasLayer = _ui()
		ui.show_target_card(_profiled_unit(), caption)
		await await_millis(50)
		assert_str(_label(ui, "tc_caption").text).is_equal(caption)
		_assert_row_fits(ui, "tc_caption", "подпись «%s»" % caption)


## Строка способностей — самая широкая в окне («СИЛ … · ЛОВ … · ТЕЛ … ·» на первой
## строке из двух): именно ей лезть за пластину первой, если пластина сузится.
func test_abilities_row_fits_its_plate() -> void:
	var ui: CanvasLayer = _ui()
	ui.show_target_card(_profiled_unit(), "Цель")
	await await_millis(50)
	var row := _label(ui, "tc_abilities")
	assert_bool(row.visible).is_true().override_failure_message(
		"строка способностей скрыта при dnd-профиле — проверять нечего, а должна")
	_assert_row_fits(ui, "tc_abilities", "строка способностей")
