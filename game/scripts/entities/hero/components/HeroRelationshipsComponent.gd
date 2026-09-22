class_name HeroRelationshipsComponent
extends HeroComponent
## team-romance-roleplay D1: состояние отношений команды героя.
## pairs: "hero-<uid>" → {bond, trust, romance, spouse, last_bond_stage, last_romance_stage}
##   — связи герой ↔ последователь (старт: bond 0, trust 50, romance 0)
## duos: "<uid_a>:<uid_b>" (a<b) → {bond, trust, jealousy_to, jealousy_fired}
##   — связи последователь ↔ последователь (ревность)
## Стадии вычисляются RelationshipSystem из чисел; last_*_stage — кэш для
## детекта переходов (событие relationship_stage_changed).

const DEFAULT_BOND := 0
const DEFAULT_TRUST := 50
const DEFAULT_ROMANCE := 0

var pairs: Dictionary = {}
var duos: Dictionary = {}
## Сцены, ожидающие решения игрока (UI, task 5.3): {type, uid, ...}
## В неинтерактивном режиме (headless/autopilot) разрешаются дефолтным
## выбором в начале следующего end_turn.
var pending_scenes: Array = []
## Временные баффы боевого духа: [{value, turns_left}] (истекают по ходу)
var temp_morale_buffs: Array = []

static func pair_key(uid: int) -> String:
	return "hero-%d" % uid

static func duo_key(a: int, b: int) -> String:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return "%d:%d" % [lo, hi]

func has_pair(uid: int) -> bool:
	return pairs.has(pair_key(uid))

## Доступ к паре герой↔последователь (создаёт со стартовыми связями).
func pair(uid: int) -> Dictionary:
	var k := pair_key(uid)
	if not pairs.has(k):
		pairs[k] = _new_pair()
	return pairs[k]

func _new_pair() -> Dictionary:
	return {
		"bond": DEFAULT_BOND,
		"trust": DEFAULT_TRUST,
		"romance": DEFAULT_ROMANCE,
		"spouse": false,
		"engaged": false,
		"last_bond_stage": 0,
		"last_romance_stage": 0,
	}

## Доступ к дуо последователь↔последователь (создаёт со стартовыми связями).
func duo(a: int, b: int) -> Dictionary:
	var k := duo_key(a, b)
	if not duos.has(k):
		duos[k] = {"bond": 0, "trust": 50, "jealousy_to": -1, "jealousy_fired": false}
	return duos[k]

func duos_for(uid: int) -> Array:
	var out: Array = []
	for k in duos:
		var parts: PackedStringArray = String(k).split(":")
		if parts.size() == 2 and (int(parts[0]) == uid or int(parts[1]) == uid):
			out.append(duos[k])
	return out

## Удаление всех связей последователя (уход/предательство/смерть).
func remove_follower(uid: int) -> void:
	pairs.erase(pair_key(uid))
	for k in duos.keys():
		var parts: PackedStringArray = String(k).split(":")
		if parts.size() == 2 and (int(parts[0]) == uid or int(parts[1]) == uid):
			duos.erase(k)

## Конец хода: RelationshipSystem.process_turn → сигналы + очередь сцен.
func end_turn() -> void:
	if _hero == null:
		return
	tick_buffs()
	_auto_resolve_stale_scenes()
	var events: Array = RelationshipSystem.process_turn(_hero, self)
	for e in events:
		_handle_event(e)

func _handle_event(e: Dictionary) -> void:
	var t: String = String(e.get("type", ""))
	match t:
		"betrayal":
			_return_to_city(int(e["uid"]))
			GameEventBus.follower_betrayal.emit(int(e["uid"]))
		"jealousy":
			GameEventBus.romance_event.emit("jealousy", int(e["uid_a"]))
			pending_scenes.append({"type": "jealousy", "uid": int(e["uid_a"]), "uid_b": int(e["uid_b"])})
		"conflict":
			pending_scenes.append({"type": "conflict", "uid": int(e["uid"])})
		"marriage_ready":
			pending_scenes.append({"type": "marriage", "uid": int(e["uid"])})
		"stage_changed":
			GameEventBus.relationship_stage_changed.emit(int(e["uid"]), int(e["stage"]), bool(e["is_romance"]))

