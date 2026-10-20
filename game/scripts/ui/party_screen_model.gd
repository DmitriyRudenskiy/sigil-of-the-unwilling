class_name PartyScreenModel
extends RefCounted

## mvp-ui-flow 3.1/3.2 (K-M8): слой данных (view model) отдельного экрана партии.
## Чистая логика (без сцены) — визуальный `party_screen.gd` привязывается к
## build_model(); headless-тестируемо (mvp-ui-flow 5.3).
##
## Данные — `party_system.gd` (state.party: [{id, class, race, level, xp,
## stats{}, luck, state?, uid?}]; state = READY/DEAD).
##
## mvp-ui-flow spec «Party screen slot hint»:
##   очередь тренировки пуста и партия полна → «что освободит слот»
##   (ссылка на бой/смерть), не пустота.
##
## Срез MVP: тренировка — immediate (без прогресса/очереди) → длина очереди
## всегда 0; параметр `training_queue_length` оставлен под Post-MVP recruit-SM
## (party-training 2.1), чтобы логика подсказки была корректна и тогда.
##
## Опредение «партия полна»: ЖИВЫХ (state != DEAD) >= capacity. Обоснование:
##   (1) канон-намерение подсказки — слот освобождается смертью в бою (только
##       при alive-подсчёте смерть реально освобождает слот);
##   (2) settlement-потребление уже считает alive (campaign_composition:
##       settlement.party_size = alive_members(party).size()).
## D-221 (V-6, 2026-10-20): несогласованность снята — CampaignTrainingService
##   теперь гейтит по alive_members (DEAD не занимают слот и не блокируют
##   тренировку/рекрутинг), согласовано с alive-моделью экрана и settlement.

## Дефолт = CampaignTrainingService.PARTY_CAPACITY (5).
const DEFAULT_CAPACITY := 5

## Вид подсказки «что освободит слот».
const HINT_KIND_FREE_SLOT := "frees_slot"
## Ссылка подсказки — бой/смерть (визуальный слой превращает в переход/ссылку).
const HINT_LINK_BATTLE_DEATH := "battle/death"
## Текст подсказки (RU; константа — легко поменять на локализацию).
const HINT_TEXT_FREE_SLOT := \
	"Партия полна — слот освободится смертью бойца в бою."


## Партия полна: число живых (state != DEAD) >= capacity.
static func is_full(party: Array, capacity: int) -> bool:
	return PartySystem.alive_members(party).size() >= maxi(capacity, 0)


## 3.1: модель списка партии (roster) + ёмкость. Чистая функция.
static func roster_model(party: Array, capacity: int) -> Dictionary:
	var members: Array = []
	var alive := 0
	var dead := 0
	for member in party:
		if not (member is Dictionary):
			continue
		var state := str(member.get("state", PartySystem.STATE_READY))
		if state == PartySystem.STATE_DEAD:
			dead += 1
		else:
			alive += 1
		members.append({
			"id": str(member.get("id", "")),
			"class": str(member.get("class", "")),
			"race": str(member.get("race", "")),
			"level": int(member.get("level", 1)),
			"xp": int(member.get("xp", 0)),
			"state": state,
			"is_veteran": PartySystem.is_veteran(member),
			"stats": (member.get("stats", {}) as Dictionary).duplicate(),  # 6 атрибутов (str/dex/con/int/wis/cha)
			"luck": int(member.get("luck", 0)),
		})
	return {
		"members": members,
		"alive_count": alive,
		"dead_count": dead,
		"capacity": maxi(capacity, 0),
		"is_full": is_full(party, capacity),
		"wiped": PartySystem.is_wiped(party),
	}


## 3.2: «что освободит слот». Показывается, когда очередь тренировки пуста
## (training_queue_length == 0) и партия полна. Возвращает
## {show, kind, link, text}.
static func slot_hint(party: Array, capacity: int, training_queue_length: int = 0) -> Dictionary:
	var show := is_full(party, capacity) and training_queue_length <= 0
	return {
		"show": show,
		"kind": HINT_KIND_FREE_SLOT if show else "",
		"link": HINT_LINK_BATTLE_DEATH if show else "",
		"text": HINT_TEXT_FREE_SLOT if show else "",
	}


## 3.1: полная модель экрана партии. `training_options` — прокинут из
## CampaignTrainingService.available_training_actions() (визуальный слой);
## здесь не вычисляется (модель чистая, без каталога/ресурсов).
static func build_model(
	party: Array,
	capacity: int = DEFAULT_CAPACITY,
	training_queue_length: int = 0,
	training_options: Array = []
) -> Dictionary:
	return {
		"roster": roster_model(party, capacity),
		"slot_hint": slot_hint(party, capacity, training_queue_length),
		"training_options": training_options,
	}
