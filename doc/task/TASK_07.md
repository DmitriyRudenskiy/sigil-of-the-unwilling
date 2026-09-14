# Задание для локального агента: Темизация, константы и локализация

---

## Цель

Единая точка управления визуальной темой, типизация всех магических значений и полная локализация через GNU gettext `.po`.

---

## Фаза 1: Темизация (иконки, спрайты, цвета)

### 1.1 Создать `res://scripts/theme/ThemeConfig.gd`

```gdscript
class_name ThemeConfig
extends RefCounted

## Единая точка конфигурации темы.
## Все цвета, иконки и спрайты проекта определяются здесь.

# ─── Цвета: текст ──────────────────────────────────────────────
const C_TEXT_PRIMARY     := Color(0.95, 0.89, 0.72)
const C_TEXT_SECONDARY   := Color(0.75, 0.80, 0.95)
const C_TEXT_GOLD        := Color(1.0, 0.85, 0.4)
const C_TEXT_LIGHT       := Color(0.95, 0.92, 0.8)
const C_TEXT_DANGER      := Color(1.0, 0.25, 0.2)
const C_TEXT_SUCCESS     := Color(0.2, 1.0, 0.4)
const C_TEXT_WARNING     := Color(1.0, 0.85, 0.1)
const C_TEXT_INFO        := Color(0.7, 0.9, 1.0)
const C_TEXT_GRAY        := Color(0.5, 0.5, 0.5)
const C_TEXT_WHITE       := Color(1.0, 1.0, 1.0)
const C_TEXT_DAMAGE      := Color(1.0, 0.2, 0.2)

# ─── Цвета: фоны и панели ─────────────────────────────────────
const C_PANEL_BG         := Color(0.16, 0.11, 0.06, 0.95)
const C_PANEL_BORDER     := Color(0.62, 0.47, 0.22)
const C_PANEL_MID        := Color(0.3, 0.2, 0.12)
const C_PANEL_DARK       := Color(0.08, 0.06, 0.04, 0.95)
const C_OVERLAY_DIM      := Color(0.0, 0.0, 0.0, 0.75)
const C_OVERLAY_HEAVY    := Color(0.0, 0.0, 0.0, 0.8)
const C_SLOT_BG          := Color(0.35, 0.24, 0.15)

# ─── Цвета: кнопки ─────────────────────────────────────────────
const C_BTN_NORMAL       := Color(0.15, 0.35, 0.75)
const C_BTN_HOVER        := Color(0.2, 0.45, 0.9)
const C_BTN_PRESSED      := Color(0.1, 0.25, 0.6)
const C_BTN_BORDER       := Color(0.3, 0.5, 0.9)
const C_BTN_TEXT         := Color(0.9, 0.95, 1.0)

# ─── Цвета: игра (бой) ────────────────────────────────────────
const C_BATTLE_HIGHLIGHT_MOVE   := Color(0.2, 0.7, 1.0, 0.28)
const C_BATTLE_HIGHLIGHT_MOVE_B := Color(0.3, 0.9, 1.0, 0.95)
const C_BATTLE_HIGHLIGHT_ATK    := Color(1.0, 0.25, 0.2, 0.95)
const C_BATTLE_HIGHLIGHT_UNREACH:= Color(0.9, 0.15, 0.15, 0.35)
const C_BATTLE_DAMAGE_NUMBER    := Color(1.0, 0.25, 0.2, 1.0)
const C_BATTLE_RETALIATION      := Color(1.0, 0.8, 0.2, 0.95)
const C_BATTLE_LUCK             := Color.RED
const C_BATTLE_MORALE           := Color.YELLOW
const C_BATTLE_SPELL_CAST       := Color.YELLOW

# ─── Цвета: школа магии ────────────────────────────────────────
const C_SCHOOL_AIR   := Color(0.4, 0.7, 1.0)
const C_SCHOOL_FIRE  := Color(1.0, 0.4, 0.2)
const C_SCHOOL_WATER := Color(0.2, 0.6, 0.9)
const C_SCHOOL_EARTH := Color(0.5, 0.8, 0.3)

# ─── Цвета: редкость артефактов ────────────────────────────────
const C_RARITY_MINOR  := Color(0.8, 0.8, 0.6)
const C_RARITY_MAJOR  := Color(0.4, 0.6, 1.0)
const C_RARITY_RELIC  := Color(1.0, 0.75, 0.15)

# ─── Цвета: ресурсы ────────────────────────────────────────────
const C_RES_WOOD    := Color(0.62, 0.44, 0.24)
const C_RES_MERCURY := Color(0.64, 0.67, 0.74)
const C_RES_ORE     := Color(0.50, 0.40, 0.34)
const C_RES_SULFUR  := Color(0.87, 0.80, 0.30)
const C_RES_CRYSTAL := Color(0.40, 0.63, 0.88)
const C_RES_GEMS    := Color(0.52, 0.80, 0.62)
const C_RES_GOLD    := Color(0.92, 0.77, 0.28)
const C_RES_SILVER  := Color(0.85, 0.85, 0.9)
const C_RES_QUARTZ  := Color(0.95, 0.95, 0.95)
const C_RES_COAL    := Color(0.2, 0.2, 0.2)

# ─── Цвета: арена города ───────────────────────────────────────
const C_ARENA_RING0 := Color(0.95, 0.8, 0.3)
const C_ARENA_RING1 := Color(0.33, 0.58, 0.33)
const C_ARENA_RING2 := Color(0.78, 0.66, 0.32)
const C_ARENA_RING3 := Color(0.72, 0.42, 0.36)
const C_ARENA_RING4 := Color(0.56, 0.42, 0.68)
const C_ARENA_RING5 := Color(0.36, 0.52, 0.78)

# ─── Цвета: статус-орб ─────────────────────────────────────────
const C_ORB_HIGH   := Color(0.2, 0.85, 0.2, 0.9)
const C_ORB_MID    := Color(1.0, 0.85, 0.1, 0.9)
const C_ORB_LOW    := Color(0.9, 0.2, 0.2, 0.9)

# ─── Цвета: мини-карта ─────────────────────────────────────────
const C_MINIMAP_CROSS    := Color(0.5, 0.5, 0.55, 0.5)
const C_MINIMAP_VIEWPORT := Color(1.0, 1.0, 0.3, 0.16)
const C_MINIMAP_BORDER   := Color(1.0, 1.0, 0.6, 0.6)

# ─── Цвета: конец игры ─────────────────────────────────────────
const C_VICTORY_TITLE := Color(0.92, 0.84, 0.55)
const C_DEFEAT_TITLE  := Color(0.75, 0.3, 0.28)

# ─── Пути: спрайты ─────────────────────────────────────────────
const SPRITE_SHEET_WORLD    := "res://assets/tiles/world_tiles.jpeg"
const SPRITE_SHEET_HEX0     := "res://assets/textures/hex_sheet_0.png"
const SPRITE_SHEET_HEX1     := "res://assets/textures/hex_sheet_1.png"
const SPRITE_SHEET_RESOURCE := "res://assets/textures/resources.png"
const SPRITE_HERO_KNIGHT    := "res://assets/raw/hero_knight.jpg"
const SPRITE_UNITS_DIR      := "res://assets/units/"

# ─── Пути: темы ────────────────────────────────────────────────
const THEME_PATH := "res://assets/theme/game_theme.tres"

# ─── Пути: аудио ────────────────────────────────────────────────
const AUDIO_DIR := "res://assets/audio/"

# ─── Иконки: эмодзи по ресурсам ────────────────────────────────
static func resource_icon(id: StringName) -> String:
	match id:
		&"wood":    return "🌲"
		&"stone":   return "🪨"
		&"mercury": return "🧪"
		&"ore":     return "🪨"
		&"sulfur":  return "🟡"
		&"crystal": return "🔷"
		&"gems":    return "💎"
		&"gold":    return "🪙"
		&"silver":  return "🥈"
		&"quartz":  return "💎"
		&"saltpeter": return "🧪"
		&"coal":    return "⬛"
		&"cinnabar": return "🔴"
		_:          return "📦"

# ─── Иконки: эмодзи по зданиям ─────────────────────────────────
static func building_icon(id: StringName) -> String:
	match id:
		&"farm":       return "🌾"
		&"mill":       return "🌀"
		&"bakery":     return "🍞"
		&"mine":       return "⛏"
		&"smithy":     return "⚒"
		&"tavern":     return "🍺"
		&"school":     return "📚"
		&"trade_post": return "⚖"
		&"market":     return "🏪"
		&"shack":      return "🛖"
		&"walls":      return "🧱"
		&"district":   return "🏘"
		&"barracks":   return "🏰"
		_:             return "🏗"

# ─── Иконки: эмодзи по потребностям ────────────────────────────
static func need_icon(need_id: StringName) -> String:
	match need_id:
		&"rest":        return "😴"
		&"social":      return "🤝"
		&"inspiration": return "💡"
		_:              return "❓"

# ─── Иконки: эмодзи по инструментам ─────────────────────────────
static func tool_icon(id: StringName) -> String:
	match id:
		&"shovel":          return "🔧"
		&"pickaxe":         return "⛏️"
		&"cart":            return "🛒"
		&"skin_protection": return "🛡️"
		&"net":             return "🥅"
		_:                  return "🧰"

# ─── Цвета: по типу ресурса (для попапа) ────────────────────────
static func resource_color(id: StringName) -> Color:
	match id:
		&"wood":    return C_RES_WOOD
		&"mercury": return C_RES_MERCURY
		&"ore":     return C_RES_ORE
		&"sulfur":  return C_RES_SULFUR
		&"crystal": return C_RES_CRYSTAL
		&"gems":    return C_RES_GEMS
		&"gold":    return C_RES_GOLD
		&"silver":  return C_RES_SILVER
		&"quartz":  return C_RES_QUARTZ
		&"coal":    return C_RES_COAL
		_:          return Color.from_hsv(float(absi(id.hash()) % 100) / 100.0, 0.45, 0.75)

# ─── Цвета: по школе магии ─────────────────────────────────────
static func school_color(school_name: String) -> Color:
	match school_name.to_lower():
		"air":   return C_SCHOOL_AIR
		"fire":  return C_SCHOOL_FIRE
		"water": return C_SCHOOL_WATER
		"earth": return C_SCHOOL_EARTH
		_:       return Color.WHITE

# ─── Цвета: по редкости артефакта ──────────────────────────────
static func rarity_color(rarity: int) -> Color:
	match rarity:
		Artifact.Rarity.MINOR: return C_RARITY_MINOR
		Artifact.Rarity.MAJOR: return C_RARITY_MAJOR
		Artifact.Rarity.RELIC: return C_RARITY_RELIC
		_: return Color.WHITE
```

