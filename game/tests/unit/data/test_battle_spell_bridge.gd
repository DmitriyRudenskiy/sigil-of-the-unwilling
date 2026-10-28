extends BaseTest

## Контракт моста реестра заклинаний в боевой книжный формат
## (`scripts/data/battle_spell_bridge.gd`, T-227 С-4).
##
## У моста две половины, и они неравны. `to_spell()` — собственная работа: он
## переводит строку `SpellRegistry` в `SpellbookDef` (шаблон, параметры, цвет по
## школе), и больше этот перевод нигде не делается. `apply_spell()` — копия живого
## разрешения заклинания из `SpellCaster`, уехавшая в собственную сторону: там
## детерминированная лестница перевеса и `custom_handler` (`cure`, `slow_mass`,
## `resurrection`), здесь — вероятностное сопротивление и свои ветки вместо
## обработчиков. Расхождение посчитано и заведено **T-265**. Тесты поэтому покрывают
## первую половину целиком, а из второй держатся только того, что с живым путём
## совпадает по смыслу: отказ по пустой цели, матрица иммунитета, величина лечения,
## границы подъёма. Арифметику сопротивления (единственный участок с ГСЧ) тест не
## закрепляет нарочно: закрепление легитимизировало бы вторую модель вместо того,
## чтобы её чинить.
##
## Словарь keyword → эффект закрыт одиннадцатью позициями, а `StatusEffects.Effect`
## содержит тринадцать: `PETRIFIED` и `BLIND` в словаре нет. Заклинание с таким
## эффектом не упало бы и не заругалось — `apply_spell` вернул бы `result == "success"`
## со `status == -1`, то есть молчаливое ничего. Проверка на закрытость словаря
## (`test_every_buff_spell...`) краснеет ровно на том коммите, который такое
## заклинание зарегистрирует.

const _SE := preload("res://scripts/data/status_effects.gd")
const _Enums := preload("res://scripts/data/spell_enums.gd")
const _Bridge := preload("res://scripts/data/battle_spell_bridge.gd")


func _unit(tags: Array = [], count: int = 10, hp: int = 10) -> BattleState.BattleUnit:
	var stack := UnitStack.new(UnitStats.new("bridge_target", "Target", 3, 2, hp, 4, 5, tags), count)
	var unit := BattleState.BattleUnit.new(stack)
	unit.max_count = maxi(count, 10)
	return unit


func _spell(id: StringName) -> SpellbookDef:
	return _Bridge.to_spell(Spells.get_spell(id))


## Знание цели = 0 → сопротивление ровно 0 → бросок ГСЧ не может сработать, и тест
## не зависит от случайности, хотя ГСЧ мосту нужен по сигнатуре.
func _apply(id: StringName, unit: BattleState.BattleUnit, sp: int = 8) -> Dictionary:
	return _Bridge.apply_spell(
		_spell(id), unit, {"spell_power": sp}, {"knowledge": 0}, RandomNumberGenerator.new()
	)


func test_to_spell_carries_identity_and_cost() -> void:
	var def: SpellRegistry.SpellDef = Spells.get_spell(&"magic_arrow")
	var spell := _Bridge.to_spell(def)

	assert_object(spell).is_not_null()
	assert_that(String(spell.id)).is_equal("magic_arrow")
	assert_that(spell.display_name).is_equal(def.display_name)
	assert_that(spell.cost).override_failure_message(
		"стоимость книжного заклинания не унаследована с реестра").is_equal(def.base_mana)
	assert_that(spell.description).is_equal(def.desc)
	assert_that(spell.speed).is_equal(_Enums.SpellSpeed.FAST)
	assert_that(String(spell.template)).is_equal("DIRECT_DAMAGE")


## Цвет — единственное, что мост придумывает сам: школа → цвет по таблице.
func test_school_decides_the_color() -> void:
	var expected := {
		&"magic_arrow": _Enums.SpellColor.TIME,   # Air
		&"fireball": _Enums.SpellColor.FIRE,      # Fire
		&"bless": _Enums.SpellColor.PRIMAL,       # Water
		&"stoneskin": _Enums.SpellColor.PRIMAL,   # Earth
	}
	for id in expected:
		assert_that(_spell(id).color).override_failure_message(
			"школа %s не отдала ожидаемый цвет" % id).is_equal(expected[id])

	var alien := SpellRegistry.SpellDef.new()
	alien.id = &"void_shard"
	alien.school = "Void"
	alien.level = 1
	assert_that(_Bridge.to_spell(alien).color).override_failure_message(
		"неизвестная школа не упала в COLORLESS — таблица молчит").is_equal(
		_Enums.SpellColor.COLORLESS)


func test_foreign_input_yields_no_spell() -> void:
	assert_object(_Bridge.to_spell(null)).is_null()
	assert_object(_Bridge.to_spell(RefCounted.new())).override_failure_message(
		"чужой объект превратился в заклинание").is_null()


