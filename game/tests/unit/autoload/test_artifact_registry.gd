extends BaseTest

## Реестр артефактов (autoload `Artifacts`, `scripts/autoload/artifact_registry.gd`).
##
## Дыра T-227 С-4: носитель на 299 строк не покрывался ни одним тестом, хотя на нём
## держатся три читателя (`hero_model_factory`, `battle_handoff` → `battle_state_builder`,
## экран снаряжения) и один визуальный спутник — иконки `assets/artifacts/`. Проверки
## поэтому не «каждая строка таблицы», а контракт реестра: то, что ломается при
## правке данных и не видно на глаз.

const ICON_DIR := "res://assets/artifacts"

## Ключи модификаторов, у которых есть читатель: `get_battle_bonus` (attack, defense,
## spell_power, knowledge, luck, morale), `hero_controller` (movement),
## `battle_state_builder` (stack_hp, stack_hp_percent, stack_speed),
## `hero_resources` (daily_gems).
const WIRED_KEYS := [
	"attack", "defense", "spell_power", "knowledge", "luck", "morale", "movement",
	"stack_hp", "stack_hp_percent", "stack_speed", "daily_gems",
]

## Ключи-писатели без читателя. Список обязан сохнуть, а не расти: ключ из него либо
## получает приёмник, либо снимается вместе с доступом (прецедент немых ключей
## событийного слоя, Q-M79 → (а), D-197). Убран из данных молча — значит вернуть
## себе долг, поэтому он здесь, а не в данных.
const NEME_KEYS := ["castle_growth_percent"]


func _reg() -> ArtifactRegistry:
	return Artifacts


func _all() -> Array[Artifact]:
	return _reg().get_all()


func test_registry_holds_unique_rows() -> void:
	var all: Array[Artifact] = _all()
	assert_bool(all.is_empty()).override_failure_message("реестр пуст — читатели получат null").is_false()
	var ids := {}
	for art in all:
		var id := String(art.id)
		assert_bool(ids.has(id)).override_failure_message("повтор id %s" % id).is_false()
		ids[id] = true
	assert_that(ids.size()).is_equal(all.size())


## Пустое имя или нулевая цена в таблице — это предмет, который игрок не может ни
## назвать, ни продать: `HeroInventory.value_of` из цены делает половину стоимости.
func test_rows_carry_name_price_and_weight() -> void:
	for art in _all():
		var tag := String(art.id)
		assert_str(art.display_name.strip_edges()).override_failure_message(
			"у %s пустое display_name" % tag).is_not_empty()
		assert_that(art.value_gold).override_failure_message(
			"у %s цена %d — предмет нельзя оценить" % [tag, art.value_gold]).is_greater(0)
		assert_that(art.weight).override_failure_message(
			"у %s отрицательный вес %.2f" % [tag, art.weight]).is_greater_equal(0.0)


## Действующий габарит обязана вмещать сетка снаряжения: иначе предмет невозможно
## положить, и единственная доступная с ним операция — отказ. `cells == ZERO` в данных
## — не дефект, а «не задан», тогда габарит берётся от слота (`resolved_cells`), а
## `cells_error()` обязан молчать: явный, но бессмысленный габарит — ошибка данных.
## Поворот разрешён: `HeroInventory.can_place` поворачивает сам.
func test_footprints_fit_the_equipment_grid() -> void:
	var grid: Vector2i = GameNumbers.INVENTORY_GRID
	for art in _all():
		var cells: Vector2i = art.resolved_cells()
		var tag: String = "%s slot=%s cells=%s" % [art.id, art.slot, cells]
		assert_str(art.cells_error()).override_failure_message(
			"%s: габарит нечем посчитать" % tag).is_empty()
		assert_that(cells.x).override_failure_message("у %s нулевая ширина" % tag).is_greater(0)
		assert_that(cells.y).override_failure_message("у %s нулевая высота" % tag).is_greater(0)
		var fits_straight: bool = cells.x <= grid.x and cells.y <= grid.y
		var fits_rotated: bool = cells.y <= grid.x and cells.x <= grid.y
		assert_bool(fits_straight or fits_rotated).override_failure_message(
			"%s не влезает в сетку %s ни прямо, ни поворотом" % [tag, grid]).is_true()


## Иконка и строка реестра — два носителя одного предмета: генератор
## `scripts/build/gen_artifact_icons.gd` рисует по строкам реестра, экран снаряжения
## грузит `assets/artifacts/<id>.png`. Расхождение в любую сторону — белая клетка
## (иконки нет) или мёртвый ассет (строки нет).
func test_rows_and_icons_are_one_to_one() -> void:
	var dir := DirAccess.open(ICON_DIR)
	assert_bool(dir != null).is_true()
	if dir == null:
		return
	var pngs: Array[String] = []
	for f in dir.get_files():
		if f.get_extension().to_lower() == "png":
			pngs.append(f.get_basename())
	pngs.sort()
	var ids: Array[String] = []
	for art in _all():
		ids.append(String(art.id))
	ids.sort()
	assert_bool(ids == pngs).override_failure_message(
		"строки реестра и набор иконок разошлись: реестр %s, иконки %s" % [ids, pngs]).is_true()


