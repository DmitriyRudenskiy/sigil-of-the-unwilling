## scripts/card/CardTemplateBootstrap.gd
## Autoload: registers all built-in card template handlers at project boot.
## This replaces the old _ensure_defaults() lazy init in CardTemplateEngine.
extends Node


func _ready() -> void:
	CardTemplateEngine.register_handler(&"DIRECT_DAMAGE", CardTemplateEngine.CardTemplateHandlers.t01_direct_damage)
	CardTemplateEngine.register_handler(&"HARD_REMOVAL", CardTemplateEngine.CardTemplateHandlers.t02_hard_removal)
	CardTemplateEngine.register_handler(&"BOUNCE", CardTemplateEngine.CardTemplateHandlers.t03_bounce)
	CardTemplateEngine.register_handler(&"COUNTERMAGIC", CardTemplateEngine.CardTemplateHandlers.t04_countermagic)
	CardTemplateEngine.register_handler(&"COMBAT_TRICK", CardTemplateEngine.CardTemplateHandlers.t05_combat_trick)
	CardTemplateEngine.register_handler(&"DEBUFF_CONTROL", CardTemplateEngine.CardTemplateHandlers.t06_debuff_control)
	CardTemplateEngine.register_handler(&"CARD_DRAW", CardTemplateEngine.CardTemplateHandlers.t07_card_draw)
	CardTemplateEngine.register_handler(&"MANA_RAMP", CardTemplateEngine.CardTemplateHandlers.t08_mana_ramp)
	CardTemplateEngine.register_handler(&"TOKEN_GENERATION", CardTemplateEngine.CardTemplateHandlers.t09_token_generation)
	CardTemplateEngine.register_handler(&"RELIC_INTERACTION", CardTemplateEngine.CardTemplateHandlers.t10_relic_interaction)
	CardTemplateEngine.register_handler(&"KEYWORD_BUFF", CardTemplateEngine.CardTemplateHandlers.t11_keyword_buff)
	CardTemplateEngine.register_handler(&"CHOICE_CYCLE", CardTemplateEngine.CardTemplateHandlers.t12_choice_cycle)
	CardTemplateEngine.register_handler(&"TOUCH_CYCLE", CardTemplateEngine.CardTemplateHandlers.t13_touch_cycle)
	CardTemplateEngine.register_handler(&"DISPLAY_CYCLE", CardTemplateEngine.CardTemplateHandlers.t14_display_cycle)
	CardTemplateEngine.register_handler(&"DISCARD_DRAW", CardTemplateEngine.CardTemplateHandlers.t15_discard_draw)
	CardTemplateEngine.register_handler(&"MARKET_NICHE", CardTemplateEngine.CardTemplateHandlers.t16_market_niche)