### 1.2 Создать `res://assets/theme/game_theme.tres`

Theme-ресурс Godot с палитрой. Используется как источник для `.tscn`.

### 1.3 Заменить все инлайновые `Color(...)` во всех `.gd` файлах на `ThemeConfig.*`

**Файлы для замены** (полный список):

| Файл | Паттерн поиска | Замена |
|---|---|---|
| `StatusOrb.gd` | `Color(0.2, 0.85, 0.2, 0.9)` и др. | `ThemeConfig.C_ORB_HIGH` и др. |
| `DestMarker.gd` | `Color(1.0, 0.25, 0.2, 0.95)` | `ThemeConfig.C_BATTLE_HIGHLIGHT_ATK` |
| `BattleView.gd` | все цвета | `ThemeConfig.C_BATTLE_*` |
| `HighlightOverlay.gd` | все цвета | `ThemeConfig.C_BATTLE_*` |
| `CursorOverlay.gd` | все цвета | `ThemeConfig.C_BATTLE_*` |
| `CityArenaView.gd` | `Color(...)` | `ThemeConfig.C_ARENA_*` |
| `ArenaHexCell.tscn` | inline Color | через тему |
| `ResourceCollectPopup.gd` | `ResourceIcons.get_color()` | `ThemeConfig.resource_color()` |
| `ResourceIcons.gd` | `DATA` dict с цветами | `ThemeConfig.resource_color()` |
| `AdventureUI.gd` | `C_BG`, `C_BORDER` | `ThemeConfig.C_PANEL_*` |
| `ArmyPanel.gd` | `C_SLOT_BG`, `C_BORDER` | `ThemeConfig.*` |
| `InfoPanel.gd` | inline цвета | `ThemeConfig.C_TEXT_*` |
| `ResourceBar.gd` | UITheme | `ThemeConfig.C_TEXT_PRIMARY` |
| `ChronicleScreen.gd` | inline | `ThemeConfig.*` |
| `DeathSequence.gd` | inline | `ThemeConfig.*` |
| `GameOverScreen.gd` | inline | `ThemeConfig.*` |
| `ArtifactInventoryScreen.gd` | inline | `ThemeConfig.*` |
| `SettingsScreen.gd` | `C_BG`, `C_BORDER` | `ThemeConfig.*` |
| `BattleFX.gd` | school colors dict | `ThemeConfig.school_color()` |

### 1.4 Удалить `res://scripts/ui/UITheme.gd`

Заменить все вызовы `UITheme.font()`, `UITheme.tint()`, `UITheme.color()` на прямые ссылки `ThemeConfig.*`.

### 1.5 Удалить `res://scripts/ui/ThemeIcons.gd`

Заменить на `ThemeConfig.resource_icon()`, `ThemeConfig.need_icon()`, `ThemeConfig.tool_icon()`.

---

## Фаза 2: Вынос текстовых констант и магических чисел

### 2.1 Создать `res://scripts/constants/GameText.gd`

