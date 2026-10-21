extends BaseTest
## V-5 (D-220): упрощённый персистентный HP + REST (план-гейт, подтверждён
## владельцем; D1–D4). Покрытие:
##   1) миграция ensure_hp (правила + идемпотентность, DEAD не воскрешаем);
##   2) rest (живые → max_hp/READY, DEAD не трогаем, идемпотентность);
##   3) apply_battle_result (DEAD / hp>0 / выжил с 0 → 1+WOUNDED);
##   4) current_hp переносится между боями без REST (вход в бой — из остатка);
##   5) REST между боями восстанавливает (боевой цикл идентичен);
##   6) REST в settlement-фазе: герой в городе → да; герой в походе → нет;
##   7) раненый герой (выжил с 0) → 1+WOUNDED → settlement-REST → полный/READY;
##   8) миграция загруженного сейва (старый сейв без HP-полей → валидный);
##   9) смерть героя: ровно один DEAD (партия 1 → wipe/defeat; партия 2 →
##      первый DEAD, второй жив, следующий герой — второй член; двойной
##      смерти нет);
##  10) WOUNDED — живой: alive_members, лимит партии (слот занят);
##  11) враги не сохраняют урон (боевой цикл идентичен, детерминизм).
##
## Статблоки (campaign.json): warrior hp45 ac15 atk19 dmg9 dex12 con3;
## raider_tier_1 hp7 ac11 atk12 dmg5 dex12 con1; raider_tier_3 (boss)
## hp55 ac15 atk16 dmg8 dex12 con3, мощный ×1.5 CD2, ярость при HP ≤ 28.
## Детерминированные расчёты (герой ходит первым: инициатива 12=12, dex 12=12,
## id "" < "raider_tN"; зона: margin ≥ 4 → triumph ×2, ≥ 0 → success ×1):
##   герой(45, ac5) vs tier1(hp20): R1 18 → рейдер 2, рейдер 10 → герой 35;
##   R2 18 → рейдер падает (WOUNDED, con1) → win, герой 35;
##   герой(35) vs то же: → 25, win (старт с остатка — без REST);
##   герой(45) vs tier3: triumph 18/раунд; босс: мощный 12, ярость (19 ≤ 28
##   после R2) → 10, 10; R4 босс падает (WOUNDED) → win, герой 13;
##   герой(1) vs tier3: R1 мощный 12 → герой с 0 → con 3: WOUNDED, lose;
##   герой(1, con −3) vs tier3: 3 провала save → DEAD, lose.

const SAVE_SLOT := 4  # отдельный слот; 1/2 — test_mvp_save, 3 — cutover-композит


func _member(uid: int, xp: int = 0) -> Dictionary:
	var m := {
		"id": "m_%d" % uid, "class": "fighter", "race": "humans", "level": 1,
		"xp": xp, "luck": 0, "state": PartySystem.STATE_READY,
		"stats": {"str": 14, "dex": 10, "con": 12, "int": 10, "wis": 10, "cha": 10},
	}
	if uid >= 0:
		m["uid"] = uid
	PartySystem.ensure_hp(m)
	return m


## ── 1) миграция ensure_hp ──────────────────────────────────────────────────

func test_ensure_hp_migration_rules() -> void:
	# живой без current_hp → полный HP
	var m: Dictionary = {"id": "a", "state": PartySystem.STATE_READY}
	PartySystem.ensure_hp(m)
	assert_int(int(m.get("max_hp", -1))) \
		.override_failure_message("max_hp = warrior hp").is_equal(45)
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("живой без current_hp → полный").is_equal(45)
	# идемпотентность
	PartySystem.ensure_hp(m)
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("повторный вызов не меняет валидное состояние").is_equal(45)
	# живой с current_hp ≤ 0 → 1 + WOUNDED
	var m2: Dictionary = {"id": "b", "state": PartySystem.STATE_READY, "max_hp": 45, "current_hp": 0}
	PartySystem.ensure_hp(m2)
	assert_int(int(m2.get("current_hp", -1))) \
		.override_failure_message("живой с ≤0 → 1").is_equal(1)
	assert_bool(str(m2.get("state", "")) == PartySystem.STATE_WOUNDED) \
		.override_failure_message("живой с ≤0 → WOUNDED").is_true()
	PartySystem.ensure_hp(m2)
	assert_int(int(m2.get("current_hp", -1))) \
		.override_failure_message("идемпотентность для 1/WOUNDED").is_equal(1)
	# DEAD — не воскрешаем
	var m3: Dictionary = {"id": "c", "state": PartySystem.STATE_DEAD}
	PartySystem.ensure_hp(m3)
	assert_bool(str(m3.get("state", "")) == PartySystem.STATE_DEAD) \
		.override_failure_message("DEAD остаётся DEAD").is_true()
	assert_bool(not m3.has("current_hp")) \
		.override_failure_message("DEAD — без current_hp (не воскрешаем)").is_true()
	# валидное WOUNDED-состояние не меняется
	var m4: Dictionary = {"id": "d", "state": PartySystem.STATE_WOUNDED, "max_hp": 45, "current_hp": 1}
	PartySystem.ensure_hp(m4)
	assert_int(int(m4.get("current_hp", -1))).is_equal(1)
	assert_bool(str(m4.get("state", "")) == PartySystem.STATE_WOUNDED).is_true()


