class_name ShardManager
extends RefCounted

const SHARD_1_ID := &"shard_1"
const SHARD_2_ID := &"shard_2"
const SHARD_2_SEED := 0x2A1F3C7
const _ShardState = preload("res://scripts/core/ShardState.gd")
const _Self := preload("res://scripts/core/ShardManager.gd")

static var _instance: _Self = null

var active_id: StringName = SHARD_1_ID
var _shards: Dictionary = {}

func _init() -> void:
	add_shard(_ShardState.new(SHARD_1_ID, "Перворечье", 0, "mixed"))
	add_shard(_ShardState.new(SHARD_2_ID, "Забвение", SHARD_2_SEED, "waste"))

static func instance() -> _Self:
	if _instance == null:
		_instance = _Self.new()
	return _instance

static func reset() -> void:
	_instance = null

func add_shard(s: _ShardState) -> _ShardState:
	_shards[s.id] = s
	if active_id == &"":
		active_id = s.id
	return s

func get_shard(id: StringName) -> _ShardState:
	return _shards.get(id)

func get_active() -> _ShardState:
	return _shards.get(active_id)

func set_active(id: StringName) -> bool:
	if _shards.has(id):
		active_id = id
		return true
	return false

func shard_ids() -> Array:
	return _shards.keys().duplicate()

func list() -> Array:
	return _shards.values().duplicate()
