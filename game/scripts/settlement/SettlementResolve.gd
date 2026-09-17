extends RefCounted
## Resolve, голод, перерывы, уход (фаза 2). Д2: статик + state.
## D4: цикл = 1 ход.

const Species = preload("res://scripts/data/settlement_species.gd")
const Num = preload("res://scripts/constants/GameNumbersSettlement.gd")

# бонусы за удовлетворённые потребности (1.2 прототипа)
const BONUS_COMPLEX_FOOD: float = 4.0
const BONUS_COAT: float = 5.0
const BONUS_COAT_STORM: float = 3.0
const BONUS_BOOTS: float = 5.0
const BONUS_HOUSE: float = 5.0
const BONUS_SHELTER: float = 2.0
const BONUS_SERVICE: float = 4.0
const HUNGER_RESOLVE_LOSS: float = 1.0
const BREAK_RESOLVE_GAIN: float = 1.0

static func on_day_passed(settle, rng: RandomNumberGenerator, storm: bool = false) -> void:
	settle.state["day"] = int(settle.state["day"]) + 1
	var leavers: Array = []
	for s in settle.state["settlers"]:
		_process_settler(settle, s, rng, storm)
		if float(s["resolve"]) <= 0.0:
			leavers.append(s)
	for s in leavers:
		_settle_leaves(settle, s)
	apply_firekeeper(settle)

static func _process_settler(settle, s: Dictionary, rng: RandomNumberGenerator, storm: bool) -> void:
	var sp: Dictionary = Species.by_id(s["species"])
	# еда
	if settle.take_resource("food", 1.0):
		s["hunger"] = 0
		# сложная еда: если есть — бонус
		if settle.take_resource("complex_food", 1.0):
			s["resolve"] = float(s["resolve"]) + BONUS_COMPLEX_FOOD
	else:
		s["hunger"] = int(s["hunger"]) + 1
		if int(s["hunger"]) > int(sp.get("hunger_tolerance", 6)):
			s["resolve"] = float(s["resolve"]) - HUNGER_RESOLVE_LOSS
	# одежда
	if settle.take_resource("coat", 1.0):
		s["resolve"] = float(s["resolve"]) + (BONUS_COAT_STORM if storm else BONUS_COAT)
	if settle.take_resource("boots", 1.0):
		s["resolve"] = float(s["resolve"]) + BONUS_BOOTS
	# жильё
	s["resolve"] = float(s["resolve"]) + _housing_bonus(settle, s)
	# сервис (таверна)
	var taverns: Array = settle.buildings_of("tavern")
	if not taverns.is_empty() and settle.take_resource("ale", 1.0):
		s["resolve"] = float(s["resolve"]) + BONUS_SERVICE
	# перерыв
	if int(s["break_in"]) <= 0:
		s["resolve"] = float(s["resolve"]) + BREAK_RESOLVE_GAIN
		s["break_in"] = int(sp.get("break_interval", 1))
	else:
		s["break_in"] = int(s["break_in"]) - 1

static func _housing_bonus(settle, s: Dictionary) -> float:
	for b in settle.state["buildings"]:
		if b["data"].get("resident", "") == s["id"]:
			if b["type"] == "shelter" and s["species"] == "frog":
				return 0.0  # лягушки отказываются от Shelter
			if b["type"] == "shelter" or b["type"] == "big_shelter":
				return BONUS_SHELTER
			return BONUS_HOUSE
	return 0.0

# 2.3 Firekeeper: вид-бонус (harpy — скорость, lizard — Resolve)
static func apply_firekeeper(settle) -> void:
	var fk_id: String = settle.state.get("firekeeper_id", "")
	if fk_id == "":
		return
	for s in settle.state["settlers"]:
		if s["id"] == fk_id:
			if s["species"] == "lizard":
				for other in settle.state["settlers"]:
					other["resolve"] = float(other["resolve"]) + 1.0
			# harpy: бонус скорости — в поселении без движения, пока нет эффекта
			break

# 2.4 Уход при Resolve 0: освобождение жилья
static func _settle_leaves(settle, s: Dictionary) -> void:
	for b in settle.state["buildings"]:
		if b["data"].get("resident", "") == s["id"]:
			b["data"]["resident"] = ""
	settle.remove_settler(s)
	if settle.state.get("firekeeper_id", "") == s["id"]:
		settle.state["firekeeper_id"] = ""
