extends BaseTest
## team-romance-roleplay 4.6: TeamDialogData/TeamDialogSystem —
## валидация, фильтры, эффекты, контент-гейт, детерминизм.


func _hero_with_follower(
	gender: StringName = &"female",
	orientation: StringName = &"hetero",
	hero_sex: String = "male",
	bond: int = 0,
	romance: int = 0,
	trust: int = 50
) -> HeroController:
	var hero = auto_free(HeroController.new())
	hero.stats_comp.sex = hero_sex
	var f := Follower.new()
	f.uid = 1
	f.name = "Вера"
	f.gender = gender
	f.orientation = orientation
	f.race = &"human"
	f.path = &"warrior"
	f.trait_ids.append(&"brave")
	hero.followers.append(f)
	var p: Dictionary = hero.relationships.pair(1)
	p["bond"] = bond
	p["romance"] = romance
	p["trust"] = trust
	return hero

# ═══════════════════════════════════════════
#  ВАЛИДАЦИЯ (4.1)
# ═══════════════════════════════════════════

func _valid_dialog() -> Dictionary:
	return {
		"id": "test_scene",
		"entry": "n1",
		"nodes": {
			"n1": {
				"lines": [{"text": "Привет", "cond": {}}],
				"choices": [
					{"text": "Ок", "tier": "pg", "cond": {}, "effects": [{"bond": 5}], "next": "n2"},
					{"text": "Пока", "tier": "adult", "cond": {"min_bond": 30}, "effects": [], "next": null,
						"pg_fallback": {"text": "Пока (pg)", "effects": [], "next": null}},
				],
			},
			"n2": {
				"lines": [{"text": "Конец"}],
				"choices": [],
			},
		},
	}

func test_validate_valid_dialog() -> void:
	assert_that(TeamDialogData.validate(_valid_dialog())).is_empty()

func test_validate_missing_id() -> void:
	var d := _valid_dialog()
	d.erase("id")
	var errors: Array = TeamDialogData.validate(d)
	assert_bool(errors.size() > 0).is_true()

func test_validate_bad_entry() -> void:
	var d := _valid_dialog()
	d["entry"] = "nope"
	var errors: Array = TeamDialogData.validate(d)
	assert_bool(errors.size() > 0).is_true()

func test_validate_unknown_cond_key() -> void:
	var d := _valid_dialog()
	(d["nodes"]["n1"]["choices"][0] as Dictionary)["cond"] = {"bogus_key": 1}
	var errors: Array = TeamDialogData.validate(d)
	assert_bool(errors.size() > 0).is_true()

func test_validate_unknown_tier() -> void:
	var d := _valid_dialog()
	(d["nodes"]["n1"]["choices"][0] as Dictionary)["tier"] = "explicit"
	var errors: Array = TeamDialogData.validate(d)
	assert_bool(errors.size() > 0).is_true()

func test_validate_missing_next() -> void:
	var d := _valid_dialog()
	(d["nodes"]["n1"]["choices"][0] as Dictionary)["next"] = "ghost"
	var errors: Array = TeamDialogData.validate(d)
	assert_bool(errors.size() > 0).is_true()

func test_validate_node_without_lines() -> void:
	var d := _valid_dialog()
	(d["nodes"]["n2"] as Dictionary).erase("lines")
	var errors: Array = TeamDialogData.validate(d)
	assert_bool(errors.size() > 0).is_true()

# ═══════════════════════════════════════════
#  ЗАГРУЗКА СТАРТОВЫХ СЦЕН (4.5)
# ═══════════════════════════════════════════

func test_starter_scenes_load() -> void:
	var all: Dictionary = TeamDialogData.load_all()
	for id in ["talk_stranger", "talk_friend", "talk_generic",
			"romance_flirt", "romance_relationship", "proposal", "wedding",
			"jealousy", "conflict", "betrayal"]:
		assert_bool(all.has(id)).is_true()

# ═══════════════════════════════════════════
#  КОНТЕКСТ И ФИЛЬТРЫ (4.2)
# ═══════════════════════════════════════════

