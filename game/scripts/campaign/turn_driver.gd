class_name TurnDriver
extends RefCounted
## T-010: Цикл хода — 21 ход, ход = сезон (T-032; авторский состав, раунд 6 §2.2).
## Структура хода (01-core-loop «Структура хода»):
##   1. SETTLEMENT — авто: производство, население, содержание районов,
##      SM дефицита, 4 тика (логика — T-040);
##   2. PLAYER — действия игрока (перемещения, бои, строительство, найм);
##   3. THREATS — авто: функция давления, экологические давления, события (T-070).
## Сериализуемое состояние (пост-условие T-110: миграция по версиям покрыта тестом).
## Инварианты: I1 (одинаковые вводные → одинаковая последовательность событий),
## K-M9 (бит-каркас: ходы 1/7/14/17/21).
## Каркас вызова боёв: request_battle(context) + battle_request_handler (шов к T-050).

const CAMPAIGN_TURNS := 21
const SCHEMA_VERSION := 1
## K-M9: бит-каркас (ходы 1/7/14/17/21) — MVP.
const BIT_TURNS: Array[int] = [1, 7, 14, 17, 21]

enum Phase { SETTLEMENT, PLAYER, THREATS, DONE }

const PHASE_NAMES := {
	Phase.SETTLEMENT: "settlement",
	Phase.PLAYER: "player",
	Phase.THREATS: "threats",
	Phase.DONE: "done",
}

var current_turn: int = 1
var phase: int = Phase.SETTLEMENT
var seed: int = 0

## Хуки фаз (логика — T-040/T-070; по умолчанию — no-op).
var settlement_hook: Callable
var threats_hook: Callable
## Каркас вызова боёв (T-050): handler(context: Dictionary) -> void.
var battle_request_handler: Callable

var _event_log: Array[String] = []


## K-M9: бит-ход?
static func is_bit_turn(turn: int) -> bool:
	return BIT_TURNS.has(turn)


## Автофаза (settlement/threats) → следующая. Вызывает игровой слой.
func advance_auto_phase() -> void:
	match phase:
		Phase.SETTLEMENT:
			if settlement_hook.is_valid():
				settlement_hook.call()
			_enter_player_phase()
		Phase.THREATS:
			if threats_hook.is_valid():
				threats_hook.call()
			_finish_turn()
		_:
			push_warning("TurnDriver: advance_auto_phase() в фазе %s — игнор" % phase_name())


## Игрок завершил действия → фаза угроз.
func end_player_phase() -> void:
	if phase != Phase.PLAYER:
		push_warning("TurnDriver: end_player_phase() в фазе %s — игнор" % phase_name())
		return
	_enter_threats_phase()


## Каркас вызова боя (T-050): фиксирует событие, передаёт контекст обработчику.
func request_battle(context: Dictionary) -> void:
	_log("battle_request:turn=%d" % current_turn)
	if battle_request_handler.is_valid():
		battle_request_handler.call(context)


func phase_name() -> String:
	return PHASE_NAMES[phase]


func is_done() -> bool:
	return phase == Phase.DONE


## ---- Сериализуемое состояние (T-110) ----
## Ключи совпадают с секцией "campaign" схемы MvpSaveSchema ({turn, seed, phase})
## + schema_version (миграция по версиям).

func to_dict() -> Dictionary:
	return {
		"turn": current_turn,
		"seed": seed,
		"phase": phase_name(),
		"schema_version": SCHEMA_VERSION,
	}


static func from_dict(data: Dictionary) -> TurnDriver:
	var migrated := migrate(data)
	var driver := TurnDriver.new()
	driver.current_turn = maxi(1, int(migrated.get("turn", 1)))
	driver.seed = int(migrated.get("seed", 0))
	driver.phase = _phase_from_name(String(migrated.get("phase", "player")))
	return driver


## Миграция по версиям (пост-условие T-110): v0 (без phase/schema_version) → v1.
## Исходный словарь не изменяется.
static func migrate(data: Dictionary) -> Dictionary:
	var d := data.duplicate()
	var version := int(d.get("schema_version", 0))
	if version <= 0:
		if not d.has("phase"):
			# v0: ход без фазы — середина хода, дефолт = фаза игрока.
			d["phase"] = "player"
		d["schema_version"] = SCHEMA_VERSION
	# Будущее: цепочка 1 → 2 → …
	return d


## I1: детерминированная последовательность событий (копия).
func event_log() -> Array[String]:
	return _event_log.duplicate()


func _log(event: String) -> void:
	_event_log.append(event)


func _enter_player_phase() -> void:
	phase = Phase.PLAYER
	_log("turn=%d:phase=player" % current_turn)


func _enter_threats_phase() -> void:
	phase = Phase.THREATS
	_log("turn=%d:phase=threats" % current_turn)


func _finish_turn() -> void:
	if current_turn >= CAMPAIGN_TURNS:
		phase = Phase.DONE
		_log("turn=%d:campaign_done" % current_turn)
		return
	current_turn += 1
	phase = Phase.SETTLEMENT
	_log("turn=%d:phase=settlement" % current_turn)


static func _phase_from_name(name: String) -> int:
	for p in Phase.values():
		if PHASE_NAMES[p] == name:
			return p
	return Phase.PLAYER
