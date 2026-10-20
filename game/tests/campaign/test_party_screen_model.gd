extends BaseTest
## mvp-ui-flow 5.3: GdUnit4 — экран партии (view model, headless).
## 3.1: модель roster + ёмкость (данные — party_system.gd).
## 3.2: «что освободит слот» (ссылка на бой/смерть) — очередь пуста и партия
##      полна → подсказка, не пустота.
##
## «Полна» = ЖИВЫХ (state != DEAD) >= capacity (alive-подсчёт): смерть в бою
## освобождает слот (канон-намерение подсказки + settlement считает alive).

const Model = preload("res://scripts/ui/party_screen_model.gd")


## Член партии: {id, class, race, level, xp, state, battles_survived}.
func _m(
	id: String,
	class_id: String = "fighter",
	race: String = "human",
	level: int = 1,
	xp: int = 0,
	state: String = "READY",
	battles: int = 0
) -> Dictionary:
	return {"id": id, "class": class_id, "race": race, "level": level,
		"xp": xp, "state": state, "battles_survived": battles}


## Мёртвый боец (state=DEAD).
func _dead(id: String) -> Dictionary:
	return _m(id, "fighter", "human", 1, 0, "DEAD", 0)


## Партия из n живых бойцов (id p1..pn).
func _party(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(_m("p%d" % (i + 1)))
	return out


## === 3.1: roster-модель ===

func test_roster_empty_party() -> void:
	var r: Dictionary = Model.roster_model([], 5)
	assert_int(r["members"].size()).is_equal(0)
	assert_int(r["alive_count"]).is_equal(0)
	assert_int(r["dead_count"]).is_equal(0)
	assert_int(r["capacity"]).is_equal(5)
	assert_bool(r["is_full"]).is_false()
	assert_bool(r["wiped"]).is_false()


func test_roster_counts_alive_and_dead() -> void:
	var party := _party(3)
	party.append(_dead("d1"))
	party.append(_dead("d2"))
	var r: Dictionary = Model.roster_model(party, 5)
	assert_int(r["members"].size()).is_equal(5)
	assert_int(r["alive_count"]).is_equal(3)
	assert_int(r["dead_count"]).is_equal(2)
	assert_bool(r["is_full"]).is_false()


func test_roster_member_fields() -> void:
	var r: Dictionary = Model.roster_model([_m("p1", "ranger", "elf", 3, 7000, "READY", 6)], 5)
	var m: Dictionary = r["members"][0]
	assert_str(m["id"]).is_equal("p1")
	assert_str(m["class"]).is_equal("ranger")
	assert_str(m["race"]).is_equal("elf")
	assert_int(m["level"]).is_equal(3)
	assert_int(m["xp"]).is_equal(7000)
	assert_str(m["state"]).is_equal("READY")
	assert_bool(m["is_veteran"]).is_true()


func test_roster_full_at_capacity() -> void:
	var r: Dictionary = Model.roster_model(_party(5), 5)
	assert_bool(r["is_full"]).is_true()
	assert_int(r["alive_count"]).is_equal(5)


func test_roster_not_full_below_capacity() -> void:
	var r: Dictionary = Model.roster_model(_party(4), 5)
	assert_bool(r["is_full"]).is_false()


func test_roster_wiped_all_dead() -> void:
	var party := [_dead("d1"), _dead("d2")]
	var r: Dictionary = Model.roster_model(party, 5)
	assert_bool(r["wiped"]).is_true()
	assert_int(r["alive_count"]).is_equal(0)
	assert_bool(r["is_full"]).is_false()


## === 3.2: «что освободит слот» ===

func test_hint_full_empty_queue_shows() -> void:
	var h: Dictionary = Model.slot_hint(_party(5), 5, 0)
	assert_bool(h["show"]).is_true()
	assert_str(h["kind"]).is_equal(Model.HINT_KIND_FREE_SLOT)
	assert_str(h["link"]).is_equal(Model.HINT_LINK_BATTLE_DEATH)
	assert_str(h["text"]).is_not_empty()


func test_hint_not_full_no_hint() -> void:
	var h: Dictionary = Model.slot_hint(_party(4), 5, 0)
	assert_bool(h["show"]).is_false()
	assert_str(h["kind"]).is_empty()
	assert_str(h["link"]).is_empty()
	assert_str(h["text"]).is_empty()


func test_hint_full_nonempty_queue_no_hint() -> void:
	# Партия полна, но в очереди тренировки кто-то есть → не подсказка,
	# а «тренируется» (визуальный слой).
	var h: Dictionary = Model.slot_hint(_party(5), 5, 1)
	assert_bool(h["show"]).is_false()


func test_hint_dead_do_not_count_toward_full() -> void:
	# 3 живых + 2 мёртвых = 5 всего, но по alive-модели НЕ полна (3 < 5).
	var party := _party(3)
	party.append(_dead("d1"))
	party.append(_dead("d2"))
	var h: Dictionary = Model.slot_hint(party, 5, 0)
	assert_bool(h["show"]).is_false()


func test_hint_negative_queue_treated_empty() -> void:
	var h: Dictionary = Model.slot_hint(_party(5), 5, -1)
	assert_bool(h["show"]).is_true()


func test_hint_zero_capacity_full() -> void:
	# capacity 0 → любая непустая живая партия «полна» (maxi(0,0)=0, alive>=0).
	var h: Dictionary = Model.slot_hint(_party(1), 0, 0)
	assert_bool(h["show"]).is_true()


## === 3.1: build_model (комбинация) ===

func test_build_model_combines_roster_hint_options() -> void:
	var options: Array = [{"class_id": "fighter", "costs": {"food": 20}}]
	var m: Dictionary = Model.build_model(_party(5), 5, 0, options)
	assert_bool(m["roster"]["is_full"]).is_true()
	assert_bool(m["slot_hint"]["show"]).is_true()
	assert_int(m["training_options"].size()).is_equal(1)
	assert_str(m["training_options"][0]["class_id"]).is_equal("fighter")


func test_build_model_defaults() -> void:
	# capacity по умолчанию 5, очередь 0, опции пусты.
	var m: Dictionary = Model.build_model(_party(4))
	assert_int(m["roster"]["capacity"]).is_equal(Model.DEFAULT_CAPACITY)
	assert_bool(m["slot_hint"]["show"]).is_false()
	assert_int(m["training_options"].size()).is_equal(0)


func test_build_model_not_full_passes_options() -> void:
	var options: Array = [{"class_id": "ranger"}]
	var m: Dictionary = Model.build_model(_party(2), 5, 0, options)
	assert_bool(m["slot_hint"]["show"]).is_false()
	assert_int(m["training_options"].size()).is_equal(1)