func test_make_context() -> void:
	var hero := _hero_with_follower(&"female", &"hetero", "male", 40, 30, 70)
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	assert_that(String(ctx["sex_h"])).is_equal("male")
	assert_that(String(ctx["sex_f"])).is_equal("female")
	assert_that(int(ctx["bond"])).is_equal(40)
	assert_that(int(ctx["romance"])).is_equal(30)
	assert_that(int(ctx["trust"])).is_equal(70)
	assert_that(int(ctx["stage"])).is_equal(RelationshipSystem.STAGE_FRIEND)
	assert_that(int(ctx["romance_stage"])).is_equal(RelationshipSystem.ROM_FLIRT)
	assert_bool(ctx["orientation_compatible"]).is_true()

func test_make_context_incompatible() -> void:
	var hero := _hero_with_follower(&"male", &"hetero", "male")
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	assert_bool(ctx["orientation_compatible"]).is_false()

func test_cond_ok_sex_and_orientation() -> void:
	var hero := _hero_with_follower(&"male", &"hetero", "male")
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	assert_bool(TeamDialogSystem.cond_ok({"sex_h": "male"}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"sex_h": "female"}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"sex_f": "male"}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"orientation_compatible": true}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"orientation_compatible": false}, ctx)).is_true()

func test_cond_ok_stats_and_relations() -> void:
	var hero := _hero_with_follower(&"female", &"hetero", "male", 40, 30, 20)
	hero.stats_comp.stats["cha"] = 5
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	assert_bool(TeamDialogSystem.cond_ok({"min_cha": 4}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"min_cha": 6}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"min_bond": 30}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"min_bond": 50}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"min_romance": 25}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"min_trust": 30}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"max_bond": 40}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"stage": RelationshipSystem.STAGE_FRIEND}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"stage": RelationshipSystem.STAGE_CLOSE_FRIEND}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"romance_stage": RelationshipSystem.ROM_FLIRT}, ctx)).is_true()

func test_cond_ok_identity() -> void:
	var hero := _hero_with_follower()
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	assert_bool(TeamDialogSystem.cond_ok({"race": "human"}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"race": "elf"}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"path": "warrior"}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"path": "priest"}, ctx)).is_false()
	assert_bool(TeamDialogSystem.cond_ok({"trait": "brave"}, ctx)).is_true()
	assert_bool(TeamDialogSystem.cond_ok({"trait": "coward"}, ctx)).is_false()

func test_visible_lines_match_vs_generic() -> void:
	var node := {
		"lines": [
			{"text": "elf_line", "cond": {"race": "elf"}},
			{"text": "generic_line", "cond": {}},
			{"text": "human_line", "cond": {"race": "human"}},
		],
	}
	var hero := _hero_with_follower()  # race human
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	var lines: Array = TeamDialogSystem.visible_lines(node, ctx)
	assert_that(int(lines.size())).is_equal(1)
	assert_that(String((lines[0] as Dictionary)["text"])).is_equal("human_line")
	# elf-герой... нет, race — раса последователя: меняем
	hero.followers[0].race = &"elf"
	ctx = TeamDialogSystem.make_context(hero, hero.followers[0])
	lines = TeamDialogSystem.visible_lines(node, ctx)
	assert_that(String((lines[0] as Dictionary)["text"])).is_equal("elf_line")
	# без совпадений → generic
	hero.followers[0].race = &"dwarf"
	ctx = TeamDialogSystem.make_context(hero, hero.followers[0])
	lines = TeamDialogSystem.visible_lines(node, ctx)
	assert_that(String((lines[0] as Dictionary)["text"])).is_equal("generic_line")

# ═══════════════════════════════════════════
#  КОНТЕНТ-ГЕЙТ (4.4)
# ═══════════════════════════════════════════