## ── 2) rest ────────────────────────────────────────────────────────────────

func test_rest_heals_alive_and_clears_wounded() -> void:
	var party: Array = [
		{"id": "a", "state": PartySystem.STATE_READY, "max_hp": 45, "current_hp": 30},
		{"id": "b", "state": PartySystem.STATE_WOUNDED, "max_hp": 45, "current_hp": 1},
		{"id": "c", "state": PartySystem.STATE_DEAD, "max_hp": 45},
	]
	var rep: Dictionary = PartySystem.rest(party)
	assert_int(int(rep.get("rested", -1))) \
		.override_failure_message("rested = живые (DEAD не трогаем)").is_equal(2)
	assert_int(int(party[0]["current_hp"])).is_equal(45)
	assert_int(int(party[1]["current_hp"])) \
		.override_failure_message("WOUNDED → max_hp").is_equal(45)
	assert_bool(str(party[1]["state"]) == PartySystem.STATE_READY) \
		.override_failure_message("WOUNDED → READY").is_true()
	assert_bool(str(party[2]["state"]) == PartySystem.STATE_DEAD) \
		.override_failure_message("DEAD не восстанавливается").is_true()
	assert_bool(not party[2].has("current_hp")) \
		.override_failure_message("DEAD — без current_hp").is_true()


func test_rest_idempotent() -> void:
	var party: Array = [
		{"id": "a", "state": PartySystem.STATE_WOUNDED, "max_hp": 45, "current_hp": 1},
	]
	PartySystem.rest(party)
	var first: Dictionary = (party[0] as Dictionary).duplicate(true)
	PartySystem.rest(party)
	assert_dict(party[0]).override_failure_message("повторный REST — без изменений").is_equal(first)


## ── 3) apply_battle_result ─────────────────────────────────────────────────

func test_apply_battle_result_cases() -> void:
	var m: Dictionary = _member(-1)
	PartySystem.apply_battle_result(m, 30, false)
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("hp > 0 → current_hp = hp").is_equal(30)
	assert_bool(str(m.get("state", "")) == PartySystem.STATE_READY) \
		.override_failure_message("статус не меняется при выживании с HP").is_true()
	# WOUNDED живёт до REST'а (не сбрасывается записью hp)
	var m2: Dictionary = _member(-2)
	m2["state"] = PartySystem.STATE_WOUNDED
	PartySystem.apply_battle_result(m2, 20, false)
	assert_int(int(m2.get("current_hp", -1))).is_equal(20)
	assert_bool(str(m2.get("state", "")) == PartySystem.STATE_WOUNDED) \
		.override_failure_message("WOUNDED снимает только REST").is_true()
	# выжил с 0 → 1 + WOUNDED
	var m3: Dictionary = _member(-3)
	PartySystem.apply_battle_result(m3, 0, false)
	assert_int(int(m3.get("current_hp", -1))) \
		.override_failure_message("выжил с 0 → 1").is_equal(1)
	assert_bool(str(m3.get("state", "")) == PartySystem.STATE_WOUNDED) \
		.override_failure_message("выжил с 0 → WOUNDED").is_true()
	# смерть → DEAD / 0
	var m4: Dictionary = _member(-4)
	PartySystem.apply_battle_result(m4, 0, true)
	assert_bool(str(m4.get("state", "")) == PartySystem.STATE_DEAD) \
		.override_failure_message("смерть → DEAD").is_true()
	assert_int(int(m4.get("current_hp", -1))).is_equal(0)


