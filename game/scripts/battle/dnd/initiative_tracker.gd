class_name DNDInitiativeTracker

## D&D 5e Initiative System
# Handles initiative rolling and turn order management

const MAX_COMBATANTS = 20

# Combatant entry
class CombatantEntry:
var id: String
var name: String
var initiative: int = 0
var dexterity_mod: int = 0
var bonus: int = 0
var has_taken_turn: bool = false
var is_active: bool = true

func _init(p_id: String, p_name: String, p_dex_mod: int = 0):
id = p_id
name = p_name
dexterity_mod = p_dex_mod

func to_dict() -> Dictionary:
return {
"id": id,
"name": name,
"initiative": initiative,
"dexterity_mod": dexterity_mod,
"bonus": bonus,
"has_taken_turn": has_taken_turn,
"is_active": is_active
}

static func from_dict(data: Dictionary) -> CombatantEntry:
var entry = CombatantEntry.new(data["id"], data.get("name", "Unknown"), data.get("dexterity_mod", 0))
entry.initiative = data.get("initiative", 0)
entry.bonus = data.get("bonus", 0)
entry.has_taken_turn = data.get("has_taken_turn", false)
entry.is_active = data.get("is_active", true)
return entry

# Turn order (sorted by initiative desc, then dex mod desc)
var turn_order: Array[CombatantEntry] = []
var current_turn_index: int = 0
var current_round: int = 1


func _init():
pass


## Roll initiative for a combatant
func roll_initiative(combatant_id: String, combatant_name: String, 
 dexterity_mod: int, rng: RandomNumberGenerator, 
 bonus: int = 0) -> int:

var entry = CombatantEntry.new(combatant_id, combatant_name, dexterity_mod)
entry.bonus = bonus

# Initiative = d20 + DEX mod + bonus
var d20_roll = rng.randi_range(1, 20)
entry.initiative = d20_roll + dexterity_mod + bonus

turn_order.append(entry)

# Sort by initiative (desc), then by dexterity mod (desc)
_sort_turn_order()

return entry.initiative


## Sort turn order
func _sort_turn_order():
turn_order.sort_custom(func(a: CombatantEntry, b: CombatantEntry) -> bool:
if a.initiative != b.initiative:
return a.initiative > b.initiative
return a.dexterity_mod > b.dexterity_mod
)


## Add existing combatant (without rolling)
func add_combatant(combatant_id: String, combatant_name: String, 
   initiative_value: int, dexterity_mod: int = 0) -> CombatantEntry:

var entry = CombatantEntry.new(combatant_id, combatant_name, dexterity_mod)
entry.initiative = initiative_value
turn_order.append(entry)
_sort_turn_order()
return entry


## Remove a combatant from initiative
func remove_combatant(combatant_id: String) -> bool:
for i in range(turn_order.size()):
if turn_order[i].id == combatant_id:
turn_order.remove_at(i)
# Adjust current turn index if needed
if i < current_turn_index:
current_turn_index -= 1
elif i == current_turn_index and current_turn_index >= turn_order.size():
current_turn_index = 0
return true
return false


## Mark combatant as inactive (but keep in order)
func deactivate_combatant(combatant_id: String):
for entry in turn_order:
if entry.id == combatant_id:
entry.is_active = false
break


## Get next combatant in turn order
func next_turn() -> CombatantEntry:
if turn_order.is_empty():
return null

# Find next active combatant
var checks = 0
while checks < turn_order.size():
var entry = turn_order[current_turn_index]
current_turn_index = (current_turn_index + 1) % turn_order.size()

if entry.is_active:
# Reset has_taken_turn for all when we loop back to start
if current_turn_index == 0:
current_round += 1
for e in turn_order:
e.has_taken_turn = false
return entry

checks += 1

return null


## Get current combatant
func get_current_combatant() -> CombatantEntry:
if turn_order.is_empty():
return null

# Find current active combatant
var index = current_turn_index
var checks = 0

while checks < turn_order.size():
var entry = turn_order[index]
if entry.is_active:
return entry
index = (index + 1) % turn_order.size()
checks += 1

return turn_order[0] if not turn_order.is_empty() else null


## Check if it's a specific combatant's turn
func is_combatant_turn(combatant_id: String) -> bool:
var current = get_current_combatant()
return current != null and current.id == combatant_id


## Mark current combatant's turn as complete
func end_turn():
var current = get_current_combatant()
if current:
current.has_taken_turn = true


## Get initiative count (for delayed actions)
func get_initiative_count() -> int:
var current = get_current_combatant()
if current:
return current.initiative
return 0


## Reset all turns (new round)
func reset_rounds():
current_round = 1
current_turn_index = 0
for entry in turn_order:
entry.has_taken_turn = false


## Get turn order as array of dictionaries
func get_turn_order() -> Array[Dictionary]:
var result: Array[Dictionary] = []
for entry in turn_order:
result.append(entry.to_dict())
return result


## Clear all combatants
func clear():
turn_order.clear()
current_turn_index = 0
current_round = 1


## Serialize to dictionary
func to_dict() -> Dictionary:
var entries: Array[Dictionary] = []
for entry in turn_order:
entries.append(entry.to_dict())

return {
"turn_order": entries,
"current_turn_index": current_turn_index,
"current_round": current_round
}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> DNDInitiativeTracker:
var tracker = DNDInitiativeTracker.new()
tracker.current_turn_index = data.get("current_turn_index", 0)
tracker.current_round = data.get("current_round", 1)

var entries_data = data.get("turn_order", [])
for entry_data in entries_data:
var entry = CombatantEntry.from_dict(entry_data)
tracker.turn_order.append(entry)

return tracker
