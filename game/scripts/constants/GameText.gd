class_name GameText
extends RefCounted

static func menu_new_game() -> String: return TranslationServer.translate("menu.new_game")
static func menu_load_game() -> String: return TranslationServer.translate("menu.load_game")
static func menu_arena() -> String: return TranslationServer.translate("menu.arena")
static func menu_model_warrior() -> String: return TranslationServer.translate("menu.model_warrior")
static func menu_model_mage() -> String: return TranslationServer.translate("menu.model_mage")
static func menu_settings() -> String: return TranslationServer.translate("menu.settings")
static func menu_chronicle() -> String: return TranslationServer.translate("menu.chronicle")
static func menu_exit() -> String: return TranslationServer.translate("menu.exit")
static func menu_version() -> String: return TranslationServer.translate("menu.version")
static func model_hero_warrior() -> String: return TranslationServer.translate("model.hero_warrior")

static func building_name(id: StringName) -> String:
	return TranslationServer.translate("building." + str(id))
static func arena_founded() -> String: return TranslationServer.translate("arena.founded")
static func arena_palette_item(emoji: String, name: String, cost: String) -> String:
	return TranslationServer.translate("arena.palette_item").format({"emoji": emoji, "name": name, "cost": cost})
static func arena_borough_cost() -> String: return TranslationServer.translate("arena.borough_cost")
static func arena_cost(n: int) -> String: return TranslationServer.translate("arena.cost").format({"n": n})
static func arena_selected(name: String) -> String:
	return TranslationServer.translate("arena.selected").format({"name": name})
static func arena_nothing() -> String: return TranslationServer.translate("arena.nothing")
static func arena_selection(emoji: String, name: String) -> String:
	return TranslationServer.translate("arena.selection").format({"emoji": emoji, "name": name})
static func arena_cluster_badge(n: int) -> String: return TranslationServer.translate("arena.cluster_badge").format({"n": n})
static func arena_borough_built() -> String: return TranslationServer.translate("arena.borough_built")
static func arena_borough_not_built() -> String: return TranslationServer.translate("arena.borough_not_built")
static func arena_borough_reason(reason: String) -> String:
	return TranslationServer.translate("arena.borough_reason").format({"reason": reason})
static func arena_ruins(n: String) -> String: return TranslationServer.translate("arena.ruins").format({"n": n})
static func arena_built(name: String, cost: int, ruins: String) -> String:
	return TranslationServer.translate("arena.built").format({"name": name, "cost": cost, "ruins": ruins})
static func arena_not_built(reason: String) -> String:
	return TranslationServer.translate("arena.not_built").format({"reason": reason})
static func arena_borough_info(level: int) -> String:
	return TranslationServer.translate("arena.borough_info").format({"level": level})
static func arena_upgraded(name: String, level: int) -> String:
	return TranslationServer.translate("arena.upgraded").format({"name": name, "level": level})
static func arena_upgrade_failed(reason: String) -> String:
	return TranslationServer.translate("arena.upgrade_failed").format({"reason": reason})
static func arena_cell_info(x: int, y: int, ring: int) -> String:
	return TranslationServer.translate("arena.cell_info").format({"x": x, "y": y, "ring": ring})
static func arena_ring_outputs(list_text: String) -> String:
	return TranslationServer.translate("arena.ring_outputs").format({"list": list_text})
static func arena_cluster_note() -> String: return TranslationServer.translate("arena.cluster_note")
static func arena_building_tip(name: String, level: int, ring: String, total: String, cluster: String, workers: int) -> String:
	return TranslationServer.translate("arena.building_tip").format({
		"name": name, "level": level, "ring": ring, "total": total,
		"cluster": cluster, "workers": workers})
static func arena_borough_tip(level: int, approval: int) -> String:
	return TranslationServer.translate("arena.borough_tip").format({"level": level, "approval": approval})
static func arena_stop() -> String: return TranslationServer.translate("arena.stop")
static func arena_auto_started() -> String: return TranslationServer.translate("arena.auto_started")
static func arena_storm_info(mult: String, food: String) -> String:
	return TranslationServer.translate("arena.storm_info").format({"mult": mult, "food": food})
