class_name NeedType
extends RefCounted

enum ID { REST = 0, SOCIAL = 1, INSPIRATION = 2 }
const COUNT := 3

static var _strategies: Dictionary = {}
static func strategies() -> Dictionary:
	if _strategies.is_empty():
		_strategies = {
			ID.REST: RestStrategy.new(),
			ID.SOCIAL: SocialStrategy.new(),
			ID.INSPIRATION: InspirationStrategy.new(),
		}
	return _strategies

static func to_name(id: int) -> StringName:
	match id:
		ID.REST: return &"rest"
		ID.SOCIAL: return &"social"
		ID.INSPIRATION: return &"inspiration"
	return &""

static func from_name(value: Variant) -> int:
	match str(value):
		"rest": return ID.REST
		"social": return ID.SOCIAL
		"inspiration": return ID.INSPIRATION
		"belief": return ID.INSPIRATION # Legacy migration
	return -1

static func is_valid(id: int) -> bool: return id >= 0 and id < COUNT
static func all_ids() -> Array[int]: return [ID.REST, ID.SOCIAL, ID.INSPIRATION]
static func all_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in all_ids():
		out.append(to_name(id))
	return out
