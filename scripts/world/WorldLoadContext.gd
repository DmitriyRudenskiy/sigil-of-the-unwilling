class_name WorldLoadContext
extends RefCounted
## Struct carrying the subsystem references _apply_loaded_save needs.

var map_gen: MapGenerator
var spawner: WorldSpawner
var resource_node_manager: ResourceNodeManager
var ui_manager: WorldUIManager
var camera: WorldCamera
var hero: HeroController
var world_delta: WorldStateDelta