## Партиция по редкости: сумма корзин равна реестру, корзины не пересекаются, пустых
## нет — `random_of_rarity` на пустой корзине возвращает null, и лут-стол молча
## осиротееет.
func test_rarity_buckets_partition_the_registry() -> void:
	var reg := _reg()
	var all := _all()
	var seen := {}
	var total: int = 0
	for rarity in [Artifact.Rarity.MINOR, Artifact.Rarity.MAJOR, Artifact.Rarity.RELIC]:
		var bucket: Array[Artifact] = reg.get_by_rarity(rarity)
		assert_bool(bucket.is_empty()).override_failure_message(
			"корзина редкости %d пуста — random_of_rarity вернёт null" % rarity).is_false()
		for art in bucket:
			var id := String(art.id)
			assert_bool(seen.has(id)).override_failure_message(
				"%s лежит в двух корзинах редкости" % id).is_false()
			seen[id] = true
			assert_that(int(art.rarity)).override_failure_message(
				"%s лежит не в своей корзине" % id).is_equal(int(rarity))
		total += bucket.size()
	assert_that(total).is_equal(all.size())


## `reset()` обязан чистить и индекс по редкости: `_by_rarity` строится один раз внутри
## `ensure_definitions`, и если его не сбросить, после сбоя (новая игра) читатель
## получит артефакты предыдущего запуска.
func test_reset_rebuilds_both_indexes() -> void:
	var reg := _reg()
	var before := {}
	for art in reg.get_all():
		before[String(art.id)] = true
	var relic_before: int = reg.get_by_rarity(Artifact.Rarity.RELIC).size()
	reg.reset()
	var after := reg.get_all()
	assert_that(after.size()).override_failure_message(
		"после reset реестр собрал другое число строк").is_equal(before.size())
	for art in after:
		assert_bool(before.has(String(art.id))).override_failure_message(
			"после reset в реестре появилась незнакомая строка %s" % art.id).is_true()
	assert_that(reg.get_by_rarity(Artifact.Rarity.RELIC).size()).is_equal(relic_before)


## Случайность обязана быть воспроизводимой по зерну: прогоны матрицы и баланс-пробы
## сравнивают между собой именно засеянные серии.
func test_random_draws_follow_the_seed_and_stay_in_pool() -> void:
	var reg := _reg()
	var all := reg.get_all()
	var ids := {}
	for art in all:
		ids[String(art.id)] = true
	var first: Array[String] = _draw(reg, 7, 12)
	var again: Array[String] = _draw(reg, 7, 12)
	assert_str(str(first)).override_failure_message(
		"одно и то же зерно дало разные серии").is_equal(str(again))
	var other: Array[String] = _draw(reg, 1234, 12)
	assert_bool(first != other).override_failure_message(
		"разные зёрна дали одну серию — зерно не доходит до rng").is_true()
	for id in first:
		assert_bool(ids.has(id)).override_failure_message(
			"random_any выдал %s вне реестра" % id).is_true()
	var rng := TestFactories.seeded(3)
	for rarity in [Artifact.Rarity.MINOR, Artifact.Rarity.MAJOR, Artifact.Rarity.RELIC]:
		for i in 8:
			var art: Artifact = reg.random_of_rarity(rarity, rng)
			assert_object(art).override_failure_message(
				"random_of_rarity(%d) вернул null на непустой корзине" % rarity).is_not_null()
			if art != null:
				assert_that(int(art.rarity)).override_failure_message(
					"random_of_rarity(%d) выдал предмет другой редкости %s" % [rarity, art.id]
				).is_equal(int(rarity))


## Словарь модификаторов закрыт: новый ключ допускается только вместе с читателем.
## Иначе он ложится в сумму `get_total_modifiers()` и живёт там как обещание, которое
## никто не исполняет, — тот же класс, что немые ключи эффектов событий (D-197).
func test_modifier_vocabulary_is_closed() -> void:
	var allowed := {}
	for key in WIRED_KEYS:
		allowed[key] = true
	for key in NEME_KEYS:
		allowed[key] = true
	var unknown: Array[String] = []
	var neme_seen: Array[String] = []
	for art in _all():
		for key in art.modifiers:
			if not allowed.has(String(key)):
				unknown.append("%s.%s" % [art.id, key])
			elif String(key) in NEME_KEYS:
				neme_seen.append("%s.%s" % [art.id, key])
	assert_bool(unknown.is_empty()).override_failure_message(
		"ключи модификаторов без читателя и без пометки: %s — добавь приёмник или "
		% unknown + "запиши в NEME_KEYS с тикетом").is_true()
	print("немые ключи модификаторов (писатель без читателя, T-264): ", neme_seen)


func _draw(reg: ArtifactRegistry, seed_value: int, count: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[String] = []
	for i in count:
		var art: Artifact = reg.random_any(rng)
		out.append(String(art.id) if art != null else "null")
	return out
