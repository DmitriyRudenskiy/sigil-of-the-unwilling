class_name StaticCaches
## Единый реестр статических кэшей проекта.
## Сброс на границе сессии вызывается только отсюда (Services.clear_session).
## При добавлении нового static-кэша — регистрируйте его в reset_all().

# Не сбрасываем TemplateEngine._handlers: это не сессионный кэш, а
# per-process конфигурация (регистр один раз в TemplateBootstrap._ready),
# сброс сломал бы шаблоны в следующей сессии.
static func reset_all() -> void:
	HexUtils.reset()
	ShardManager.reset()
	ArenaClusterSystem.reset()
	ResourceIcons.clear_cache()
	UnitSprites.clear_caches()
	PlaceholderTexture.clear()
	ResourceAtlas.clear()
	TileAtlasCache.clear_cache()