static func arena_turn_log(turn: int, food: String, netto: String, prosperity: String, level: int, warn: String, clusters: String) -> String:
	return TranslationServer.translate("arena.turn_log").format({
		"turn": turn, "food": food, "netto": netto, "prosperity": prosperity,
		"level": level, "warn": warn, "clusters": clusters})
static func arena_worker_hired(pop: int) -> String:
	return TranslationServer.translate("arena.worker_hired").format({"pop": pop})
static func arena_no_worker() -> String: return TranslationServer.translate("arena.no_worker")
static func arena_level_up(level: int, radius: int) -> String:
	return TranslationServer.translate("arena.level_up").format({"level": level, "radius": radius})
static func arena_level_reasons(reasons: String) -> String:
	return TranslationServer.translate("arena.level_reasons").format({"reasons": reasons})
static func arena_cluster_mark(n: int) -> String: return TranslationServer.translate("arena.cluster_mark").format({"n": n})
static func arena_hud(turn: int, food: String, netto: String, industry: String, gold: String,
		pop: int, prosperity: String, level: int, storm: String, cluster: String) -> String:
	return TranslationServer.translate("arena.hud").format({
		"turn": turn, "food": food, "netto": netto, "industry": industry, "gold": gold,
		"pop": pop, "prosperity": prosperity, "level": level, "storm": storm, "cluster": cluster})
static func arena_score(n: String) -> String: return TranslationServer.translate("arena.score").format({"n": n})
static func model_hero_mage() -> String: return TranslationServer.translate("model.hero_mage")

static func battle_select_unit() -> String: return TranslationServer.translate("battle.select_unit")
static func battle_your_turn() -> String: return TranslationServer.translate("battle.your_turn")
static func battle_enemy_turn() -> String: return TranslationServer.translate("battle.enemy_turn")
static func battle_retreat() -> String: return TranslationServer.translate("battle.retreat")
static func battle_wait() -> String: return TranslationServer.translate("battle.wait")
static func battle_attack() -> String: return TranslationServer.translate("battle.attack")
static func battle_defend() -> String: return TranslationServer.translate("battle.defend")
static func battle_skip() -> String: return TranslationServer.translate("battle.skip")
static func battle_retaliation() -> String: return TranslationServer.translate("battle.retaliation")
static func battle_high_morale() -> String: return TranslationServer.translate("battle.high_morale")
static func battle_luck() -> String: return TranslationServer.translate("battle.luck")
static func battle_killed(count: int) -> String: return TranslationServer.translate("battle.killed").format({"n": count})
static func battle_spell_label(id: StringName) -> String: return TranslationServer.translate("battle.spell_label").format({"id": id})
static func battle_retreat_confirm() -> String: return TranslationServer.translate("battle.retreat_confirm")
static func battle_defend_bonus() -> String: return TranslationServer.translate("battle.defend_bonus")
static func battle_damage_preview(dmin: int, dmax: int, kmin: int, kmax: int) -> String:
	return TranslationServer.translate("battle.damage_preview").format({"dmin": dmin, "dmax": dmax, "kmin": kmin, "kmax": kmax})
static func battle_move_help(name: String) -> String: return TranslationServer.translate("battle.move_help").format({"name": name})
static func battle_click_enemy() -> String: return TranslationServer.translate("battle.click_enemy")
static func battle_no_mana() -> String: return TranslationServer.translate("battle.no_mana")
static func battle_unit_info(name: String, count: int, hp: int, atk: int, defn: int, spd: int, tags: String) -> String:
	return TranslationServer.translate("battle.unit_info").format(
		{"name": name, "count": count, "hp": hp, "atk": atk, "def": defn, "spd": spd, "tags": tags})
static func battle_unit_short(name: String, count: int) -> String:
	return TranslationServer.translate("battle.unit_short").format({"name": name, "count": count})
