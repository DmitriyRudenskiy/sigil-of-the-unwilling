"""SoundManager: headless-режим, null-стримы, неизвестные кьюи.

На headless-платформе _ready() выходит до создания пула и music_player —
всё публичное API должно переживать null/пустые состояния без крашей.
"""
extends BaseTest

var _sm: SoundManagerAutoload


func before_test() -> void:
	_sm = SoundManagerAutoload.new()
	add_child(_sm)


func after_test() -> void:
	_sm.queue_free()
	await get_tree().process_frame


func test_headless_ready_no_players() -> void:
	# Headless: _ready не создаёт пул и music_player — и не крашится.
	assert_int(_sm.sfx_players.size()).is_equal(0)
	assert_that(_sm.music_player).is_null()


func test_play_sfx_null_stream() -> void:
	# Не существующий ассет: стрим null → без краша, path записан.
	_sm.play_sfx("res://assets/audio/nope.wav")
	assert_str(_sm.last_sfx_path).is_equal("res://assets/audio/nope.wav")


func test_play_sfx_cue_unknown() -> void:
	# Неизвестный кьюи → warning, без краша.
	_sm.play_sfx_cue(&"no_such_cue_xyz")
	assert_that(true).is_true()


func test_play_music_null_stream() -> void:
	_sm.play_music("res://assets/audio/nope.ogg")
	assert_str(_sm.last_music_path).is_equal("res://assets/audio/nope.ogg")


func test_stop_music_null_player() -> void:
	# music_player null (headless) → stop без краша.
	_sm.stop_music()
	assert_that(true).is_true()