## UI вызывает с выбором игрока: "soothe"/"joke"/"ignore" (ревность),
## "reconcile"/"sever" (конфликт), "confirm"/"decline" (свадьба/предложение).
func resolve_pending(index: int, choice: String) -> void:
	if index < 0 or index >= pending_scenes.size():
		return
	var scene: Dictionary = pending_scenes[index]
	var uid := int(scene.get("uid", 0))
	var cha := 2
	if _hero != null and _hero.stats_comp != null:
		cha = int(_hero.stats_comp.stats.get("cha", 2))
	match String(scene.get("type", "")):
		"jealousy":
			match choice:
				"soothe":
					RelationshipSystem.modify(self, _hero_sex(), _follower(uid), {"bond": 10, "trust": 5})
				"joke":
					RelationshipSystem.modify(self, _hero_sex(), _follower(uid), {"bond": 5, "trust": -5})
				_:
					RelationshipSystem.modify(self, _hero_sex(), _follower(uid), {"bond": -5})
		"conflict":
			if choice == "sever":
				RelationshipSystem.sever(_hero, self, uid)
			else:
				RelationshipSystem.try_reconcile(self, uid, cha)
		"marriage":
			if choice == "confirm":
				RelationshipSystem.marry(self, uid)
				GameEventBus.marriage.emit(uid)
			else:
				RelationshipSystem.modify(self, _hero_sex(), _follower(uid), {"romance": -15})
		"proposal":
			if choice == "confirm":
				var p: Dictionary = pair(uid)
				p["engaged"] = true
			else:
				RelationshipSystem.modify(self, _hero_sex(), _follower(uid), {"romance": -15})
	pending_scenes.remove_at(index)

## Неинтерактивный режим: сцены старше хода разрешаются дефолтным выбором.
func _auto_resolve_stale_scenes() -> void:
	while not pending_scenes.is_empty():
		var scene: Dictionary = pending_scenes[0]
		var def := "soothe"
		match String(scene.get("type", "")):
			"conflict": def = "reconcile"
			"marriage": def = "confirm"
			"proposal": def = "confirm"
		resolve_pending(0, def)

## team-romance-roleplay 3.3: предавший возвращается в население города
## (если герой стоит на центре города; иначе покидает мир).
func _return_to_city(uid: int) -> void:
	if _hero == null or _hero.city_manager == null or _hero.movement_comp == null:
		return
	var cell: Vector2i = _hero.movement_comp.get_current_cell()
	var city := _hero.city_manager.city_at(cell)
	if city != null:
		city.add_migrant(PopUnit.State.FOLLOWER, -1)

func _hero_sex() -> String:
	if _hero != null and _hero.stats_comp != null:
		return String(_hero.stats_comp.sex)
	return "male"

func _follower(uid: int) -> Follower:
	if _hero == null:
		return null
	for f in _hero.followers:
		if f != null and int(f.uid) == uid:
			return f
	return null

## Средний bond по всем последователям (боевой дух; пусто → 0).
func average_bond() -> float:
	if pairs.is_empty():
		return 0.0
	var total := 0.0
	for k in pairs:
		total += float((pairs[k] as Dictionary).get("bond", 0))
	return total / float(pairs.size())

## Временный боевой дух (диалоговые баффы): суммарное значение активных.
func active_morale() -> int:
	var total := 0
	for b in temp_morale_buffs:
		if b is Dictionary:
			total += int((b as Dictionary).get("value", 0))
	return total

func add_morale_buff(value: int, turns: int) -> void:
	temp_morale_buffs.append({"value": value, "turns_left": turns})

func tick_buffs() -> void:
	for b in temp_morale_buffs:
		if b is Dictionary:
			(b as Dictionary)["turns_left"] = int((b as Dictionary).get("turns_left", 1)) - 1
	temp_morale_buffs = temp_morale_buffs.filter(
		func(b): return b is Dictionary and int((b as Dictionary).get("turns_left", 0)) > 0)

func serialize() -> Dictionary:
	return {"relationships": {"pairs": pairs.duplicate(true), "duos": duos.duplicate(true),
		"temp_morale_buffs": temp_morale_buffs.duplicate(true), "pending_scenes": pending_scenes.duplicate(true)}}

func deserialize(data: Dictionary) -> void:
	var rel: Dictionary = data.get("relationships", {})
	var loaded_pairs: Dictionary = rel.get("pairs", {})
	pairs.clear()
	for k in loaded_pairs:
		var fresh := _new_pair()
		fresh.merge(loaded_pairs[k], true)
		pairs[k] = fresh
	var loaded_duos: Dictionary = rel.get("duos", {})
	duos.clear()
	for k in loaded_duos:
		var fresh := {"bond": 0, "trust": 50, "jealousy_to": -1, "jealousy_fired": false}
		fresh.merge(loaded_duos[k], true)
		duos[k] = fresh
	var loaded_buffs: Array = rel.get("temp_morale_buffs", [])
	temp_morale_buffs.clear()
	for b in loaded_buffs:
		if b is Dictionary:
			temp_morale_buffs.append(b)
	var loaded_scenes: Array = rel.get("pending_scenes", [])
	pending_scenes.clear()
	for s in loaded_scenes:
		if s is Dictionary:
			pending_scenes.append(s)