static func battle_spell_target() -> String: return TranslationServer.translate("battle.spell_target")
static func battle_spell_failed(reason: String) -> String: return TranslationServer.translate("battle.spell_failed").format({"reason": reason})
static func battle_sacrifice_failed(reason: String) -> String: return TranslationServer.translate("battle.sacrifice_failed").format({"reason": reason})
static func battle_forced_retreat() -> String: return TranslationServer.translate("battle.forced_retreat")
static func battle_retreat_wait() -> String: return TranslationServer.translate("battle.retreat_wait")
static func battle_heal(n: int) -> String: return TranslationServer.translate("battle.heal").format({"n": n})
static func battle_hp_loss(n: int) -> String: return TranslationServer.translate("battle.hp_loss").format({"n": n})
static func battle_turn_info(side: String, name: String, count: int) -> String:
	return TranslationServer.translate("battle.turn_info").format({"side": side, "name": name, "count": count})

static func city_title(name: String) -> String: return TranslationServer.translate("city.title").format({"name": name})
static func city_capital() -> String: return TranslationServer.translate("city.capital")
static func city_population(cur: int, cap: int) -> String: return TranslationServer.translate("city.population").format({"cur": cur, "cap": cap})
static func city_food() -> String: return TranslationServer.translate("city.food")
static func city_industry() -> String: return TranslationServer.translate("city.industry")
static func city_gold() -> String: return TranslationServer.translate("city.gold")
static func city_prosperity() -> String: return TranslationServer.translate("city.prosperity")
static func city_reputation() -> String: return TranslationServer.translate("city.reputation")
static func city_buildings() -> String: return TranslationServer.translate("city.buildings")
static func city_hire() -> String: return TranslationServer.translate("city.hire")
static func city_level_up() -> String: return TranslationServer.translate("city.level_up")
static func city_close() -> String: return TranslationServer.translate("city.close")
static func city_build_farm() -> String: return TranslationServer.translate("city.build_farm")
static func city_build_mine() -> String: return TranslationServer.translate("city.build_mine")
static func city_exit() -> String: return TranslationServer.translate("city.exit")
static func city_no_industry(have: float, need: float) -> String: return TranslationServer.translate("city.no_industry").format({"have": have, "need": need})
static func city_no_cell() -> String: return TranslationServer.translate("city.no_cell")
static func city_hired(name: String) -> String: return TranslationServer.translate("city.hired").format({"name": name})
static func city_no_followers() -> String: return TranslationServer.translate("city.no_followers")
static func city_max_level() -> String: return TranslationServer.translate("city.max_level")
static func city_level_title(name: String, level: int) -> String:
	return TranslationServer.translate("city.level_title").format({"name": name, "level": level})
static func city_population_detail(pop: String, free: int) -> String:
	return TranslationServer.translate("city.population_detail").format({"pop": pop, "free": free})
static func city_food_netto(food: String, netto: String) -> String:
	return TranslationServer.translate("city.food_netto").format({"food": food, "netto": netto})
static func city_industry_gold(industry: String, gold: String) -> String:
	return TranslationServer.translate("city.industry_gold").format({"industry": industry, "gold": gold})
static func city_prosperity_reputation(p: String, r: int) -> String:
	return TranslationServer.translate("city.prosperity_reputation").format({"p": p, "r": r})
static func city_building_line(name: String, level: int, x: int, y: int) -> String:
	return TranslationServer.translate("city.building_line").format({"name": name, "level": level, "x": x, "y": y})
static func city_buildings_none() -> String: return TranslationServer.translate("city.buildings_none")
static func city_intro() -> String: return TranslationServer.translate("city.intro")
static func city_not_bound() -> String: return TranslationServer.translate("city.not_bound")
static func city_building_not_found(id: String) -> String:
	return TranslationServer.translate("city.building_not_found").format({"id": id})
static func city_cannot_build(reason: String) -> String:
	return TranslationServer.translate("city.cannot_build").format({"reason": reason})
static func city_build_failed() -> String: return TranslationServer.translate("city.build_failed")
static func city_built(name: String, x: int, y: int, cost: String) -> String:
	return TranslationServer.translate("city.built").format({"name": name, "x": x, "y": y, "cost": cost})
static func city_cannot_upgrade(reasons: String) -> String:
	return TranslationServer.translate("city.cannot_upgrade").format({"reasons": reasons})
static func city_upgrade_failed() -> String: return TranslationServer.translate("city.upgrade_failed")
static func city_upgraded(from_level: int, to_level: int) -> String:
	return TranslationServer.translate("city.upgraded").format({"from": from_level, "to": to_level})
