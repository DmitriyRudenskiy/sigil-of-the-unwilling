class_name ThemeConfig
extends RefCounted

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
const C_TEXT_LIGHT_SOFT  := Color("#f0dcae")
const C_TEXT_GOLD_SOFT   := Color("#e6cf9a")

const C_PANEL_BG         := Color(0.16, 0.11, 0.06, 0.95)
const C_PANEL_BORDER     := Color(0.62, 0.47, 0.22)
const C_PANEL_BORDER_ALT := Color(0.50, 0.38, 0.18)
const C_PANEL_MID        := Color(0.3, 0.2, 0.12)
const C_PANEL_DARK       := Color(0.08, 0.06, 0.04, 0.95)
const C_OVERLAY_DIM      := Color(0.0, 0.0, 0.0, 0.75)
const C_OVERLAY_HEAVY    := Color(0.0, 0.0, 0.0, 0.8)
const C_SLOT_BG          := Color(0.35, 0.24, 0.15)
const C_BG_DARK          := Color(0.05, 0.04, 0.10)
const C_RARITY_TRACK     := Color(0.15, 0.15, 0.15, 0.5)
const C_POPUP_BORDER     := Color(0.12, 0.10, 0.08, 0.9)

const C_BTN_NORMAL       := Color(0.15, 0.35, 0.75)
const C_BTN_HOVER        := Color(0.2, 0.45, 0.9)
const C_BTN_PRESSED      := Color(0.1, 0.25, 0.6)
const C_BTN_BORDER       := Color(0.3, 0.5, 0.9)
const C_BTN_SHADOW       := Color(0.10, 0.20, 0.50, 0.50)
const C_BTN_TEXT         := Color(0.9, 0.95, 1.0)

const C_BATTLE_HIGHLIGHT_MOVE   := Color(0.2, 0.7, 1.0, 0.28)
const C_BATTLE_HIGHLIGHT_MOVE_B := Color(0.3, 0.9, 1.0, 0.95)
const C_BATTLE_HIGHLIGHT_ATK    := Color(1.0, 0.25, 0.2, 0.95)
const C_BATTLE_HIGHLIGHT_UNREACH:= Color(0.9, 0.15, 0.15, 0.35)
const C_BATTLE_DAMAGE_NUMBER    := Color(1.0, 0.25, 0.2, 1.0)
const C_BATTLE_RETALIATION      := Color(1.0, 0.8, 0.2, 0.95)
const C_BATTLE_LUCK             := Color.RED
const C_BATTLE_MORALE           := Color.YELLOW
const C_BATTLE_SPELL_CAST       := Color.YELLOW
const C_BATTLE_BG_FLOW          := Color(0.10, 0.10, 0.12)
const C_BATTLE_BG_VIEW          := Color(0.33, 0.30, 0.18)
const C_SIDE_ATTACKER           := Color(0.2, 0.5, 0.9)
const C_SIDE_DEFENDER           := Color(0.9, 0.3, 0.2)
const C_ACTIVE_INFO             := Color(0.85, 0.90, 1.0)
const C_INITIATIVE_YOUR         := Color(0.7, 0.85, 1.0)
const C_INITIATIVE_ENEMY        := Color(1.0, 0.75, 0.7)
const C_HIT_FLASH               := Color(1, 0.3, 0.3)
const C_LOCK_FLASH              := Color(1, 0.5, 0.5)

const C_SCHOOL_AIR   := Color(0.4, 0.7, 1.0)
const C_SCHOOL_FIRE  := Color(1.0, 0.4, 0.2)
const C_SCHOOL_WATER := Color(0.2, 0.6, 0.9)
const C_SCHOOL_EARTH := Color(0.5, 0.8, 0.3)

const C_RARITY_MINOR  := Color(0.8, 0.8, 0.6)
const C_RARITY_MAJOR  := Color(0.4, 0.6, 1.0)
const C_RARITY_RELIC  := Color(1.0, 0.75, 0.15)

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

const C_ARENA_RING0 := Color(0.95, 0.8, 0.3)
const C_ARENA_RING1 := Color(0.33, 0.58, 0.33)
const C_ARENA_RING2 := Color(0.78, 0.66, 0.32)
const C_ARENA_RING3 := Color(0.72, 0.42, 0.36)
const C_ARENA_RING4 := Color(0.56, 0.42, 0.68)
const C_ARENA_RING5 := Color(0.36, 0.52, 0.78)

const C_ORB_HIGH   := Color(0.2, 0.85, 0.2, 0.9)
const C_ORB_MID    := Color(1.0, 0.85, 0.1, 0.9)
const C_ORB_LOW    := Color(0.9, 0.2, 0.2, 0.9)

const C_MINIMAP_BG       := Color(0.12, 0.14, 0.18, 0.9)
const C_MINIMAP_CROSS    := Color(0.5, 0.5, 0.55, 0.5)
const C_MINIMAP_VIEWPORT := Color(1.0, 1.0, 0.3, 0.16)
const C_MINIMAP_BORDER   := Color(1.0, 1.0, 0.6, 0.6)
const C_MINIMAP_HERO     := Color(0.1, 0.9, 0.4, 0.9)
const C_MINIMAP_HERO_RING:= Color(0.1, 0.9, 0.4, 0.6)
const C_MINIMAP_CITY     := Color(0.95, 0.78, 0.35, 1.0)
const C_MINIMAP_CAPITAL  := Color(0.9, 0.35, 0.3, 1.0)
const C_MINIMAP_TERRAIN_WATER := Color(0.15, 0.35, 0.75)
const C_MINIMAP_TERRAIN_2     := Color(0.2, 0.45, 0.4)
const C_MINIMAP_TERRAIN_3     := Color(0.85, 0.75, 0.45)
const C_MINIMAP_TERRAIN_GRASS := Color(0.35, 0.6, 0.3)
const C_MINIMAP_TERRAIN_FOREST:= Color(0.15, 0.35, 0.15)
const C_MINIMAP_TERRAIN_6     := Color(0.45, 0.4, 0.35)
const C_MINIMAP_TERRAIN_7     := Color(0.9, 0.93, 0.98)
const C_FOG_GRAY        := Color(0.5, 0.5, 0.5, 1)

