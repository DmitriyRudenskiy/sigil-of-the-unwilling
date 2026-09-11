class_name StaticCaches

static func reset_all() -> void:
	HexGrid.shift_right = true
	ShardManager.reset()
	ArenaClusterSystem.reset()
	ResourceIcons.clear_cache()
	BuildingDefs.reset_cache()  # TASK_19_1 R2
	UnitSprites.clear_caches()
	PlaceholderTexture.clear()
	ResourceAtlas.clear()
	TileAtlasCache.clear_cache()

	var services: Variant = Services
	if services != null:
		var persistence: Variant = services.resolve(&"persistence")
		if persistence != null:
			persistence.reset_session_state()