static func city_hire_no_hero() -> String: return TranslationServer.translate("city.hire_no_hero")
static func city_cost_industry(n: String) -> String: return TranslationServer.translate("city.cost_industry").format({"n": n})
static func city_cost_special(res: String, n: String) -> String:
	return TranslationServer.translate("city.cost_special").format({"res": res, "n": n})
static func city_cost_followers(n: int) -> String: return TranslationServer.translate("city.cost_followers").format({"n": n})
static func city_cost_free() -> String: return TranslationServer.translate("city.cost_free")

static func arena_palette_hint() -> String: return TranslationServer.translate("arena.palette_hint")
static func arena_turn_button() -> String: return TranslationServer.translate("arena.turn_button")
static func arena_auto_button() -> String: return TranslationServer.translate("arena.auto_button")
static func arena_hire_button() -> String: return TranslationServer.translate("arena.hire_button")
static func arena_level_button() -> String: return TranslationServer.translate("arena.level_button")
static func arena_reset_button() -> String: return TranslationServer.translate("arena.reset_button")
static func arena_menu_button() -> String: return TranslationServer.translate("arena.menu_button")
static func arena_storm() -> String: return TranslationServer.translate("arena.storm")
static func arena_starving(day: int) -> String: return TranslationServer.translate("arena.starving").format({"day": day})
static func arena_cluster(n: int) -> String: return TranslationServer.translate("arena.cluster").format({"n": n})
static func arena_center_msg() -> String: return TranslationServer.translate("arena.center_msg")
static func arena_select_msg() -> String: return TranslationServer.translate("arena.select_msg")

static func hero_title(name: String, path: String) -> String: return TranslationServer.translate("hero.title").format({"name": name, "path": path})
static func hero_combat_hp(cur: int, max: int) -> String: return TranslationServer.translate("hero.combat_hp").format({"cur": cur, "max": max})
static func hero_mana(cur: int, max: int) -> String: return TranslationServer.translate("hero.mana").format({"cur": cur, "max": max})
static func hero_followers_label() -> String: return TranslationServer.translate("hero.followers_label")
static func hero_no_followers() -> String: return TranslationServer.translate("hero.no_followers")
static func hero_default_title() -> String: return TranslationServer.translate("hero.default_title")
static func hero_stats(atk: int, def_v: int, kn: int, sp: int) -> String:
	return TranslationServer.translate("hero.stats").format({"atk": atk, "def": def_v, "kn": kn, "sp": sp})
static func hero_followers_none() -> String: return TranslationServer.translate("hero.followers_none")
static func hero_followers_more(n: int) -> String:
	return TranslationServer.translate("hero.followers_more").format({"n": n})
static func hero_no_path() -> String: return TranslationServer.translate("hero.no_path")
static func adventure_glory(cur: int, max_v: int) -> String:
	return TranslationServer.translate("adventure.glory").format({"cur": cur, "max": max_v})
static func info_date(month: int, week: int, day: int) -> String:
	return TranslationServer.translate("info.date").format({"month": month, "week": week, "day": day})
static func creation_background_value(value: String) -> String:
	return TranslationServer.translate("creation.background_value").format({"value": value})
static func creation_stats(atk: int, def_v: int, mag: int, wis: int) -> String:
	return TranslationServer.translate("creation.stats").format({"atk": atk, "def": def_v, "mag": mag, "wis": wis})
static func creation_name_placeholder() -> String: return TranslationServer.translate("creation.name_placeholder")

static func ui_close() -> String: return TranslationServer.translate("ui.close")
static func adventure_options() -> String: return TranslationServer.translate("adventure.options")
static func adventure_show_markers() -> String: return TranslationServer.translate("adventure.show_markers")
static func adventure_hex_grid() -> String: return TranslationServer.translate("adventure.hex_grid")
static func info_tooltip(node_name: String) -> String:
	var keys := {
		"CastleButton": "info.tooltip_castle",
		"FlagButton": "info.tooltip_flag",
		"CampButton": "info.tooltip_camp",
		"StableButton": "info.tooltip_stable",
		"ShipButton": "info.tooltip_ship",
		"ForgeButton": "info.tooltip_smithy",
		"ScoutButton": "info.tooltip_recon",
		"ArmyButton": "info.tooltip_army",
		"JournalButton": "info.tooltip_journal",
		"EndTurnButton": "info.tooltip_end_turn",
		"KingdomButton": "info.tooltip_kingdom",
		"OptionsButton": "info.tooltip_options",
	}
	var key: String = keys.get(node_name, "")
	return TranslationServer.translate(key) if key != "" else node_name