const C_MARKER_GREEN       := Color(0.2, 0.85, 0.2, 0.75)
const C_MARKER_YELLOW      := Color(1.0, 0.85, 0.1, 0.8)
const C_MARKER_RED         := Color(0.9, 0.2, 0.2, 0.6)
const C_MARKER_DANGER_ARC  := Color(0.95, 0.25, 0.2, 0.85)
const C_MARKER_MAGIC_FILL  := Color(0.62, 0.47, 0.9, 0.25)
const C_MARKER_MAGIC_RING  := Color(0.8, 0.65, 1.0, 0.95)
const C_MARKER_LABEL       := Color(1.0, 0.96, 0.85, 0.95)
const C_MARKER_EXHAUSTED   := Color(0.7, 0.7, 0.75, 0.9)
const C_MARKER_ACTIVE      := Color(0.95, 0.85, 0.4, 0.95)

const C_CURSOR_SWORD   := Color(1.0, 0.3, 0.22, 0.95)
const C_CURSOR_ARROW   := Color(1.0, 0.68, 0.2, 0.95)
const C_CURSOR_WAND    := Color(0.78, 0.42, 1.0, 0.95)
const C_CURSOR_BOOT    := Color(0.35, 1.0, 0.55, 0.98)
const C_CURSOR_DEFAULT := Color(0.3, 0.7, 1.0, 0.9)

const C_TIME_NIGHT   := Color(0.3, 0.3, 0.8)
const C_TIME_EVENING := Color(0.9, 0.6, 0.2)
const C_TIME_NOON    := Color(0.9, 0.9, 0.3)
const C_TIME_DAY     := Color(0.4, 0.9, 0.4)

const C_VICTORY_TITLE := Color(0.92, 0.84, 0.55)
const C_DEFEAT_TITLE  := Color(0.75, 0.3, 0.28)

const C_GRID_LINE    := Color(0, 0, 0, 0.4)
const C_GOLD_OUTLINE := Color(1, 1, 0, 0.6)
const C_WHITE_DIM_30 := Color(1, 1, 1, 0.3)
const C_GRAY_DIM_40  := Color(0.5, 0.5, 0.5, 0.4)

const SPRITE_SHEET_WORLD    := "res://assets/tiles/world_tiles.jpeg"
const SPRITE_SHEET_HEX0     := "res://assets/textures/hex_sheet_0.png"
const SPRITE_SHEET_HEX1     := "res://assets/textures/hex_sheet_1.png"
const SPRITE_SHEET_RESOURCE := "res://assets/textures/resources.png"
const SPRITE_HERO_KNIGHT    := "res://assets/raw/hero_knight.jpg"
const SPRITE_UNITS_DIR      := "res://assets/units/"

const THEME_PATH := "res://assets/theme/game_theme.tres"

const ICON_DIR := "res://assets/ui/icons/"
const ICON_DIR_RESOURCES := ICON_DIR + "resources/"
const ICON_DIR_BUILDINGS := ICON_DIR + "buildings/"
const ICON_DIR_NEEDS := ICON_DIR + "needs/"
const ICON_DIR_SCHOOLS := ICON_DIR + "schools/"
const ICON_DIR_WIDGETS := "res://assets/ui/widgets/"
const ICON_FALLBACK := ICON_DIR + "fallback.png"

const FONT_SIZE_SMALL := 14

const AUDIO_DIR := "res://assets/audio/"

# ui-icons: кэшированная загрузка иконки; при отсутствии — fallback-текстура.
static var _icon_cache: Dictionary = {}

static func icon_texture(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		path = ICON_FALLBACK
		tex = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon_cache[path] = tex
	return tex

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

static func building_icon(id: StringName) -> String:
	match id:
		&"farm":       return "🌾"
		&"mill":       return "🌀"
		&"bakery":     return "🍞"
		&"mine":       return "⛏"
		&"smithy":     return "🔨"
		&"tavern":     return "🍺"
		&"school":     return "📚"
		&"trade_post": return "⚖"
		&"market":     return "🏪"
		&"shack":      return "🛖"
		&"walls":      return "🧱"
		&"district":   return "🏘"
		&"barracks":   return "🏰"
		_:             return "🏗"

static func need_icon(need_id: StringName) -> String:
	match need_id:
		&"rest":        return "😴"
		&"social":      return "🤝"
		&"inspiration": return "💡"
		_:              return "❓"

static func tool_icon(id: StringName) -> String:
	match id:
		&"shovel":          return "🔧"
		&"pickaxe":         return "⛏️"
		&"cart":            return "🛒"
		&"skin_protection": return "🛡️"
		&"net":             return "🥅"
		_:                  return "🧰"

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

static func school_color(school_name: String) -> Color:
	match school_name.to_lower():
		"air":   return C_SCHOOL_AIR
		"fire":  return C_SCHOOL_FIRE
		"water": return C_SCHOOL_WATER
		"earth": return C_SCHOOL_EARTH
		_:       return Color.WHITE

static func rarity_color(rarity: int) -> Color:
	match rarity:
		Artifact.Rarity.MINOR: return C_RARITY_MINOR
		Artifact.Rarity.MAJOR: return C_RARITY_MAJOR
		Artifact.Rarity.RELIC: return C_RARITY_RELIC
		_: return Color.WHITE
