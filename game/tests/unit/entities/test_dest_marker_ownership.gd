extends BaseTest

## T-214: `DestMarker` — глобальный оверлей пути, он монтируется **вне** дерева героя
## (в слой-хост, а когда хоста нет — под `root` сцены). Узел вне дерева героя не
## освобождается вместе с героем, поэтому владение им надо объявлять явно. Пока этого
## не было, осиротевший `DestMarker` висел под `root` перед каждым из десяти прогонов
## когорты выживания, и его приходилось снимать измерительным инструментом
## (`SURVIVAL-SWEEP`) — то есть утечку маскировал инструмент, а не игра.
##
## Тест проверяет ровно то, чего не хватало: после гибели героя (снять с родителя —
## путь `HeroLifecycleSystem._detach_hero`) или после `free()` героя под `root` не
## остаётся ни одного маркера.

func _root_markers() -> Array:
	var out: Array = []
	for c in get_tree().root.get_children():
		if c is DestMarker:
			out.append(c)
	return out


## Герой + контроллер визуала, собранные так, как их собирает мир, но без слоя-хоста:
## это и есть путь (headless-прогоны, частичный bootstrap), на котором маркер уезжал
## под `root` и оставался там навсегда.
func _make_controller_with_marker() -> HeroController:
	var hero: HeroController = HeroController.new()
	add_child(hero)
	auto_free(hero)
	var ctrl: HeroVisualController = HeroVisualController.new()
	hero.add_child(ctrl)
	ctrl.setup(null, hero)
	ctrl.setup_path_visual()
	return hero


func test_marker_is_a_global_overlay_outside_the_hero_tree() -> void:
	var hero := _make_controller_with_marker()
	var markers := _root_markers()
	assert_that(markers.size()).is_equal(1)
	assert_bool(markers[0].get_parent() != hero).is_true() \
		.override_failure_message("маркер обязан монтироваться вне дерева героя — иначе он не оверлей")
	# Убираем за собой, чтобы следующий кейс стартовал с чистого root.
	hero.free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(_root_markers().size()).is_equal(0)


func test_marker_does_not_outlive_a_freed_hero() -> void:
	var hero := _make_controller_with_marker()
	assert_that(_root_markers().size()).is_equal(1)

	hero.free()
	# Снятие отложенное (`queue_free` из `_exit_tree`: внутри пересборки детей дерево
	# не позволяет ни `remove_child`, ни `free`), поэтому ждём кадр.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_that(_root_markers().size()).is_equal(0)


## Путь `_detach_hero`: героя снимают с родителя, не освобождая (он ещё нужен экрану
## смерти и наследованию). Маркер обязан уйти сразу: «герой мёртв, а его цель боя
## подсвечена на карте» — это и визуальный баг, и течь.
func test_marker_leaves_when_the_dead_hero_is_detached() -> void:
	var hero := _make_controller_with_marker()
	assert_that(_root_markers().size()).is_equal(1)

	hero.get_parent().remove_child(hero)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_that(_root_markers().size()).is_equal(0) \
		.override_failure_message("осиротевший DestMarker пережил героя — утечка под root")
	hero.free()