```gdscript
class_name GameText
extends RefCounted

## Все пользовательские тексты. Локализуемые строки обёрнуты в tr().
## Нелокализуемые (логи, отладка) остаются как есть.

# ─── Главное меню ──────────────────────────────────────────────
static func menu_new_game() -> String: return tr("menu.new_game")
static func menu_load_game() -> String: return tr("menu.load_game")
static func menu_arena() -> String: return tr("menu.arena")
static func menu_model_warrior() -> String: return tr("menu.model_warrior")
static func menu_model_mage() -> String: return tr("menu.model_mage")
static func menu_settings() -> String: return tr("menu.settings")
static func menu_chronicle() -> String: return tr("menu.chronicle")
static func menu_exit() -> String: return tr("menu.exit")
static func menu_version() -> String: return tr("menu.version")

# ─── Бой ───────────────────────────────────────────────────────
static func battle_select_unit() -> String: return tr("battle.select_unit")
static func battle_your_turn() -> String: return tr("battle.your_turn")
static func battle_enemy_turn() -> String: return tr("battle.enemy_turn")
static func battle_retreat() -> String: return tr("battle.retreat")
static func battle_wait() -> String: return tr("battle.wait")
static func battle_attack() -> String: return tr("battle.attack")
static func battle_defend() -> String: return tr("battle.defend")
static func battle_skip() -> String: return tr("battle.skip")
static func battle_retaliation() -> String: return tr("battle.retaliation")
static func battle_high_morale() -> String: return tr("battle.high_morale")
static func battle_luck() -> String: return tr("battle.luck")
static func battle_killed(count: int) -> String: return tr("battle.killed").format({"n": count})
static func battle_spell_label(id: StringName) -> String: return tr("battle.spell_label").format({"id": id})
static func battle_retreat_confirm() -> String: return tr("battle.retreat_confirm")
static func battle_defend_bonus() -> String: return tr("battle.defend_bonus")
static func battle_damage_preview(dmin: int, dmax: int, kmin: int, kmax: int) -> String:
	return tr("battle.damage_preview").format({"dmin": dmin, "dmax": dmax, "kmin": kmin, "kmax": kmax})

# ─── Город ─────────────────────────────────────────────────────
static func city_title(name: String) -> String: return tr("city.title").format({"name": name})
static func city_capital() -> String: return tr("city.capital")
static func city_population(cur: int, cap: int) -> String: return tr("city.population").format({"cur": cur, "cap": cap})
static func city_food() -> String: return tr("city.food")
static func city_industry() -> String: return tr("city.industry")
static func city_gold() -> String: return tr("city.gold")
static func city_prosperity() -> String: return tr("city.prosperity")
static func city_reputation() -> String: return tr("city.reputation")
static func city_buildings() -> String: return tr("city.buildings")
static func city_hire() -> String: return tr("city.hire")
static func city_level_up() -> String: return tr("city.level_up")
static func city_close() -> String: return tr("city.close")
static func city_build_farm() -> String: return tr("city.build_farm")
static func city_build_mine() -> String: return tr("city.build_mine")
static func city_exit() -> String: return tr("city.exit")
static func city_no_industry(have: float, need: float) -> String: return tr("city.no_industry").format({"have": have, "need": need})
static func city_no_cell() -> String: return tr("city.no_cell")
static func city_hired(name: String) -> String: return tr("city.hired").format({"name": name})
static func city_no_followers() -> String: return tr("city.no_followers")
static func city_max_level() -> String: return tr("city.max_level")

# ─── Арена ─────────────────────────────────────────────────────
static func arena_palette_hint() -> String: return tr("arena.palette_hint")
static func arena_turn_button() -> String: return tr("arena.turn_button")
static func arena_auto_button() -> String: return tr("arena.auto_button")
static func arena_hire_button() -> String: return tr("arena.hire_button")
static func arena_level_button() -> String: return tr("arena.level_button")
static func arena_reset_button() -> String: return tr("arena.reset_button")
static func arena_menu_button() -> String: return tr("arena.menu_button")
static func arena_storm() -> String: return tr("arena.storm")
static func arena_starving(day: int) -> String: return tr("arena.starving").format({"day": day})
static func arena_cluster(n: int) -> String: return tr("arena.cluster").format({"n": n})
static func arena_center_msg() -> String: return tr("arena.center_msg")
static func arena_select_msg() -> String: return tr("arena.select_msg")

# ─── Герой ─────────────────────────────────────────────────────
static func hero_title(name: String, path: String) -> String: return tr("hero.title").format({"name": name, "path": path})
static func hero_combat_hp(cur: int, max: int) -> String: return tr("hero.combat_hp").format({"cur": cur, "max": max})
static func hero_mana(cur: int, max: int) -> String: return tr("hero.mana").format({"cur": cur, "max": max})
static func hero_followers_label() -> String: return tr("hero.followers_label")
static func hero_no_followers() -> String: return tr("hero.no_followers")

# ─── Создание персонажа ────────────────────────────────────────
static func creation_title() -> String: return tr("creation.title")
static func creation_subtitle() -> String: return tr("creation.subtitle")
static func creation_name_label() -> String: return tr("creation.name_label")
static func creation_sex_label() -> String: return tr("creation.sex_label")
static func creation_race_label() -> String: return tr("creation.race_label")
static func creation_subrace_label() -> String: return tr("creation.subrace_label")
static func creation_class_label() -> String: return tr("creation.class_label")
static func creation_culture_label() -> String: return tr("creation.culture_label")
static func creation_background_label() -> String: return tr("creation.background_label")
static func creation_create() -> String: return tr("creation.create")
static func creation_back() -> String: return tr("creation.back")
static func creation_sex_male() -> String: return tr("creation.sex_male")
static func creation_sex_female() -> String: return tr("creation.sex_female")

# ─── Конец игры ────────────────────────────────────────────────
static func endgame_victory() -> String: return tr("endgame.victory")
static func endgame_defeat() -> String: return tr("endgame.defeat")
static func endgame_victory_title() -> String: return tr("endgame.victory_title")
static func endgame_defeat_title() -> String: return tr("endgame.defeat_title")
static func endgame_turns(n: int) -> String: return tr("endgame.turns").format({"n": n})
static func endgame_date(m: int, w: int, d: int) -> String: return tr("endgame.date").format({"m": m, "w": w, "d": d})
static func endgame_cities(n: int) -> String: return tr("endgame.cities").format({"n": n})
static func endgame_glory(n: int) -> String: return tr("endgame.glory").format({"n": n})
static func endgame_battles(w: int, l: int) -> String: return tr("endgame.battles").format({"w": w, "l": l})
static func endgame_generations(n: int) -> String: return tr("endgame.generations").format({"n": n})
static func endgame_to_menu() -> String: return tr("endgame.to_menu")

# ─── Смерть героя ──────────────────────────────────────────────
static func death_cycle_continues(name: String) -> String: return tr("death.cycle_continues").format({"name": name})
static func death_cycle_ends(name: String) -> String: return tr("death.cycle_ends").format({"name": name})
static func death_fell_in(cause: String) -> String: return tr("death.fell_in").format({"cause": cause})
static func death_successor(name: String) -> String: return tr("death.successor").format({"name": name})
static func death_successor_button() -> String: return tr("death.successor_button")
static func death_resurrection_button(cost_ind: int, cost_gold: int) -> String:
	return tr("death.resurrection_button").format({"ind": cost_ind, "gold": cost_gold})
static func death_chronicle_button() -> String: return tr("death.chronicle_button")
static func death_menu_button() -> String: return tr("death.menu_button")

# ─── Летопись ──────────────────────────────────────────────────
static func chronicle_title() -> String: return tr("chronicle.title")
static func chronicle_empty() -> String: return tr("chronicle.empty")
static func chronicle_close() -> String: return tr("chronicle.close")
static func chronicle_entry(gen: int, name: String, path: String, outcome: String, glory: int, w: int, l: int) -> String:
	return tr("chronicle.entry").format({"gen": gen, "name": name, "path": path, "outcome": outcome, "glory": glory, "w": w, "l": l})

# ─── Настройки ─────────────────────────────────────────────────
static func settings_title() -> String: return tr("settings.title")
static func settings_graphics() -> String: return tr("settings.graphics")
static func settings_zoom() -> String: return tr("settings.zoom")
static func settings_fullscreen() -> String: return tr("settings.fullscreen")
static func settings_ui_anim() -> String: return tr("settings.ui_anim")
static func settings_particles() -> String: return tr("settings.particles")
static func settings_audio() -> String: return tr("settings.audio")
static func settings_master() -> String: return tr("settings.master")
static func settings_music() -> String: return tr("settings.music")
static func settings_sfx() -> String: return tr("settings.sfx")
static func settings_mute() -> String: return tr("settings.mute")
static func settings_gameplay() -> String: return tr("settings.gameplay")
static func settings_autosave() -> String: return tr("settings.autosave")
static func settings_apply() -> String: return tr("settings.apply")
static func settings_reset() -> String: return tr("settings.reset")
static func settings_cancel() -> String: return tr("settings.cancel")

# ─── Ресурсы ───────────────────────────────────────────────────
static func resource_panel_title() -> String: return tr("resource.panel_title")
static func resource_collected(amount: int) -> String: return tr("resource.collected").format({"n": amount})
static func resource_hidden_cell() -> String: return tr("resource.hidden_cell")
static func resource_name(id: StringName) -> String:
	match id:
		&"wood":    return tr("resource.wood")
		&"stone":   return tr("resource.stone")
		&"mercury": return tr("resource.mercury")
		&"ore":     return tr("resource.ore")
		&"sulfur":  return tr("resource.sulfur")
		&"crystal": return tr("resource.crystal")
		&"gems":    return tr("resource.gems")
		&"gold":    return tr("resource.gold")
		&"silver":  return tr("resource.silver")
		&"quartz":  return tr("resource.quartz")
		&"saltpeter": return tr("resource.saltpeter")
		&"coal":    return tr("resource.coal")
		&"cinnabar": return tr("resource.cinnabar")
		&"turquoise": return tr("resource.turquoise")
		&"limonite": return tr("resource.limonite")
		&"bog_iron": return tr("resource.bog_iron")
		&"coal_swamp": return tr("resource.coal_swamp")
		&"gold_ore": return tr("resource.gold_ore")
		&"oak":     return tr("resource.oak")
		_:          return str(id)

# ─── Навыки ────────────────────────────────────────────────────
static func skill_name(id: StringName) -> String:
	match id:
		&"nature_sense": return tr("skill.nature_sense")
		&"keen_eye":     return tr("skill.keen_eye")
		&"navigation":   return tr("skill.navigation")
		&"geology":      return tr("skill.geology")
		&"alchemy":      return tr("skill.alchemy")
		_: return str(id)

# ─── Приём: репутация ──────────────────────────────────────────
static func rep_band(band: int) -> String:
	match band:
		0: return tr("rep.rebellion")
		1: return tr("rep.crisis")
		2: return tr("rep.discontent")
		3: return tr("rep.normal")
		4: return tr("rep.prosperity")
		5: return tr("rep.golden_age")
		_: return str(band)

# ─── Приём: сезон ──────────────────────────────────────────────
static func season_name(id: int) -> String:
	match id:
		Season.ID.SPRING: return tr("season.spring")
		Season.ID.SUMMER: return tr("season.summer")
		Season.ID.AUTUMN: return tr("season.autumn")
		Season.ID.WINTER: return tr("season.winter")
		_: return str(id)

# ─── Приём: погода ─────────────────────────────────────────────
static func weather_name(id: int) -> String:
	match id:
		MapConfig.WEATHER_CLEAR: return tr("weather.clear")
		MapConfig.WEATHER_RAIN:  return tr("weather.rain")
		MapConfig.WEATHER_SNOW:  return tr("weather.snow")
		MapConfig.WEATHER_STORM: return tr("weather.storm")
		_: return str(id)

# ─── Приём: причина смерти ─────────────────────────────────────
static func death_cause(cause: StringName) -> String:
	match cause:
		&"battle":     return tr("cause.battle")
		&"exhaustion": return tr("cause.exhaustion")
		&"isolation":  return tr("cause.isolation")
		&"burnout":    return tr("cause.burnout")
		_: return str(cause)

# ─── Приём: результат боя ──────────────────────────────────────
static func battle_result_win() -> String: return tr("result.win")
static func battle_result_lose() -> String: return tr("result.lose")
static func battle_result_retreat() -> String: return tr("result.retreat")

# ─── Служебные ─────────────────────────────────────────────────
static func save_ok() -> String: return tr("save.ok")
static func save_failed() -> String: return tr("save.failed")
static func load_ok() -> String: return tr("load.ok")
static func load_failed() -> String: return tr("load.failed")
static func no_save_found() -> String: return tr("load.no_save")
```

