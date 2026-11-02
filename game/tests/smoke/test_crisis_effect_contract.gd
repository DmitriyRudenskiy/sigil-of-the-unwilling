extends BaseTest

## Контракт эффектов каталога событий (Q-M79 → (а), D-197).
## Каждый ключ эффектов в данных обязан иметь обработчик, доходящий до живого
## носителя: немые ключи из данных удалены, а новый ключ без обработчика —
## падение теста, а не тихий no-op. Канал настроения ведёт на шкалу поселения
## 02g (Q-M78 → (а)): изобретённое поле player_data["morale"] снято (оно
## запрещено сейвом — MvpSaveSchema.DERIVED_KEYS).

## Ключи выбора: обработаны CrisisEventSystem.apply_choice_effects.
const CHOICE_KEYS: Array[String] = [
	"resource_change", "morale_change", "population_change",
	"unlock_building",
]

## Ключи кризиса (ongoing): обработаны apply_crisis_effects напрямую.
const CRISIS_KEYS: Array[String] = [
	"resource_drain", "morale_penalty",
]

## Ключи разрешения кризиса: словарь выбора поверх кризисного (crisis_01_fire:
## population_change в resolution_effects) — apply_crisis_effects делегирует их
## в apply_choice_effects (Q-M79 → (а)).
const RESOLUTION_KEYS: Array[String] = [
	"resource_drain", "morale_penalty",
	"resource_change", "morale_change", "population_change",
	"unlock_building",
]

## Снятые каналы (Q-M81 → разбор построчно, D-200): писатели без читателя.
## `unlock_law` вёл приватный LawManager вне дерева и UI (пассивные эффекты не
## читал никто); `production_reduction` писал player_data["production_modifier"],
## где его не читал никто, а канонического модификатора производства нет.
## В данных их быть не должно; живой диспетчер на них кричит.
const RETIRED_EFFECT_KEYS: Array[String] = [
	"unlock_law", "production_reduction",
]

var _gm: GameManager = null


func _sys() -> CrisisEventSystem:
	return make_node(CrisisEventSystem)  # _ready грузит шаблоны событий и кризисов


func _districts() -> DistrictSystem:
	return DistrictSystem.new(MvpInvariants.load_config("districts"), {"farm": 2})


func _wire_game_manager() -> GameManager:
	_gm = GameManager.new()
	_gm.name = "GameManager"
	get_tree().root.add_child(_gm)
	return _gm


## Живая стопка как в main.tscn: GameManager + UIManager + CrisisEventSystem.
## Нужна, чтобы пройти путь клика (UIManager.decision_made → GameManager →
## CrisisEventSystem), а не вызвать диспетчер напрямую.
func _wire_live_stack() -> CrisisEventSystem:
	_gm = GameManager.new()
	_gm.name = "GameManager"
	var um := UIManager.new()
	um.name = "UIManager"
	_gm.add_child(um)
	var sys := CrisisEventSystem.new()
	sys.name = "CrisisEventSystem"
	_gm.add_child(sys)
	get_tree().root.add_child(_gm)
	return sys


## Первое событие каталога с каналом resource_change + индекс его выбора.
func _pick_resource_event(sys: CrisisEventSystem) -> Dictionary:
	for e in sys.event_templates:
		if e.id == "":
			continue
		for i in range(e.choices.size()):
			if e.choices[i].effects.has("resource_change"):
				return {"event": e, "index": i}
	return {}


# --- Канал выбора игрока: клик по панели обязан доходить до эффектов ---