## Шаблоны: три именных исключения и три класса по полям строки.
func test_template_table() -> void:
	var expected := {
		&"cure": "HEAL_CLEAR",
		&"resurrection": "REVIVE",
		&"town_portal": "PORTAL",
		&"magic_arrow": "DIRECT_DAMAGE",
		&"haste": "KEYWORD_BUFF",
		&"curse": "DEBUFF_CONTROL",
		&"slow_mass": "DEBUFF_CONTROL",
	}
	for id in expected:
		assert_that(String(_spell(id).template)).override_failure_message(
			"заклинание %s попало не в свой шаблон" % id).is_equal(expected[id])

	# Полнота: ни одна строка реестра не осталась без шаблона и не выдумала свой.
	var known := ["DIRECT_DAMAGE", "KEYWORD_BUFF", "DEBUFF_CONTROL", "HEAL_CLEAR", "REVIVE", "PORTAL"]
	for def in Spells.get_all_spells():
		var template := String(_Bridge.to_spell(def).template)
		assert_bool(template in known).override_failure_message(
			"%s: шаблон %s вне списка шести" % [def.id, template]).is_true()


## Таблица целей урона: три заклинания бьют по всем врагам, остальные — по одному.
func test_damage_target_table() -> void:
	for id in [&"fireball", &"armageddon", &"meteor_shower"]:
		assert_that(str(_spell(id).params.get("target", ""))).override_failure_message(
			"%s потерял групповую цель" % id).is_equal("ALL_ENEMY_UNITS")
	for id in [&"magic_arrow", &"lightning_bolt"]:
		assert_that(str(_spell(id).params.get("target", ""))).override_failure_message(
			"%s записан групповым" % id).is_equal("ENEMY_UNIT")


## Флаг `mass` читается из id, а не из эффекта: массовость — свойство строки.
func test_mass_flag_marks_only_the_mass_version() -> void:
	assert_bool(_spell(&"slow_mass").params.get("mass", false)).is_true()
	for id in [&"slow", &"curse", &"weakness"]:
		assert_that(bool(_spell(id).params.get("mass", false))).override_failure_message(
			"одиночное %s помечено массовым" % id).is_false()
	assert_that(_spell(&"haste").params.has("mass")).override_failure_message(
		"буфф получил признак массовости — дебафф-ветка сработала на баффе").is_false()


## Уровень строки ездит в параметрах: от него зависят иммунитет драконов и
## ветвление книжного слоя.
func test_level_travels_into_params() -> void:
	for def in Spells.get_all_spells():
		var spell := _Bridge.to_spell(def)
		assert_that(int(spell.params.get("level", 0))).override_failure_message(
			"%s: уровень не доехал до параметров" % def.id).is_equal(def.level)


## Закрытый словарь keyword → эффект. `StatusEffects.Effect` шире словаря на
## PETRIFIED/BLIND, и новое заклинание с таким эффектом прошло бы как успешное с
## `status == -1` — молчаливое ничего.
func test_every_buff_spell_reaches_a_real_status() -> void:
	var checked := 0
	for def in Spells.get_all_spells():
		if def.buff_effect < 0:
			continue
		checked += 1
		var spell := _Bridge.to_spell(def)
		var keyword := str(spell.params.get("keyword", ""))
		assert_that(keyword).override_failure_message(
			"%s: эффект %d не имеет keyword — словарь keyword → эффект молчит"
			% [def.id, def.buff_effect]).is_not_equal("UNKNOWN")
		assert_bool(_Bridge.KEYWORD_TO_EFFECT.has(keyword)).override_failure_message(
			"%s: keyword %s отсутствует в словаре моста" % [def.id, keyword]).is_true()

		# Статус несут только бафф/дебафф шаблоны; cure лечит и снимает дебаффы,
		# не вешая статус — ровно так же, как его custom_handler в живом пути.
		var template := String(spell.template)
		if template != "KEYWORD_BUFF" and template != "DEBUFF_CONTROL":
			continue
		var unit := _unit()
		var result: Dictionary = _Bridge.apply_spell(
			spell, unit, {"spell_power": 5}, {"knowledge": 0}, RandomNumberGenerator.new()
		)
		assert_that(int(result.get("status", -1))).override_failure_message(
			"%s: успех без наложенного статуса — заклинание-пустышка" % def.id).is_equal(
			def.buff_effect)
		assert_that(unit.statuses.size()).override_failure_message(
			"%s: статус не лёг на юнита" % def.id).is_equal(1)

	assert_that(checked).override_failure_message(
		"ни одной буффающей строки в реестре — проверка выродилась").is_greater_equal(11)


