extends BaseTest

## mvp-ui-flow 3.1: PartyScreen — технический экран партии (headless).
## Данные — PartyScreenModel; обновление явное (refresh); структура
## детерминирована (Root/Header/Slot<i>/EmptySlot<i>/SlotHint).
## Визуальная раскладка — ui-mockup-parity (зона владельца), здесь — данные.

const Screen = preload("res://scripts/ui/party_screen.gd")

var screen: Screen


func _member(id: String, extra: Dictionary = {}) -> Dictionary:
	var m := {
		"id": id,
		"class": "fighter",
		"race": "human",
		"level": 2,
		"xp": 1200,
		"stats": {"str": 15, "dex": 12, "con": 14, "int": 10, "wis": 11, "cha": 9},
		"luck": 1,
		"state": "READY",
	}
	m.merge(extra)
	return m


func _party(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(_member("p%d" % i))
	return out


func before_test() -> void:
	screen = Screen.new()
	add_child(screen)


func after_test() -> void:
	screen.queue_free()
	screen = null


# --- базовое состояние ---

func test_initial_no_slots_until_refresh() -> void:
	assert_bool(screen.has_node("Root")).is_true()
	assert_int(screen.get_slot_count()).is_equal(0)
	assert_str(screen.get_header_text()).is_equal("Партия: 0/0")


# --- roster: 5 слотов, пустые слоты ---

func test_full_party_5_slots() -> void:
	screen.refresh(_party(5))
	assert_str(screen.get_header_text()).is_equal("Партия: 5/5")
	assert_int(screen.get_slot_count()).is_equal(5)
	for i in range(5):
		assert_bool(screen.has_node("Root/Slot%d" % i)).is_true()
		assert_bool(screen.has_node("Root/EmptySlot%d" % i)).is_false()


func test_partial_party_empty_slots() -> void:
	screen.refresh(_party(2))
	assert_str(screen.get_header_text()).is_equal("Партия: 2/5")
	assert_bool(screen.has_node("Root/Slot0")).is_true()
	assert_bool(screen.has_node("Root/Slot1")).is_true()
	assert_bool(screen.has_node("Root/EmptySlot2")).is_true()
	assert_bool(screen.has_node("Root/EmptySlot3")).is_true()
	assert_bool(screen.has_node("Root/EmptySlot4")).is_true()
	assert_bool(screen.has_node("Root/Slot2")).is_false()


func test_empty_party_all_empty() -> void:
	screen.refresh([])
	assert_str(screen.get_header_text()).is_equal("Партия: 0/5")
	for i in range(5):
		assert_bool(screen.has_node("Root/EmptySlot%d" % i)).is_true()


# --- содержимое строки бойца: статы, Удача, уровень/XP, ветеран ---

func test_member_row_content() -> void:
	screen.refresh(_party(1))
	var line1: Label = screen.get_node("Root/Slot0/Box/Line1")
	assert_str(line1.text).contains("p0")
	assert_str(line1.text).contains("fighter")
	assert_str(line1.text).contains("human")
	assert_str(line1.text).contains("ур. 2")
	var line2: Label = screen.get_node("Root/Slot0/Box/Line2")
	assert_str(line2.text).contains("XP 1200")
	assert_str(line2.text).contains("str 15")
	assert_str(line2.text).contains("cha 9")
	assert_str(line2.text).contains("Удача 1")
	assert_str(line2.text).not_contains("Ветеран")


func test_veteran_marked() -> void:
	screen.refresh([_member("vet", {"battles_survived": 5})])
	var line2: Label = screen.get_node("Root/Slot0/Box/Line2")
	assert_str(line2.text).contains("Ветеран")


# --- состояния: READY / WOUNDED / UNSTABLE / DEAD ---

func test_dead_member_tagged_and_not_counted() -> void:
	var party := _party(5)
	party[3]["state"] = "DEAD"
	screen.refresh(party)
	assert_str(screen.get_header_text()).is_equal("Партия: 4/5")  # alive-подсчёт
	var line1: Label = screen.get_node("Root/Slot3/Box/Line1")
	assert_str(line1.text).contains("МЁРТВ")
	var line1_alive: Label = screen.get_node("Root/Slot0/Box/Line1")
	assert_str(line1_alive.text).not_contains("МЁРТВ")


func test_in_battle_states_rendered() -> void:
	var party := _party(2)
	party[0]["state"] = "WOUNDED"
	party[1]["state"] = "UNSTABLE"
	screen.refresh(party)
	assert_str(screen.get_header_text()).is_equal("Партия: 2/5")  # не DEAD → alive
	var l0: Label = screen.get_node("Root/Slot0/Box/Line1")
	assert_str(l0.text).not_contains("МЁРТВ")


# --- подсказка 3.2 «что освободит слот» ---

func test_slot_hint_when_full() -> void:
	screen.refresh(_party(5))
	assert_bool(screen.get_hint_visible()).is_true()
	assert_str(screen.get_hint_text()).contains("освободится")
	var hint: Label = screen.get_node("Root/SlotHint")
	assert_bool(hint.visible).is_true()


func test_slot_hint_hidden_when_not_full() -> void:
	screen.refresh(_party(4))
	assert_bool(screen.get_hint_visible()).is_false()
	var hint: Label = screen.get_node("Root/SlotHint")
	assert_bool(hint.visible).is_false()


# --- инвариант: не больше capacity слотов ---

func test_party_over_capacity_capped() -> void:
	# невалидное состояние (6 > 5) — экран не ломается, показывает capacity
	screen.refresh(_party(6))
	assert_int(screen.get_slot_count()).is_equal(5)
	assert_bool(screen.has_node("Root/Slot4")).is_true()
	assert_bool(screen.has_node("Root/Slot5")).is_false()


# --- обновление и сигнал ---

func test_screen_updated_signal() -> void:
	var seen: Array = []
	screen.screen_updated.connect(func(m: Dictionary) -> void: seen.append(m))
	screen.refresh(_party(3))
	assert_int(seen.size()).is_equal(1)
	assert_int(seen[0]["roster"]["alive_count"]).is_equal(3)


func test_refresh_rebuilds_deterministically() -> void:
	screen.refresh(_party(4))
	var header1: String = screen.get_header_text()
	var hint1: bool = screen.get_hint_visible()
	var l1: String = (screen.get_node("Root/Slot0/Box/Line1") as Label).text
	screen.refresh(_party(4))  # те же входы → тот же вывод
	assert_str(screen.get_header_text()).is_equal(header1)
	assert_bool(screen.get_hint_visible()).is_equal(hint1)
	var l2: String = (screen.get_node("Root/Slot0/Box/Line1") as Label).text
	assert_str(l2).is_equal(l1)
	# rebuild не копится: ровно capacity слотов + hint
	var panels: int = 0
	for i in range(5):
		if screen.has_node("Root/Slot%d" % i) or screen.has_node("Root/EmptySlot%d" % i):
			panels += 1
	assert_int(panels).is_equal(5)
