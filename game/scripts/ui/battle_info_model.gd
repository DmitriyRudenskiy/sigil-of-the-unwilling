class_name BattleInfoModel
extends RefCounted

## Экран боя (3.4): все правила D&D видны без подсказок (справка — по клавише).
## Headless-проекции активных правил/модификаторов для пары бойцов — слой
## данных, который боевой UI показывает без скрытых подсказок.
##
## Чистые чтения (без мутации состояния боя): данные — из бойцов (Dictionary),
## разбивка margin — через CampaignBattle.strike_breakdown.

const Battle = preload("res://scripts/campaign/campaign_battle.gd")


## Разбивка перевеса удара (все компоненты margin + зона). Чистая проекция.
static func strike_info(atk: Dictionary, def_: Dictionary, flank_bonus: int = 0) -> Dictionary:
	return Battle.strike_breakdown(atk, def_, flank_bonus)


## Активные правила/модификаторы для пары (что видно в бою, 3.4).
## Возвращает список id активных условий (не «ноль-маржа», а сами условия).
static func active_rules(atk: Dictionary, def_: Dictionary, flank_bonus: int = 0) -> Array:
	var rules: Array = []
	if bool(atk.get("prone", false)) or bool(def_.get("prone", false)):
		rules.append("prone")
	if bool(atk.get("elevated", false)) or bool(def_.get("elevated", false)):
		rules.append("elevated")
	var at: String = str(atk.get("terrain", ""))
	var dt: String = str(def_.get("terrain", ""))
	if at != "":
		rules.append("terrain_%s" % at)
	if dt != "":
		rules.append("terrain_%s" % dt)
	if flank_bonus != 0:
		rules.append("flank")
	if int(atk.get("hunger_penalty", 0)) != 0:
		rules.append("hunger")
	if int(atk.get("fate_debt", 0)) >= 1:
		rules.append("fate_debt")
	return rules


## Карточка бойца для UI: {id, hp, state, attack, ac, luck, terrain, prone,
## elevated, fate_debt}.
static func combatant_card(c: Dictionary) -> Dictionary:
	return {
		"id": str(c.get("id", "")),
		"hp": int(c.get("hp", 0)),
		"state": str(c.get("state", "ready")),
		"attack": int(c.get("attack", 0)),
		"ac": int(c.get("ac", 0)),
		"luck": int(c.get("luck", 0)),
		"terrain": str(c.get("terrain", "")),
		"prone": bool(c.get("prone", false)),
		"elevated": bool(c.get("elevated", false)),
		"fate_debt": int(c.get("fate_debt", 0)),
	}
