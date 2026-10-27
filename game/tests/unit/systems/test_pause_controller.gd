extends BaseTest

## PauseController: смена сцены снимает паузу (2026-10-27).
##
## Обработчик движкового `SceneTree.scene_changed` стоял с параметром
## `(_scenetree: SceneTree)`, тогда как сигнал аргументов не несёт: движок каждый
## эмит ронял на арности («Method expected 1 argument(s), but called with 0»),
## `force_release_all()` не вызывался, и уходящая сцена оставалась держать паузу —
## при том что `acquire()` обещает обратное («release(token, owner) обязателен
## или scene_changed»). Проверка ровно об этом: после эмита глубина нуля.
##
## Тест держит и обратную сторону: пока токен не отпущен, пауза обязана стоять,
## иначе «после эмита ноль» проходило бы на вечно пустом стеке.


func test_scene_change_releases_pause_tokens() -> void:
	PauseController.acquire(&"autotest_a")
	PauseController.acquire(&"autotest_b")
	assert_int(PauseController.get_depth()).is_equal(2)
	assert_bool(PauseController.is_paused()).is_true()

	# Отпускание по токену работает до смены сцены (иначе следующий шаг —
	# проверка не автоосвобождения, а того, что пул вообще не растёт).
	var token := PauseController.acquire(&"autotest_c")
	PauseController.release(token, &"autotest_c")
	assert_int(PauseController.get_depth()).is_equal(2)

	(Engine.get_main_loop() as SceneTree).scene_changed.emit()
	assert_int(PauseController.get_depth()).is_equal(0)
	assert_bool(PauseController.is_paused()).is_false()