### 2.2 Создать `res://scripts/constants/GameNumbers.gd`

```gdscript
class_name GameNumbers
extends RefCounted

## Все магические числа проекта в одном месте.
## Разделены по домену. Не менять без изменения баланса.

# ─── Камера и зум ──────────────────────────────────────────────
const CAMERA_SPEED          := 600.0
const CAMERA_EDGE_ZONE      := 20
const CAMERA_ZOOM_TWEEN_SEC := 0.175
const ZOOM_LEVELS           := [0.5, 0.7, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25]
const ZOOM_DEFAULT_INDEX    := 2

# ─── UI: размеры панелей ──────────────────────────────────────
const ADVENTURE_RIGHT_PANEL_W   := 252
const ADVENTURE_BOTTOM_BAR_H    := 58
const CITY_PANEL_W              := 340.0
const CITY_PANEL_TOP            := 40.0
const CITY_PANEL_BOTTOM         := 40.0
const MENU_BTN_MIN_W            := 300
const MENU_BTN_MIN_H            := 70
const MENU_COL_SEPARATION       := 20

# ─── Бой: анимации ────────────────────────────────────────────
const BATTLE_HEX_OUTLINE_RADIUS := 38.0
const BATTLE_ATTACK_LUNGE_PX    := 26.0
const BATTLE_MOVE_TWEEN_SEC     := 0.15
const BATTLE_ATTACK_ANIM_SEC    := 0.3
const BATTLE_SPELL_ANIM_TIME    := 0.35
const BATTLE_AI_THINK_TIME      := 0.7
const BATTLE_TURN_DELAY         := 0.15
const BATTLE_FIELD_RING         := 5
const BATTLE_CLICK_RADIUS_PX    := 60.0

# ─── Бой: правила ─────────────────────────────────────────────
const ATK_ADVANTAGE_PER_POINT   := 0.05
const DEF_ADVANTAGE_PER_POINT   := 0.025
const MAX_DAMAGE_MULTIPLIER     := 5.0
const MIN_DAMAGE_MULTIPLIER     := 0.3
const LUCK_CHANCE               := 0.10
const MORALE_CHANCE             := 0.08
const DEFEND_DEFENSE_BONUS      := 1.2
const RANGED_MELEE_PENALTY      := 0.5
const RETREAT_SURVIVAL_RATIO    := 0.5
const RETREAT_STACK_LIMIT       := 2
const MAX_UNITS_PER_SIDE        := 7
const CHARGE_MULT               := 1.5
const BREATH_DMG_RATIO          := 0.5
const STATUS_PROC_CHANCE        := 0.20
const REBIRTH_CHANCE            := 0.20

# ─── Карта ─────────────────────────────────────────────────────
const MAP_SIZE_MIN              := 40
const MAP_SIZE_MAX              := 70
const MAP_VILLAGE_COUNT         := 8
const MAP_RESOURCE_COUNT        := 25
const MAP_ENEMY_COUNT           := 20
const MAP_ENEMY_DEF_BONUS_MIN   := 2
const MAP_ENEMY_DEF_BONUS_MAX   := 6
const ENEMY_AGGRO_RADIUS        := 8
const ENEMY_MP                  := 5.0
const ENEMY_RESPAWN_TURNS       := 6
const FOG_HERO_SIGHT            := 3
const FOG_CITY_SIGHT            := 4
const HERO_DAILY_MOVEMENT       := 10.0
const HERO_BASE_SPEED           := 120.0
const CHEST_GOLD_MIN            := 30
const CHEST_GOLD_MAX            := 80
const CHEST_COUNT               := 5
const MONSTER_DROP_CHANCE       := 0.05
const RESOURCE_CAPACITY         := 10
const RESOURCE_AUTO_WOOD        := 2
const RESOURCE_AUTO_STONE       := 2
const RESOURCE_NODE_REMOVE_DAYS := 3
const RESOURCE_NODE_CHANCE      := 0.08
const SPAWN_DECOR_SAND_CHANCE   := 0.04
const SPAWN_SCROLL_MAX_ATTEMPTS := 200
const SPAWN_CHEST_MIN_BORDER    := 3
const SPAWN_ENEMY_MIN_BORDER    := 3
const TOOL_INVENTORY_SLOTS      := 8
const SALTPETER_EXPLOSION_MULT  := 2.0

# ─── Город ─────────────────────────────────────────────────────
const CITY_CYCLE_TURNS          := 7
const INFLOW_BASE               := 2.0
const INFLOW_PER_TEMPLE         := 2.0
const INFLOW_GLORY_DIVISOR      := 50.0
const INFLOW_SUMMER_MOD         := 1.0
const INFLOW_WINTER_MOD         := 0.5
const INFLOW_SPRING_AUTUMN_MOD  := 1.0
const GROWTH_THRESHOLD_BASE     := 5.0
const GROWTH_THRESHOLD_EXP      := 2.75
const FOOD_PER_WORKER           := 1.0
const FOOD_PER_MILITIA          := 1.0
const FOOD_PER_FOLLOWER         := 0.0
const FOOD_PER_SCHOLAR          := 0.5
const BASE_SETTLEMENT_HOUSING   := 10
const BOROUGH_BASE_COST         := 20.0
const BOROUGH_COST_STEP         := 10.0
const BOROUGH_POP_RATIO_DEFAULT := 2.0
const BOROUGH_POP_RATIO_WIDE    := 1.0
const BOROUGH_LEVELUP_NEIGHBORS := 4
const BOROUGH_MAX_LEVEL         := 3
const BUILDING_MAX_LEVEL        := 3
const BUILDING_MAX_DIST_BASE    := 3
const SAFETY_PER_PATROL         := 5
const STARVING_APPROVAL_PENALTY := 10
const REP_MIN                   := -100
const REP_MAX                   := 100
const REP_BAND_GOLDEN_AGE       := 80
const REP_BAND_PROSPERITY       := 30
const REP_BAND_DISCONTENT       := -30
const REP_BAND_CRISIS           := -70
const REP_FOOD_SURPLUS          := 1
const REP_STARVING              := -5
const REP_OVERPOP_PER           := -2
const MIGRATE_IN_AT             := 30
const MIGRATE_OUT_AT            := -30
const MIGRATE_CRISIS_AT         := -70
const MIGRATE_IN_PER_TURN       := 1
const MIGRATE_CRISIS_PER_TURN   := 2
const ROYALTY_FRACTION          := 0.25
const PROSPERITY_BASE           := 50.0
const PROSPERITY_MAX            := 100.0
const PROSPERITY_FOOD_BONUS     := 10.0
const PROSPERITY_GOLD_REQ       := 10.0
const PROSPERITY_BLD_PER        := 2.0
const PROSPERITY_BLD_CAP        := 20.0
const PROSPERITY_POP_BONUS      := 10.0
const PROSPERITY_POP_RATIO      := 0.75
const PROSPERITY_GOLD_PER_PT    := 0.05
const PROSPERITY_LEVEL_REQ      := 60.0
const PROSPERITY_LEVEL_POP_BASE := 12
const PROSPERITY_LEVEL_POP_STEP := 8
const PROSPERITY_LEVEL_BLD_PER  := 2
const PROSPERITY_MAX_RADIUS     := 5
const CITY_LEVEL_MAX            := 5
const CITY_LEVEL_MIN            := 1

# ─── Рейд ──────────────────────────────────────────────────────
const RAID_CHANCE_BASE          := 0.10
const RAID_CHANCE_MIN           := 0.02
const RAID_CHANCE_MAX           := 0.30
const RAID_REP_DIVISOR          := 500.0
const RAID_DEF_PER_MILITIA      := 2
const RAID_DEF_PER_WALL         := 5
const RAID_STRENGTH_MIN         := 5
const RAID_STRENGTH_SPAN        := 11
const RAID_REP_RELIEF           := 5
const RAID_REP_LOSS             := -10
const RAID_PILLAGE_FRACTION     := 0.30

# ─── Рынок ─────────────────────────────────────────────────────
const MARKET_DEFAULT_RATE       := 2.0
const MARKET_MIN_AMOUNT         := 1.0

# ─── Зоны ──────────────────────────────────────────────────────
const ZONE_INDUSTRIAL_MIN_DIST  := 2
const ZONE_AGGLOMERATION_COUNT  := 2
const ZONE_AGGLOMERATION_BONUS  := 0.10
const ZONE_COMMERCIAL_MARKET    := 0.10
const ZONE_INDUSTRIAL_ROAD      := 0.10
const ZONE_MAX_MULT             := 1.5

# ─── Логистика ─────────────────────────────────────────────────
const LOGISTICS_DIST_FALLOFF    := 0.15
const LOGISTICS_MIN_MULT        := 0.25
const LOGISTICS_MAX_MULT        := 1.0
const LOGISTICS_ROAD_BONUS      := 0.15
const LOGISTICS_ROAD_MAX        := 1.5

# ─── Масштабирование ───────────────────────────────────────────
const SCALE_TIERS               := [4, 14, 29]
const SCALE_STORAGE_MULT        := [1.0, 1.25, 1.5, 2.0]
const SCALE_AUTO_MULT           := [1.0, 1.1, 1.2, 1.4]
const SCALE_UPKEEP_MULT         := [1.0, 0.95, 0.9, 0.85]

# ─── Демография ────────────────────────────────────────────────
const DEMO_CRITICAL_THRESHOLD   := 0.2
const DEMO_DEATH_STREAK         := 3
const DEMO_OUTBREAK_COOLDOWN    := 5
const DEMO_MAX_TRAITS           := 3

# ─── Потребности ───────────────────────────────────────────────
const NEED_REST_DECAY           := 0.10
const NEED_SOCIAL_DECAY         := 0.08
const NEED_INSP_DECAY           := 0.05
const NEED_REST_RECOVERY_CITY   := 0.36
const NEED_REST_RECOVERY_POP    := 0.12
const NEED_SOCIAL_RECOVERY_CITY := 0.30
const NEED_SOCIAL_RECOVERY_POP  := 0.10
const NEED_INSP_RECOVERY_CITY   := 0.15
const NEED_INSP_RECOVERY_POP    := 0.05

# ─── Арена города ──────────────────────────────────────────────
const ARENA_RADIUS              := 5
const ARENA_CLUSTER_MIN         := 4
const ARENA_CLUSTER_MULT        := 1.5
const ARENA_CLUSTER_HOUSING     := 2
const ARENA_FEATURE_CHANCE      := 0.13
const ARENA_FEATURE_QUARRY      := 1.5
const ARENA_FEATURE_SPRING      := 1.5
const ARENA_FEATURE_RIVER       := 1.25
const ARENA_FEATURE_RUINS_GOLD  := 15.0
const ARENA_STORM_PERIOD        := 6
const ARENA_STORM_PROD_MULT     := 0.75
const ARENA_STORM_MITIG_MULT    := 0.875
const ARENA_STORM_FOOD          := 2.0
const ARENA_STORM_MITIG_FOOD    := 1.0

# ─── Сукцессия ─────────────────────────────────────────────────
const SUCCESSION_RESURRECT_IND  := 500.0
const SUCCESSION_RESURRECT_GOLD := 100.0

# ─── Слава ─────────────────────────────────────────────────────
const GLORY_VICTORY_THRESHOLD   := 500
```

