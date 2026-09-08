extends SceneTree
## Генерация locale/en.po из locale/messages.pot.
## Запуск: godot --headless --script tools/gen_en_po.gd

const EN: Dictionary = {
	# Меню
	"menu.new_game": "New game",
	"menu.load_game": "Load",
	"menu.arena": "🏙 City arena",
	"menu.model_warrior": "🗡 Model: Knight",
	"menu.model_mage": "✨ Model: Mage",
	"menu.settings": "Settings",
	"menu.chronicle": "📜 Chronicle",
	"menu.exit": "Exit",
	"menu.version": "Sigil of the Unwilling v0.1 — Godot 4.7",
	# Бой
	"battle.select_unit": "Select a creature…",
	"battle.your_turn": "Your turn",
	"battle.enemy_turn": "Enemy turn",
	"battle.retreat": "🏕️",
	"battle.wait": "🏃",
	"battle.attack": "⚔️",
	"battle.defend": "🛡️",
	"battle.skip": "⏳",
	"battle.retaliation": "RETALIATION",
	"battle.high_morale": "HIGH MORALE!",
	"battle.luck": "LUCK!",
	"battle.killed": "KILLED: {n}",
	"battle.spell_label": "SPELL: {id}",
	"battle.retreat_confirm": "Retreat! Lose 50% of stacks.",
	"battle.defend_bonus": "🛡️ Defend: +20% DEF until end of round.",
	"battle.damage_preview": "Damage: ~{dmin}-{dmax} (kills ~{kmin}-{kmax})",
	# Город
	"city.title": "{name}",
	"city.capital": " (capital)",
	"city.population": "Population: {cur}/{cap}",
	"city.food": "🌾 Food",
	"city.industry": "🏭 Industry",
	"city.gold": "🪙 Gold",
	"city.prosperity": "⭐ Prosperity",
	"city.reputation": "💠 Reputation",
	"city.buildings": "Buildings",
	"city.hire": "👤 Hire",
	"city.level_up": "⬆️ Upgrade",
	"city.close": "✕ Leave city",
	"city.build_farm": "🌾 Build farm",
	"city.build_mine": "⛏️ Build mine",
	"city.exit": "✕ Leave city",
	"city.no_industry": "Industry: {have}/{need}",
	"city.no_cell": "No free cell to build on",
	"city.hired": "Hired: {name}",
	"city.no_followers": "No free followers to hire",
	"city.max_level": "City is already at max level",
	# Арена
	"arena.palette_hint": "Palette (click to pick, click again to deselect)",
	"arena.turn_button": "⏭ Turn",
	"arena.auto_button": "▶ Auto",
	"arena.hire_button": "🧑‍🌾 Hire",
	"arena.level_button": "🏛 Level up",
	"arena.reset_button": "↺ Reset",
	"arena.menu_button": "⌂ Menu",
	"arena.storm": "🌪 STORM",
	"arena.starving": "⚠ STARVING (day {day})",
	"arena.cluster": "⚡clusters: {n}",
	"arena.center_msg": "This is the city center.",
	"arena.select_msg": "First pick a building in the palette (or click a built one to upgrade).",
	# Герой
	"hero.title": "🧙 {name} — {path}",
	"hero.combat_hp": "❤️ {cur}/{max}",
	"hero.mana": "✨ {cur}/{max}",
	"hero.followers_label": "👥 Followers",
	"hero.no_followers": "none",
	# Создание персонажа
	"creation.title": "Hero creation",
	"creation.subtitle": "Choose the hero's appearance for a new game",
	"creation.name_label": "Name:",
	"creation.sex_label": "Sex:",
	"creation.race_label": "Race:",
	"creation.subrace_label": "Subrace:",
	"creation.class_label": "Class:",
	"creation.culture_label": "Culture:",
	"creation.background_label": "Past:",
	"creation.create": "Create",
	"creation.back": "Back",
	"creation.sex_male": "Male",
	"creation.sex_female": "Female",
	# Конец игры
	"endgame.victory": "The Path is complete",
	"endgame.defeat": "The Sigil has faded",
	"endgame.victory_title": "The Path is complete",
	"endgame.defeat_title": "The Sigil has faded",
	"endgame.turns": "Turns: {n}",
	"endgame.date": "Date: {m}/{w}/{d}",
	"endgame.cities": "Cities: {n}",
	"endgame.glory": "Glory: {n}",
	"endgame.battles": "Battles: {w} wins / {l} losses",
	"endgame.generations": "Generations: {n}",
	"endgame.to_menu": "Main menu",
	# Смерть
	"death.cycle_continues": "{name} — the cycle continues",
	"death.cycle_ends": "{name} — the cycle is broken",
	"death.fell_in": "The hero fell {cause}.",
	"death.successor": "The Sigil passes to: {name}",
	"death.successor_button": "Pass the Sigil",
	"death.resurrection_button": "Resurrect ({ind}⚙ + {gold}💰)",
	"death.chronicle_button": "Chronicle",
	"death.menu_button": "To menu",
	# Летопись
	"chronicle.title": "📜 Chronicle of generations",
	"chronicle.empty": "The chronicle is empty — the legend has only begun.",
	"chronicle.close": "Close",
	"chronicle.entry": "{gen}. {name} ({path}) — {outcome} | turns {glory}, glory {w}/{l}",
	# Настройки
	"settings.title": "⚙️ Settings",
	"settings.graphics": "🖥️ Graphics",
	"settings.zoom": "Camera zoom:",
	"settings.fullscreen": "Fullscreen mode",
	"settings.ui_anim": "UI animations",
	"settings.particles": "Particles",
	"settings.audio": "🔊 Audio",
	"settings.master": "Master",
	"settings.music": "Music",
	"settings.sfx": "SFX",
	"settings.mute": "🔇 Mute (M)",
	"settings.gameplay": "🎮 Gameplay",
	"settings.autosave": "Autosave on exit",
	"settings.apply": "Apply and close",
	"settings.reset": "Reset to defaults",
	"settings.cancel": "Cancel",
	# Ресурсы
	"resource.panel_title": "📦 Resources",
	"resource.collected": "+{n}",
	"resource.hidden_cell": "Cell not settled",
	"resource.wood": "Wood",
	"resource.stone": "Stone",
	"resource.mercury": "Mercury",
	"resource.ore": "Ore",
	"resource.sulfur": "Sulfur",
	"resource.crystal": "Crystal",
	"resource.gems": "Gems",
	"resource.gold": "Gold",
	"resource.silver": "Silver",
	"resource.quartz": "Quartz",
	"resource.saltpeter": "Saltpeter",
	"resource.coal": "Coal",
	"resource.cinnabar": "Cinnabar",
	"resource.turquoise": "Turquoise",
	"resource.limonite": "Limonite",
	"resource.bog_iron": "Bog iron",
	"resource.coal_swamp": "Coal (swamp)",
	"resource.gold_ore": "Gold",
	"resource.oak": "Oak",
	# Навыки
	"skill.nature_sense": "Nature's Sense",
	"skill.keen_eye": "Keen Eye",
	"skill.navigation": "Navigation",
	"skill.geology": "Geology",
	"skill.alchemy": "Alchemy",
	# Репутация
	"rep.rebellion": "Rebellion",
	"rep.crisis": "Crisis",
	"rep.discontent": "Discontent",
	"rep.normal": "Normal",
	"rep.prosperity": "Prosperity",
	"rep.golden_age": "Golden Age",
	# Сезоны
	"season.spring": "Spring",
	"season.summer": "Summer",
	"season.autumn": "Autumn",
	"season.winter": "Winter",
	# Погода
	"weather.clear": "Clear",
	"weather.rain": "Rain",
	"weather.snow": "Snow",
	"weather.storm": "Storm",
	# Причины смерти
	"cause.battle": "in battle",
	"cause.exhaustion": "of exhaustion",
	"cause.isolation": "of loneliness",
	"cause.burnout": "of burnout",
	# Результаты боя
	"result.win": "Victory",
	"result.lose": "Defeat",
	"result.retreat": "Retreat",
	# Сохранение
	"save.ok": "Game saved",
	"save.failed": "Save error",
	"load.ok": "Game loaded",
	"load.failed": "Load error",
	"load.no_save": "Save not found",
}


func _initialize() -> void:
	var pot := FileAccess.open("res://locale/messages.pot", FileAccess.READ)
	if pot == null:
		push_error("gen_en_po: не открылся locale/messages.pot")
		quit(1)
		return
	var out: PackedStringArray = []
	var msg_id := ""
	var missing: Array[String] = []
	for line in pot.get_as_text().split("\n"):
		if line.begins_with("msgid "):
			msg_id = "" if line == 'msgid ""' else line.substr(7, line.length() - 8)
			out.append(line)
		elif line.begins_with("msgstr"):
			if msg_id == "":
				out.append("msgstr \"\"")
			elif EN.has(msg_id):
				out.append('msgstr "%s"' % EN[msg_id])
			else:
				missing.append(msg_id)
				out.append('msgstr "%s"' % msg_id)
		elif line == '"Language: ru\\n"':
			out.append('"Language: en\\n"')
		else:
			out.append(line)
	var f := FileAccess.open("res://locale/en.po", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	if missing.size() > 0:
		push_warning("gen_en_po: нет перевода: " + str(missing))
	print("gen_en_po: locale/en.po создан (%d строк)" % out.size())
	quit(0)
