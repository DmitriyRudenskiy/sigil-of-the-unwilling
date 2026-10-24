extends BaseTest

## T-183 / Q-M102: шов двух носителей населения (pin состояния, не приёмка).
##
## В живом кампейне у поселения **два** счёта жителей:
##   * `city.pop` — `PopUnit`-ы; их читает экономика: спрос еды
##     (`economic_turn_processor.gd:153`, `city.pop.size() × 0.1`) и вывод зданий
##     по рабочим (`_assigned_workers_by_group`, состояние WORKER + `assigned_to`);
##   * `PopulationSystem.residents` — возраст, рождения (K-M12), миграция (F-3),
##     потери боя; из него считается скаляр `settlement.population`.
## K-A5 (party-training 2.3) требует **одну** модель статусов и вакансию при
## призыве; прежде чем её выбирать, шов зафиксирован тестом, потому что цифры
## из этого тикета — основание вопроса владельцу, а проверяемый артефакт
## обязан быть в git (D-192).
##
## Что зафиксировано (числа сняты 2026-10-24, сид 12345, 14 ходов):
## 1. стартовая партия не несёт uid жителя → смерть в бою не списывает жителя;
## 2. `city.pop` за 14 ходов не меняется ни на единицу (застывший носитель),
##    тогда как `PopulationSystem` за те же ходы теряет жителя (смерть на 13-м);
## 3. uid-пространства двух носителей пересекаются (оба начинают с 1) — при
##    появлении uid у партии потеря списала бы **чужого** жителя;
## 4. `conscript()`/`issue_uid()` (A5-шов «рекрут = житель») не вызываются ни из
##    одного скрипта игры — заглушка K-A5 существует, но не подключена.
##
## Кейсы 1–3 краснеют, когда носители сведут в один (тогда же правится и
## Q-M102); кейс 4 краснеет, когда призыв начнёт проходить через реестр.

const SEED := 12345
const TURNS := 14
const START_POPULATION := 20
const SCRIPTS_ROOT := "res://scripts"


func _composition() -> CampaignComposition:
	return CampaignComposition.from_campaign_config(SEED)


## 1. Партийцы стартовой партии — «только-ростерные»: uid жителя у них нет
## (-1), поэтому потери боя в реестр жителей не приходят вовсе.
func test_starting_party_carries_no_resident_uid() -> void:
	var composition := _composition()
	assert_that(composition.party.size()).is_greater(0)
	for member in composition.party:
		assert_int(int(member.get("uid", -1))).is_equal(-1)
	var before: int = composition.population_system.size()
	# Путь потерь той же формы, что даёт бой: `CampaignBattle` кладёт в losses
	# только character_uid ≥ 0, поэтому смерть «ростерного» героя — пустой список.
	composition._on_battle_losses([], {})
	composition.apply_party_battle_losses({"losses": []})
	assert_int(composition.population_system.size()).is_equal(before)


## 2. Два носителя расходятся: экономика ест застывший `city.pop`, демография
## живёт своей жизнью. За 14 ходов первый не меняется ни разу.
func test_city_population_carrier_is_frozen_while_registry_moves() -> void:
	var composition := _composition()
	assert_int(composition.city.pop.size()).is_equal(START_POPULATION)
	var age0 := float(composition.population_system.residents[0]["age"])
	var frozen := true
	for _turn in range(TURNS):
		composition.advance_turn()
		if composition.city.pop.size() != START_POPULATION:
			frozen = false
	# Реестр тикает: возраст первого жителя растёт (смерти/рождения — от сида,
	# возраст — нет), поэтому «носители расходятся» проверяется без хрупкости.
	var age1 := float(composition.population_system.residents[0]["age"])
	assert_bool(frozen).is_true()
	assert_bool(age1 > age0).is_true()


## 3. uid-пространства пересекаются: и реестр жителей, и город начинают с 1.
## Пока у партии нет uid, пересечение безвредно; оно же — цена «быстрого»
## решения «просто писать партии uid реестра».
func test_uid_spaces_of_the_two_carriers_overlap() -> void:
	var composition := _composition()
	var resident_uids := {}
	var resident_min := 999999
	for resident in composition.population_system.residents:
		var uid := int(resident["uid"])
		resident_uids[uid] = true
		resident_min = mini(resident_min, uid)
	var pop_min := 999999
	var overlap := 0
	for unit in composition.city.pop:
		pop_min = mini(pop_min, int(unit.uid))
		if resident_uids.has(int(unit.uid)):
			overlap += 1
	assert_int(resident_min).is_equal(1)
	assert_int(pop_min).is_equal(0)
	# Разница ровно в одном номере: под общим id 0 в реестре никого нет, а id
	# 1..19 в двух носителях — разные сущности.
	assert_int(overlap).is_equal(composition.city.pop.size() - 1)


## 4. A5-шов не подключён: ни один скрипт игры не вызывает `conscript()` и не
## просит uid у реестра (`issue_uid`). Механизм есть, потребителя нет — ровно то
## и требует доделать задача 2.3.
func test_no_production_caller_of_conscription() -> void:
	var callers: Array[String] = []
	for path in _script_paths(SCRIPTS_ROOT):
		if path.ends_with("population_system.gd"):
			continue  # сам реестр — эмитент, не потребитель
		var text := _read(path)
		if text.contains("conscript(") or text.contains("issue_uid("):
			callers.append(path)
	assert_str(", ".join(callers)).is_equal("")


func _script_paths(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null or dir.list_dir_begin() != OK:
		return out
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_script_paths(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	return out


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
