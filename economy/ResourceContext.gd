class_name ResourceContext
extends RefCounted
## Глобальное хранилище ресурсов (M1: Экономика).
##
## Единый словарь id -> количество с лимитами по типу.
## Используется процессором экономики для городских цепочек
## (production_chain) и поддержки (upkeep). Работает с любыми
## StringName-идентификаторами: для неизвестных id автоматически
## создаётся запись с безлимитной ёмкостью (реестр можно расширять
## без изменения контекста).
##
## НЕ зависит от узлов Godot — сериализуется в Dictionary (JSON-совместимо).

signal resource_changed(id: StringName, old_val: float, new_val: float)
signal capacity_reached(id: StringName)

var _resources: Dictionary = {}  # StringName -> float
var _capacities: Dictionary = {}  # StringName -> float (INF = без лимита)


## Инициализация лимитов из определений ресурсов.
## Неизвестные id появятся автоматически при первом add() с INF-лимитом.
func setup(defs: Array) -> void:
	for def in defs:
		if def == null:
			continue
		var cap: float = float(get_def_capacity(def))
		if not _capacities.has(def.id):
			_capacities[def.id] = cap


static func get_def_capacity(def: ResourceDef) -> float:
	return def.capacity if def.capacity > 0.0 else INF


## Остаток ресурса (0.0, если нет). Имя не get() — чтобы не переопределять
## нативный Object.get(), который в проекте запрещён предупреждением-ошибкой.
func amount(id: StringName) -> float:
	return float(_resources.get(id, 0.0))


func get_all() -> Dictionary:
	return _resources.duplicate()


func has(id: StringName) -> bool:
	return _resources.has(id) and amount(id) > 0.0


func is_empty() -> bool:
	for id in _resources:
		if amount(id) > 0.0:
			return false
	return true


## Добавляет ресурсы с учётом лимита.
## Возвращает ФАКТИЧЕСКИ добавленное количество (может быть 0.0).
func add(id: StringName, add_amount: float) -> float:
	if add_amount <= 0.0:
		return 0.0
	if not _capacities.has(id):
		_capacities[id] = INF
	var old: float = amount(id)
	var cap: float = _capacities[id]
	var new_val: float = minf(old + add_amount, cap)
	var actual: float = maxf(new_val - old, 0.0)
	_resources[id] = new_val
	resource_changed.emit(id, old, new_val)
	if new_val >= cap and actual < add_amount:
		capacity_reached.emit(id)
	return actual


## Снимает ресурсы. Возвращает фактический снятый объём (0.0, если пусто).
func remove(id: StringName, remove_amount: float) -> float:
	if remove_amount <= 0.0:
		return 0.0
	var old: float = amount(id)
	var actual: float = minf(remove_amount, old)
	_resources[id] = old - actual
	resource_changed.emit(id, old, old - actual)
	return actual


func get_capacity(id: StringName) -> float:
	return float(_capacities.get(id, INF))


func set_capacity(id: StringName, cap: float) -> void:
	_capacities[id] = cap
	# Урежем текущий запас, если он превысил новый лимит.
	var cur: float = amount(id)
	if cur > cap:
		_resources[id] = cap
		resource_changed.emit(id, cur, cap)


## Можно ли покрыть набор {id: amount} текущими остатками?
func can_afford(costs: Dictionary) -> bool:
	for id in costs:
		if amount(id) < float(costs[id]):
			return false
	return true


## Списание набора ресурсов. Возвращает true только если списано ВСЁ.
func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for id in costs:
		remove(id, float(costs[id]))
	return true


## Сериализация в JSON-совместимый словарь: {id: amount, ...}.
func serialize() -> Dictionary:
	var out := {}
	for id in _resources:
		out[String(id)] = amount(id)
	return out


## Восстановление из словаря (ключи — String или StringName).
func deserialize(data: Dictionary) -> void:
	_resources.clear()
	for id in data:
		_resources[StringName(id)] = float(data[id])
