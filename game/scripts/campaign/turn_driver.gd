class_name TurnDriver
extends RefCounted
## T-010: Цикл хода кампании — машина фаз (T-122: 6 фаз, GDD-мандат §1),
## 21 ход, ход = сезон (WorldSeasons), K-M9 бит-каркас (ходы 1/7/14/17/21),
## I1-детерминизм, сериализуемое состояние + миграция по версиям
## (пост-условие T-110), каркас вызова боёв.
##
## Порядок фаз — GDD-мандат §1 (дословно): «городские и популяционные
## события → движение героя и армии → караваны и торговля → дипломатия
## и совет → разрешение боёв и рейдов → расчёт производства» (Q-M31,
## закрыто, раунд 8: TurnDriver — единственный носитель; 6-фазный
## порядок — канон; TurnDriver расширяется, а не заменяется).
##
## MVP-срез (Q-M31 §1.3): settlement_events (население/события) →
## player (движение) → [caravans, diplomacy — post-MVP-слоты, no-op
## в MVP, фазы существуют как каркас] → threats (бой/рейды) →
## production (расчёт производства). Production — ПОСЛЕ threats
## (T-122: рейды бьют pre-production запасы).
##
## Логика фаз — T-040 (settlement/production), T-070 (threats); тут —
## каркас + порядок + хуки.

const SCHEMA_VERSION := 2  # v2 (T-122, раунд 8): набор фаз расширен
## (caravans/diplomacy/production); v1-имена сохранены (без пере-маппинга).
const TOTAL_TURNS := 21
const BIT_TURNS := [1, 7, 14, 17, 21]  # K-M9: бит-каркас (07-balance §6)

enum Phase { SETTLEMENT, PLAYER, CARAVANS, DIPLOMACY, THREATS, PRODUCTION, DONE }

const PHASE_NAMES := {
	Phase.SETTLEMENT: "settlement",
	Phase.PLAYER: "player",
	Phase.CARAVANS: "caravans",
	Phase.DIPLOMACY: "diplomacy",
	Phase.THREATS: "threats",
	Phase.PRODUCTION: "production",
	Phase.DONE: "done",
}

var current_turn: int = 1
var phase: int = Phase.SETTLEMENT
var seed: int = 12345  # campaign seed (I1: детерминизм; K-M9: бит-каркас)
## T-060 (R1): статус кампании — ongoing / defeat (wipe партии); T-071
## расширит victory (босс/финальный рейд). Стейт, не производное (в сейве).
var campaign_status: String = "ongoing"

## Хуки фаз (T-040/T-070 вешают свою логику; каркас — no-op).
## settlement: население/события/настроение (T-040, без production — T-122).
var settlement_hook: Callable
## T-020/T-021: player-фаза — переходы героя (RegionMap): авто-режим/отступление
## (time-based); решение игрока (куда идти) — через UI, до end_player_phase.
var player_hook: Callable
## caravans/diplomacy: post-MVP-слоты (Q-M31 §1.3) — no-op в MVP.
var caravans_hook: Callable
var diplomacy_hook: Callable
## threats: бой/рейды (T-070).
var threats_hook: Callable
## production: расчёт производства (T-040) — ПОСЛЕ threats (T-122).
var production_hook: Callable

## Шов T-050: обработчик вызова боя (context: {cause, turn, ...}).
var battle_request_handler: Callable

var _events: Array = []  # I1: детерминированный журнал (сериализуется)


static func is_bit_turn(turn: int) -> bool:
	return BIT_TURNS.has(turn)


func phase_name() -> String:
	return PHASE_NAMES[phase]


func is_done() -> bool:
	return phase == Phase.DONE


## T-060 (R1): wipe всей партии = конец кампании (DEFEAT). Сейв и Престиж
## сохраняются (02-mechanics §3.2 EC1: нет «game over без возврата»). Повторный
## вызов — no-op (флаг, не таймер; D-152-семья).
func defeat(reason: String) -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	campaign_status = "defeat"
	_log("campaign_defeat:turn=%d:reason=%s" % [current_turn, reason])