static func tools_title() -> String: return TranslationServer.translate("tools.title")
static func tools_slot_empty(n: int) -> String: return TranslationServer.translate("tools.slot_empty").format({"n": n})
static func tools_slot_filled(n: int, name: String, qty: int) -> String:
	return TranslationServer.translate("tools.slot_filled").format({"n": n, "name": name, "qty": qty})
static func cityjob_name(id: StringName) -> String: return TranslationServer.translate("cityjob." + str(id))
static func skills_title() -> String: return TranslationServer.translate("skills.title")
static func tool_name(id: int) -> String:
	var name: StringName = ToolType.to_name(id)
	return TranslationServer.translate("tool." + str(name)) if name != &"" else str(id)
static func stat_label(key: String) -> String: return TranslationServer.translate("stat." + key)
static func artifact_default_name() -> String: return TranslationServer.translate("artifact.default_name")
static func citypanel_capital() -> String: return TranslationServer.translate("citypanel.capital")
static func citypanel_over_limit(n: int) -> String:
	return "  " + TranslationServer.translate("citypanel.over_limit").format({"n": n})
static func citypanel_starving() -> String:
	return "  " + TranslationServer.translate("citypanel.starving")
static func citypanel_patrol_tag() -> String:
	return " " + TranslationServer.translate("citypanel.patrol_tag")
static func citypanel_in_building() -> String:
	return " " + TranslationServer.translate("citypanel.in_building")
static func citypanel_can_upgrade() -> String:
	return "  " + TranslationServer.translate("citypanel.can_upgrade")
static func citypanel_patrol_off() -> String: return TranslationServer.translate("citypanel.patrol_off")
static func citypanel_patrol_on() -> String: return TranslationServer.translate("citypanel.patrol_on")
static func citypanel_summary(pop: int, cap: int, over: String, workers: int, free: int,
		militia: int, patrol: int, food: String, cap_food: String, netto: String,
		starving: String, approval: String, safety: int, districts: int, max_districts: int,
		industry: String) -> String:
	return TranslationServer.translate("citypanel.summary").format({
		"pop": pop, "cap": cap, "over": over, "workers": workers, "free": free,
		"militia": militia, "patrol": patrol, "food": food, "cap_food": cap_food,
		"netto": netto, "starving": starving, "approval": approval, "safety": safety,
		"districts": districts, "max_districts": max_districts, "industry": industry,
	})
static func citypanel_building_line(name: String, level: int, extra: String) -> String:
	return TranslationServer.translate("citypanel.building_line").format({"name": name, "level": level, "extra": extra})

static func creation_title() -> String: return TranslationServer.translate("creation.title")
static func creation_subtitle() -> String: return TranslationServer.translate("creation.subtitle")
static func creation_name_label() -> String: return TranslationServer.translate("creation.name_label")
static func creation_sex_label() -> String: return TranslationServer.translate("creation.sex_label")
static func creation_race_label() -> String: return TranslationServer.translate("creation.race_label")
static func creation_subrace_label() -> String: return TranslationServer.translate("creation.subrace_label")
static func creation_class_label() -> String: return TranslationServer.translate("creation.class_label")
static func creation_culture_label() -> String: return TranslationServer.translate("creation.culture_label")
static func creation_background_label() -> String: return TranslationServer.translate("creation.background_label")
static func creation_create() -> String: return TranslationServer.translate("creation.create")
static func creation_back() -> String: return TranslationServer.translate("creation.back")
static func creation_sex_male() -> String: return TranslationServer.translate("creation.sex_male")
static func creation_sex_female() -> String: return TranslationServer.translate("creation.sex_female")

