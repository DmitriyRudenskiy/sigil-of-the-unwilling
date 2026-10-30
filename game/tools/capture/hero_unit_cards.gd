# Кадр карточек отряда и строки уровня для ux-review T-306.
#
# Что проверяется кадром. Макет (T-249, строки 23–25 карты элементов) требует в
# карточках отряда имя, иконку, численность, уровень и значения (полоски HP/MP),
# а в левой колонке — строку уровня. У модели героя, которую экран видит в
# единственном своём живом носителе (окно «Модель героя» из настроек, D-255),
# уровня нет: `HeroController` хранит только опыт (`get_xp`), а его писатель
# `world_battle_coordinator.gd:370` живёт в архивной мирной линии. У стека тоже
# нет ни уровня, ни текущего HP, ни второй шкалы. Поэтому `LevelRow` и
# `CardLv_*`/`CardHp_*`/`CardMp_*` скрыты, а не обнулены (D-280, T-251), и кадр
# обязан это показывать: пустая полоса под именем, в карточках — имя, иконка и
# число без третьей строки и без полосок.
#
# Герой строится той же фабрикой, что и живой путь: `HeroModelFactory.build_hero`
# (`main_menu.gd:227`), — чтобы левая колонка, кукла и снаряжение были из того же
# состояния, а не из голого `HeroController.new()`. Два отклонения от живого пути
# фиксируются открыто.
#
#   1) Фикстура добавляет героя в дерево (`screen.add_child`), как `hero_doll`
#      (T-258): живой путь героя не аддоцит, но без `_ready` кукла остаётся без
#      текстур, и кадр мерил бы не то. На данные карточек это не влияет.
#   2) Фикстура наполняет ростер настоящими стеками из реестра `units`. Живая
#      модель приходит с пустой армией (`HeroArmyController.initialize()`
#      вызывается только из `HeroController.setup(map)`, а карту модель не
#      получает), и в этом состоянии все четыре карточки — пустые рамки; этот
#      случай зафиксирован гардом теста, а не кадром. Кадром закрытых состояний
#      открытые не выдаются (урок гарда шрифтовой гигиены).
#
# Уровня и второй шкалы у стека нет, поэтому фикстура ничего из этого не
# выставляет: она только наполняет существующие носители (имя, иконка, число).

var scene: Node = get_tree().current_scene
var screen: Node = scene.get_node_or_null("HeroModelWindow") as Node
# Тот же конструктор модели, что у живого пути из настроек.
var hero: HeroController = HeroModelFactory.build_hero(GameText.model_hero_warrior(), "warrior")
screen.add_child(hero)
# Ростер из настоящих стеков того же реестра, которым пользуется экран.
var units: Node = Services.resolve(&"units")
var stacks: Array[UnitStack] = []
for pair in [["swordsmen", 103], ["archers", 36], ["cavalry", 34], ["mages", 10]]:
	stacks.append(units.make_fixed_stack(String(pair[0]), int(pair[1])))
hero.army.army = stacks
# Живой путь: set_hero() -> show().
screen.set_hero(hero)
screen.show()

# Меры, а не пиксели: уровень и опыт модели, размеры и видимость скрытых меток.
var out := {}
out["hero_xp"] = hero.get_xp()
out["hero_has_get_level"] = hero.has_method("get_level")
out["hero_has_level_property"] = hero.get("level") != null
out["roster_size"] = hero.army.army.size()
var lv := screen.get_node_or_null("Center/Window/Sheet/Left/LevelRow") as Control
out["level_row_visible"] = lv.visible if lv else "нет узла"
out["level_row_text"] = (lv as Label).text if lv is Label else "-"
out["mana_val"] = (screen.get_node_or_null("Center/Window/Sheet/BandMana/Mana_val") as Label).text
var stats: Array = []
for i in 4:
	var nm := screen.get_node_or_null("Center/Window/Sheet/Left/StatName_%d" % i) as Label
	var sv := screen.get_node_or_null("Center/Window/Sheet/Left/StatValue_%d" % i) as Label
	stats.append({"name": nm.text if nm else "-", "value": sv.text if sv else "-"})
out["stats"] = stats
var cards: Array = []
for i in 4:
	var base := "Center/Window/Sheet/Units/Bottom/Cards/Card_%d/" % i
	var ic := screen.get_node_or_null(base + "ArmyIcon_%d" % i) as TextureRect
	var ct := screen.get_node_or_null(base + "ArmyCount_%d" % i) as Label
	var nm := screen.get_node_or_null(base + "CardName_%d" % i) as Label
	var lvv := screen.get_node_or_null(base + "CardLv_%d" % i) as Control
	var hp := screen.get_node_or_null(base + "CardHp_%d" % i) as Control
	var mp := screen.get_node_or_null(base + "CardMp_%d" % i) as Control
	var entry := {
		"i": i,
		"name_visible": nm.visible if nm else "нет узла",
		"name_text": nm.text if nm else "нет узла",
		"icon_visible": ic.visible if ic else "нет узла",
		"count_text": ct.text if ct else "нет узла",
		"lv_visible": lvv.visible if lvv else "нет узла",
		"hp_visible": hp.visible if hp else "нет узла",
		"mp_visible": mp.visible if mp else "нет узла",
	}
	if i < hero.army.army.size():
		var st: UnitStack = hero.army.army[i]
		entry["stack_key"] = str(st.get_key())
		entry["stack_count"] = st.count
		entry["stack_has_level"] = st.has_method("get_level") or st.get("level") != null
		entry["stack_has_current_hp"] = st.get("current_hp") != null
		entry["stack_stats_hp_max"] = st.stats.hp if st.stats else -1
		entry["stack_has_mana"] = st.get("mana") != null
	cards.append(entry)
out["cards"] = cards
return out
