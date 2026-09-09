class_name StaticCaches

static func reset_all() -> void:
	HexUtils.reset()
	ShardManager.reset()
	ArenaClusterSystem.reset()
	ResourceIcons.clear_cache()
	UnitSprites.clear_caches()
	PlaceholderTexture.clear()
	ResourceAtlas.clear()
	TileAtlasCache.clear_cache()

	var services: Variant = Services
	if services != null:
		var persistence: Variant = services.resolve(&"persistence")
		if persistence != null:
			persistence.reset_session_state()
