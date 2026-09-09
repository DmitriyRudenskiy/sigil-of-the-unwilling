extends RefCounted
class_name HeroTools

signal tools_changed

static var _tool_types: Array[int] = []
static func tool_types() -> Array[int]:
	if _tool_types.is_empty():
		_tool_types = ToolType.all_ids()
	return _tool_types
const MAX_SLOTS := 8

var slots: Array[Dictionary] = []

func _init() -> void:
	for i in MAX_SLOTS:
		slots.append({})

func has_tool(tool_id: int) -> bool:
	for slot in slots:
		if slot.has("id") and slot.id == tool_id:
			return true
	return false

func get_tool_count(tool_id: int) -> int:
	var count := 0
	for slot in slots:
		if slot.has("id") and slot.id == tool_id:
			count += slot.get("quantity", 1)
	return count

func add_tool(tool_id: int, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if tool_id in [ToolType.ID.SKIN_PROTECTION, ToolType.ID.NET]:
		for slot in slots:
			if slot.has("id") and slot.id == tool_id:
				slot.quantity += quantity
				tools_changed.emit()
				return true
	for i in MAX_SLOTS:
		if slots[i].is_empty():
			slots[i] = {"id": tool_id, "quantity": quantity}
			tools_changed.emit()
			return true
	return false

func remove_tool(tool_id: int, quantity: int = 1) -> bool:
	var remaining := quantity
	for i in MAX_SLOTS:
		if remaining <= 0:
			break
		if slots[i].has("id") and slots[i].id == tool_id:
			var avail: int = int(slots[i].get("quantity", 1))
			if avail <= remaining:
				remaining -= avail
				slots[i] = {}
			else:
				slots[i].quantity -= remaining
				remaining = 0
	if remaining == 0:
		tools_changed.emit()
		return true
	return false

func get_empty_slots() -> int:
	var count := 0
	for slot in slots:
		if slot.is_empty():
			count += 1
	return count

func get_all() -> Array[Dictionary]:
	return slots.duplicate(true)

func clear() -> void:
	for i in MAX_SLOTS:
		slots[i] = {}
	tools_changed.emit()

func serialize() -> Array[Dictionary]:
	var out: Array[Dictionary] = slots.duplicate(true)
	for slot in out:
		if slot.has("id"):
			slot.id = ToolType.to_name(int(slot.id))
	return out

func deserialize(data: Array) -> void:
	slots.clear()
	for i in MAX_SLOTS:
		if i < data.size():
			var s: Dictionary = data[i].duplicate()
			if s.has("id"):
				s.id = ToolType.from_name(s.id)
			slots.append(s)
		else:
			slots.append({})
