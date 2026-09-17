extends RefCounted
## Demand/Decadence, Hostility, штормы, победа/поражение (фаза 4). Д2/Д5.

const Species = preload("res://scripts/data/settlement_species.gd")
const Num = preload("res://scripts/constants/GameNumbersSettlement.gd")
const B = preload("res://scripts/data/settlement_buildings.gd")

# 4.2 Hostility: рост за год/поселенца/glade/лагерь
const HOSTILITY_PER_YEAR: int = 2
const HOSTILITY_PER_SETTLER: int = 1
const HOSTILITY_PER_GLADE: int = 3
const HOSTILITY_PER_WOODCUTTER: int = 1
const HOSTILITY_SMALL_HEARTH: int = -2

# 4.3 Шторм
const STORM_BASE_PENALTY: float = 2.0
const STORM_HOSTILITY_FACTOR: float = 0.5
const STORM_EXODUS_RESOLVE: float = 3.0

static func on_day_passed(settle, rng: RandomNumberGenerator, force_storm: bool = false) -> void:
	var storm := force_storm or _roll_storm(settle, rng)
	_settle_hostility(settle)
	if storm:
		_apply_storm(settle)
	_reputation(settle)
	_check_endgame(settle)

# 4.1 Demand/Decadence: средний Resolve вида > Demand → очко;
# за очко порог снижается на Decadence
static func _reputation(settle) -> void:
	for sp in settle.species_in_caravan():
		var s: Dictionary = Species.by_id(sp)
		var rep: Dictionary = settle.state["reputation"].get(sp, {
			"points": 0, "demand_threshold": int(s["demand"]), "decadence_spent": 0,
		})
		var avg := _avg_resolve(settle, sp)
		if avg > float(rep["demand_threshold"]):
			rep["points"] = int(rep["points"]) + 1
			rep["demand_threshold"] = int(rep["demand_threshold"]) - int(s["decadence"])
		settle.state["reputation"][sp] = rep

static func _avg_resolve(settle, sp: String) -> float:
	var list: Array = settle.settlers_of(sp)
	if list.is_empty():
		return 0.0
	var sum := 0.0
	for s in list:
		sum += float(s["resolve"])
	return sum / float(list.size())

static func total_reputation(settle) -> int:
	var total := 0
	for sp in settle.state["reputation"]:
		total += int(settle.state["reputation"][sp]["points"])
	return total

static func victory_reached(settle) -> bool:
	return total_reputation(settle) >= Num.REPUTATION_GOAL

# 4.2 Hostility
static func _settle_hostility(settle) -> void:
	# Hostility = функция состояния (не накопление): год/поселенец/glade/лагерь
	var day: int = int(settle.state["day"])
	var h := (day / Num.YEAR_LENGTH) * HOSTILITY_PER_YEAR
	h += int(settle.state["settlers"].size()) * HOSTILITY_PER_SETTLER
	h += int(settle.state.get("glades_opened", 0)) * HOSTILITY_PER_GLADE
	h += settle.buildings_of("woodcutters_camp").size() * HOSTILITY_PER_WOODCUTTER
	h += settle.buildings_of("small_hearth").size() * HOSTILITY_SMALL_HEARTH
	settle.state["hostility"] = maxi(h, 0)

static func _roll_storm(settle, rng: RandomNumberGenerator) -> bool:
	# вероятность ∝ Hostility
	var chance: int = int(float(int(settle.state["hostility"])) * 2)
	return rng.randi_range(1, 100) <= chance

static func _apply_storm(settle) -> void:
	var penalty: float = STORM_BASE_PENALTY + float(int(settle.state["hostility"])) * STORM_HOSTILITY_FACTOR
	var leavers: Array = []
	for s in settle.state["settlers"]:
		# coats +3 в шторм уже учтены в Resolve-цикле; здесь — сам шторм
		s["resolve"] = float(s["resolve"]) - penalty
		if float(s["resolve"]) < STORM_EXODUS_RESOLVE:
			leavers.append(s)
	for s in leavers:
		s["home"] = ""
		settle.remove_settler(s)
	# увольнение лесорубов (4.3): лагеря сгорают
	var keep: Array = []
	for b in settle.state["buildings"]:
		if b["type"] == "woodcutters_camp":
			continue
		keep.append(b)
	settle.state["buildings"] = keep

# 4.4 Поражение
static func _check_endgame(settle) -> void:
	if settle.state["defeat"] != "":
		return
	if int(settle.state["settlers"].size()) == 0:
		settle.state["defeat"] = "no_settlers"
		return
	if int(settle.state["hostility"]) >= 100:
		settle.state["defeat"] = "instability"
