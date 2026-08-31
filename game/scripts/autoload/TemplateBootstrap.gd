## scripts/data/TemplateBootstrap.gd
## Autoload: registers all built-in spell template handlers at project boot.
## This replaces the old _ensure_defaults() lazy init in TemplateEngine.
extends Node


func _ready() -> void:
	TemplateEngine.register_handler(&"DIRECT_DAMAGE", TemplateEngine.TemplateHandlers.t01_direct_damage)
	TemplateEngine.register_handler(&"HARD_REMOVAL", TemplateEngine.TemplateHandlers.t02_hard_removal)
	TemplateEngine.register_handler(&"BOUNCE", TemplateEngine.TemplateHandlers.t03_bounce)
	TemplateEngine.register_handler(&"COUNTERMAGIC", TemplateEngine.TemplateHandlers.t04_countermagic)
	TemplateEngine.register_handler(&"COMBAT_TRICK", TemplateEngine.TemplateHandlers.t05_combat_trick)
	TemplateEngine.register_handler(&"DEBUFF_CONTROL", TemplateEngine.TemplateHandlers.t06_debuff_control)
	TemplateEngine.register_handler(&"SPELL_DRAW", TemplateEngine.TemplateHandlers.t07_spell_draw)
	TemplateEngine.register_handler(&"MANA_RAMP", TemplateEngine.TemplateHandlers.t08_mana_ramp)
	TemplateEngine.register_handler(&"TOKEN_GENERATION", TemplateEngine.TemplateHandlers.t09_token_generation)
	TemplateEngine.register_handler(&"RELIC_INTERACTION", TemplateEngine.TemplateHandlers.t10_relic_interaction)
	TemplateEngine.register_handler(&"KEYWORD_BUFF", TemplateEngine.TemplateHandlers.t11_keyword_buff)
	TemplateEngine.register_handler(&"CHOICE_CYCLE", TemplateEngine.TemplateHandlers.t12_choice_cycle)
	TemplateEngine.register_handler(&"TOUCH_CYCLE", TemplateEngine.TemplateHandlers.t13_touch_cycle)
	TemplateEngine.register_handler(&"DISPLAY_CYCLE", TemplateEngine.TemplateHandlers.t14_display_cycle)
	TemplateEngine.register_handler(&"DISPEL_DRAW", TemplateEngine.TemplateHandlers.t15_dispel_draw)
	TemplateEngine.register_handler(&"MARKET_NICHE", TemplateEngine.TemplateHandlers.t16_market_niche)
