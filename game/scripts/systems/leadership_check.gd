class_name LeadershipCheck
extends RefCounted

const GameNumbers = preload("res://scripts/constants/game_numbers.gd")
## social-stats-weapon-tech D3: харизма — население и отряд.
## Таблицы в GameNumbers.SOCIAL_CHA_TABLES, сложности найма — GameNumbers.RECRUIT_DC.

static func _idx(cha: int) -> int:
	var arr: Array = GameNumbers.SOCIAL_CHA_TABLES["immigration"]
	return clampi(cha - 1, 0, arr.size() - 1)

## Множитель иммиграции (−50%…+50%)
static func immigration_modifier(cha: int) -> float:
	return float(GameNumbers.SOCIAL_CHA_TABLES["immigration"][_idx(cha)])

## Cap стеков армии героя (1…7), минимум 3 (задача 3.3)
static func max_army_stacks(cha: int) -> int:
	return maxi(3, int(GameNumbers.SOCIAL_CHA_TABLES["max_stacks"][_idx(cha)]))

## Множитель качества найма (0.8…1.25)
static func recruit_quality(cha: int) -> float:
	return float(GameNumbers.SOCIAL_CHA_TABLES["recruit_quality"][_idx(cha)])

## d20-проверка найма.
## difficulty — ключ в RECRUIT_DC ("desperate"…"champion").
## rep — репутация города (±3 к броску), offers — свободные вакансии (до +3).
## Возвращает: {outcome: "success"|"rumor"|"refused"|"critical", d20, total, dc, rep_delta}
static func recruit_check(rng: RandomNumberGenerator, cha: int, rep: int,
		offers: int, difficulty: String) -> Dictionary:
	var dc: int = int(GameNumbers.RECRUIT_DC.get(difficulty, 10))
	var d20: int = rng.randi_range(1, 20)
	var rep_bonus: int = clampi(int(roundf(float(rep) / 10.0)), -3, 3)
	var total: int = d20 + maxi(cha - 10, 0) + rep_bonus + mini(offers, 3)
	var out := {"outcome": "success", "d20": d20, "total": total, "dc": dc, "rep_delta": 0}
	if d20 == 1:
		out["outcome"] = "critical"
		out["rep_delta"] = -10
	elif d20 == 20:
		pass  # успех, качество по таблице
	elif total < dc:
		if total >= dc - 4:
			out["outcome"] = "rumor"  # слухи: репутация −5
			out["rep_delta"] = -5
		else:
			out["outcome"] = "refused"
	return out
