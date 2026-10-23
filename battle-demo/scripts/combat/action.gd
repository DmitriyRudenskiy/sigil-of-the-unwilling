class_name BattleAction extends RefCounted

## Одно действие одного юнита за один ход.

enum Kind { PASS, ATTACK, ABILITY }

var kind: int = Kind.PASS
var actor: BattleUnit
## Пусто для PASS. Для ABILITY пусто, если цель умерла, пока действие ждало очереди.
var targets: Array[BattleUnit] = []
## null для PASS и базовой атаки.
var ability: Ability = null
## Фактический урон по целям (uid -> сумма) — для журнала, синхронности и отладки.
var damage := {}


static func skip(actor: BattleUnit) -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.PASS
	action.actor = actor
	return action


static func attack(actor: BattleUnit, target: BattleUnit) -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.ATTACK
	action.actor = actor
	action.targets = [target]
	return action


static func use_ability(
	actor: BattleUnit, ability: Ability, targets: Array[BattleUnit]
) -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.ABILITY
	action.actor = actor
	action.ability = ability
	action.targets = targets
	return action
