class_name DeceptionCheck
extends RefCounted

const GameNumbers = preload("res://scripts/constants/GameNumbers.gd")
## social-stats-weapon-tech D2: проверка обмана в важных городских сделках.
## Статик-модуль как LoadCalculator: один источник правил, все броски через rng.
##
## шанс = clamp(base + (10 - int) * 4 - max(wis, cha, luk, по 10) * 2, 5, 85)

static func chance(int_: int, wis: int, cha: int, luk: int, base_pct: int) -> int:
	var comp: int = max(maxi(wis - 10, 0), max(cha - 10, luk - 10, 0))
	var raw: int = base_pct + (10 - int_) * 4 - comp * 2
	return clampi(raw, GameNumbers.DECEPTION_MIN_PCT, GameNumbers.DECEPTION_MAX_PCT)

## Полный бросок сделки.
## rng — управляемый RandomNumberGenerator (детерминизм по seed).
## trap_dc — d20-сложность ловушки (GameNumbers.DECEPTION_TRAP_DC).
## Возвращает: {deceived, severity (index в DECEPTION_SEVERITIES), note, discount, revealed}
static func roll(rng: RandomNumberGenerator, int_: int, wis: int, cha: int, luk: int,
		base_pct: int, trap_dc: int = 10) -> Dictionary:
	var pct: int = chance(int_, wis, cha, luk, base_pct)

	# мудрость: шанс заранее заметить подвох -> отказ без потерь или -1 ступень
	var wis_notice: bool = rng.randi_range(1, 100) <= maxi((wis - 10), 0) * 5
	# удача: шанс полностью избежать обмана / случайно раскрыть мошенника
	var luk_save: bool = rng.randi_range(1, 100) <= maxi((luk - 10), 0) * 5
	# харизма: честная цена (скидка) — давя авторитетом
	var discount: float = 0.1 if cha >= 14 else (0.05 if cha >= 12 else 0.0)

	var cheated_roll: int = rng.randi_range(1, 100)
	var d20: int = rng.randi_range(1, 20)
	var margin: int = d20 + maxi(int_ - 10, 0) + maxi(wis - 10, 0) + maxi(luk - 10, 0) - trap_dc

	var out := {
		"deceived": false, "severity": 0, "note": "", "discount": discount,
		"revealed": false, "chance": pct, "d20": d20,
	}
	if cheated_roll < pct:
		# удача спасает: обман не случился или мошенник раскрыт (выгода)
		if luk_save:
			out["revealed"] = true
			out["note"] = "Мошенник раскрыт — вы вышли в плюс."
			return out
		if wis_notice:
			out["deceived"] = true
			out["severity"] = 1  # минимальная ступень: мудрость смягчила исход
			out["note"] = "Вы заметили подвох в последний момент."
			return out
		# степень по magnitude d20-провала: -2+ medium, -5+ severe, -10+ critical
		var sev: int = 1
		if margin <= -GameNumbers.DECEPTION_CRITICAL_MARGIN:
			sev = 3
		elif margin <= -10:
			sev = 4
		elif margin <= -2:
			sev = 2
		out["deceived"] = true
		out["severity"] = sev
		out["note"] = _severity_note(sev)
	return out

static func severity_label(severity: int) -> String:
	var arr: Array = GameNumbers.DECEPTION_SEVERITIES
	if severity < 0 or severity >= arr.size():
		return ""
	return str(arr[severity].get("desc", ""))

static func _severity_note(sev: int) -> String:
	match sev:
		1: return "Обманули: переплатили."
		2: return "Товар оказался низкокачественным."
		3: return "Кабальные условия: долг/штраф."
		4: return "Ловушка: кража или репутационный ущерб."
	return ""
