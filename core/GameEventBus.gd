extends Node
## Глобальная шина событий (autoload: GameEventBus).
## Все кросс-системные события проходят через эту шину.

# ==================== БОЙ ====================
signal battle_started
signal battle_completed(winner: BattleState.Side, enemy_cell: Vector2i)
signal battle_won(enemy_cell: Vector2i)
signal battle_lost(enemy_cell: Vector2i)

# ==================== МИР ====================
signal village_captured(cell: Vector2i)
signal turn_ended(turn: int, month: int)

# ==================== РЕСУРСЫ ====================
signal resource_discovered(cell: Vector2i, resource_id: StringName)
signal resource_extracted(cell: Vector2i, resource_id: StringName, amount: int)
signal resource_exhausted(cell: Vector2i, resource_id: StringName)

# ==================== СЛАВА ====================
signal glory_earned(amount: float, reason: StringName)

# ==================== ЭКОНОМИКА (M1) ====================
signal production_completed(city_uid: int, chain_id: StringName, outputs: Dictionary)
signal resource_depleted(city_uid: int, resource_id: StringName)
signal upkeep_failed(building_uid: int, resource_id: StringName)

# ==================== ДЕМОГРАФИЯ (M2) ====================
signal character_born(city_uid: int, char_uid: int)
signal character_died(city_uid: int, char_uid: int)
signal character_need_critical(char_uid: int, need_id: StringName)
signal disease_outbreak(city_uid: int, char_uid: int)

# ==================== ГОРОД (M3) ====================
signal building_constructed(city_uid: int, building_uid: int)
signal scale_shift(city_uid: int, new_scale: int)
signal zone_violation(city_uid: int, cell: Vector2i)

# ==================== НАРРАТИВ (M5) ====================
signal chronicle_entry_added(entry_id: StringName, text: String)
signal weather_changed(new_weather: int)
signal faith_milestone(city_uid: int, level: int)