func test_adult_gate_with_fallback() -> void:
	var node := {
		"choices": [
			{"text": "pg_choice", "tier": "pg", "cond": {}, "effects": [], "next": null},
			{"text": "adult_choice", "tier": "adult", "cond": {}, "effects": [{"romance": 20}], "next": null,
				"pg_fallback": {"text": "pg_fallback_text", "effects": [{"romance": 10}], "next": null}},
		],
	}
	var hero := _hero_with_follower()
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	# adult выключен: pg + fallback вместо adult
	var off: Array = TeamDialogSystem.visible_choices(node, ctx, false)
	assert_that(int(off.size())).is_equal(2)
	assert_that(String((off[1] as Dictionary)["text"])).is_equal("pg_fallback_text")
	assert_that(int(((off[1] as Dictionary)["effects"][0] as Dictionary)["romance"])).is_equal(10)
	# adult включён: pg + adult
	var on: Array = TeamDialogSystem.visible_choices(node, ctx, true)
	assert_that(int(on.size())).is_equal(2)
	assert_that(String((on[1] as Dictionary)["text"])).is_equal("adult_choice")

func test_adult_gate_without_fallback_hides() -> void:
	var node := {
		"choices": [
			{"text": "pg_choice", "tier": "pg", "cond": {}, "effects": [], "next": null},
			{"text": "adult_choice", "tier": "adult", "cond": {}, "effects": [], "next": null},
		],
	}
	var hero := _hero_with_follower()
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	var off: Array = TeamDialogSystem.visible_choices(node, ctx, false)
	assert_that(int(off.size())).is_equal(1)
	var on: Array = TeamDialogSystem.visible_choices(node, ctx, true)
	assert_that(int(on.size())).is_equal(2)

func test_choice_cond_hides() -> void:
	var node := {
		"choices": [
			{"text": "always", "tier": "pg", "cond": {}, "effects": [], "next": null},
			{"text": "needs_bond", "tier": "pg", "cond": {"min_bond": 60}, "effects": [], "next": null},
		],
	}
	var hero := _hero_with_follower()  # bond 0
	var ctx: Dictionary = TeamDialogSystem.make_context(hero, hero.followers[0])
	var choices: Array = TeamDialogSystem.visible_choices(node, ctx, true)
	assert_that(int(choices.size())).is_equal(1)
	assert_that(String((choices[0] as Dictionary)["text"])).is_equal("always")

# ═══════════════════════════════════════════
#  ВЫБОР СЦЕНЫ ПО СТАДИЯМ (4.2)
# ═══════════════════════════════════════════

func test_pick_dialog_by_stage() -> void:
	TeamDialogSystem.load_dialogs()
	# незнакомец
	var stranger := _hero_with_follower()
	assert_that(TeamDialogSystem.pick_dialog(
		TeamDialogSystem.make_context(stranger, stranger.followers[0]))).is_equal("talk_stranger")
	# друг
	var friend := _hero_with_follower(&"female", &"hetero", "male", 35)
	assert_that(TeamDialogSystem.pick_dialog(
		TeamDialogSystem.make_context(friend, friend.followers[0]))).is_equal("talk_friend")
	# флирт
	var flirt := _hero_with_follower(&"female", &"hetero", "male", 35, 30)
	assert_that(TeamDialogSystem.pick_dialog(
		TeamDialogSystem.make_context(flirt, flirt.followers[0]))).is_equal("romance_flirt")
	# отношения (включая помолвку: proposal — только как сцена-событие)
	var rel := _hero_with_follower(&"female", &"hetero", "male", 35, 55)
	assert_that(TeamDialogSystem.pick_dialog(
		TeamDialogSystem.make_context(rel, rel.followers[0]))).is_equal("romance_relationship")
	var engaged := _hero_with_follower(&"female", &"hetero", "male", 35, 80)
	assert_that(TeamDialogSystem.pick_dialog(
		TeamDialogSystem.make_context(engaged, engaged.followers[0]))).is_equal("romance_relationship")

func test_pick_dialog_fallback_generic() -> void:
	TeamDialogSystem._dialogs = {}
	TeamDialogSystem._dialogs["talk_generic"] = {"id": "talk_generic", "entry": "n1", "nodes": {}}
	var hero := _hero_with_follower()
	assert_that(TeamDialogSystem.pick_dialog(
		TeamDialogSystem.make_context(hero, hero.followers[0]))).is_equal("talk_generic")

