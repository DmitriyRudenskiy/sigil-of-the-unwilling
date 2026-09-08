class_name ToolType
extends RefCounted

enum ID { SHOVEL = 0, PICKAXE = 1, CART = 2, SKIN_PROTECTION = 3, NET = 4 }
const COUNT := 5

static func to_name(id: int) -> StringName:
	match id:
		ID.SHOVEL: return &"shovel"
		ID.PICKAXE: return &"pickaxe"
		ID.CART: return &"cart"
		ID.SKIN_PROTECTION: return &"skin_protection"
		ID.NET: return &"net"
	return &""

static func from_name(value: Variant) -> int:
	match str(value):
		"shovel": return ID.SHOVEL
		"pickaxe": return ID.PICKAXE
		"cart": return ID.CART
		"skin_protection": return ID.SKIN_PROTECTION
		"net": return ID.NET
	return -1

static func is_valid(id: int) -> bool: return id >= 0 and id < COUNT
static func all_ids() -> Array[int]: return [ID.SHOVEL, ID.PICKAXE, ID.CART, ID.SKIN_PROTECTION, ID.NET]
static func all_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in all_ids():
		out.append(to_name(id))
	return out
