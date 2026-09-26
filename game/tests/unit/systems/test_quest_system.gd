extends BaseTest

const QuestSystem = preload("res://scripts/systems/quest_system.gd")
const QuestTemplates = preload("res://scripts/data/quest_templates.gd")
const FactionReputation = preload("res://scripts/systems/faction_reputation.gd")

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 42

func test_generate_respects_count_and_no_duplicates() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var quests: Array = QuestSystem.generate_quests(state, "human", 1, rng, 3)
	assert_that(quests.size() <= 3)
	assert_that(quests.size() > 0)
	assert_that(int(state["active"].size()) == quests.size())
	# Нет дублей type+target
	var seen := {}
	for q in quests:
		var key: String = str(q["type"]) + ":" + str(q["target"])
		assert_bool(not seen.has(key)).override_failure_message("duplicate: " + key)
		seen[key] = true

func test_generate_ring_limits() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var quests: Array = QuestSystem.generate_quests(state, "elf", 3, rng, 1)
	assert_that(quests.size() == 1)
	assert_that(int(quests[0]["ring"]) == 3)
	assert_that(int(quests[0]["reward"]["reputation"]) == 30)

func test_kill_progress_and_complete() -> void:
	var state: Dictionary = QuestSystem.new_state()
	# Фиксированный kill-квест
	var q: Dictionary = QuestTemplates.generate("q1", "human", 1, rng)
	q["type"] = "kill"
	q["target"] = "wolf"
	q["target_count"] = 3
	q["progress"] = 0
	q["starts_day"] = 1
	state["active"]["q1"] = q
	assert_bool(QuestSystem.add_progress(state, "q1", 1) == false)
	assert_bool(QuestSystem.add_progress(state, "q1", 1) == false)
	assert_bool(QuestSystem.add_progress(state, "q1", 1) == true)
	assert_that(int(state["active"]["q1"]["progress"]) == 3)
	# Сдача
	var rep := FactionReputation.initial_state("human", "fighter")
	var res: Dictionary = QuestSystem.complete_quest(state, "q1", rep, "human")
	assert_bool(not res.is_empty())
	assert_that(int(res["reward"]["gold"]) >= 15)
	assert_bool(not state["active"].has("q1"))
	assert_bool(state["completed"].has("q1"))
	# Репутация выросла
	assert_that(int(rep["human"]) > 0)

func test_complete_requires_progress() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var q: Dictionary = QuestTemplates.generate("q1", "human", 1, rng)
	q["target_count"] = 5
	q["progress"] = 2
	state["active"]["q1"] = q
	var res: Dictionary = QuestSystem.complete_quest(state, "q1")
	assert_bool(res.is_empty())
	assert_bool(state["active"].has("q1"))

func test_gather_progress_capped_at_target() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var q: Dictionary = QuestTemplates.generate("q1", "elf", 1, rng)
	q["type"] = "gather"
	q["target"] = "herb"
	q["target_count"] = 2
	q["progress"] = 0
	state["active"]["q1"] = q
	QuestSystem.add_progress(state, "q1", 10)
	assert_that(int(state["active"]["q1"]["progress"]) == 2)

func test_fail_timeout_penalty() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var q: Dictionary = QuestTemplates.generate("q1", "dwarf", 1, rng)
	q["deadline"] = 5
	q["starts_day"] = 1
	state["active"]["q1"] = q
	var rep := FactionReputation.initial_state("dwarf", "fighter")
	var res: Dictionary = QuestSystem.fail_quest(state, "q1", "timeout", rep, "dwarf")
	assert_that(int(res["penalty"]) == -10)
	assert_bool(state["failed"].has("q1"))
	assert_that(int(rep["dwarf"]) < 10)

func test_fail_escort_dead_penalty() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var q: Dictionary = QuestTemplates.generate("q1", "aumaua", 1, rng)
	q["deadline"] = 5
	q["starts_day"] = 1
	state["active"]["q1"] = q
	var rep := FactionReputation.initial_state("aumaua", "fighter")
	var res: Dictionary = QuestSystem.fail_quest(state, "q1", "escort_dead", rep, "aumaua")
	assert_that(int(res["penalty"]) == -20)

func test_check_deadlines() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var q1: Dictionary = QuestTemplates.generate("q1", "human", 1, rng)
	q1["deadline"] = 5
	q1["starts_day"] = 1
	state["active"]["q1"] = q1
	var q2: Dictionary = QuestTemplates.generate("q2", "human", 1, rng)
	q2["type"] = "gather"
	q2["target"] = "wood"
	q2["deadline"] = 5
	q2["starts_day"] = 1
	state["active"]["q2"] = q2
	# День 6: оба должны провалиться
	var failed: Array = QuestSystem.check_deadlines(state, 6)
	assert_that(failed.size() == 2)
	assert_bool(state["active"].is_empty())
	assert_that(state["failed"].size() == 2)
	# День 3: не проваливаются
	var state2: Dictionary = QuestSystem.new_state()
	var q3: Dictionary = QuestTemplates.generate("q1", "human", 1, rng)
	q3["deadline"] = 5
	q3["starts_day"] = 1
	state2["active"]["q1"] = q3
	var failed2: Array = QuestSystem.check_deadlines(state2, 3)
	assert_that(failed2.size() == 0)

func test_chain_link_and_complete_opens_next() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var qa: Dictionary = QuestTemplates.generate("q1", "elf", 1, rng)
	qa["target_count"] = 1
	qa["progress"] = 0
	state["active"]["q1"] = qa
	var qb: Dictionary = QuestTemplates.generate("q2", "elf", 1, rng)
	qb["type"] = "gather"
	qb["target"] = "quartz"
	qb["target_count"] = 1
	qb["progress"] = 0
	state["active"]["q2"] = qb
	QuestSystem.link_chain(state, "q1", "q2")
	assert_that(str(state["active"]["q1"]["next_quest_id"]) == "q2")
	QuestSystem.add_progress(state, "q1", 1)
	var res: Dictionary = QuestSystem.complete_quest(state, "q1")
	assert_that(str(res["next_quest_id"]) == "q2")

func test_journal_format() -> void:
	var state: Dictionary = QuestSystem.new_state()
	var q: Dictionary = QuestTemplates.generate("q1", "human", 2, rng)
	q["progress"] = 2
	q["starts_day"] = 1
	state["active"]["q1"] = q
	var j: Array = QuestSystem.journal(state)
	assert_that(j.size() == 1)
	assert_that(int(j[0]["progress"]) == 2)
	assert_that(str(j[0]["faction"]) == "human")
	assert_that(int(j[0]["target"]) >= 1)

func test_serialization_roundtrip() -> void:
	var state: Dictionary = QuestSystem.new_state()
	QuestSystem.generate_quests(state, "dwarf", 1, rng, 2)
	var saved: String = JSON.stringify(state)
	var loaded: Variant = JSON.parse_string(saved)
	assert_that(loaded is Dictionary)
	assert_that(int((loaded as Dictionary)["active"].size()) == int(state["active"].size()))
