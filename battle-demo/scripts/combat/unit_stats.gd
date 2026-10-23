class_name UnitStats extends Resource

## Статическое описание юнита. Экземпляр в бою — BattleUnit.

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 80
@export var attack: int = 12
@export var defense: int = 6
## Место в общей очереди ходов; больше = ходит раньше.
@export var initiative: int = 10
@export var abilities: Array[Ability] = []
