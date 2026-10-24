extends BaseTest
## Q-M100 → (а) (D-239): аксессор канон-рас (CanonRaces).
## Данные (7 рас первого эшелона, `first_tier`, имена, модификаторы) лежат в
## mvp_catalog.json и покрываются test_mvp_catalog.gd; здесь — поведение аксессора,
## которым пользуется конструктор (зеркало test_canon_classes.gd для классов).

func test_first_tier_seven_canon_races() -> void:
	var ids: Array[String] = []
	for race in CanonRaces.first_tier():
		ids.append(String(race.get("id", "")))
	var expected := ["gnomes", "halflings", "tieflings", "elves", "humans", "dwarves", "half_orcs"]
	assert_bool(ids == expected) \
		.override_failure_message("первый эшелон K-M5: ожидался %s, получен %s" % [expected, ids]) \
		.is_true()


func test_canon_names_from_catalog() -> void:
	assert_str(CanonRaces.name_for("humans")).is_equal("Люди")
	assert_str(CanonRaces.name_for("half_orcs")).is_equal("Полуорки")
	assert_str(CanonRaces.name_for("elves")).is_equal("Эльфы")


func test_unknown_and_legacy_ids_have_no_canon_name() -> void:
	# «—» для неизвестного id и для легаси-id MoM-тила: подписи легаси-мира остаются
	# за hero_races.gd (фолбэк `_race_label`), каталог их не описывает.
	assert_str(CanonRaces.name_for("elf")).is_equal("—")
	assert_str(CanonRaces.name_for("")).is_equal("—")
	assert_str(CanonRaces.name_for("nobody")).is_equal("—")
	assert_bool(CanonRaces.by_id("elf").is_empty()).is_true()
	assert_bool(CanonRaces.by_id("elves").is_empty()).is_false()
