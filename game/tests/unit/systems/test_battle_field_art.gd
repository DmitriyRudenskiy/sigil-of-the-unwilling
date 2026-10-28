extends BaseTest

## T-269 → (б): полем становится кадр местности БЕЗ собственной гекс-сетки.
##
## Режим выбирает ключ мировой местности, а не константа: `FIELD_ART` даёт
## арт-поле (`uses_art_field()` — тайлы гаснут, границу рисует `BoardOutline`),
## `BACKDROP_ART` и местность вне таблиц оставляют поле тайловым, а кадр —
## пейзажем за краями. Пока режим держался на булевой константе, это было
## нечем проверить; теперь контракт обязателен — мутант «две таблицы слили в
## одну» или «ключ игнорируется» обязан краснеть здесь.
##
## `modulate.a` тайлмапа не проверяется: он ставится в `paint_field()`, а тот
## требует собранный тайлсет, которого у голой сцены нет. Проверяется выбор
## носителя — то, из чего `paint_field()` исходит.

const _Scene := preload("res://scenes/battle_view.tscn")

var _view: BattleView


func before_test() -> void:
	_view = _Scene.instantiate()
	add_child(_view)
	_view.setup()


func after_test() -> void:
	super.after_test()
	_view.queue_free()
	await get_tree().process_frame


func test_field_art_terrain_makes_art_the_field() -> void:
	_view.set_background("grass")
	assert_bool(_view.uses_art_field()).is_true()
	assert_bool(_view._background.texture != null).is_true()


func test_backdrop_terrain_keeps_tile_field() -> void:
	_view.set_background("snow")
	assert_bool(_view.uses_art_field()).is_false()
	assert_bool(_view._background.texture != null).is_true()


func test_terrain_without_approved_art_has_no_background() -> void:
	_view.set_background("lava")
	assert_bool(_view.uses_art_field()).is_false()
	assert_bool(_view._background.texture == null).is_true()