## ── 4) персистентность между боями без REST ────────────────────────────────

func test_current_hp_persists_between_battles_without_rest() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var m: Dictionary = comp.party[0]
	var t1: Dictionary = comp._statblocks["raider_tier_1"]
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_t1_hp: int = int(t1.get("hp", 0))
	var saved_ac: int = int(w.get("ac", 0))
	# tier 1 с hp 20 переживает первый удар; ac героя 5 → рейдер попадает.
	t1["hp"] = 20
	w["ac"] = 5
	var r1: String = comp._request_battle({"tier": 1})
	assert_str(r1).override_failure_message("бой 1: win").is_equal("win")
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("бой 1: герой 45 → 35 (2 попадания по 5)").is_equal(35)
	# без REST (ход не идёт) второй бой стартует с 35.
	var r2: String = comp._request_battle({"tier": 1})
	assert_str(r2).override_failure_message("бой 2: win").is_equal("win")
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("бой 2: старт 35 → 25 (не 45 → 35)").is_equal(25)
	t1["hp"] = saved_t1_hp
	w["ac"] = saved_ac


## ── 5) REST между боями ────────────────────────────────────────────────────

func test_rest_between_battles_restores() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var m: Dictionary = comp.party[0]
	var t1: Dictionary = comp._statblocks["raider_tier_1"]
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_t1_hp: int = int(t1.get("hp", 0))
	var saved_ac: int = int(w.get("ac", 0))
	t1["hp"] = 20
	w["ac"] = 5
	var r1: String = comp._request_battle({"tier": 1})
	assert_str(r1).is_equal("win")
	assert_int(int(m.get("current_hp", -1))).is_equal(35)
	PartySystem.rest(comp.party)
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("REST: 35 → 45").is_equal(45)
	var r2: String = comp._request_battle({"tier": 1})
	assert_str(r2).is_equal("win")
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("после REST бой идентичен первому (→ 35)").is_equal(35)
	t1["hp"] = saved_t1_hp
	w["ac"] = saved_ac


## ── 6) REST в settlement-фазе ──────────────────────────────────────────────

func test_rest_in_settlement_when_hero_in_city() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var m: Dictionary = comp.party[0]
	m["current_hp"] = 30
	m["state"] = PartySystem.STATE_WOUNDED
	comp.campaign.settlement_hook.call()
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("герой в городе → REST: полный HP").is_equal(45)
	assert_bool(str(m.get("state", "")) == PartySystem.STATE_READY) \
		.override_failure_message("герой в городе → REST: READY").is_true()


func test_no_rest_when_hero_out_of_city() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var m: Dictionary = comp.party[0]
	m["current_hp"] = 30
	m["state"] = PartySystem.STATE_WOUNDED
	# E4 — соседний регион стартового E3 (edges: E3–E4); герой в походе.
	comp.region_map.hero_region = "E4"
	comp.campaign.settlement_hook.call()
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("герой в походе → REST нет: остаток сохраняется").is_equal(30)
	assert_bool(str(m.get("state", "")) == PartySystem.STATE_WOUNDED) \
		.override_failure_message("герой в походе → WOUNDED живёт").is_true()


## ── 7) раненый герой → settlement-REST ─────────────────────────────────────

func test_wounded_after_battle_rested_by_settlement() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var m: Dictionary = comp.party[0]
	# герой(1 HP) vs босс tier 3: падает от мощного удара (12), выживает с 0
	# (con 3) → WOUNDED, lose (атаковал босс).
	m["current_hp"] = 1
	var r1: String = comp._request_battle({"tier": 3})
	assert_str(r1).override_failure_message("полный герой vs босс: lose").is_equal("lose")
	assert_str(str(comp.last_battle_report["states"][""])) \
		.override_failure_message("герой WOUNDED (стабилизирован)").is_equal("wounded")
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("член: 1 HP после боя").is_equal(1)
	assert_bool(str(m.get("state", "")) == PartySystem.STATE_WOUNDED) \
		.override_failure_message("WOUNDED персистится между боями (D4)").is_true()
	# settlement-фаза (герой в городе) → REST.
	comp.campaign.settlement_hook.call()
	assert_int(int(m.get("current_hp", -1))) \
		.override_failure_message("settlement-REST: полный HP").is_equal(45)
	assert_bool(str(m.get("state", "")) == PartySystem.STATE_READY) \
		.override_failure_message("settlement-REST: READY").is_true()
	# следующий бой — с полным HP (победа над tier 1).
	var r2: String = comp._request_battle({"tier": 1})
	assert_str(r2).override_failure_message("после REST: win").is_equal("win")


