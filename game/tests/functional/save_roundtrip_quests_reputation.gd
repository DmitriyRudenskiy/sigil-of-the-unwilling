extends BaseTest
## save-load-coverage-expansion 3.3: прогресс квестов и репутация фракций
## (HeroStatsComponent.quest_state / faction_rep / rep_history) roundtrip.
## Состояние живёт в hero-компоненте → сериализуется через hero.serialize().

const _HeroStats = preload("res://scripts/entities/hero/components/hero_stats_component.gd")
const _QuestSystem = preload("res://scripts/systems/quest_system.gd")
const _FactionRep = preload("res://scripts/systems/faction_reputation.gd")


func _make_component() -> HeroStatsComponent:
	var c: HeroStatsComponent = auto_free(_HeroStats.new())
	var p := HeroBuildProfile.new()
	p.name = "TestHero"
	p.race = "human"
	p.character_class = "warrior"
	p.culture = "northern"
	p.background = "soldier"
	c.apply_build(p)
	return c


func test_quest_progress_roundtrip() -> void:
	var c := _make_component()
	# Сгенерируем квесты и продвинем прогресс
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_QuestSystem.generate_quests(c.quest_state, "orlan", 1, rng, 3)
	assert_bool(c.quest_state["active"].size() > 0).is_true()
	var first_id: String = str((c.quest_state["active"].keys() as Array)[0])
	_QuestSystem.add_progress(c.quest_state, first_id, 2)
	var progress_before: int = int(c.quest_state["active"][first_id]["progress"])

	var dict := c.serialize()
	var c2: HeroStatsComponent = auto_free(_HeroStats.new())
	c2.deserialize(dict)

	assert_that(c2.quest_state["active"].size()).is_equal(c.quest_state["active"].size())
	assert_that(int(c2.quest_state["active"][first_id]["progress"])).is_equal(progress_before)
	assert_that(int(c2.quest_state["next_id"])).is_equal(int(c.quest_state["next_id"]))


func test_completed_quest_stays_completed() -> void:
	var c := _make_component()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_QuestSystem.generate_quests(c.quest_state, "godlike", 2, rng, 1)
	var qid: String = str((c.quest_state["active"].keys() as Array)[0])
	var q: Dictionary = c.quest_state["active"][qid]
	# Доводим до выполнения и сдаём (награда + перенос в completed)
	var needed: int = int(q.get("target_count", 1))
	assert_that(_QuestSystem.add_progress(c.quest_state, qid, needed)).is_true()
	var done: Dictionary = _QuestSystem.complete_quest(c.quest_state, qid, c.faction_rep, "human")
	assert_bool(done.is_empty() == false).is_true()
	assert_bool(c.quest_state["completed"].has(qid)).is_true()

	var dict := c.serialize()
	var c2: HeroStatsComponent = auto_free(_HeroStats.new())
	c2.deserialize(dict)
	assert_bool(c2.quest_state["completed"].has(qid)).is_true()
	assert_bool(not c2.quest_state["active"].has(qid)).is_true()


func test_faction_reputation_roundtrip() -> void:
	var c := _make_component()
	# Начальная репутация (раса +10, класс +5)
	assert_bool(c.faction_rep.size() > 0).is_true()
	_FactionRep.apply(c.faction_rep, "orlan", 15, "human")
	_FactionRep.apply(c.faction_rep, "godlike", -20, "human")
	_FactionRep.log(c.rep_history, "orlan", 15, "quest_reward")
	var rep_before: int = int(c.faction_rep.get("orlan", 0))
	var history_before: int = c.rep_history.size()

	var dict := c.serialize()
	var c2: HeroStatsComponent = auto_free(_HeroStats.new())
	c2.deserialize(dict)

	assert_that(int(c2.faction_rep.get("orlan", 0))).is_equal(rep_before)
	assert_that(int(c2.faction_rep.get("godlike", 0))).is_equal(int(c.faction_rep.get("godlike", 0)))
	assert_that(c2.rep_history.size()).is_equal(history_before)


func test_legacy_save_without_quest_state() -> void:
	# Сейв до quests-reputation-system: ключей нет — компонент сохраняет
	# текущее (пустое) состояние, не падая.
	var c := _make_component()
	var dict := c.serialize()
	dict.erase("quest_state")
	dict.erase("faction_rep")
	dict.erase("rep_history")

	var c2: HeroStatsComponent = auto_free(_HeroStats.new())
	c2.deserialize(dict)
	assert_bool(c2 != null).is_true()
	assert_bool(c2.quest_state is Dictionary).is_true()