## Путь клика: панель → UIManager.decision_made → резолвер → носитель. До
## прохода 9 резолвера обычного события не было: _on_decision_made писал в
## decision_log и вызывал пустую заглушку, эффекты выбора не применял никто
## (в отличие от кризиса, у которого есть resolve_crisis).
func test_player_choice_applies_effects() -> void:
	var sys := _wire_live_stack()
	var picked := _pick_resource_event(sys)
	assert_that(not picked.is_empty()).override_failure_message(
		"в каталоге нет события с resource_change").is_true()
	var event = picked["event"]
	var idx: int = int(picked["index"])
	var effects: Dictionary = event.choices[idx].effects["resource_change"]
	var res: String = str(effects.keys()[0])
	var delta: int = int(effects[res])
	var before: int = _gm.get_resource(res)

	sys.trigger_event(event)
	assert_that(sys.active_events.size()).override_failure_message(
		"событие не встало в активные").is_equal(1)

	_gm.ui_manager.decision_made.emit(event.id, idx)

	assert_that(_gm.get_resource(res)).override_failure_message(
		"выбор игрока не применил resource_change (эффекты события не применяются)"\
		+ ": %s %d → %d, ожидалось %d" % [res, before, _gm.get_resource(res), before + delta]\
		).is_equal(before + delta)


## Разрешённое событие снимается с активных, помечается разрешённым в истории и
## закрывает панель — на это опирается on_day_passed («показанное событие уже
## разрешено игроком»). Заодно держит живым путь создания панели: до прохода 9
## он падал на первых же строках (Window/Control, Vector2i), и игрок события
## не видел вовсе.
func test_player_choice_closes_the_event() -> void:
	var sys := _wire_live_stack()
	var um := _gm.get_node("UIManager") as UIManager
	var picked := _pick_resource_event(sys)
	var event = picked["event"]
	sys.trigger_event(event)
	assert_that(um.current_decision_popup != null).override_failure_message(
		"панель события не создана — UIManager._create_simple_decision_panel падает"
		+ " (игрок не видит события каталога)").is_true()
	assert_that(um.current_decision_popup.is_inside_tree()).override_failure_message(
		"панель события не добавлена в дерево").is_true()
	_gm.ui_manager.decision_made.emit(event.id, int(picked["index"]))
	assert_that(um.current_decision_popup == null).override_failure_message(
		"панель события не закрылась после выбора (останется висеть поверх игры)")\
		.is_true()
	assert_that(sys.active_events.size()).override_failure_message(
		"разрешённое событие осталось в active_events (на следующий день его"
		+ " съест active_events.clear() — игрок потерял выбор без эффектов)"\
		).is_equal(0)
	var record: Dictionary = sys.event_history[sys.event_history.size() - 1]
	assert_that(bool(record.get("resolved", false))).override_failure_message(
		"событие не помечено разрешённым в истории").is_true()


## Панель кризиса — тот же fallback-путь, что и панель события (те же ошибки
## создания), но резолвер у кризиса был всегда: проверяем саму панель.
## Панель вызывается напрямую: get_available_crises на нулевом дне фильтрует
## все шаблоны по min_day/триггерам — это не то, что здесь проверяется.
func test_crisis_panel_is_created_and_closes() -> void:
	var sys := _wire_live_stack()
	var um := _gm.get_node("UIManager") as UIManager
	assert_that(sys.crisis_templates.size() > 0).is_true()
	var crisis = sys.crisis_templates[0]
	sys.current_crisis = crisis
	sys.show_crisis_panel(crisis)
	assert_that(um.current_crisis_popup != null).override_failure_message(
		"панель кризиса не создана — UIManager._create_simple_crisis_panel падает").is_true()
	um.crisis_resolved.emit(crisis.id, 0)
	assert_that(um.current_crisis_popup == null).override_failure_message(
		"панель кризиса не закрылась после разрешения").is_true()
	assert_that(sys.current_crisis == null).override_failure_message(
		"кризис не снят после разрешения").is_true()


## Вне диапазона — без эффектов и без падения (зеркало resolve_crisis), но
## событие закрывается: панель не должна оставаться открытой.
func test_out_of_range_choice_applies_nothing() -> void:
	var sys := _wire_live_stack()
	var picked := _pick_resource_event(sys)
	var event = picked["event"]
	var effects: Dictionary = event.choices[int(picked["index"])].effects["resource_change"]
	var res: String = str(effects.keys()[0])
	var before: int = _gm.get_resource(res)
	sys.trigger_event(event)
	_gm.ui_manager.decision_made.emit(event.id, 99)
	assert_that(_gm.get_resource(res)).override_failure_message(
		"выбор вне диапазона применил эффекты").is_equal(before)
	assert_that(sys.active_events.size()).is_equal(0)