func test_apply_spell_refusals() -> void:
	var unit := _unit()
	var rng := RandomNumberGenerator.new()

	var missing: Dictionary = _Bridge.apply_spell(null, unit, {}, {}, rng)
	assert_that(str(missing.get("result", ""))).is_equal("not_found")

	var no_target: Dictionary = _Bridge.apply_spell(_spell(&"magic_arrow"), null, {}, {}, rng)
	assert_that(str(no_target.get("result", ""))).is_equal("invalid_target")

	var dead := _unit()
	dead.set_count(0)
	var on_dead: Dictionary = _Bridge.apply_spell(
		_spell(&"magic_arrow"), dead, {"spell_power": 8}, {"knowledge": 0}, rng
	)
	assert_that(str(on_dead.get("result", ""))).override_failure_message(
		"заклинание по мёртвому цели вернулось успешным").is_equal("invalid_target")

	# Воскрешение — единственное, что по мёртвому работает.
	var revived: Dictionary = _Bridge.apply_spell(
		_spell(&"resurrection"), dead, {"spell_power": 8}, {"knowledge": 0}, rng
	)
	assert_that(str(revived.get("result", ""))).is_equal("success")


## Матрица иммунитета моста обязана совпадать с живым `SpellCaster`: две копии
## одного правила, и это тот случай, когда расхождение — дефект, а не модель.
func test_immunity_matrix() -> void:
	for id in [&"bless", &"cure", &"curse", &"weakness", &"slow"]:
		var result := _apply(id, _unit(["undead"]))
		assert_that(str(result.get("result", ""))).override_failure_message(
			"нежить не получила иммунитет к %s" % id).is_equal("immune")
	assert_that(str(_apply(&"haste", _unit(["undead"])).get("result", ""))).is_equal("success")

	# Дракон: всё ниже четвёртого уровня, четвёртый и выше — проходит.
	assert_that(str(_apply(&"magic_arrow", _unit(["dragon"])).get("result", ""))).is_equal("immune")
	assert_that(str(_apply(&"lightning_bolt", _unit(["dragon"])).get("result", ""))).is_equal("immune")
	assert_that(str(_apply(&"armageddon", _unit(["dragon"])).get("result", ""))).is_equal("success")

	for id in [&"curse", &"misfortune", &"weakness", &"slow"]:
		for tag in ["mind_immune", "immune_mind"]:
			assert_that(str(_apply(id, _unit([tag])).get("result", ""))).override_failure_message(
				"%s не работает на %s" % [id, tag]).is_equal("immune")
	assert_that(str(_apply(&"shield", _unit(["mind_immune"])).get("result", ""))).is_equal("success")


## Урон считается от силы заклинания, а потери ограничены размером стека.
func test_damage_and_losses_are_bounded_by_the_stack() -> void:
	var squad := _unit([], 3, 10)
	var result := _apply(&"meteor_shower", squad, 8)

	assert_that(int(result.get("damage", 0))).override_failure_message(
		"урон = сила × множитель строки реестра").is_equal(240)
	assert_that(int(result.get("kills", 0))).override_failure_message(
		"заклинание скосило больше существ, чем в стеке").is_equal(3)


## `cure` вешает на себя `custom_handler`, который мост не читает (T-265) и идёт
## через шаблон HEAL_CLEAR. Проверяется то, что в обеих моделях одинаково: снятие
## дебаффов и величина лечения.
func test_cure_clears_debuffs_and_heals() -> void:
	var unit := _unit()
	unit.add_status(_SE.Effect.CURSE, 3)
	unit.add_status(_SE.Effect.HASTE, 3)

	var result := _apply(&"cure", unit, 7)

	assert_that(int(result.get("heal", 0))).override_failure_message(
		"лечение = 10 × сила заклинания").is_equal(70)
	assert_that(unit.statuses.has(_SE.Effect.CURSE)).override_failure_message(
		"проклятие пережило исцеление").is_false()
	assert_that(unit.statuses.has(_SE.Effect.HASTE)).override_failure_message(
		"исцеление сняло не дебафф").is_true()


## Подъём ограничен размером стека и не бывает нулевым.
func test_revive_is_capped_by_the_stack_size() -> void:
	var fallen := _unit([], 0, 40)
	var result := _apply(&"resurrection", fallen, 8)
	assert_that(int(result.get("revive_count", 0))).override_failure_message(
		"подъём = сила × 20 / hp существа").is_equal(4)

	var tiny := _unit([], 0, 40)
	tiny.max_count = 2
	var capped := _apply(&"resurrection", tiny, 8)
	assert_that(int(capped.get("revive_count", 0))).override_failure_message(
		"подняли больше, чем вмещает стек").is_equal(2)

	var frail := _unit([], 0, 1000)
	var floored := _apply(&"resurrection", frail, 1)
	assert_that(int(floored.get("revive_count", 0))).override_failure_message(
		"нулевой подъём — это не подъём; нижняя граница равна одному").is_equal(1)
