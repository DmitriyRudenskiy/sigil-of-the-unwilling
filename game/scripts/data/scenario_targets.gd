class_name ScenarioTargets
extends RefCounted
## autopilot-scenario-matrix (D3): цели ролей — const-таблица.
## Калибровка — правкой этих чисел по отчётам (фаза 5), не кодом.

const ROLES := {
	"collector": {
		"name": "Собиратель",
		"max_turns": 60,
		"rare_ids": [4, 5, 6],  # crystal, gems, gold
		"rare_goal": 10,
	},
	"traveler": {
		"name": "Путешественник",
		"max_turns": 90,
		"distance_goal": 25,
		"biome_goal": 2,
	},
	"trader": {
		"name": "Торговец",
		"max_turns": 90,
		"gold_goal": 1000,
		"gold_start": 100,
	},
	"adventurer": {
		"name": "Приключенец",
		"max_turns": 90,
		"kill_goal": 5,
		"boss_ring": 2,
	},
	"builder": {
		"name": "Городостроитель",
		"max_turns": 90,
		"population_goal": 8,
		"city_level_goal": 2,
		"buildings_goal": 2,
	},
}

const CLASSES := [
	"barbarian", "fighter", "monk", "paladin", "priest",
	"druid", "cipher", "wizard", "ranger", "rogue", "chanter",
]

## Когорта выживания (задача 7.1, `scenario-matrix-behavior-reliability`).
## Это **не шестая роль матрицы**: матрица меряет «класс × роль» и обязана остаться
## 5×11, а когорта меряет один автопилот на фиксированных картах. Поэтому запись
## живёт отдельным константным словарём, а в `ROLES` не входит — `role_ids()`
## по-прежнему отдаёт пять ролей, и `matrix_report.gd` когорту не видит.
##
## seed — литералы, а не `seed_for()`: хеш зависит от списка классов и строгих имён
## ролей, то есть когорта молча пересобралась бы при добавлении класса в `CLASSES`.
## Наборы seed **не перезаписываются**: любое изменение списка = `version + 1` и
## пересъёмка базовой линии когорты, иначе «среднее выживание 55» начинает означать
## разные карты в разных замерах.
## Значения заведомо меньше 1 000 000 — `seed_for()` возвращает hash+1000000, поэтому
## seed когорты не может совпасть с seed профиля матрицы и перепутать два замера.
const SURVIVAL := {
	"version": 1,
	"name": "Когорта выживания",
	"max_turns": 60,
	"seeds": [4211, 907, 13613, 257, 6571, 10007, 1723, 33071, 4517, 20899],
	## Один класс на всю когорту: меняем seed — меняются карта и угрозы, а не сила
	## класса. Иначе «8/10 выжили» нельзя приписать ни карте, ни классу.
	"class": "fighter",
	"survival_goal": 8,
	"average_turns_goal": 55,
}

static func role_ids() -> Array:
	return (ROLES as Dictionary).keys()

## Роль по id; когорта выживания обслуживается тем же интерфейсом цели/метрик,
## поэтому отдаёт свою запись отсюда же, не входя в `ROLES` (см. SURVIVAL).
static func role(id: String) -> Dictionary:
	if id == "survival":
		return (SURVIVAL as Dictionary)
	return (ROLES as Dictionary).get(id, {})

static func survival_seeds() -> Array:
	return (SURVIVAL as Dictionary).get("seeds", [])

static func survival_turns() -> int:
	return int((SURVIVAL as Dictionary).get("max_turns", 60))

static func survival_class() -> String:
	return str((SURVIVAL as Dictionary).get("class", "fighter"))

static func max_turns(id: String) -> int:
	return int((ROLES as Dictionary).get(id, {}).get("max_turns", 60))

## seed = f(класс, роль): разные клетки матрицы — разные карты (design, open Q).
static func seed_for(class_id: String, role_id: String) -> int:
	var key := "%s|%s" % [class_id, role_id]
	var h := 1469598103
	for i in key.length():
		h = (h ^ key.unicode_at(i)) * 947 % 2147483647
	return int(h) + 1000000
