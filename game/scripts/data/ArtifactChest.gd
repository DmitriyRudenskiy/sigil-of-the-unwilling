extends Resource
class_name ArtifactChest
## World chest: spawns on map, contains one artifact + gold fallback.

@export var id: String = ""
@export var artifact: Artifact = null
@export var gold_reward: int = 50
@export var is_opened: bool = false
@export var cell: Vector2i = Vector2i(-1, -1)


func open() -> void:
    is_opened = true
