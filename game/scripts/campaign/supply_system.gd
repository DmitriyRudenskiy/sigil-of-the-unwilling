class_name SupplySystem
extends RefCounted
## party-characters 3.2 (R7, Q-M75→(б), P-4): снабжение героя — еда в походе.
## Канон: 02-mechanics §3.2; MVP-scope (Снабжение).
##
## Герой носит 10 еды (ёмкость). Расход — 1/персонаж/переход (Q-M75→(б):
## еда тратится в днях переходов, не в городе). Полный (>50% ёмкости) → +2 к
## первому спасброску; голод (0 еды) → −2 к атакам (P-4 РЕШЁН). Штраф голода
## держится до пополнения в городе (resupply).
##
## I1: детерминизм — ни ГСЧ; входы (num_characters, resupply) → байт-идентичный
## результат. Числа — balance-конфиг `campaign.json → supply` (K-M15).

## Бонус к первому спасброску при полном запасе (>50% ёмкости).
const FULL_SAVE_BONUS := 2

var _capacity: int = 10
var _food: int = 10
var _food_per_unit: int = 1
var _starvation_penalty: int = -2


## Инициализация из balance-конфига (campaign.json → supply).
## Дефолты — канон (R7: ёмкость 10; Q-M75→(б): 1/персонаж/переход; P-4: −2).
static func from_config(cfg: Dictionary) -> SupplySystem:
	var s := SupplySystem.new()
	var supply: Dictionary = cfg.get("supply", {}) if cfg is Dictionary else {}
	s._capacity = int(supply.get("hero_capacity_food", 10))
	s._food = s._capacity  # старт с полным запасом
	s._food_per_unit = int(supply.get("food_per_unit_per_day", 1))
	s._starvation_penalty = int(supply.get("starvation_attack_penalty", -2))
	return s


## Ёмкость запаса (10).
func capacity() -> int:
	return _capacity


## Текущий запас еды.
func food() -> int:
	return _food


## Расход на переход: 1 еда/персонаж (Q-M75→(б)). Запас не уходит в минус.
## Возвращает фактический расход.
func consume_for_travel(num_characters: int) -> int:
	var cost := maxi(0, num_characters) * _food_per_unit
	var actual := mini(cost, _food)
	_food -= actual
	return actual


## Пополнение в городе (до ёмкости). Штраф голода снимается.
func resupply() -> void:
	_food = _capacity


## Голод: 0 еды (P-4). Штраф держится до resupply.
func is_hungry() -> bool:
	return _food <= 0


## Полный запас: >50% ёмкости → +2 к первому спасброску.
func is_full() -> bool:
	return _food > _capacity / 2


## Бонус к первому спасброску: +2 если полный, иначе 0.
func first_save_bonus() -> int:
	return FULL_SAVE_BONUS if is_full() else 0


## Штраф к атакам: −2 если голод, иначе 0 (P-4).
func attack_penalty() -> int:
	return _starvation_penalty if is_hungry() else 0


func to_dict() -> Dictionary:
	return {
		"food": _food,
		"capacity": _capacity,
		"food_per_unit": _food_per_unit,
		"starvation_penalty": _starvation_penalty,
	}


static func from_dict(data: Dictionary) -> SupplySystem:
	var s := SupplySystem.new()
	if data.is_empty():
		return s
	s._capacity = int(data.get("capacity", 10))
	s._food = int(data.get("food", s._capacity))
	s._food_per_unit = int(data.get("food_per_unit", 1))
	s._starvation_penalty = int(data.get("starvation_penalty", -2))
	return s
