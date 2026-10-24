extends BaseTest





func _full_profile() -> HeroBuildProfile:
	var p := HeroBuildProfile.new()
	p.name = "Darkstorn"
	p.race = "dwarf"
	p.subrace = "mountain"
	p.character_class = "barbarian"
	p.culture = "aedyr"
	p.background = "soldier"
	p.sex = "male"
	return p

func test_profile_invalid_when_empty() -> void:
	var p := HeroBuildProfile.new()
	assert_bool(p.is_valid()).is_false()

func test_profile_requires_all_fields() -> void:
	var cases := {
		"name": "Dwarf",
		"race": "elf",
		"character_class": "wizard",
		"culture": "aedyr",
		"background": "scholar",
	}
	for field in cases:
		var p := HeroBuildProfile.new()
		p.name = "Dwarf"
		p.race = "elf"
		p.character_class = "wizard"
		p.culture = "aedyr"
		p.background = "scholar"
		p.set(field, "")
		assert_bool(p.is_valid()).is_false()

func test_profile_valid_when_all_set() -> void:
	assert_bool(_full_profile().is_valid()).is_true()

func test_get_stats_base_only() -> void:
	var p := HeroBuildProfile.new()
	p.name = "Dwarf"
	p.race = "human"
	p.character_class = "fighter"
	p.culture = "aedyr"
	p.background = "scholar"
	var s := p.get_stats()
	assert_that(s["attack"]).is_equal(4)
	assert_that(s["defense"]).is_equal(4)
	assert_that(s["spell_power"]).is_equal(4)
	assert_that(s["knowledge"]).is_equal(4)

func test_get_stats_dwarf_bonuses() -> void:
	var p := _full_profile()
	var s := p.get_stats()
	assert_that(s["attack"]).is_equal(6)
	assert_that(s["defense"]).is_equal(6)
	assert_that(s["spell_power"]).is_equal(2)
	assert_that(s["knowledge"]).is_equal(3)

func test_get_stats_negative_bonus_applied() -> void:
	var p := HeroBuildProfile.new()
	p.name = "Dwarf"
	p.race = "orlan"
	p.character_class = "priest"
	p.culture = "living_lands"
	p.background = "merchant"
	var s := p.get_stats()
	assert_that(s["attack"]).is_equal(2)
	assert_that(s["defense"]).is_equal(3)
	assert_that(s["spell_power"]).is_equal(6)
	assert_that(s["knowledge"]).is_equal(7)

func test_get_stats_no_bonus_unknown_key() -> void:
	var p := _full_profile()
	p.race = "does_not_exist"
	p.character_class = "does_not_exist"
	p.culture = "does_not_exist"
	p.background = "does_not_exist"
	var s := p.get_stats()
	assert_that(s["attack"]).is_equal(2)
	assert_that(s["defense"]).is_equal(2)
	assert_that(s["spell_power"]).is_equal(2)
	assert_that(s["knowledge"]).is_equal(2)

func test_get_stats_returns_copy() -> void:
	var p := _full_profile()
	var s1 := p.get_stats()
	s1["attack"] = 999
	var s2 := p.get_stats()
	assert_that(s2["attack"]).is_equal(6)

func test_summary_maps_keys_to_names() -> void:
	var p := _full_profile()
	var s := p.summary()
	assert_that(s["name"]).is_equal("Darkstorn")
	assert_that(s["sex"]).is_equal("Мужской")
	assert_that(s["race"]).is_equal("Дварф")
	assert_that(s["subrace"]).is_equal("Горный")
	assert_that(s["class"]).is_equal("Варвар")
	assert_that(s["culture"]).is_equal("Эдир")
	assert_that(s["background"]).is_equal("Солдат")
	assert_that(s["stats"]).is_equal({"attack": 6, "defense": 6, "spell_power": 2, "knowledge": 3, "int": 2, "wis": 3, "cha": 4, "luk": 2})

func test_summary_sex_mapping() -> void:
	var cases := {"male": "Мужской", "female": "Женский"}
	for key in cases:
		var p := _full_profile()
		p.sex = key
		assert_that(p.summary()["sex"]).is_equal(cases[key])

func test_summary_empty_profile() -> void:
	var p := HeroBuildProfile.new()
	var s := p.summary()
	assert_that(s["name"]).is_equal("—")
	assert_that(s["sex"]).is_equal("Мужской")
	assert_that(s["race"]).is_equal("—")
	assert_that(s["subrace"]).is_equal("")
	assert_that(s["class"]).is_equal("—")
	assert_that(s["culture"]).is_equal("—")
	assert_that(s["background"]).is_equal("—")
	assert_that(s["stats"]).is_equal({"attack": 2, "defense": 2, "spell_power": 2, "knowledge": 2, "int": 2, "wis": 2, "cha": 2, "luk": 2})

func test_to_identity_returns_dict() -> void:
	var p := _full_profile()
	var d := p.to_identity()
	assert_that(d["hero_name"]).is_equal("Darkstorn")
	assert_that(d["hero_race"]).is_equal("dwarf")
	assert_that(d["hero_class"]).is_equal("barbarian")
	assert_that(d["hero_culture"]).is_equal("aedyr")
	assert_that(d["hero_background"]).is_equal("soldier")
	assert_that(d["hero_stats"]).is_equal({"attack": 6, "defense": 6, "spell_power": 2, "knowledge": 3, "int": 2, "wis": 3, "cha": 4, "luk": 2})