## Автофаза: одна авто-фаза за вызов (MVP: player — единственный
## ручной; caravans/diplomacy — авто no-op-слоты).
func advance_auto_phase() -> void:
	match phase:
		Phase.SETTLEMENT:
			_log("settlement:turn=%d" % current_turn)
			if settlement_hook.is_valid():
				settlement_hook.call()
			_enter_player_phase()
		Phase.CARAVANS:
			_log("caravans:turn=%d" % current_turn)
			if caravans_hook.is_valid():
				caravans_hook.call()
			phase = Phase.DIPLOMACY
		Phase.DIPLOMACY:
			_log("diplomacy:turn=%d" % current_turn)
			if diplomacy_hook.is_valid():
				diplomacy_hook.call()
			phase = Phase.THREATS
		Phase.THREATS:
			_log("threats:turn=%d" % current_turn)
			if threats_hook.is_valid():
				threats_hook.call()
			phase = Phase.PRODUCTION
		Phase.PRODUCTION:
			_log("production:turn=%d" % current_turn)
			if production_hook.is_valid():
				production_hook.call()
			_finish_turn()
		Phase.PLAYER:
			push_warning("TurnDriver: advance_auto_phase в player-фазе — ожидается end_player_phase")
		Phase.DONE:
			push_warning("TurnDriver: advance_auto_phase после DONE")


## Игрок завершил player-фазу (движение) → caravans (Q-M31 §1.3).
func end_player_phase() -> void:
	if phase != Phase.PLAYER:
		push_warning("TurnDriver: end_player_phase вне player-фазы (текущая: %s)" \
			% phase_name())
		return
	_log("player_end:turn=%d" % current_turn)
	phase = Phase.CARAVANS


func _enter_player_phase() -> void:
	phase = Phase.PLAYER
	_log("player:turn=%d" % current_turn)
	if player_hook.is_valid():
		player_hook.call()


func _finish_turn() -> void:
	if current_turn >= TOTAL_TURNS:
		phase = Phase.DONE
		_log("campaign_done:turn=%d" % current_turn)
		return
	current_turn += 1
	phase = Phase.SETTLEMENT


## Шов T-050: запросить бой (context сериализуемый; I1).
func request_battle(context: Dictionary) -> void:
	_log("battle_request:turn=%d" % int(context.get("turn", current_turn)))
	if battle_request_handler.is_valid():
		battle_request_handler.call(context)


func event_log() -> Array:
	return _events.duplicate()


func _log(msg: String) -> void:
	_events.append(msg)


## --- Сериализация (T-110: схема с версиями + миграция) ---

func to_dict() -> Dictionary:
	return {
		"turn": current_turn,
		"seed": seed,
		"phase": phase_name(),
		"status": campaign_status,  # T-060: ongoing/defeat (T-071: victory)
		"schema_version": SCHEMA_VERSION,
		"events": _events.duplicate(),
	}


static func from_dict(data: Dictionary) -> TurnDriver:
	var d := migrate(data)
	var driver := TurnDriver.new()
	driver.current_turn = int(d.get("turn", 1))
	driver.seed = int(d.get("seed", 12345))
	driver.phase = _phase_from_name(str(d.get("phase", "player")))
	driver.campaign_status = str(d.get("status", "ongoing"))  # T-060
	driver._events = (d.get("events", []) as Array).duplicate()
	return driver


## Миграция по версиям (T-110-пост-условие; chain: v0 → v1 → v2).
static func migrate(data: Dictionary) -> Dictionary:
	var d := data.duplicate()
	var version := int(d.get("schema_version", 0))
	if version <= 0:
		# v0 (до T-110): {turn, seed} без фазы → v1: дефолт player.
		if not d.has("phase"):
			d["phase"] = "player"
		d["schema_version"] = 1
	if version <= 1:
		# v1 → v2 (T-122): набор фаз расширен (caravans/diplomacy/
		# production); v1-имена (settlement/player/threats/done)
		# сохраняются — пере-маппинг не нужен, только маркер версии.
		d["schema_version"] = 2
	return d


static func _phase_from_name(name: String) -> int:
	for p in PHASE_NAMES:
		if PHASE_NAMES[p] == name:
			return p
	return Phase.PLAYER  # неизвестное имя → безопасный дефолт (T-110)
