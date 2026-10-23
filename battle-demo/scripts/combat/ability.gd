class_name Ability extends Resource

## Одна способность юнита. Базовая атака — отдельный вид действия (BattleAction
## .Kind.ATTACK), а не запись этого ресурса: cost = 0, mult = 1.0.

enum TargetKind { ENEMY_SINGLE, ENEMY_ALL, ALLY_SINGLE, ALLY_OTHERS }

@export var id: StringName
@export var display_name: String
## Расход focus.
@export var cost: int = 1
## Кулдаун в ходах владельца. 0 — без кулдауна.
@export var cooldown: int = 0
## Множитель атаки.
@export var multiplier: float = 1.0
## Доля защиты цели, которую игнорирует (0..1).
@export var defense_ignores: float = 0.0
## Количество ударов за одно применение.
@export var hits: int = 1
@export var target_kind: TargetKind = TargetKind.ENEMY_SINGLE
## false — способность только навешивает статусы (щит, благословение).
@export var deals_damage: bool = true
## Статусы на цель (id из BattleUnit.STATUSES).
@export var applies: Array[StringName] = []
## Статусы на самого исполнителя (цена приёма).
@export var self_applies: Array[StringName] = []
