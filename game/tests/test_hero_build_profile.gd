extends "res://tests/test_base.gd"
## hero-build-profile: HeroBuildProfile — данные о герое, собранных при
## создании в CharacterCreationUI. is_valid(), get_stats() (базовые {2,2,2,2}
## + бонусы расы/класса/культуры/прошлого), summary() (ключи → RU-названия,
## пустые = «—»), to_identity() (словарь с hero_-ключами для WorldBootstrap).

const _Profile = preload("res://scripts/data/HeroBuildProfile.gd")
const _Races = preload("res://scripts/data/hero_races.gd")
const _Classes = preload("res://scripts/data/hero_classes.gd")
const _Cultures = preload("res://scripts/data/hero_cultures.gd")

## Профиль с полным набором: Дварф / Горный / Варвар / Эдир / Солдат.
## Статы: base {2,2,2,2} + dwarf {a1,d2,sp-1} + barbarian {a2,d1}
## + aedyr {k1,sp1} + soldier {a1,d1} = {a6, d6, sp2, k3}.
func _full_profile() -> _Profile:
	var p := _Profile.new()
	p.name = "Darkstorn"
	p.race = "dwarf"
	p.subrace = "mountain"
	p.character_class = "barbarian"
	p.culture = "aedyr"
	p.background = "soldier"
	p.sex = "male"
	return p

# ==================== 1.1 is_valid ====================

func test_profile_invalid_when_empty() -> void:
	var p := _Profile.new()
	assert_false(p.is_valid(), "empty profile invalid")


func test_profile_requires_all_fields() -> void:
	var cases := {
		"name": "Dwarf",
		"race": "elf",
		"character_class": "wizard",
		"culture": "aedyr",
		"background": "scholar",
	}
	for field in cases:
		var p := _Profile.new()
		p.name = "Dwarf"
		p.race = "elf"
		p.character_class = "wizard"
		p.culture = "aedyr"
		p.background = "scholar"
		p.set(field, "")
		assert_false(p.is_valid(), "invalid when %s empty" % field)


func test_profile_valid_when_all_set() -> void:
	assert_true(_full_profile().is_valid(), "valid when all set")

# ==================== 1.2 get_stats ====================

func test_get_stats_base_only() -> void:
	var p := _Profile.new()
	p.name = "Dwarf"
	p.race = "human"
	p.character_class = "fighter"
	p.culture = "aedyr"
	p.background = "scholar"
	var s := p.get_stats()
	# human {a1,d1}, fighter {a1,d1}, aedyr {k1,sp1}, scholar {sp1,k1}.
	assert_eq(s["attack"], 4, "base 2 + 1 + 1")
	assert_eq(s["defense"], 4, "base 2 + 1 + 1")
	assert_eq(s["spell_power"], 4, "base 2 + 1 + 1")
	assert_eq(s["knowledge"], 4, "base 2 + 1 + 1")


func test_get_stats_dwarf_bonuses() -> void:
	var p := _full_profile()
	var s := p.get_stats()
	assert_eq(s["attack"], 6, "2+1+2+1")
	assert_eq(s["defense"], 6, "2+2+1+1")
	assert_eq(s["spell_power"], 2, "2-1+1")
	assert_eq(s["knowledge"], 3, "2+1")


func test_get_stats_negative_bonus_applied() -> void:
	# orlan {k2,sp1,a-1} + priest {sp2,k1} + living_lands {a1,d1,sp1} + merchant {k2}.
	var p := _Profile.new()
	p.name = "Dwarf"
	p.race = "orlan"
	p.character_class = "priest"
	p.culture = "living_lands"
	p.background = "merchant"
	var s := p.get_stats()
	assert_eq(s["attack"], 2, "2-1+1")
	assert_eq(s["defense"], 3, "2+1")
	assert_eq(s["spell_power"], 6, "2+1+2+1")
	assert_eq(s["knowledge"], 7, "2+2+1+2")


