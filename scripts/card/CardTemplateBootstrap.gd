## scripts/card/CardTemplateBootstrap.gd
## Autoload: registers all built-in card template handlers at project boot.
## This replaces the old _ensure_defaults() lazy init in CardTemplateEngine.
extends Node


func _ready() -> void:
	var engine := CardTemplateEngine.new()
	engine.register_handler(&"DIRECT_DAMAGE", CardTemplateEngine.CardTemplateHandlers.t01_direct_damage)
	engine.register_handler(&"HARD_REMOVAL", CardTemplateEngine.CardTemplateHandlers.t02_hard_removal)
	engine.register_handler(&"BOUNCE", CardTemplateEngine.CardTemplateHandlers.t03_bounce)
	engine.register_handler(&"COUNTERMAGIC", CardTemplateEngine.CardTemplateHandlers.t04_countermagic)
	engine.register_handler(&"COMBAT_TRICK", CardTemplateEngine.CardTemplateHandlers.t05_combat_trick)
	engine.register_handler(&"DEBUFF_CONTROL", CardTemplateEngine.CardTemplateHandlers.t06_debuff_control)
	engine.register_handler(&"CARD_DRAW", CardTemplateEngine.CardTemplateHandlers.t07_card_draw)
	engine.register_handler(&"MANA_RAMP", CardTemplateEngine.CardTemplateHandlers.t08_mana_ramp)
	engine.register_handler(&"TOKEN_GENERATION", CardTemplateEngine.CardTemplateHandlers.t09_token_generation)
	engine.register_handler(&"RELIC_INTERACTION", CardTemplateEngine.CardTemplateHandlers.t10_relic_interaction)
	engine.register_handler(&"KEYWORD_BUFF", CardTemplateEngine.CardTemplateHandlers.t11_keyword_buff)
	engine.register_handler(&"CHOICE_CYCLE", CardTemplateEngine.CardTemplateHandlers.t12_choice_cycle)
	engine.register_handler(&"TOUCH_CYCLE", CardTemplateEngine.CardTemplateHandlers.t13_touch_cycle)
	engine.register_handler(&"DISPLAY_CYCLE", CardTemplateEngine.CardTemplateHandlers.t14_display_cycle)
	engine.register_handler(&"DISCARD_DRAW", CardTemplateEngine.CardTemplateHandlers.t15_discard_draw)
	engine.register_handler(&"MARKET_NICHE", CardTemplateEngine.CardTemplateHandlers.t16_market_niche)
