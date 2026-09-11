extends Node
class_name GameEventBusAutoload

signal battle_started
signal battle_completed(winner: BattleState.Side, enemy_cell: Vector2i)
signal battle_won(enemy_cell: Vector2i)
signal battle_lost(enemy_cell: Vector2i)

signal village_captured(cell: Vector2i)
signal turn_ended(turn: int, month: int)
signal hero_moving_changed(moving: bool)

signal resource_discovered(cell: Vector2i, resource_id: StringName)
signal resource_extracted(cell: Vector2i, resource_id: StringName, amount: int)
signal resource_exhausted(cell: Vector2i, resource_id: StringName)

signal glory_earned(amount: float, reason: StringName)

signal production_completed(city_uid: int, chain_id: StringName, outputs: Dictionary)
signal resource_depleted(city_uid: int, resource_id: StringName)
signal upkeep_failed(building_uid: int, resource_id: StringName)

signal character_born(city_uid: int, char_uid: int)
signal character_died(city_uid: int, char_uid: int)
signal character_need_critical(char_uid: int, need_id: int)
signal disease_outbreak(city_uid: int, char_uid: int)

signal hero_died(cause: StringName)
signal hero_successor(hero: Node)

signal game_ended(result: String, reason: StringName, summary: Dictionary)

signal building_constructed(city_uid: int, building_uid: int)
signal scale_shift(city_uid: int, new_scale: int)
signal zone_violation(city_uid: int, cell: Vector2i)

signal reputation_changed(city_uid: int, value: int, band: int)
signal migration_occurred(city_uid: int, immigrants: int, emigrants: int)
signal city_level_up(city_uid: int, new_level: int)
signal raid_occurred(city_uid: int, repelled: bool)
signal trade_completed(city_uid: int, resource_id: StringName, amount: float, gold: float)
signal city_event_occurred(city_uid: int, event_id: StringName)
signal relocation_completed(city_uid: int, new_center: Vector2i)

signal chronicle_entry_added(entry_id: StringName, text: String)
signal weather_changed(new_weather: int)
signal faith_milestone(city_uid: int, level: int)
