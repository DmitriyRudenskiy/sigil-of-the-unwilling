extends BaseTest

# T-148 (подсрез 6.1): восемь мёртвых `theme_override_colors/font_color`.
#
# Семь подписей числа войск на экране артефактов (`ArmyCount`) и счётчик стека юнита
# (`CountLabel` в `unit_sprite.tscn`) перекрашивались в `Color(1, 1, 1, 1)`. В теме
# игры нет `Label/colors/font_color` — обычный `Label` резолвит ровно этот белый из
# дефолтной темы Godot. Переопределение красило цвет, который узел получил бы и без
# него: запись мёртвая, удаление — нулевая дельта.
#
# Нулевость держится двух вещей, и обе закреплены тестом:
#   1) узлы не несут своего носителя (`theme_type_variation`) и в сценах нет
#      вложенной `theme` — иначе снятая запись резолвилась бы не в белый;
#   2) в теме игры по-прежнему нет базового `Label/colors/font_color` — если его
#      добавят (например, по ответу на `Q-M96`), эти восемь удалений перестают быть
#      нулевой дельтой, и гард обязан упасть, а не молчать.
#
# Рантайм-код этих узлов трогает только `text`/`visible`
# (`artifact_inventory_screen.gd` `_refresh_army`, `battle_view.gd` `update_unit_count`)
# — цвета не перекрашивает, проверено по месту.
#
# Что осталось в этих же сценах и ждёт `Q-M96`: шесть золотых подписей уровня навыка
# (`SkillLevel`, корзина S3). Гард их не трогает и держит их счётчиком.
#
# **Поправка (T-189, UI-AC7).** Семь `ArmyCount` перешли на роль `LabelNumber`
# (кегль 14 был ниже порога AC7; по §2 счётчики — числа, 20 PT Mono), то есть перестали быть «узлами без носителя» — по
# прецеденту T-185 («подписи получили золото ролей темы, это перевод в носитель, а не
# локальная перекраска»). Историческое утверждение 6.1 от этого не меняется: у
# базового `Label` в теме цвета нет (кейс ниже), и снятая запись и сегодня резолвилась
# бы в белый — это по-прежнему проверяется на `unit_sprite/CountLabel`, где носителя
# нет. Синтаксический пункт «на узле нет носителя» заменён семантическим: счётчик одет
# ровно в объявленную роль, а его цвет — ровно цвет роли, без локальной записи.

const _ARTIFACT_SCENE := preload("res://scenes/ui/artifact_inventory_screen.tscn")
const _UNIT_SPRITE_SCENE := preload("res://scenes/ui/unit_sprite.tscn")
const _THEME_FILE := "res://assets/theme/game_theme.tres"
const _ARTIFACT_FILE := "res://scenes/ui/artifact_inventory_screen.tscn"
const _UNIT_SPRITE_FILE := "res://scenes/ui/unit_sprite.tscn"

## Снятый цвет — он же дефолт `Label`. Сверка значение в значение, не «похоже на белый».
const _REMOVED_COLOR := Color(1, 1, 1, 1)

## Сколько `theme_override_colors/font_color` обязано остаться в сцене после среза.
# Экран артефактов: 6 золотых `SkillLevel` (S3, ждут Q-M96). Спрайт юнита: ноль.
const _REMAINING_ARTIFACT := 0
const _REMAINING_UNIT_SPRITE := 0

## Роль, в которую T-189 одел семь счётчиков войск (вместо обхода 14 px). Шкала
## §2 [[17-ui-style-guide]] отдаёт «числа/статы … счётчики» строке «20 | LabelNumber
## | PT Mono» — тот же носитель, что на боевом HUD, а не «вторичный текст».
const _ARMY_COUNT_ROLE := "LabelNumber"

const _ARMY_COUNT_PATHS: Array[String] = [
	"Center/Window/Sheet/Units/Bottom/Cards/Card_0/ArmyCount_0",
	"Center/Window/Sheet/Units/Bottom/Cards/Card_1/ArmyCount_1",
	"Center/Window/Sheet/Units/Bottom/Cards/Card_2/ArmyCount_2",
	"Center/Window/Sheet/Units/Bottom/Cards/Card_3/ArmyCount_3",
]


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	return text


func _count_font_color(path: String) -> int:
	var hits := 0
	for line in _read(path).split("\n"):
		if line.strip_edges().begins_with("theme_override_colors/font_color"):
			hits += 1
	return hits


