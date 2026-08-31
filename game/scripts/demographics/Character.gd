class_name Character
extends RefCounted
## Персонаж (M2: Демография) — нарративная оболочка над PopUnit.
##
## Связь: PopUnit.character_uid -> Character.uid (один к одному;
## персонаж живёт, пока жива фигурка). Потребности 0..1 (1 = полностью
## удовлетворена); дельты считает DemographicTurnProcessor.
## Чистый RefCounted: сериализуется в Dictionary, не зависит от узлов.

const NEED_KEYS: Array[StringName] = [&"hunger", &"rest", &"social", &"inspiration"]

var uid := 0
var name := ""
var icon := "🙂"
var birth_turn := 0
var city_uid := -1
var pop_uid := -1
var alive := true
## 0..1: 1 = полностью удовлетворена.
var needs: Dictionary = {}
var traits: Array[TraitDef] = []
## Сколько дней подряд потребность = 0.0 (проверка смерти).
var need_zero_streak: Dictionary = {}
## Потребности, находившиеся в критике в прошлом тике (анти-спам сигналов).
var was_critical: Dictionary = {}


func _init() -> void:
	reset_needs()


func reset_needs() -> void:
	needs.clear()
	need_zero_streak.clear()
	was_critical.clear()
	for k in NEED_KEYS:
		needs[k] = 0.8
		need_zero_streak[k] = 0
		was_critical[k] = false


func age_in_days(turn: int) -> int:
	return maxi(turn - birth_turn, 0)


## Меняет потребность с зажимом в [0..1].
func modify_need(id: StringName, delta: float) -> void:
	needs[id] = clampf(float(needs.get(id, 0.5)) + delta, 0.0, 1.0)


func is_need_critical(id: StringName, threshold: float = 0.2) -> bool:
	return float(needs.get(id, 1.0)) < threshold


## Сумма модификаторов черт к потребности [type] за день.
func trait_modifier(type: StringName) -> float:
	var v := 0.0
	for t in traits:
		if t != null:
			v += t.modifier_for(type)
	return v


func serialize() -> Dictionary:
	return {
		"uid": uid,
		"name": name,
		"icon": icon,
		"birth_turn": birth_turn,
		"city_uid": city_uid,
		"pop_uid": pop_uid,
		"alive": alive,
		"needs": _needs_to_str(needs),
		"traits": traits.map(func(t: TraitDef) -> Dictionary:
			return t.to_dict() if t != null else {}),
	}


static func _needs_to_str(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = float(src[k])
	return out


static func deserialize(data: Dictionary) -> Character:
	var ch := Character.new()
	ch.uid = int(data.get("uid", 0))
	ch.name = String(data.get("name", ""))
	ch.icon = String(data.get("icon", "🙂"))
	ch.birth_turn = int(data.get("birth_turn", 0))
	ch.city_uid = int(data.get("city_uid", -1))
	ch.pop_uid = int(data.get("pop_uid", -1))
	ch.alive = bool(data.get("alive", true))
	var raw_needs: Dictionary = data.get("needs", {})
	# Миграция старых сохранений: потребность belief переименована в inspiration.
	# Без переноса у героя пропадала бы одна из четырёх потребностей.
	if raw_needs.has("belief"):
		if not raw_needs.has("inspiration"):
			raw_needs["inspiration"] = raw_needs["belief"]
		raw_needs.erase("belief")
	for k in raw_needs:
		ch.needs[StringName(k)] = float(raw_needs[k])
	var raw_traits: Array = data.get("traits", [])
	for d in raw_traits:
		var t := TraitDef.from_dict(d)
		if t.id != &"":
			ch.traits.append(t)
	return ch
