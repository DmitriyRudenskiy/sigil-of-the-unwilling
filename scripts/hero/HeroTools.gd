extends RefCounted
class_name HeroTools
## Separate 8-slot tool inventory.
## Tools: shovel, pickaxe, cart, skin_protection, net.

signal tools_changed

const TOOL_TYPES := ["shovel", "pickaxe", "cart", "skin_protection", "net"]
const MAX_SLOTS := 8

var slots: Array[Dictionary] = []


func _init() -> void:
	for i in MAX_SLOTS:
		slots.append({})


func has_tool(tool_id: StringName) -> bool:
	for slot in slots:
		if slot.has("id") and slot.id == tool_id:
			return true
	return false


func get_tool_count(tool_id: StringName) -> int:
	var count := 0
	for slot in slots:
		if slot.has("id") and slot.id == tool_id:
			count += slot.get("quantity", 1)
	return count


func add_tool(tool_id: StringName, quantity: int = 1) -> bool:
	"""Add tool to inventory. Consumables stack."""
	if quantity <= 0:
		return false

	# Try to stack consumables
	if tool_id in [&"skin_protection", &"net"]:
		for slot in slots:
			if slot.has("id") and slot.id == tool_id:
				slot.quantity += quantity
				tools_changed.emit()
				return true

	# Add to empty slot
	for i in MAX_SLOTS:
		if slots[i].is_empty():
			slots[i] = {"id": tool_id, "quantity": quantity}
			tools_changed.emit()
			return true

	return false  # Full


func remove_tool(tool_id: StringName, quantity: int = 1) -> bool:
	"""Remove tool from inventory."""
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
	return slots.duplicate(true)


func deserialize(data: Array) -> void:
	slots.clear()
	for i in MAX_SLOTS:
		if i < data.size():
			slots.append(data[i].duplicate())
		else:
			slots.append({})
	tools_changed.emit()