## ── 8) миграция загруженного сейва ─────────────────────────────────────────

func test_migration_on_loaded_save() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var state: Dictionary = comp.build_save_state()
	# старый сейв: HP-поля отсутствуют (до V-5).
	var saved_party: Array = state["party"] as Array
	for mem in saved_party:
		(mem as Dictionary).erase("current_hp")
		(mem as Dictionary).erase("max_hp")
	var comp2 := CampaignComposition.from_campaign_config(12345)
	comp2.load_save_state(state)
	assert_int(comp2.party.size()).override_failure_message("партия загружена").is_equal(2)
	for mem in comp2.party:
		var m: Dictionary = mem
		assert_int(int(m.get("max_hp", -1))) \
			.override_failure_message("миграция: max_hp восстановлен").is_equal(45)
		assert_int(int(m.get("current_hp", -1))) \
			.override_failure_message("миграция: живой → полный current_hp").is_equal(45)
	# боевой вход после загрузки использует восстановленный current_hp.
	var r: String = comp2._request_battle({"tier": 1})
	assert_str(r).override_failure_message("бой после загрузки: win").is_equal("win")
	assert_int(int(comp2.party[0].get("current_hp", -1))) \
		.override_failure_message("герой (tier 1: 0 урона) остаётся полным").is_equal(45)


## ── 9) смерть героя: ровно один DEAD ───────────────────────────────────────

func test_single_member_party_wipes_on_hero_death() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(-1)]
	var m: Dictionary = comp.party[0]
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_con: int = int(w.get("con", 0))
	# герой(1 HP, con −3) vs босс: мощный удар 12 → 3 провала save → DEAD.
	m["current_hp"] = 1
	w["con"] = -3
	var r: String = comp._request_battle({"tier": 3})
	w["con"] = saved_con
	assert_str(r).override_failure_message("ослабленный герой: lose").is_equal("lose")
	assert_bool(str(m.get("state", "")) == PartySystem.STATE_DEAD) \
		.override_failure_message("единственный член — DEAD").is_true()
	assert_bool(comp.campaign.is_done()) \
		.override_failure_message("партия из 1: смерть героя = wipe (R1)").is_true()
	assert_str(str(comp.campaign.campaign_status)) \
		.override_failure_message("статус — defeat").is_equal("defeat")


func test_hero_death_marks_first_member_and_second_fights() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(-1), _member(-2)]
	var pop_before: int = comp.population_system.size()
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_con: int = int(w.get("con", 0))
	var m1: Dictionary = comp.party[0]
	var m2: Dictionary = comp.party[1]
	# бой 1: герой = первый член; гибнет.
	m1["current_hp"] = 1
	w["con"] = -3
	var r1: String = comp._request_battle({"tier": 3})
	w["con"] = saved_con
	assert_str(r1).override_failure_message("бой 1: lose").is_equal("lose")
	assert_bool(str(m1.get("state", "")) == PartySystem.STATE_DEAD) \
		.override_failure_message("первый член (герой) — DEAD").is_true()
	assert_int(int(m1.get("current_hp", -1))).is_equal(0)
	assert_bool(str(m2.get("state", "")) == PartySystem.STATE_READY) \
		.override_failure_message("второй член жив").is_true()
	var dead_count := 0
	for mem in comp.party:
		if str((mem as Dictionary).get("state", "")) == PartySystem.STATE_DEAD:
			dead_count += 1
	assert_int(dead_count).override_failure_message("ровно один DEAD в ростере").is_equal(1)
	assert_bool(not comp.campaign.is_done()) \
		.override_failure_message("смерть первого ≠ конец (R1: wipe партии)").is_true()
	assert_int(comp.settlement.party_size) \
		.override_failure_message("party_size = живые = 1").is_equal(1)
	assert_int(comp.population_system.size()) \
		.override_failure_message("только-ростерный герой (uid −1): население не тронуто").is_equal(pop_before)
	# бой 2: следующий герой — второй член (полный HP, win над tier 1).
	var r2: String = comp._request_battle({"tier": 1})
	assert_str(r2).override_failure_message("бой 2: второй член (герой) — win").is_equal("win")
	assert_bool(str(m2.get("state", "")) == PartySystem.STATE_READY) \
		.override_failure_message("второй член жив после боя").is_true()
	assert_int(int(m2.get("current_hp", -1))) \
		.override_failure_message("второй член: полный HP (tier 1: 0 урона)").is_equal(45)


