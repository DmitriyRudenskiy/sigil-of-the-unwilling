#extends GdUnitTestSuite
# tests/unit/view/test_sprite_tracks.gd
# [AI]: сгенерировано по задаче 8.2/9.4 tasks.md, проверено человеком.
# Комплект дорожек: у каждого юнита из каталога — четыре состояния по четыре кадра.
#
# Тест появился как реакция на молчавший дефект: пять клипов завернули на аудите
# кадров, `.sprite_frames` собрались с тремя дорожками, а в бою это выглядело как
# «юнит просто не дёрнулся» — `play()` на отсутствующей дорожке пишет `push_error`
# и оставляет предыдущий кадр. Гейт про это не знал.

extends GdUnitTestSuite

const SPRITE_DIR := "res://assets/sprites"
const STATES := ["idle", "attack", "hit", "turn"]
const FRAME_COUNT := 4

## Дорожек нет, потому что клип завернут машинным аудитом (замеры 2026-10-25).
## Четыре из пяти — одна причина: в Wan I2V первый кадр пришёл на белом фоне, а не
## на зелёном, и локальный кей (`g - max(r,b) > 60`) его не убирает: `wizard/attack`
## 69%, `stormmage/turn` 75%, `spearman/attack` 80%, `sorcerer/turn` 86% силуэта —
## плоский белый. По манифесту корреляция чистая: угол зелёный → 31 принят из 33,
## угол белый → 0 принят из 4. Пятая — `priest/hit`: ступни уезжают по полу на
## 79.8 / 79.6 / 97.1 px при пороге 8 px (три семени и правка промпта не помогли).
## Возвращает дорожку пересъёмка `tools/gen_clip.py` либо покадровый путь
## `tools/gen_frames.py` (D5, как у walk). Список пустеет по мере приёмки: тест
## падает и если дорожка пропала вне списка, и если её починили, а строку не убрали.
const INCOMPLETE := {
	"priest": ["hit"],
	"sorcerer": ["turn"],
	"spearman": ["attack"],
	"stormmage": ["turn"],
	"wizard": ["attack"],
}


func test_every_unit_has_four_tracks_of_four_frames() -> void:
	var problems := PackedStringArray()
	for id in DataLibrary.load_units():
		var gaps: Array = INCOMPLETE.get(id, [])
		var path := "%s/%s.sprite_frames.tres" % [SPRITE_DIR, id]
		var frames := load(path) as SpriteFrames
		if frames == null:
			problems.append("дорожки %s не загрузились" % path)
			continue
		for state in STATES:
			var where := "%s/%s" % [id, state]
			var present := frames.has_animation(state)
			if state in gaps:
				if present:
					problems.append("%s: клип принят — убери строку из INCOMPLETE" % where)
			elif not present:
				problems.append("%s: дорожки нет, и её нет в INCOMPLETE" % where)
			elif frames.get_frame_count(state) != FRAME_COUNT:
				problems.append("%s: %d кадров, надо %d"
						% [where, frames.get_frame_count(state), FRAME_COUNT])
	assert_str("; ".join(problems)).is_empty()
