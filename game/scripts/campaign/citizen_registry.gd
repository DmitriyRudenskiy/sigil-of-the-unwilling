class_name CitizenRegistry
extends RefCounted
## T-116 (старт, раунд 8 §4.4): модель населения — жители (uid, возраст, семья).
##
## - Возраст: age_days; 1 ход = days_per_turn дней — инъект из
##   WorldSeasons.DAYS_PER_SEASON (Q-M26: единственная конверсия день↔ход,
##   независимые день-константы запрещены).
## - Рождения (K-M12-схема): n = int(k_pop_per_day × days_per_turn);
##   MVP: все m = 1. k_pop — population.json (баланс-конфиг, K-M12: 0.1/день).
## - Семьи: family_id. Инициал — каждый житель в своей семье (MVP-упрощение;
##   образование семей парами — post-MVP). Новорождённые — в семью-основатель
##   (family_0; 02f-a-core: «Рождается ребёнок — первый уроженец Очага»).
## - T-050 шов: apply_losses(uids) — вычитание жителей по character_uid;
##   раненые НЕ потери (CampaignBattle._finalize: losses — только dead;
##   стабилизированный — ранен, в losses не попадает). Чужой uid — не житель
##   (игнорируется, не ошибка).
## - Миграция (F-3): apply_migration(reputation) — Репутация ЕДИНСТВЕННЫЙ
##   вход (Э1-3: Престиж никогда не влияет на миграцию — в сигнатуре нет
##   prestige; «appeal» удалён из живого слоя). MVP — no-op: формула — Q-M32
##   (TBD, к владельцу; числа — только в баланс-списке).
## - Сериализация: to_dict/from_dict (I1: стабильный порядок — citizens по
##   возрастанию uid; next_uid/next_family — непрерывность после restore).
##
## I1: детерминизм — без ГСЧ, стабильный порядок, без глобальных чтений.

const SCHEMA_VERSION := 1
const CONFIG_PATH := "res://data/config/balance/population.json"

## Жители: [{uid: int, age_days: float, family_id: String}] — по возрастанию uid.
var citizens: Array = []
var _next_uid: int = 0
var _next_family: int = 0
var _event_log: Array[String] = []


## Чтение balance-конфига (D-161: перед созданием/перезаписью — проверка
## существования и чтение текущей версии; здесь — только чтение).
static func load_config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


## Детерминированная инициализация: uids 0..count−1, возраст 0, каждый — в
## своей семье (MVP-упрощение, см. шапку).
func create_initial(count: int) -> void:
	citizens = []
	_next_uid = 0
	_next_family = 0
	for i in count:
		_add_citizen(0.0, true)  # каждый инициал-житель — в своей семье
	_log("init: %d жителей" % count)


func count() -> int:
	return citizens.size()


## Житель по uid ({} — не житель).
func citizen(uid: int) -> Dictionary:
	for c in citizens:
		if int(c["uid"]) == uid:
			return c
	return {}


func has(uid: int) -> bool:
	return not citizen(uid).is_empty()


## Возраст: 1 ход = days_per_turn дней (Q-M26: инъект из WorldSeasons.
## DAYS_PER_SEASON — единственная конверсия).
func age_turn(days_per_turn: int) -> void:
	for c in citizens:
		c["age_days"] = float(c["age_days"]) + float(days_per_turn)


## Рождения (K-M12-схема): n = int(k_pop_per_day × days_per_turn); MVP: m = 1.
## Новорождённые: возраст 0, семья-основатель (family_0). Возвращает число.
func births(k_pop_per_day: float, days_per_turn: int) -> int:
	var n := int(k_pop_per_day * float(days_per_turn))
	for i in n:
		_add_citizen(0.0, false)  # новорождённые — в семью-основатель
	if n > 0:
		_log("births: %d" % n)
	return n


## R3-кап (применяется в settlement-фазе, T-122): избыток — ПОСЛЕДНИЕ
## добавленные жители (детерминированно, I1). Возвращает число вычтенных.
func clamp_to(cap: int) -> int:
	var excess := citizens.size() - cap
	if excess <= 0:
		return 0
	for i in excess:
		citizens.pop_back()
	_log("cap: −%d (cap %d)" % [excess, cap])
	return excess


## T-050 шов: потери — вычитание жителей по character_uid. Раненые — не
## потери (CampaignBattle: losses — только dead; стабилизированный — ранен,
## в losses не попадает). Чужой uid — не житель (игнорируется).
func apply_losses(uids: Array) -> int:
	var removed := 0
	for uid in uids:
		if remove(int(uid)):
			removed += 1
	if removed > 0:
		_log("losses: −%d (%s)" % [removed, str(uids)])
	return removed


func remove(uid: int) -> bool:
	for i in citizens.size():
		if int(citizens[i]["uid"]) == uid:
			citizens.remove_at(i)
			return true
	return false


## Миграция (F-3): Репутация — единственный вход (Э1-3: Престиж никогда не
## влияет на миграцию — в сигнатуре нет prestige). MVP — no-op (Q-M32:
## формула TBD; предложение — пороговая +1/−1/0, числа — в баланс-список).
## Возвращает net-изменение (MVP: 0).
func apply_migration(reputation: float) -> int:
	# Q-M32: формула TBD, к владельцу. Seam готов: репутация-вход, Э1-3.
	return 0


## Семьи (стабильный порядок — порядок первого жителя, I1).
func families() -> Array:
	var out: Array = []
	for c in citizens:
		if not out.has(c["family_id"]):
			out.append(c["family_id"])
	return out


func _add_citizen(age_days: float, own_family: bool) -> Dictionary:
	var family := "family_%d" % _next_family
	_next_family += 1
	if not own_family and not citizens.is_empty():
		# Новорождённые — в семью-основатель (family_0; 02f-a-core: «первый
		# уроженец Очага»); инициал-жители — свои семьи (create_initial).
		family = str(citizens[0]["family_id"])
	var c := {"uid": _next_uid, "age_days": float(age_days), "family_id": family}
	_next_uid += 1
	citizens.append(c)
	return c


func event_log() -> Array[String]:
	return _event_log.duplicate()


func _log(msg: String) -> void:
	_event_log.append(msg)


## Сериализация (I1: citizens — по возрастанию uid; next_uid/next_family —
## непрерывность uid/семей после restore).
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"citizens": citizens.duplicate(true),
		"next_uid": _next_uid,
		"next_family": _next_family,
	}


static func from_dict(data: Dictionary) -> CitizenRegistry:
	var r := CitizenRegistry.new()
	r.citizens = (data.get("citizens", []) as Array).duplicate(true)
	r._next_uid = int(data.get("next_uid", 0))
	r._next_family = int(data.get("next_family", 0))
	return r
