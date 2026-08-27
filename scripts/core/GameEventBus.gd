extends Node
## Глобальная шина событий (autoload: GameEventBus).
## Все кросс-системные события проходят через эту шину.

# ==================== БОЙ ====================
signal battle_started
signal battle_completed(winner: String, enemy_cell: Vector2i)
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