## Выбор по неактивному событию не должен порождать эффектов (защита от двойного
## клика / позднего сигнала после active_events.clear()).
func test_choice_for_inactive_event_applies_nothing() -> void:
	var sys := _wire_live_stack()
	var picked := _pick_resource_event(sys)
	var event = picked["event"]
	var effects: Dictionary = event.choices[int(picked["index"])].effects["resource_change"]
	var res: String = str(effects.keys()[0])
	var before: int = _gm.get_resource(res)
	_gm.ui_manager.decision_made.emit(event.id, int(picked["index"]))
	assert_that(_gm.get_resource(res)).override_failure_message(
		"эффекты применены для события, которого нет в активных").is_equal(before)


func after_test() -> void:
	# Базовый сброс (пауза дерева/токены) — иначе живой стопке хватит паузы,
	# чтобы повесить следующие тесты этого набора.
	super.after_test()
	if is_instance_valid(_gm):
		var um := _gm.get_node_or_null("UIManager")
		if um != null:
			for popup_key in ["current_decision_popup", "current_crisis_popup"]:
				if um.get(popup_key) != null:
					um.get(popup_key).queue_free()
					um.set(popup_key, null)
			# Живая стопка: UIManager/CrisisEventSystem — дети GameManager, их тоже
			# снимаем с дерева до освобождения родителя (иначе сироты на следующий тест).
			for child in _gm.get_children():
				_gm.remove_child(child)
				child.queue_free()
		get_tree().root.remove_child(_gm)
		_gm.queue_free()
	_gm = null
	await get_tree().process_frame


# --- Закрытый набор ключей (fail-fast вместо тихого no-op) ---

func test_choice_keys_within_closed_set() -> void:
	var sys := _sys()
	var offenders: Array[String] = []
	for e in sys.event_templates:
		if e.id == "":
			continue
		for c in e.choices:
			for key in c.effects.keys():
				if not CHOICE_KEYS.has(str(key)):
					offenders.append("%s: %s" % [e.id, str(key)])
	for c in sys.crisis_templates:
		for ch in c.choices:
			for key in ch.effects.keys():
				if not CHOICE_KEYS.has(str(key)):
					offenders.append("%s: %s" % [c.id, str(key)])
	assert_that(offenders).override_failure_message(
		"немые ключи эффектов в данных (нет обработчика): " + str(offenders)).is_empty()


func test_crisis_keys_within_closed_set() -> void:
	var sys := _sys()
	var offenders: Array[String] = []
	for c in sys.crisis_templates:
		for key in c.ongoing_effects.keys():
			if not CRISIS_KEYS.has(str(key)):
				offenders.append("%s/ongoing_effects: %s" % [c.id, str(key)])
		for key in c.resolution_effects.keys():
			if not RESOLUTION_KEYS.has(str(key)):
				offenders.append("%s/resolution_effects: %s" % [c.id, str(key)])
	assert_that(offenders).override_failure_message(
		"немые ключи кризисных эффектов (нет обработчика): " + str(offenders)).is_empty()


# --- Канал настроения: носитель = настроение поселения (02g, 0–100, старт 70) ---

func test_morale_change_lands_on_settlement_mood() -> void:
	_wire_game_manager()
	var sys := _sys()
	var districts := _districts()
	sys.mood_sink = districts
	sys.apply_choice_effects({"morale_change": -5})
	for g in districts.mood.keys():
		assert_float(float(districts.mood[g])).override_failure_message(
			"morale_change не дошёл до настроения района " + str(g)).is_equal(65.0)


func test_morale_penalty_lands_on_settlement_mood() -> void:
	_wire_game_manager()
	var sys := _sys()
	var districts := _districts()
	sys.mood_sink = districts
	sys.apply_crisis_effects({"morale_penalty": -8})
	for g in districts.mood.keys():
		assert_float(float(districts.mood[g])).override_failure_message(
			"morale_penalty не дошёл до настроения района " + str(g)).is_equal(62.0)


