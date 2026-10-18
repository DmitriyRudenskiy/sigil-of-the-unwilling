class_name SignSystem
extends RefCounted
## signs-prestige 2.1/2.2 (T-129): SM знака + фракционные действия.
## Канон: 02-mechanics §3.7, 02c; K-M16 (Престиж = ledger); Q-M32 (все 8 знаков).
##
## SM знака: DORMANT → ACTIVE (выбор) → SLEEPING (Престиж ≤ 0) → ACTIVE (Престиж > 0).
## SLEEPING ≠ game over (кампания продолжается). TRIAL — Post-MVP.
##
## Фракционные действия: ≤12 за кампанию (faction_actions_max из prestige.json);
## штраф стиля — только за повтор (то же id); 13-е → без начисления.
## Счётчик в ledger-секции сейва ("sign" → "faction_actions_used").
##
## I1: детерминизм — ни ГСЧ; входы (id, amount, turn) → байт-идентичный результат.

const STATE_DORMANT := "DORMANT"
const STATE_ACTIVE := "ACTIVE"
const STATE_SLEEPING := "SLEEPING"

## Id выбранного знака (spark/time/balance/primal/shadow/harmony/cycle/basis).
## "" — не выбран (DORMANT).
var sign_id: String = ""
## Состояние SM (DORMANT/ACTIVE/SLEEPING).
var sign_state: String = STATE_DORMANT
## Счётчик фракционных действий за кампанию (≤ faction_actions_max).
var faction_actions_used: int = 0
## Лимит фракционных действий (из prestige.json, дефолт 12).
var faction_actions_max: int = 12
## Последнее фракционное действие (id) — для детекции повтора (штраф стиля).
var _last_action_id: String = ""
## Журнал фракционных действий (детерминированный; для аудита/тестов).
var action_log: Array = []


## DORMANT→ACTIVE (выбор знака). Один знак на носителя (инвариант):
## повторный вызов — no-op.
func select_sign(id: String) -> void:
	if sign_id != "":
		return  # уже выбран
	sign_id = id
	sign_state = STATE_ACTIVE


## Осталось фракционных действий (для UI «N осталось»).
func faction_actions_remaining() -> int:
	return maxi(0, faction_actions_max - faction_actions_used)


## Фракционное действие: ≤12 за кампанию; штраф стиля только за повтор.
## Возвращает amount (0 если: SLEEPING/DORMANT, лимит исчерпан, повтор).
## Вызов записывает действие в журнал и инкрементирует счётчик (даже при штрафе).
func perform_faction_action(id: String, amount: int, turn: int) -> int:
	if sign_state != STATE_ACTIVE:
		return 0  # SLEEPING/DORMANT — действия недоступны
	if faction_actions_used >= faction_actions_max:
		return 0  # 13-е → без начисления (счётчик не растёт)
	faction_actions_used += 1
	var is_repeat := (_last_action_id != "" and id == _last_action_id)
	_last_action_id = id
	action_log.append({"turn": turn, "id": id, "amount": amount, "repeat": is_repeat})
	if is_repeat:
		return 0  # штраф стиля: без начисления
	return amount


## SM: ACTIVE→SLEEPING (Престиж ≤ 0); SLEEPING→ACTIVE (Престиж > 0).
## SLEEPING ≠ game over. Вызывается при каждом изменении баланса Престижа.
func on_prestige_changed(balance: int) -> void:
	if sign_state == STATE_ACTIVE and balance <= 0:
		sign_state = STATE_SLEEPING
	elif sign_state == STATE_SLEEPING and balance > 0:
		sign_state = STATE_ACTIVE


## Смерть носителя: знак потерян (MVP: передача нет). SM → DORMANT.
## Кампания продолжается (R1: «утрата», −2 к спасам, K-M11).
func bearer_died() -> void:
	sign_state = STATE_DORMANT


func to_dict() -> Dictionary:
	return {
		"sign_id": sign_id,
		"state": sign_state,
		"faction_actions_used": faction_actions_used,
		"faction_actions_max": faction_actions_max,
		"last_action_id": _last_action_id,
	}


static func from_dict(data: Dictionary) -> SignSystem:
	var s := SignSystem.new()
	if data.is_empty():
		return s
	s.sign_id = str(data.get("sign_id", ""))
	s.sign_state = str(data.get("state", STATE_DORMANT))
	s.faction_actions_used = int(data.get("faction_actions_used", 0))
	s.faction_actions_max = int(data.get("faction_actions_max", 12))
	s._last_action_id = str(data.get("last_action_id", ""))
	return s