static func endgame_victory() -> String: return TranslationServer.translate("endgame.victory")
static func endgame_defeat() -> String: return TranslationServer.translate("endgame.defeat")
static func endgame_victory_title() -> String: return TranslationServer.translate("endgame.victory_title")
static func endgame_defeat_title() -> String: return TranslationServer.translate("endgame.defeat_title")
static func endgame_turns(n: int) -> String: return TranslationServer.translate("endgame.turns").format({"n": n})
static func endgame_date(m: int, w: int, d: int) -> String: return TranslationServer.translate("endgame.date").format({"m": m, "w": w, "d": d})
static func endgame_cities(n: int) -> String: return TranslationServer.translate("endgame.cities").format({"n": n})
static func endgame_glory(n: int) -> String: return TranslationServer.translate("endgame.glory").format({"n": n})
static func endgame_battles(w: int, l: int) -> String: return TranslationServer.translate("endgame.battles").format({"w": w, "l": l})
static func endgame_generations(n: int) -> String: return TranslationServer.translate("endgame.generations").format({"n": n})
static func endgame_to_menu() -> String: return TranslationServer.translate("endgame.to_menu")
static func endgame_reason(reason: StringName) -> String:
	match reason:
		&"unsuccessored_death": return TranslationServer.translate("endgame.reason_unsuccessored_death")
		&"total_collapse":    return TranslationServer.translate("endgame.reason_total_collapse")
		&"path_completed":    return TranslationServer.translate("endgame.reason_path_completed")
		&"domination":        return TranslationServer.translate("endgame.reason_domination")
		_: return str(reason)

static func death_cycle_continues(name: String) -> String: return TranslationServer.translate("death.cycle_continues").format({"name": name})
static func death_cycle_ends(name: String) -> String: return TranslationServer.translate("death.cycle_ends").format({"name": name})
static func death_fell_in(cause: String) -> String: return TranslationServer.translate("death.fell_in").format({"cause": cause})
static func death_successor(name: String) -> String: return TranslationServer.translate("death.successor").format({"name": name})
static func death_successor_button() -> String: return TranslationServer.translate("death.successor_button")
static func death_resurrection_button(cost_ind: int, cost_gold: int) -> String:
	return TranslationServer.translate("death.resurrection_button").format({"ind": cost_ind, "gold": cost_gold})
static func death_chronicle_button() -> String: return TranslationServer.translate("death.chronicle_button")
static func death_menu_button() -> String: return TranslationServer.translate("death.menu_button")

static func chronicle_title() -> String: return TranslationServer.translate("chronicle.title")
static func chronicle_empty() -> String: return TranslationServer.translate("chronicle.empty")
static func chronicle_close() -> String: return TranslationServer.translate("chronicle.close")
static func chronicle_entry(icon: String, gen: int, name: String, path: String, outcome: String, turns: int, glory: int, w: int, l: int) -> String:
	return TranslationServer.translate("chronicle.entry").format(
		{"icon": icon, "gen": gen, "name": name, "path": path, "outcome": outcome,
		 "turns": turns, "glory": glory, "w": w, "l": l})

static func settings_title() -> String: return TranslationServer.translate("settings.title")
static func settings_graphics() -> String: return TranslationServer.translate("settings.graphics")
static func settings_zoom() -> String: return TranslationServer.translate("settings.zoom")
static func settings_fullscreen() -> String: return TranslationServer.translate("settings.fullscreen")
static func settings_ui_anim() -> String: return TranslationServer.translate("settings.ui_anim")
static func settings_particles() -> String: return TranslationServer.translate("settings.particles")
static func settings_audio() -> String: return TranslationServer.translate("settings.audio")
static func settings_master() -> String: return TranslationServer.translate("settings.master")
static func settings_music() -> String: return TranslationServer.translate("settings.music")
static func settings_sfx() -> String: return TranslationServer.translate("settings.sfx")
static func settings_mute() -> String: return TranslationServer.translate("settings.mute")
static func settings_gameplay() -> String: return TranslationServer.translate("settings.gameplay")
static func settings_autosave() -> String: return TranslationServer.translate("settings.autosave")
static func settings_apply() -> String: return TranslationServer.translate("settings.apply")
static func settings_reset() -> String: return TranslationServer.translate("settings.reset")
static func settings_cancel() -> String: return TranslationServer.translate("settings.cancel")