### 2.3 Заменить все `MapConfig.*`, `BattleConfig.*`, `CityBalance.*`, `UIConfig.*`, `EndgameConfig.*` на `GameNumbers.*`

После замены удалить файлы:
- `res://scripts/core/BattleConfig.gd`
- `res://scripts/core/MapConfig.gd`
- `res://scripts/core/UIConfig.gd`
- `res://scripts/core/EndgameConfig.gd`
- `res://scripts/world/CityBalance.gd`
- `res://scripts/city/ArenaBalance.gd` (константы перенесены в `GameNumbers`)

---

## Фаза 3: Локализация через PO

### 3.1 Создать структуру

```
res://locale/
  ru.po          ← русский (основной)
  en.po          ← английский
  messages.pot   ← шаблон
```

### 3.2 Создать `res://locale/ru.po`

```po
msgid ""
msgstr ""
"Project-Id-Version: SigilOfTheUnwilling 0.1\n"
"Language: ru\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

# ─── Меню ──────────────────────────────────────────────────────
msgid "menu.new_game"
msgstr "Новая игра"

msgid "menu.load_game"
msgstr "Загрузить"

msgid "menu.arena"
msgstr "🏙 Арена города"

msgid "menu.model_warrior"
msgstr "🗡 Модель: Рыцарь"

msgid "menu.model_mage"
msgstr "✨ Модель: Маг"

msgid "menu.settings"
msgstr "Настройки"

msgid "menu.chronicle"
msgstr "📜 Летопись"

msgid "menu.exit"
msgstr "Выход"

msgid "menu.version"
msgstr "Sigil of the Unwilling v0.1 — Godot 4.7"

# ─── Бой ───────────────────────────────────────────────────────
msgid "battle.select_unit"
msgstr "Выберите существо…"

msgid "battle.your_turn"
msgstr "Ваш ход"

msgid "battle.enemy_turn"
msgstr "Ход противника"

msgid "battle.retreat"
msgstr "🏕️"

msgid "battle.wait"
msgstr "🏃"

msgid "battle.attack"
msgstr "⚔️"

msgid "battle.defend"
msgstr "🛡️"

msgid "battle.skip"
msgstr "⏳"

msgid "battle.retaliation"
msgstr "RETALIATION"

msgid "battle.high_morale"
msgstr "HIGH MORALE!"

msgid "battle.luck"
msgstr "LUCK!"

msgid "battle.killed"
msgstr "KILLED: {n}"

msgid "battle.spell_label"
msgstr "SPELL: {id}"

msgid "battle.retreat_confirm"
msgstr "Отступление! Потеря 50% стеков."

msgid "battle.defend_bonus"
msgstr "🛡️ Защита: +20% DEF до конца раунда."

msgid "battle.damage_preview"
msgstr "Damage: ~{dmin}-{dmax} (kills ~{kmin}-{kmax})"

# ─── Город ─────────────────────────────────────────────────────
msgid "city.title"
msgstr "{name}"

msgid "city.capital"
msgstr " (столица)"

msgid "city.population"
msgstr "Население: {cur}/{cap}"

msgid "city.food"
msgstr "🌾 Еда"

msgid "city.industry"
msgstr "🏭 Промышленность"

msgid "city.gold"
msgstr "🪙 Золото"

msgid "city.prosperity"
msgstr "⭐ Процветание"

msgid "city.reputation"
msgstr "💠 Репутация"

msgid "city.buildings"
msgstr "Здания"

msgid "city.hire"
msgstr "👤 Нанять"

msgid "city.level_up"
msgstr "⬆️ Улучшить"

msgid "city.close"
msgstr "✕ Выход из города"

msgid "city.build_farm"
msgstr "🌾 Построить ферму"

msgid "city.build_mine"
msgstr "⛏️ Построить шахту"

msgid "city.exit"
msgstr "✕ Выход из города"

msgid "city.no_industry"
msgstr "Промышленность: {have}/{need}"

msgid "city.no_cell"
msgstr "Нет свободной клетки под постройку"

msgid "city.hired"
msgstr "Нанят: {name}"

msgid "city.no_followers"
msgstr "Нет свободных последователей для найма"

msgid "city.max_level"
msgstr "Город уже на максимальном уровне"

# ─── Арена ─────────────────────────────────────────────────────
msgid "arena.palette_hint"
msgstr "Палитра (клик — выбор, повторный клик — снять)"

msgid "arena.turn_button"
msgstr "⏭ Ход"

msgid "arena.auto_button"
msgstr "▶ Авто"

msgid "arena.hire_button"
msgstr "🧑‍🌾 Нанять"

msgid "arena.level_button"
msgstr "🏛 Уровень"

msgid "arena.reset_button"
msgstr "↺ Заново"

msgid "arena.menu_button"
msgstr "⌂ Меню"

msgid "arena.storm"
msgstr "🌪 ШТОРМ"

msgid "arena.starving"
msgstr "⚠ ГОЛОД (день {day})"

msgid "arena.cluster"
msgstr "⚡кластеры: {n}"

msgid "arena.center_msg"
msgstr "Это центр города."

msgid "arena.select_msg"
msgstr "Сначала выберите здание в палитре (или кликните по построенному — апгрейд)."

# ─── Герой ─────────────────────────────────────────────────────
msgid "hero.title"
msgstr "🧙 {name} — {path}"

msgid "hero.combat_hp"
msgstr "❤️ {cur}/{max}"

msgid "hero.mana"
msgstr "✨ {cur}/{max}"

msgid "hero.followers_label"
msgstr "👥 Последователи"

msgid "hero.no_followers"
msgstr "нет"

# ─── Создание персонажа ────────────────────────────────────────
msgid "creation.title"
msgstr "Создание героя"

msgid "creation.subtitle"
msgstr "Выберите облик героя для новой игры"

msgid "creation.name_label"
msgstr "Имя:"

msgid "creation.sex_label"
msgstr "Пол:"

msgid "creation.race_label"
msgstr "Раса:"

msgid "creation.subrace_label"
msgstr "Подраса:"

msgid "creation.class_label"
msgstr "Класс:"

msgid "creation.culture_label"
msgstr "Культура:"

msgid "creation.background_label"
msgstr "Прошлое:"

msgid "creation.create"
msgstr "Создать"

msgid "creation.back"
msgstr "Назад"

msgid "creation.sex_male"
msgstr "Мужской"

msgid "creation.sex_female"
msgstr "Женский"

# ─── Конец игры ────────────────────────────────────────────────
msgid "endgame.victory"
msgstr "Путь завершён"

msgid "endgame.defeat"
msgstr "Знак угас"

msgid "endgame.victory_title"
msgstr "Путь завершён"

msgid "endgame.defeat_title"
msgstr "Знак угас"

msgid "endgame.turns"
msgstr "Ходы: {n}"

msgid "endgame.date"
msgstr "Дата: {m}/{w}/{d}"

msgid "endgame.cities"
msgstr "Города: {n}"

msgid "endgame.glory"
msgstr "Слава: {n}"

msgid "endgame.battles"
msgstr "Боёв: {w} побед / {l} поражений"

msgid "endgame.generations"
msgstr "Поколений: {n}"

msgid "endgame.to_menu"
msgstr "В главное меню"

# ─── Смерть ────────────────────────────────────────────────────
msgid "death.cycle_continues"
msgstr "{name} — цикл продолжится"

msgid "death.cycle_ends"
msgstr "{name} — цикл оборвался"

msgid "death.fell_in"
msgstr "Герой пал {cause}."

msgid "death.successor"
msgstr "Знак переходит к: {name}"

msgid "death.successor_button"
msgstr "Знак переходит"

msgid "death.resurrection_button"
msgstr "Воскресить ({ind}⚙ + {gold}💰)"

msgid "death.chronicle_button"
msgstr "Летопись"

msgid "death.menu_button"
msgstr "В меню"

# ─── Летопись ──────────────────────────────────────────────────
msgid "chronicle.title"
msgstr "📜 Летопись поколений"

msgid "chronicle.empty"
msgstr "Летопись пуста — легенда только начинается."

msgid "chronicle.close"
msgstr "Закрыть"

msgid "chronicle.entry"
msgstr "{gen}. {name} ({path}) — {outcome} | ходы {glory}, слава {w}/{l}"

# ─── Настройки ─────────────────────────────────────────────────
msgid "settings.title"
msgstr "⚙️ Настройки"

msgid "settings.graphics"
msgstr "🖥️ Графика"

msgid "settings.zoom"
msgstr "Зум камеры:"

msgid "settings.fullscreen"
msgstr "Полноэкранный режим"

msgid "settings.ui_anim"
msgstr "Анимации UI"

msgid "settings.particles"
msgstr "Частицы"

msgid "settings.audio"
msgstr "🔊 Звук"

msgid "settings.master"
msgstr "Master"

msgid "settings.music"
msgstr "Музыка"

msgid "settings.sfx"
msgstr "Эффекты"

msgid "settings.mute"
msgstr "🔇 Мьют (M)"

msgid "settings.gameplay"
msgstr "🎮 Игра"

msgid "settings.autosave"
msgstr "Автосохранение при выходе"

msgid "settings.apply"
msgstr "Применить и закрыть"

msgid "settings.reset"
msgstr "Сбросить по умолчанию"

msgid "settings.cancel"
msgstr "Отмена"

# ─── Ресурсы ───────────────────────────────────────────────────
msgid "resource.panel_title"
msgstr "📦 Ресурсы"

msgid "resource.collected"
msgstr "+{n}"

msgid "resource.hidden_cell"
msgstr "Клетка не разведена"

msgid "resource.wood"
msgstr "Дерево"

msgid "resource.stone"
msgstr "Камень"

msgid "resource.mercury"
msgstr "Ртуть"

msgid "resource.ore"
msgstr "Руда"

msgid "resource.sulfur"
msgstr "Сера"

msgid "resource.crystal"
msgstr "Кристалл"

msgid "resource.gems"
msgstr "Самоцветы"

msgid "resource.gold"
msgstr "Золото"

msgid "resource.silver"
msgstr "Серебро"

msgid "resource.quartz"
msgstr "Кварц"

msgid "resource.saltpeter"
msgstr "Селитра"

msgid "resource.coal"
msgstr "Уголь"

msgid "resource.cinnabar"
msgstr "Киноварь"

msgid "resource.turquoise"
msgstr "Бирюза"

msgid "resource.limonite"
msgstr "Лимонит"

msgid "resource.bog_iron"
msgstr "Болотное железо"

msgid "resource.coal_swamp"
msgstr "Уголь (болото)"

msgid "resource.gold_ore"
msgstr "Золото"

msgid "resource.oak"
msgstr "Дуб"

# ─── Навыки ────────────────────────────────────────────────────
msgid "skill.nature_sense"
msgstr "Чувство Природы"

msgid "skill.keen_eye"
msgstr "Зоркий Взор"

msgid "skill.navigation"
msgstr "Навигация"

msgid "skill.geology"
msgstr "Геология"

msgid "skill.alchemy"
msgstr "Алхимия"

# ─── Репутация ─────────────────────────────────────────────────
msgid "rep.rebellion"
msgstr "Бунт"

msgid "rep.crisis"
msgstr "Кризис"

msgid "rep.discontent"
msgstr "Недовольство"

msgid "rep.normal"
msgstr "Норма"

msgid "rep.prosperity"
msgstr "Процветание"

msgid "rep.golden_age"
msgstr "Золотой век"

# ─── Сезоны ────────────────────────────────────────────────────
msgid "season.spring"
msgstr "Весна"

msgid "season.summer"
msgstr "Лето"

msgid "season.autumn"
msgstr "Осень"

msgid "season.winter"
msgstr "Зима"

# ─── Погода ────────────────────────────────────────────────────
msgid "weather.clear"
msgstr "Ясно"

msgid "weather.rain"
msgstr "Дождь"

msgid "weather.snow"
msgstr "Снег"

msgid "weather.storm"
msgstr "Шторм"

# ─── Причины смерти ────────────────────────────────────────────
msgid "cause.battle"
msgstr "в бою"

msgid "cause.exhaustion"
msgstr "от истощения"

msgid "cause.isolation"
msgstr "от одиночества"

msgid "cause.burnout"
msgstr "от выгорания"

# ─── Результаты боя ────────────────────────────────────────────
msgid "result.win"
msgstr "Победа"

msgid "result.lose"
msgstr "Поражение"

msgid "result.retreat"
msgstr "Отступление"

# ─── Сохранение ────────────────────────────────────────────────
msgid "save.ok"
msgstr "Игра сохранена"

msgid "save.failed"
msgstr "Ошибка сохранения"

msgid "load.ok"
msgstr "Игра загружена"

msgid "load.failed"
msgstr "Ошибка загрузки"

msgid "load.no_save"
msgstr "Сохранение не найдено"
```