func test_get_stats_no_bonus_unknown_key() -> void:
	# race/key не существует — бонусов нет, только база {2,2,2,2}.
	var p := _full_profile()
	p.race = "does_not_exist"
	p.character_class = "does_not_exist"
	p.culture = "does_not_exist"
	p.background = "does_not_exist"
	var s := p.get_stats()
	assert_eq(s["attack"], 2, "base only")
	assert_eq(s["defense"], 2, "base only")
	assert_eq(s["spell_power"], 2, "base only")
	assert_eq(s["knowledge"], 2, "base only")


func test_get_stats_returns_copy() -> void:
	var p := _full_profile()
	var s1 := p.get_stats()
	s1["attack"] = 999
	var s2 := p.get_stats()
	assert_eq(s2["attack"], 6, "mutating returned dict doesn't affect profile")

# ==================== 1.3 summary ====================

func test_summary_maps_keys_to_names() -> void:
	var p := _full_profile()
	var s := p.summary()
	assert_eq(s["name"], "Darkstorn", "name")
	assert_eq(s["sex"], "Мужской", "sex key -> RU name")
	assert_eq(s["race"], "Дварф", "race key -> RU name")
	assert_eq(s["subrace"], "Горный", "subrace key -> RU name")
	assert_eq(s["class"], "Варвар", "class key -> RU name")
	assert_eq(s["culture"], "Эдир", "culture key -> RU name")
	assert_eq(s["background"], "Солдат", "background key -> RU name")
	assert_eq(s["stats"], {"attack": 6, "defense": 6, "spell_power": 2, "knowledge": 3}, "stats")


func test_summary_sex_mapping() -> void:
	var cases := {"male": "Мужской", "female": "Женский"}
	for key in cases:
		var p := _full_profile()
		p.sex = key
		assert_eq(p.summary()["sex"], cases[key], "sex %s -> %s" % [key, cases[key]])


func test_summary_empty_profile() -> void:
	var p := _Profile.new()
	var s := p.summary()
	assert_eq(s["name"], "—", "empty name")
	assert_eq(s["sex"], "Мужской", "default sex")
	assert_eq(s["race"], "—", "empty race")
	assert_eq(s["subrace"], "", "empty subrace")
	assert_eq(s["class"], "—", "empty class")
	assert_eq(s["culture"], "—", "empty culture")
	assert_eq(s["background"], "—", "empty background")
	assert_eq(s["stats"], {"attack": 2, "defense": 2, "spell_power": 2, "knowledge": 2}, "base stats")

# ==================== 1.4 to_identity ====================

func test_to_identity_returns_dict() -> void:
	var p := _full_profile()
	var d := p.to_identity()
	assert_eq(d["hero_name"], "Darkstorn", "hero_name")
	assert_eq(d["hero_race"], "dwarf", "hero_race key")
	assert_eq(d["hero_class"], "barbarian", "hero_class key")
	assert_eq(d["hero_culture"], "aedyr", "hero_culture key")
	assert_eq(d["hero_background"], "soldier", "hero_background key")
	assert_eq(d["hero_stats"], {"attack": 6, "defense": 6, "spell_power": 2, "knowledge": 3}, "hero_stats")

# ==================== 1.5 registry sanity ====================

func test_registries_have_expected_keys() -> void:
	for k in ["human", "elf", "dwarf", "aumaua", "orlan", "godlike"]:
		assert_true(_Races.RACES.has(k), "race %s present" % k)
	for k in ["barbarian", "fighter", "monk", "paladin", "priest", "druid", "cipher", "wizard", "ranger", "rogue", "chanter"]:
		assert_true(_Classes.CLASSES.has(k), "class %s present" % k)
	for k in ["aedyr", "deadfire", "ixamitl", "old_vailia", "rauatai", "living_lands", "white_that_wends", "dyrwood", "naasitaq", "eir_glanfath"]:
		assert_true(_Cultures.CULTURES.has(k), "culture %s present" % k)
	for k in ["soldier", "scholar", "criminal", "sailor", "zealot", "merchant"]:
		assert_true(_Cultures.BACKGROUNDS.has(k), "background %s present" % k)