## Приёмника нет — канал обязан кричать (push_error), а не писать в мёртвое поле.
func test_morale_channel_without_sink_is_push_error() -> void:
	_wire_game_manager()
	var sys := _sys()
	await assert_error(func () -> void: sys.apply_choice_effects({"morale_change": -5})) \
		.is_push_error("CrisisEventSystem: morale_change без приёмника настроения (DistrictSystem)")


## Изобретённое поле player_data["morale"] снято вместе с API GameManager.
func test_invented_morale_store_is_removed() -> void:
	_wire_game_manager()
	var sys := _sys()
	sys.mood_sink = _districts()
	sys.apply_choice_effects({"morale_change": -5})
	assert_that(_gm.player_data.has("morale")).is_false()
	assert_that(_gm.has_method("modify_global_morale")).is_false()
	assert_that(_gm.has_method("get_global_morale")).is_false()


## Мёртвые ключи удалены из данных вместе с обработчиками (Q-M79 → (а)),
## писатели без читателя — следом (Q-M81 → разбор построчно, D-200).
func test_dead_effect_handlers_are_removed() -> void:
	var gm := _wire_game_manager()
	assert_that(gm.has_method("add_permanent_modifier")).is_false()
	assert_that(gm.has_method("apply_production_modifier")).is_false()
	# Мёртвый обработчик с фантомными писателями (reputation, trigger_event).
	assert_that(gm.has_method("_apply_effects")).is_false()
	var sys := _sys()
	assert_that(sys.serialize_state().has("law")).is_false()


# --- Снятые каналы: в данных их нет, диспетчер на них кричит (D-200) ---

func test_retired_channels_absent_from_data() -> void:
	var sys := _sys()
	var offenders: Array[String] = []
	for e in sys.event_templates:
		if e.id == "":
			continue
		for c in e.choices:
			for key in c.effects.keys():
				if RETIRED_EFFECT_KEYS.has(str(key)):
					offenders.append("%s: %s" % [e.id, str(key)])
	for c in sys.crisis_templates:
		for key in c.ongoing_effects.keys():
			if RETIRED_EFFECT_KEYS.has(str(key)):
				offenders.append("%s/ongoing_effects: %s" % [c.id, str(key)])
		for key in c.resolution_effects.keys():
			if RETIRED_EFFECT_KEYS.has(str(key)):
				offenders.append("%s/resolution_effects: %s" % [c.id, str(key)])
	assert_that(offenders).override_failure_message(
		"снятый канал вернулся в данные: " + str(offenders)).is_empty()


func test_unlock_law_is_a_retired_channel() -> void:
	_wire_game_manager()
	var sys := _sys()
	await assert_error(func () -> void: sys.apply_choice_effects({"unlock_law": "order_tax_code"})) \
		.is_push_error("CrisisEventSystem.apply_choice_effects: " \
		+ "немой ключ эффекта unlock_law (нет обработчика)")


func test_production_reduction_is_a_retired_channel() -> void:
	_wire_game_manager()
	var sys := _sys()
	await assert_error(func () -> void: sys.apply_crisis_effects({"production_reduction": -0.1})) \
		.is_push_error("CrisisEventSystem.apply_choice_effects: " \
		+ "немой ключ эффекта production_reduction (нет обработчика)")
	assert_that(_gm.player_data.has("production_modifier")).is_false()


## Граница внутреннего контура (D-200): население каталога — собственный счётчик
## effects/триггеров, каноническое население (резиденты T-110) оно не трогает.
## Тест фиксирует границу: роутинг на канон — решение T-131, а не случайность.
func test_population_change_does_not_touch_canonical_residents() -> void:
	_wire_game_manager()
	var sys := _sys()
	var pop := PopulationSystem.new()
	var before: int = pop.size()
	sys.apply_choice_effects({"population_change": 3})
	# Счётчик каталога стартует с 5 (_initialize_game) — канал прибавил к нему.
	assert_that(_gm.get_population()).is_equal(8)
	assert_that(pop.size()).is_equal(before)