func _labels(paths: Array[String], scene: PackedScene) -> Array[Label]:
	var root := make_node(scene)
	var found: Array[Label] = []
	for path in paths:
		var label := root.get_node_or_null(path) as Label
		assert_that(label).is_not_null()
		found.append(label)
	return found


## Мёртвых записей не осталось, живые (S3) не задеты: счётчик по файлам.
func test_dead_overrides_removed_and_live_ones_kept() -> void:
	assert_int(_count_font_color(_ARTIFACT_FILE)).is_equal(_REMAINING_ARTIFACT) \
		.override_failure_message(
			"в artifact_inventory_screen.tscn ждал %d font_color: семь мёртвых сняты, "
			% _REMAINING_ARTIFACT + "шесть золотых SkillLevel ждут Q-M96"
		)
	assert_int(_count_font_color(_UNIT_SPRITE_FILE)).is_equal(_REMAINING_UNIT_SPRITE) \
		.override_failure_message("в unit_sprite.tscn не должно остаться font_color")


## Экран артефактов: счётчик одет ровно в объявленную роль (T-189), спрайт юнита:
# носителя по-прежнему нет — на нём держится исходное доказательство 6.1. Вложенной
# `theme` нет ни там ни там, иначе резолв пошёл бы мимо темы игры.
func test_removed_nodes_carry_no_variation_and_scenes_no_nested_theme() -> void:
	for label in _labels(_ARMY_COUNT_PATHS, _ARTIFACT_SCENE):
		assert_str(str(label.theme_type_variation)).is_equal(_ARMY_COUNT_ROLE) \
			.override_failure_message(
				"%s: ждался носитель %s — кегль счётчика обязан приезжать из роли (AC7)"
				% [label.name, _ARMY_COUNT_ROLE]
			)
	for label in _labels(["CountLabel"], _UNIT_SPRITE_SCENE):
		assert_str(str(label.theme_type_variation)).is_empty() \
			.override_failure_message("unit_sprite/%s: на узле носитель темы" % label.name)
	for file in [_ARTIFACT_FILE, _UNIT_SPRITE_FILE]:
		var nested: Array[String] = []
		for line in _read(file).split("\n"):
			var t := line.strip_edges()
			if t.begins_with("theme =") or t.begins_with("theme["):
				nested.append(t)
		assert_str(", ".join(nested)).is_empty() \
			.override_failure_message(
				"%s: в сцене вложенная theme — резолв белого пойдёт не от темы игры" % file
			)


## Цвет счётчика — **цвет роли из темы**, а не локальная запись и не дефолт движка:
# локальный `font_color` вернул бы в сцену ровно тот тип мёртвой записи, из-за
# которого и писался этот гард, а белый дефолт означал бы, что роль слетела.
func test_army_counters_resolve_the_role_color_not_a_local_override() -> void:
	var theme: Theme = load(_THEME_FILE)
	assert_that(theme).is_not_null()
	var role_color: Color = theme.get_color("font_color", _ARMY_COUNT_ROLE)
	for label in _labels(_ARMY_COUNT_PATHS, _ARTIFACT_SCENE):
		assert_bool(label.get_theme_color("font_color") == role_color).is_true() \
			.override_failure_message(
				"%s: резолвится %s, ждался цвет роли %s (%s)"
				% [label.name, label.get_theme_color("font_color"), _ARMY_COUNT_ROLE, role_color]
			)


## Нулевая дельта там, где носителя нет: без снятой записи узел рисует тот же цвет,
# что рисовал с ней.
func test_removed_nodes_still_resolve_the_removed_color() -> void:
	for label in _labels(["CountLabel"], _UNIT_SPRITE_SCENE):
		assert_bool(label.get_theme_color("font_color") == _REMOVED_COLOR).is_true() \
			.override_failure_message(
				"unit_sprite/%s: резолв сменился со снятого белого" % label.name
			)


## Предпосылка среза: у базового `Label` в теме игры цвета нет. Появится — восемь
# удалений перестают быть нулевой дельтой, и этот гард должен упасть первым.
func test_theme_has_no_base_label_font_color() -> void:
	var offenders: Array[String] = []
	for line in _read(_THEME_FILE).split("\n"):
		if line.begins_with("Label/colors/"):
			offenders.append(line)
	assert_str(", ".join(offenders)).is_empty() \
		.override_failure_message(
			"в теме появился базовый цвет Label — «белый = дефолт» больше не верно, "
			+ "подсрез 6.1 нужно пересматривать как перекраску"
		)
