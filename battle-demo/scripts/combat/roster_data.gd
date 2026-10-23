class_name RosterData extends Resource

## Набор из семи юнитов упорядоченного пула.

@export var id: StringName
@export var title: String
## Чем набор отличается от другого — одна строка на экране выбора.
@export_multiline var difference: String = ""
## Позиции 1–7 или 2–8 упорядоченного пула. Порядок значим: он задаёт slot.
@export var units: Array[UnitStats] = []
