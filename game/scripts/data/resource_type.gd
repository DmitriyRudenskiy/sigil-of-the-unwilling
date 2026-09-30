
class_name ResourceType
extends RefCounted

enum ID {
    WOOD = 0,
    MERCURY = 1,
    ORE = 2,
    SULFUR = 3,
    CRYSTAL = 4,
    GEMS = 5,
    GOLD = 6,

    STONE = 7,
}

const CLASSIC_COUNT := 7

const _START_AMOUNTS := {
    ID.WOOD: 10,
    ID.MERCURY: 2,
    ID.ORE: 10,
    ID.SULFUR: 2,
    ID.CRYSTAL: 2,
    ID.GEMS: 2,
    ID.GOLD: 500,
}

static func all_ids() -> Array[int]:
    var out: Array[int] = []
    out.assign(ID.values())
    return out

static func classic_ids() -> Array[int]:
    var out: Array[int] = []
    for i in CLASSIC_COUNT:
        out.append(i)
    return out

static func is_valid(id: int) -> bool:
    return id >= 0 and id < ID.size()

static func to_name(id: int) -> StringName:
    if not is_valid(id):
        return &""
    return StringName(_key_of(id))

static func to_key(id: int) -> String:
    return _key_of(id) if is_valid(id) else ""

static func from_name(value: Variant) -> int:
    return ID.get(str(value).to_upper(), -1)

static func start_amount(id: int) -> int:
    return int(_START_AMOUNTS.get(id, 0))

static func pickup_amount(id: int) -> int:
    if id == ID.GOLD:
        return 50
    return 5 if is_valid(id) else 0

static func _key_of(id: int) -> String:
    return ID.keys()[id].to_lower()
