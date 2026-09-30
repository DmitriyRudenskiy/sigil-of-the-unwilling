class_name AudioCues
extends RefCounted

const CUES: Dictionary = {
	&"ui_click": "res://assets/audio/sfx/ui_click.wav",
	&"ui_hover": "res://assets/audio/sfx/ui_hover.wav",

	&"hero_step": "res://assets/audio/sfx/hero_step.wav",
	&"village_captured": "res://assets/audio/sfx/village_capture.wav",
	&"resource_collected": "res://assets/audio/sfx/resource_collect.wav",

	&"battle_hit": "res://assets/audio/sfx/sword_hit.wav",
	&"spell_cast": "res://assets/audio/sfx/spell_cast.wav",
	&"battle_victory": "res://assets/audio/sfx/victory.wav",
	&"battle_defeat": "res://assets/audio/sfx/defeat.wav",

	&"music_menu": "res://assets/audio/music/menu_music.mp3",
	&"music_world": "res://assets/audio/music/world_music.mp3",
	&"music_battle": "res://assets/audio/music/battle_music.mp3",
}

static func has(cue: StringName) -> bool:
	return CUES.has(cue)

static func path(cue: StringName) -> String:
	return CUES.get(cue, "")
