class_name AudioCues
extends RefCounted
## Карту «событие → аудио-ассет» (единственный источник правды для звуков).
##
## Все call-сиды играют через SoundManager.play_sfx_cue / play_music_cue
## с ключами из CUES. Пути — res://assets/audio/{sfx,music}/.
##
## См. openspec/changes/audio-pass (capability: audio).

const CUES: Dictionary = {
	# --- UI ---
	&"ui_click": "res://assets/audio/sfx/ui_click.wav",
	&"ui_hover": "res://assets/audio/sfx/ui_hover.wav",

	# --- Мир: герой и взаимодействие ---
	&"hero_step": "res://assets/audio/sfx/hero_step.wav",
	&"village_captured": "res://assets/audio/sfx/village_capture.wav",
	&"resource_collected": "res://assets/audio/sfx/resource_collect.wav",

	# --- Бой ---
	&"battle_hit": "res://assets/audio/sfx/sword_hit.wav",
	&"spell_cast": "res://assets/audio/sfx/spell_cast.wav",
	&"battle_victory": "res://assets/audio/sfx/victory.wav",
	&"battle_defeat": "res://assets/audio/sfx/defeat.wav",

	# --- Музыка (по локациям) ---
	&"music_menu": "res://assets/audio/music/menu_music.mp3",
	&"music_world": "res://assets/audio/music/world_music.mp3",
	&"music_battle": "res://assets/audio/music/battle_music.mp3",
}


static func has(cue: StringName) -> bool:
	return CUES.has(cue)


## Путь ассета для cue ("" если cue неизвестен).
static func path(cue: StringName) -> String:
	return CUES.get(cue, "")
