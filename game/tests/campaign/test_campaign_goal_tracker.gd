extends BaseTest
## mvp-ui-flow 5.2 (M3): GdUnit4 — панель целей 3 дней.
## День 1 — ферма + казармы; день 2 — тренировка воина; день 3 — руины.
## Панель видна, пока не выполнены все цели; после — скрыта и не показывается снова.

const Tracker = preload("res://scripts/ui/campaign_goal_tracker.gd")


func _tracker(ruins_region: String = "R03") -> CampaignGoalTracker:
	return Tracker.new(Tracker.default_mvp_goals(ruins_region))


## === Начальное состояние: все цели pending, панель видна ===

func test_initial_all_pending_panel_visible() -> void:
	var t := _tracker()
	assert_bool(t.all_complete()).is_false()
	assert_bool(t.visible()).is_true()
	assert_int(t.pending().size()).is_equal(4)


func test_default_goals_structure() -> void:
	var t := _tracker()
	assert_int(t.goals.size()).is_equal(4)
	# День 1 — две цели (ферма + казармы).
	assert_int(t.goals_for_day(1).size()).is_equal(2)
	# День 2 — тренировка воина (класс fighter, K-M15).
	var day2: Array = t.goals_for_day(2)
	assert_int(day2.size()).is_equal(1)
	assert_str(day2[0]["type"]).is_equal(Tracker.GOAL_TRAIN)
	assert_str(day2[0]["target"]).is_equal("fighter")
	# День 3 — руины (регион).
	var day3: Array = t.goals_for_day(3)
	assert_int(day3.size()).is_equal(1)
	assert_str(day3[0]["type"]).is_equal(Tracker.GOAL_REGION)


## === Выполнение целей по событиям ===

func test_building_goal_completes_on_build() -> void:
	var t := _tracker()
	assert_bool(t.is_complete("farm")).is_false()
	t.note_building_built("campaign_farm")
	assert_bool(t.is_complete("farm")).is_true()
	# Чужое здание не закрывает цель.
	assert_bool(t.is_complete("barracks")).is_false()


func test_train_warrior_goal() -> void:
	var t := _tracker()
	t.note_training_completed("ranger")  # не воин — не закрывает
	assert_bool(t.is_complete("train_warrior")).is_false()
	t.note_training_completed("fighter")
	assert_bool(t.is_complete("train_warrior")).is_true()


func test_ruins_goal_region_match() -> void:
	var t := _tracker("R03")
	t.note_region_visited("R01")  # не руины
	assert_bool(t.is_complete("ruins")).is_false()
	t.note_region_visited("R03")
	assert_bool(t.is_complete("ruins")).is_true()


func test_ruins_goal_empty_target_any_region() -> void:
	# Пустой target = «выйти в поле»: любой посещённый регион закрывает цель.
	var t := _tracker("")
	t.note_region_visited("E4")
	assert_bool(t.is_complete("ruins")).is_true()


## === Панель: видимость и «не показывается снова» ===

func test_panel_hides_when_all_complete() -> void:
	var t := _tracker("R03")
	t.note_building_built("campaign_farm")
	t.note_building_built("campaign_barracks")
	t.note_training_completed("fighter")
	assert_bool(t.visible()).is_true()  # руины ещё не посещены
	t.note_region_visited("R03")
	assert_bool(t.all_complete()).is_true()
	assert_bool(t.visible()).is_false()
	assert_int(t.pending().size()).is_equal(0)


func test_goals_not_reshown_after_complete() -> void:
	var t := _tracker("R03")
	t.note_building_built("campaign_farm")
	t.note_building_built("campaign_barracks")
	t.note_training_completed("fighter")
	t.note_region_visited("R03")
	assert_bool(t.visible()).is_false()
	# Цели только помечаются done — повторные события не «включают» панель.
	t.note_building_built("campaign_farm")
	t.note_region_visited("R03")
	assert_bool(t.visible()).is_false()
	assert_bool(t.all_complete()).is_true()


func test_goal_completed_signal_fires_once_per_goal() -> void:
	var t := _tracker("R03")
	var fired: Array = []
	t.goal_completed.connect(func(id: String) -> void: fired.append(id))
	t.note_building_built("campaign_farm")
	t.note_building_built("campaign_farm")  # повтор — без сигнала
	assert_int(fired.size()).is_equal(1)
	assert_str(fired[0]).is_equal("farm")


## === Сейв/загрузка ===

func test_save_load_roundtrip() -> void:
	var t := _tracker("R03")
	t.note_building_built("campaign_farm")
	t.note_training_completed("fighter")
	var data: Dictionary = t.to_dict()
	var restored: CampaignGoalTracker = Tracker.from_dict(data)
	assert_bool(restored.is_complete("farm")).is_true()
	assert_bool(restored.is_complete("train_warrior")).is_true()
	assert_bool(restored.is_complete("barracks")).is_false()
	assert_bool(restored.visible()).is_true()


func test_from_dict_empty_is_fresh_defaults() -> void:
	var t: CampaignGoalTracker = Tracker.from_dict({})
	# Пустой сейв → свежий трекер с целями по умолчанию (все pending).
	assert_int(t.goals.size()).is_equal(4)
	assert_bool(t.visible()).is_true()