func test_registries_have_expected_keys() -> void:
	for k in ["human", "elf", "dwarf", "aumaua", "orlan", "godlike"]:
		assert_bool(HeroRaces.RACES.has(k)).is_true()
	for k in ["barbarian", "fighter", "monk", "paladin", "priest", "druid", "cipher", "wizard", "ranger", "rogue", "chanter"]:
		assert_bool(HeroClasses.CLASSES.has(k)).is_true()
	for k in ["aedyr", "deadfire", "ixamitl", "old_vailia", "rauatai", "living_lands", "white_that_wends", "dyrwood", "naasitaq", "eir_glanfath"]:
		assert_bool(HeroCultures.CULTURES.has(k)).is_true()
	for k in ["soldier", "scholar", "criminal", "sailor", "zealot", "merchant"]:
		assert_bool(HeroCultures.BACKGROUNDS.has(k)).is_true()

# --- social-stats-weapon-tech: 8 статов ---

const SOCIAL_KEYS := ["int", "wis", "cha", "luk"]

func test_every_race_class_has_all_8_stats() -> void:
	var races := HeroRaces.RACES
	var classes := HeroClasses.CLASSES
	for race in races:
		for cls in classes:
			var p := HeroBuildProfile.new()
			p.name = "T"
			p.race = race
			p.character_class = cls
			p.culture = "aedyr"
			p.background = "soldier"
			var s := p.get_stats()
			for key in ["attack", "defense", "spell_power", "knowledge"] + SOCIAL_KEYS:
				assert_bool(bool(s.has(key))).override_failure_message("race=%s class=%s stat=%s" % [race, cls, key]).is_true()

func test_battle_stats_unchanged_by_social() -> void:
	var p := _full_profile()
	var s := p.get_stats()
	# до социальных бонусов: attack 6 / defense 6 / spell 2 / knowledge 3
	assert_that(s["attack"]).is_equal(6)
	assert_that(s["defense"]).is_equal(6)
	assert_that(s["spell_power"]).is_equal(2)
	assert_that(s["knowledge"]).is_equal(3)

func test_social_bonuses_meaningful() -> void:
	# маг: +wis +int; плут: +luk; варвар: +cha
	var wizard := _social("wizard")
	assert_bool(bool(wizard["wis"] > 2 and wizard["int"] > 2)).is_true()
	var rogue := _social("rogue")
	assert_bool(bool(rogue["luk"] > 2)).is_true()
	var barbarian := _social("barbarian")
	assert_bool(bool(barbarian["cha"] > 2)).is_true()

func _social(class_id: String) -> Dictionary:
	var p := HeroBuildProfile.new()
	p.name = "T"
	p.race = "human"
	p.character_class = class_id
	p.culture = "aedyr"
	p.background = "soldier"
	return p.get_stats()

func test_battle_bonus_excludes_social_stats() -> void:
	var comp: HeroStatsComponent = auto_free(HeroStatsComponent.new())
	comp.stats = {"attack": 3, "defense": 1, "spell_power": 2, "knowledge": 1, "int": 10, "wis": 10, "cha": 10, "luk": 10}
	var b := comp.get_battle_bonus({})
	assert_that(b["attack"]).is_equal(3)
	assert_that(b["defense"]).is_equal(1)
	assert_bool(bool(not b.has("int") and not b.has("cha"))).is_true()


## === Q-M100 → (а) (D-239): раса конструктора = канон-каталог ===


## Подпись расы — канон-имя из mvp_catalog.json; легаси-id по-прежнему подписывается
## hero_races.gd (фолбэк), как классы после T-113.
func test_race_label_prefers_canon_catalog() -> void:
	var p := _full_profile()
	p.race = "half_orcs"
	assert_str(String(p.summary()["race"])).is_equal("Полуорки")
	p.race = "dwarf"
	assert_str(String(p.summary()["race"])).is_equal("Дварф")
	p.race = "nobody"
	assert_str(String(p.summary()["race"])).is_equal("—")


## Чисел раса канон-идой не даёт: SRD-модификаторы каталога — шесть атрибутов,
## словарь статов героя — MoM-восьмёрка, читателя у них нет (T-176). Сравниваем
## статы того же профиля без расы: расхождение = 0, выдуманные бонусы не появились.
func test_canon_race_adds_no_stat_bonuses() -> void:
	var bare := _profile_with_race("")
	for race_id in ["humans", "half_orcs", "elves"]:
		var with_race := _profile_with_race(race_id)
		for stat in with_race:
			assert_int(int(with_race[stat])).is_equal(int(bare.get(stat, 0)))


## Легаси-раста (MoM-тила, hero_races.gd) числами по-прежнему играет — фолбэк снят
## быть не может: на нём держится легаси-контур (Q-M44, корзина B).
func test_legacy_race_still_adds_bonuses() -> void:
	var bare := _profile_with_race("")
	var dwarf := _profile_with_race("dwarf")
	assert_int(int(dwarf["defense"]) - int(bare["defense"])).is_equal(2)
	assert_int(int(dwarf["attack"]) - int(bare["attack"])).is_equal(1)


func _profile_with_race(race_id: String) -> Dictionary:
	var p := HeroBuildProfile.new()
	p.name = "Тест"
	p.race = race_id
	p.character_class = "fighter"
	p.culture = "aedyr"
	p.background = "soldier"
	return p.get_stats()
