extends BaseTest
## races-cultures 4.1 (Q-M100 → (а), D-239): конструктор предлагает playable slice 3
## из канон-каталога — «только люди/полуорки/эльфы» (K-M5-правка, владелец 2026-10-04).
##
## До D-239 конструктор наполнялся из hero_races.gd (6 рас MoM-тила: human/elf/dwarf/
## aumaua/orlan/godlike) и предлагал канонически чужие расы, а маска `PLAYABLE_RACES`
## не имела ни одного потребителя. Имя расы в списке — из каталога, а не из легаси.
##
## Экран поднимается как объект (без change_scene); сверяется наполнение OptionButton
## и состояние строки подрасы — это то, что видит игрок.

const CREATION_SCENE := "res://scenes/ui/character_creation.tscn"
const RACE_PATH := "Overlay/Scroll/Root/RaceRow/RaceOption"
const SUBRACE_PATH := "Overlay/Scroll/Root/SubraceRow/SubraceOption"

## Легаси-имена hero_races.gd — их в списке быть не должно. Сравнение точное,
## а не «contains»: канон-«Эльфы» содержит легаси-«Эльф» как подстроку.
const LEGACY_LABELS := ["Человек", "Эльф", "Дварф", "Амауа", "Орлан", "Богоподобный"]

var _screen: Control = null


func before_test() -> void:
	var packed: PackedScene = load(CREATION_SCENE)
	_screen = packed.instantiate()
	add_child(_screen)


func after_test() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _labels(option: OptionButton) -> Array[String]:
	var out: Array[String] = []
	for i in range(option.item_count):
		out.append(option.get_item_text(i))
	return out


func test_race_option_offers_exactly_the_playable_slice() -> void:
	var option: OptionButton = _screen.get_node(RACE_PATH)
	var labels := _labels(option)
	assert_int(labels.size()).is_equal(3)
	# Порядок — порядок каталога, отфильтрованный маской: elves, humans, half_orcs.
	assert_bool(labels == Array(["Эльфы", "Люди", "Полуорки"])) \
		.override_failure_message("ожидались канон-имена каталога, получено %s" % labels) \
		.is_true()


func test_race_option_offers_no_legacy_mom_races() -> void:
	var labels := _labels(_screen.get_node(RACE_PATH) as OptionButton)
	for legacy in LEGACY_LABELS:
		assert_bool(not labels.has(legacy)) \
			.override_failure_message("легаси-раса MoM-тила «%s» в списке конструктора" % legacy) \
			.is_true()


## Ключи, которые конструктор отдаёт профилю, обязаны быть канон-id каталога: их
## читают кампейн-гейты (`first_tier`) и `PopUnit.ancestry_id`. Расхождение `elf`
## (конструктор) ↔ `elves` (кампейн) и есть измеренный дефект Q-M100. Экран берёт
## ключи из этого же списка (проверка ниже — подписи экрана = подписи модели).
func test_playable_race_options_are_catalog_first_tier_ids() -> void:
	var options: Array = PregameFlowModel.playable_race_options()
	assert_int(options.size()).is_equal(3)
	for option in options:
		var race_id := String(option.get("id", ""))
		assert_bool(PregameFlowModel.is_playable_race(race_id)) \
			.override_failure_message("id вне playable slice: %s" % race_id).is_true()
		var race: Dictionary = CanonRaces.by_id(race_id)
		assert_bool(not race.is_empty()) \
			.override_failure_message("id нет в каталоге: %s" % race_id).is_true()
		assert_bool(bool(race.get("first_tier", false))) \
			.override_failure_message("id не первого эшелона: %s" % race_id).is_true()
		var label := String(option.get("name", ""))
		assert_bool(label != race_id and label != "") \
			.override_failure_message("у расы %s нет канон-имени" % race_id).is_true()


## Список конструктора и модель дают один и тот же набор — экран не имеет права
## придумывать свой (иначе маска снова разъедется с носителем).
func test_race_screen_matches_model_options() -> void:
	var labels := _labels(_screen.get_node(RACE_PATH) as OptionButton)
	var from_model: Array[String] = []
	for option in PregameFlowModel.playable_race_options():
		from_model.append(String(option.get("name", "")))
	assert_bool(labels == from_model) \
		.override_failure_message("экран %s ≠ модель %s" % [labels, from_model]).is_true()


## У канон-рас подрас нет (каталог их не описывает) → строка подрасы остаётся «—»
## и неактивна; выбор канон-расы не должен выставлять в список легаси-подрасы.
func test_canon_race_leaves_subrace_row_empty() -> void:
	var option: OptionButton = _screen.get_node(RACE_PATH)
	option.select(0)
	_screen._on_race_changed(0)
	var subrace: OptionButton = _screen.get_node(SUBRACE_PATH)
	assert_bool(subrace.disabled).is_true()
	assert_int(subrace.item_count).is_equal(1)
	assert_str(subrace.get_item_text(0)).is_equal("—")
