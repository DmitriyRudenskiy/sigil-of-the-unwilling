class_name WorldLoadContext
extends RefCounted

var map_gen: MapGenerator
var spawner: WorldSpawner
var resource_node_manager: ResourceNodeManager
var terrain_resource_manager: Variant = null
var ui_manager: WorldUIManager
var camera: WorldCamera
var hero: HeroController
var world_delta: WorldStateDelta
var cities: Node = null
var character_registry: CharacterRegistry = null