func test_second_member_death_wipes_party() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(-1), _member(-2)]
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_con: int = int(w.get("con", 0))
	var m1: Dictionary = comp.party[0]
	var m2: Dictionary = comp.party[1]
	# бой 1: гибнет первый.
	m1["current_hp"] = 1
	w["con"] = -3
	assert_str(comp._request_battle({"tier": 3})).is_equal("lose")
	w["con"] = saved_con
	# бой 2: гибнет второй (герой = первый живой).
	m2["current_hp"] = 1
	w["con"] = -3
	var r2: String = comp._request_battle({"tier": 3})
	w["con"] = saved_con
	assert_str(r2).override_failure_message("бой 2: lose").is_equal("lose")
	assert_bool(str(m1.get("state", "")) == PartySystem.STATE_DEAD).is_true()
	assert_bool(str(m2.get("state", "")) == PartySystem.STATE_DEAD) \
		.override_failure_message("второй член (герой боя 2) — DEAD").is_true()
	var dead_count := 0
	for mem in comp.party:
		if str((mem as Dictionary).get("state", "")) == PartySystem.STATE_DEAD:
			dead_count += 1
	assert_int(dead_count) \
		.override_failure_message("двойной смерти нет: ровно по одному DEAD за бой").is_equal(2)
	assert_bool(comp.campaign.is_done()) \
		.override_failure_message("партия выбита → wipe").is_true()
	assert_str(str(comp.campaign.campaign_status)).is_equal("defeat")


## ── 10) WOUNDED — живой ────────────────────────────────────────────────────

func test_wounded_counts_as_alive() -> void:
	var party: Array = [
		{"id": "a", "state": PartySystem.STATE_READY, "max_hp": 45, "current_hp": 45},
		{"id": "b", "state": PartySystem.STATE_WOUNDED, "max_hp": 45, "current_hp": 1},
		{"id": "c", "state": PartySystem.STATE_DEAD, "max_hp": 45},
	]
	assert_int(PartySystem.alive_members(party).size()) \
		.override_failure_message("WOUNDED — живой (alive_members)").is_equal(2)
	assert_bool(PartyScreenModel.is_full(party, 2)) \
		.override_failure_message("WOUNDED занимает слот (лимит партии)").is_true()
	var no_wounded: Array = [
		{"id": "a", "state": PartySystem.STATE_READY, "max_hp": 45, "current_hp": 45},
		{"id": "c", "state": PartySystem.STATE_DEAD, "max_hp": 45},
		{"id": "d", "state": PartySystem.STATE_DEAD, "max_hp": 45},
	]
	assert_bool(not PartyScreenModel.is_full(no_wounded, 2)) \
		.override_failure_message("мёртвые слоты не блокируют тренировку").is_true()


## ── 11) враги не сохраняют урон / детерминизм ──────────────────────────────

func test_enemies_do_not_persist_damage() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	var t1: Dictionary = comp._statblocks["raider_tier_1"]
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_t1_hp: int = int(t1.get("hp", 0))
	var saved_ac: int = int(w.get("ac", 0))
	t1["hp"] = 20
	w["ac"] = 5
	var r1: String = comp._request_battle({"tier": 1})
	var rep1: Dictionary = comp.last_battle_report.duplicate(true)
	PartySystem.rest(comp.party)
	var r2: String = comp._request_battle({"tier": 1})
	t1["hp"] = saved_t1_hp
	w["ac"] = saved_ac
	assert_str(r1).is_equal("win")
	assert_str(r2).is_equal("win")
	# REST вернул героя к тем же входам: отчёты идентичны → рейдер
	# собирается из спека заново (нет персистентного урона врага).
	assert_dict(comp.last_battle_report) \
		.override_failure_message("боевой цикл идентичен (враг без персистентности)").is_equal(rep1)
