class_name EthicsSystem
extends RefCounted
## T-124 Ф4-MVP «этический минимум»: журнал этических событий, сверка на
## ходах 10/20, Репутация. Формула — приказ раунда 15 §3 (w_r=1, w_d=2,
## якорь дельты [−3,+3]); числа — ethics.json (K-M15).
## Журнал — отдельная секция от престиж-леджера (T-124); события не
## пересчитываются при загрузке (I1): аккумулятор и журнал — состояние.
## Оси (конвенция T-124): − = Порядок/Аскеза/Открытость, + = Свобода/Роскошь/Изоляция.

## kind журнала: потери защитника → Диссонанс; победа в обороне → Резонанс;
## победа с Долгом судьбы → метка «свобода/риск» (ось order_freedom +1);
## reconcile — итог сверки {r, d, delta, reputation}.
const KIND_LOSSES := "defender_losses"
const KIND_DEFENSE_WIN := "defense_win"
const KIND_FATE_WIN := "fate_debt_win"
const KIND_RECONCILE := "reconcile"

var config: Dictionary = {}
var sign_id: String = ""
var journal: Array = []
## Аккумуляторы до ближайшей сверки (сбрасываются на сверке).
var axes: Dictionary = {}
var resonance: int = 0
var dissonance: int = 0
## Репутация: старт 0; ± только от сверок (T-124 п.4).
var reputation: int = 0
var last_reconcile_turn: int = 0


static func new_for_sign(sign_id: String, config: Dictionary) -> EthicsSystem:
	var e := EthicsSystem.new()
	e.config = config
	e.sign_id = sign_id
	e._reset_axes()
	return e


static func from_dict(data: Dictionary, config: Dictionary) -> EthicsSystem:
	var e := EthicsSystem.new()
	e.config = config
	e.sign_id = str(data.get("sign_id", ""))
	e.journal = (data.get("journal", []) as Array).duplicate(true)
	e.axes = (data.get("axes", {}) as Dictionary).duplicate(true)
	e.resonance = int(data.get("resonance", 0))
	e.dissonance = int(data.get("dissonance", 0))
	e.reputation = int(data.get("reputation", 0))
	e.last_reconcile_turn = int(data.get("last_reconcile_turn", 0))
	if e.axes.is_empty():
		e._reset_axes()
	return e


func to_dict() -> Dictionary:
	return {
		"sign_id": sign_id,
		"journal": journal.duplicate(true),
		"axes": axes.duplicate(true),
		"resonance": resonance,
		"dissonance": dissonance,
		"reputation": reputation,
		"last_reconcile_turn": last_reconcile_turn,
	}


## ---- События (журнал; аккумулятор до сверки) ----

func record_losses(turn: int) -> void:
	_journal(turn, KIND_LOSSES)
	dissonance += int(_events().get(KIND_LOSSES, {}).get("dissonance", 1))


func record_defense_win(turn: int) -> void:
	_journal(turn, KIND_DEFENSE_WIN)
	resonance += int(_events().get(KIND_DEFENSE_WIN, {}).get("resonance", 1))


## Победа с Долгом судьбы (trace: debt > 0 у атакующего) — «свобода/риск».
func record_fate_debt_win(turn: int) -> void:
	_journal(turn, KIND_FATE_WIN)
	var ev: Dictionary = _events().get(KIND_FATE_WIN, {})
	var axis := str(ev.get("axis", "order_freedom"))
	axes[axis] = int(axes.get(axis, 0)) + int(ev.get("amount", 1))


## ---- Сверка (ходы 10/20) ----
## Направление по осям: накопленный вектор vs референс знака — совпадение
## направления → Резонанс, противоречие → Диссонанс; нулевая ось (любой
## стороны) = нейтраль, вклад 0 (T-124). Дельта = clamp(w_r·R − w_d·D, якорь).
## sign_vectors — {sign_id: {axis: int}} из signs.json.
func reconcile(turn: int, sign_vectors: Dictionary) -> Dictionary:
	var ref: Dictionary = sign_vectors.get(sign_id, {})
	if ref.is_empty():
		return {"reconciled": false, "reason": "no_sign"}
	var r := resonance
	var d := dissonance
	for axis in (config.get("axes", []) as Array):
		var a: int = signi(int(axes.get(str(axis), 0)))
		var b: int = signi(int(ref.get(str(axis), 0)))
		if a != 0 and b != 0:
			if a == b:
				r += 1
			else:
				d += 1
	var w: Dictionary = config.get("weights", {})
	var anchor: Array = config.get("delta_anchor", [-3, 3])
	var delta: int = clampi(
		int(w.get("resonance", 1)) * r - int(w.get("dissonance", 2)) * d,
		int(anchor[0]), int(anchor[1]))
	reputation += delta
	journal.append({
		"turn": turn, "kind": KIND_RECONCILE,
		"r": r, "d": d, "delta": delta, "reputation": reputation,
	})
	last_reconcile_turn = turn
	_reset_axes()
	resonance = 0
	dissonance = 0
	return {"reconciled": true, "r": r, "d": d, "delta": delta,
		"reputation": reputation}


func needs_reconcile(turn: int) -> bool:
	# JSON-числа — float; сравнение int-элемента с float-массивом ложно — приводим.
	for t in (config.get("reconcile_turns", []) as Array):
		if int(t) == turn:
			return last_reconcile_turn != turn
	return false


static func signi(v: int) -> int:
	return 1 if v > 0 else (-1 if v < 0 else 0)


## Референс-векторы знаков из signs.json: {id: {axis: int}}.
static func load_sign_vectors(signs_json: Dictionary) -> Dictionary:
	var out := {}
	for s in signs_json.get("signs", []):
		out[str(s.get("id", ""))] = (s.get("ethics_vector", {}) as Dictionary).duplicate()
	return out


func _reset_axes() -> void:
	axes = {}
	for axis in (config.get("axes", []) as Array):
		axes[str(axis)] = 0


func _journal(turn: int, kind: String) -> void:
	journal.append({"turn": turn, "kind": kind})


func _events() -> Dictionary:
	return config.get("events", {})
