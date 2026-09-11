extends BaseTest
## TASK_21: KnightFramesBuilder — лист 8x5 (574x574), анимации side/run/away,
## нормализация кадров по alpha-bbox (центрирование + общая линия земли).

const SHEET_PATH := "res://assets/raw/hero_knight.png"


func test_build_creates_expected_animations() -> void:
	var sf := KnightFramesBuilder.build_from_file(SHEET_PATH)
	assert_that(sf).is_not_null()
	assert_bool(sf.has_animation(&"side")).is_true()
	assert_bool(sf.has_animation(&"away")).is_true()
	assert_bool(sf.has_animation(&"run")).is_true()
	assert_int(sf.get_frame_count(&"side")).is_equal(8)
	assert_int(sf.get_frame_count(&"run")).is_equal(8)
	assert_int(sf.get_frame_count(&"away")).is_equal(8)
	# Кадры всех анимаций одного размера (единый канвас).
	var a0: Image = sf.get_frame_texture(&"side", 0).get_image()
	var b7: Image = sf.get_frame_texture(&"run", 7).get_image()
	var c3: Image = sf.get_frame_texture(&"away", 3).get_image()
	assert_that(b7.get_size()).is_equal(a0.get_size())
	assert_that(c3.get_size()).is_equal(a0.get_size())


func test_background_stripped_and_frames_recentered() -> void:
	var sf := KnightFramesBuilder.build_from_file(SHEET_PATH)
	var img: Image = sf.get_frame_texture(&"side", 0).get_image()
	# Фон прозрачный: углы канваса прозрачны (у листа и так альфа-канал).
	assert_float(img.get_pixel(0, 0).a).is_equal(0.0)
	assert_float(img.get_pixel(img.get_width() - 1, 0).a).is_equal(0.0)
	# Кадр отцентрован по X с точностью до 1 px (нормализация bbox).
	var used := img.get_used_rect()
	var center_x := float(used.position.x) + float(used.size.x) * 0.5
	assert_float(center_x).is_equal_approx(float(img.get_width()) * 0.5, 1.0)


func test_ground_line_consistent_across_frames() -> void:
	# Общая линия земли: нижний край силуэта не «прыгает» между кадрами цикла.
	var sf := KnightFramesBuilder.build_from_file(SHEET_PATH)
	var bottoms: Array[float] = []
	for i in 8:
		var img: Image = sf.get_frame_texture(&"side", i).get_image()
		bottoms.append(float(img.get_used_rect().end.y))
	var spread: float = bottoms.max() - bottoms.min()
	# Нормализация выстраивает кадры по мин. нижнему отступу; в цикле шага нога
	# поднимается, поэтому нижняя граница может законно уходить вверх.
	# Допуск 10 px: ловит систематический сдвиг (дрожание), прощает позу.
	assert_float(spread).is_less(10.0)


func test_missing_sheet_returns_null() -> void:
	assert_that(KnightFramesBuilder.build_from_file("res://nope.png")).is_null()