### 3.3 Настроить `project.godot`

Добавить в `[internationalization]`:

```ini
[internationalization]
locale/translations=PackedStringArray("res://locale/ru.po")
locale/fallback="ru"
```

### 3.4 Заменить все строковые литералы в `.tscn` и `.gd`

Для `.tscn`: убрать `text = "..."` из нод, заменять на `GameText.*()` в коде при `_ready()`.

Пример для `MainMenu.tscn`:
```gdscript
# В MainMenu.gd _ready():
_new_game_btn.text = GameText.menu_new_game()
_load_game_btn.text = GameText.menu_load_game()
_arena_btn.text = GameText.menu_arena()
# ... и т.д.
```

Для `BattleUI.tscn`, `CityArena.tscn`, `SettingsScreen.tscn`, `CharacterCreation.tscn` — аналогично.

### 3.5 Создать скрипт генерации `en.po`

`res://tools/gen_en_po.gd` — генерирует `en.po` из `messages.pot` с английскими переводами.

---

## Фаза 4: Порядок выполнения

| Шаг | Действие | Файлы |
|---|---|---|
| 1 | Создать `ThemeConfig.gd` | новый |
| 2 | Создать `GameText.gd` | новый |
| 3 | Создать `GameNumbers.gd` | новый |
| 4 | Создать `ru.po` | новый |
| 5 | Настроить `project.godot` | редактировать |
| 6 | Заменить цвета в `StatusOrb.gd`, `DestMarker.gd` | 2 файла |
| 7 | Заменить цвета в `BattleView.gd`, `HighlightOverlay.gd`, `CursorOverlay.gd` | 3 файла |
| 8 | Заменить цвета в `CityArenaView.gd`, `ArenaHexCell.gd` | 2 файла |
| 9 | Заменить цвета в `AdventureUI.gd`, `ArmyPanel.gd`, `InfoPanel.gd` | 3 файла |
| 10 | Заменить цвета в `SettingsScreen.gd`, `ChronicleScreen.gd`, `DeathSequence.gd`, `GameOverScreen.gd` | 4 файла |
| 11 | Заменить цвета в `ArtifactInventoryScreen.gd`, `ResourceCollectPopup.gd`, `BattleFX.gd` | 3 файла |
| 12 | Заменить все `MapConfig.*` → `GameNumbers.*` | все файлы |
| 13 | Заменить все `BattleConfig.*` → `GameNumbers.*` | все файлы |
| 14 | Заменить все `CityBalance.*` → `GameNumbers.*` | все файлы |
| 15 | Заменить все `UIConfig.*` → `GameNumbers.*` | все файлы |
| 16 | Заменить все `ArenaBalance.*` константы → `GameNumbers.*` | все файлы |
| 17 | Удалить `UITheme.gd`, `ThemeIcons.gd`, `BattleConfig.gd`, `MapConfig.gd`, `UIConfig.gd`, `EndgameConfig.gd`, `CityBalance.gd`, `ArenaBalance.gd` | удалить |
| 18 | Заменить строки в `MainMenu.gd` | 1 файл |
| 19 | Заменить строки в `BattleUI.gd`, `BattleController.gd` | 2 файла |
| 20 | Заменить строки в `CityScreen.gd`, `CityArenaView.gd` | 2 файла |
| 21 | Заменить строки в `CharacterCreationUI.gd` | 1 файл |
| 22 | Заменить строки в `DeathSequence.gd`, `GameOverScreen.gd`, `ChronicleScreen.gd` | 3 файла |
| 23 | Заменить строки в `SettingsScreen.gd` | 1 файл |
| 24 | Заменить строки в `HeroStatusPanel.gd`, `ResourceCollectPopup.gd` | 2 файла |
| 25 | Заменить строки в `AdventureUI.gd`, `InfoPanel.gd` | 2 файла |
| 26 | Заменить `ResourceIcons.resource_name()` → `GameText.resource_name()` | все файлы |
| 27 | Заменить `ReputationSystem.band_name()` → `GameText.rep_band()` | все файлы |
| 28 | Заменить `_CAUSES` в `DeathSequence.gd` → `GameText.death_cause()` | 1 файл |
| 29 | Удалить `ResourceIcons.resource_name()` | 1 файл |
| 30 | Проверить компиляцию всех `.gd` | все |
| 31 | Запустить все тесты | — |

---

## Критерии приёмки

- Ни одного инлайнового `Color(...)` в `.gd` файлах (кроме генерации `PlaceholderTexture`)
- Ни одного `MapConfig.*`, `BattleConfig.*`, `CityBalance.*`, `UIConfig.*` в коде
- Все пользовательские строки проходят через `GameText.*()`
- `ru.po` содержит все ключи из `GameText`
- Проект компилируется без ошибок
- Все существующие тесты проходят
- Смена языка в `project.godot` меняет все тексты