# ═══════════════════════════════════════════
#  ЭФФЕКТЫ (4.3)
# ═══════════════════════════════════════════

func test_apply_relationship_effects() -> void:
	var hero := _hero_with_follower()
	var f: Follower = hero.followers[0]
	TeamDialogSystem.apply_effects(hero, f, [
		{"bond": 10}, {"trust": 5}, {"romance": 12},
	])
	var p: Dictionary = hero.relationships.pair(1)
	assert_that(int(p["bond"])).is_equal(10)
	assert_that(int(p["trust"])).is_equal(55)
	assert_that(int(p["romance"])).is_equal(12)

func test_apply_romance_gate() -> void:
	# несовместимая ориентация: romance не растёт
	var hero := _hero_with_follower(&"male", &"hetero", "male")
	var f: Follower = hero.followers[0]
	TeamDialogSystem.apply_effects(hero, f, [{"romance": 12}, {"bond": 5}])
	var p: Dictionary = hero.relationships.pair(1)
	assert_that(int(p["romance"])).is_equal(0)
	assert_that(int(p["bond"])).is_equal(5)

func test_apply_stat_effect() -> void:
	var hero := _hero_with_follower()
	TeamDialogSystem.apply_effects(hero, hero.followers[0], [{"stat": "cha", "delta": 2}])
	assert_that(int(hero.stats_comp.stats["cha"])).is_equal(4)

func test_apply_buff_effect() -> void:
	var hero := _hero_with_follower()
	TeamDialogSystem.apply_effects(hero, hero.followers[0], [{"buff": "morale", "value": 2, "turns": 5}])
	assert_that(hero.morale_bonus()).is_equal(2)
	hero.relationships.tick_buffs()
	assert_that(hero.relationships.active_morale()).is_equal(2)
	for i in 4:
		hero.relationships.tick_buffs()
	assert_that(hero.relationships.active_morale()).is_equal(0)
	assert_that(hero.relationships.temp_morale_buffs.is_empty()).is_true()

func test_apply_event_effect() -> void:
	var hero := _hero_with_follower()
	TeamDialogSystem.apply_effects(hero, hero.followers[0], [{"event": "proposal"}])
	assert_that(int(hero.relationships.pending_scenes.size())).is_equal(1)
	assert_that(String((hero.relationships.pending_scenes[0] as Dictionary)["type"])).is_equal("proposal")

func test_apply_item_effect() -> void:
	var hero := _hero_with_follower()
	var before := int(hero.inventory.backpack.size())
	TeamDialogSystem.apply_effects(hero, hero.followers[0], [{"item": "gift_small"}])
	assert_that(int(hero.inventory.backpack.size())).is_equal(before + 1)
	var art: Artifact = hero.inventory.backpack[before]
	assert_that(String(art.id)).is_equal("gift_small")

# ═══════════════════════════════════════════
#  ДЕТЕРМИНИЗМ (4.6)
# ═══════════════════════════════════════════

func test_deterministic_choices() -> void:
	TeamDialogSystem.load_dialogs()
	var d: Dictionary = TeamDialogSystem.get_dialog("talk_stranger")
	var node: Dictionary = d["nodes"]["n1"]
	var hero_a := _hero_with_follower(&"female", &"hetero", "male", 0, 0, 50)
	var hero_b := _hero_with_follower(&"female", &"hetero", "male", 0, 0, 50)
	var ctx_a: Dictionary = TeamDialogSystem.make_context(hero_a, hero_a.followers[0])
	var ctx_b: Dictionary = TeamDialogSystem.make_context(hero_b, hero_b.followers[0])
	var a: Array = TeamDialogSystem.visible_choices(node, ctx_a, false)
	var b: Array = TeamDialogSystem.visible_choices(node, ctx_b, false)
	assert_that(int(a.size())).is_equal(int(b.size()))
	for i in a.size():
		assert_that(String((a[i] as Dictionary)["text"])).is_equal(String((b[i] as Dictionary)["text"]))
		assert_that(a[i]).is_equal(b[i])