static func resource_panel_title() -> String: return TranslationServer.translate("resource.panel_title")
static func resource_collected(amount: int) -> String: return TranslationServer.translate("resource.collected").format({"n": amount})
static func resource_hidden_cell() -> String: return TranslationServer.translate("resource.hidden_cell")
static func resource_name(id: StringName) -> String:
	match id:
		&"wood":    return TranslationServer.translate("resource.wood")
		&"stone":   return TranslationServer.translate("resource.stone")
		&"mercury": return TranslationServer.translate("resource.mercury")
		&"ore":     return TranslationServer.translate("resource.ore")
		&"sulfur":  return TranslationServer.translate("resource.sulfur")
		&"crystal": return TranslationServer.translate("resource.crystal")
		&"gems":    return TranslationServer.translate("resource.gems")
		&"gold":    return TranslationServer.translate("resource.gold")
		&"silver":  return TranslationServer.translate("resource.silver")
		&"quartz":  return TranslationServer.translate("resource.quartz")
		&"saltpeter": return TranslationServer.translate("resource.saltpeter")
		&"coal":    return TranslationServer.translate("resource.coal")
		&"cinnabar": return TranslationServer.translate("resource.cinnabar")
		&"turquoise": return TranslationServer.translate("resource.turquoise")
		&"limonite": return TranslationServer.translate("resource.limonite")
		&"bog_iron": return TranslationServer.translate("resource.bog_iron")
		&"coal_swamp": return TranslationServer.translate("resource.coal_swamp")
		&"gold_ore": return TranslationServer.translate("resource.gold_ore")
		&"oak":     return TranslationServer.translate("resource.oak")
		_:          return str(id)

static func skill_name(id: StringName) -> String:
	match id:
		&"nature_sense": return TranslationServer.translate("skill.nature_sense")
		&"keen_eye":     return TranslationServer.translate("skill.keen_eye")
		&"navigation":   return TranslationServer.translate("skill.navigation")
		&"geology":      return TranslationServer.translate("skill.geology")
		&"alchemy":      return TranslationServer.translate("skill.alchemy")
		_: return str(id)

static func rep_band(band: int) -> String:
	match band:
		0: return TranslationServer.translate("rep.rebellion")
		1: return TranslationServer.translate("rep.crisis")
		2: return TranslationServer.translate("rep.discontent")
		3: return TranslationServer.translate("rep.normal")
		4: return TranslationServer.translate("rep.prosperity")
		5: return TranslationServer.translate("rep.golden_age")
		_: return str(band)

static func season_name(id: int) -> String:
	match id:
		Season.ID.SPRING: return TranslationServer.translate("season.spring")
		Season.ID.SUMMER: return TranslationServer.translate("season.summer")
		Season.ID.AUTUMN: return TranslationServer.translate("season.autumn")
		Season.ID.WINTER: return TranslationServer.translate("season.winter")
		_: return str(id)

static func weather_name(id: int) -> String:
	match id:
		GameNumbers.WEATHER_CLEAR: return TranslationServer.translate("weather.clear")
		GameNumbers.WEATHER_RAIN:  return TranslationServer.translate("weather.rain")
		GameNumbers.WEATHER_SNOW:  return TranslationServer.translate("weather.snow")
		GameNumbers.WEATHER_STORM: return TranslationServer.translate("weather.storm")
		_: return str(id)

static func death_cause(cause: StringName) -> String:
	match cause:
		&"battle":     return TranslationServer.translate("cause.battle")
		&"exhaustion": return TranslationServer.translate("cause.exhaustion")
		&"isolation":  return TranslationServer.translate("cause.isolation")
		&"burnout":    return TranslationServer.translate("cause.burnout")
		_: return str(cause)

static func battle_result_win() -> String: return TranslationServer.translate("result.win")
static func battle_result_lose() -> String: return TranslationServer.translate("result.lose")
static func battle_result_retreat() -> String: return TranslationServer.translate("result.retreat")

static func save_ok() -> String: return TranslationServer.translate("save.ok")
static func save_failed() -> String: return TranslationServer.translate("save.failed")
static func load_ok() -> String: return TranslationServer.translate("load.ok")
static func load_failed() -> String: return TranslationServer.translate("load.failed")
static func no_save_found() -> String: return TranslationServer.translate("load.no_save")
