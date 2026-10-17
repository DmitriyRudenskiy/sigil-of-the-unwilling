extends BaseTest
## T-060 (R1/R4): проводка партии в кампанию (composition root, D-157 —
## раннер проверяет ту же игру, что видит игрок).
## 1) партия — состояние сейва (roundtrip); 2) бой → XP партии (победа:
## 100×CR×1.1 + рейд пережит 300; ничья: только 300; поражение: 0);
## 3) потери → wipe → DEFEAT (R1: сейв и Престиж сохраняются);
## 4) снабжение: party_size = живые члены.

const WIRING_SLOT := 3  # отдельный слот; 1/2 — test_mvp_save, 3 — cutover-композит (чистит)

func _member(uid: int = -1, xp: int = 0) -> Dictionary:
	return {
		"id": "m_%d" % uid, "class": "fighter", "race": "humans", "level": 1,
		"xp": xp, "luck": 0,
		"stats": {"str": 14, "dex": 10, "con": 12, "int": 10, "wis": 10, "cha": 10},
		"uid": uid,
	}


func after_test() -> void:
	MvpSaveManager.delete_slot(WIRING_SLOT)


## — 1. Партия — состояние сейва (T-110-схема: party = TYPE_ARRAY) —

func test_party_save_roundtrip() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1, 2700), _member(2)]
	comp.party[1]["state"] = PartySystem.STATE_DEAD
	var saved := MvpSaveManager.save_slot(WIRING_SLOT, comp.build_save_state())
	assert_bool(bool(saved.ok)).override_failure_message(str(saved.get("message", ""))).is_true()
	var loaded := MvpSaveManager.load_slot(WIRING_SLOT)
	assert_bool(bool(loaded.ok)).override_failure_message(str(loaded.get("message", ""))).is_true()
	var comp2 := CampaignComposition.from_campaign_config(12345)
	comp2.load_save_state(loaded.state)
	assert_bool(comp2.party.size() == 2).is_true()
	assert_bool(str(comp2.party[0].id) == "m_1").is_true()
	assert_bool(int(comp2.party[0].xp) == 2700).is_true()
	assert_bool(int(comp2.party[0].level) == 2).is_true()
	assert_bool(str(comp2.party[1].state) == PartySystem.STATE_DEAD).is_true()


func test_defeat_status_save_roundtrip() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1)]
	comp.apply_party_battle_losses({"losses": [1]})
	assert_bool(comp.campaign.campaign_status == "defeat").is_true()
	var saved := MvpSaveManager.save_slot(WIRING_SLOT, comp.build_save_state())
	assert_bool(bool(saved.ok)).is_true()
	var loaded := MvpSaveManager.load_slot(WIRING_SLOT)
	var comp2 := CampaignComposition.from_campaign_config(12345)
	comp2.load_save_state(loaded.state)
	assert_bool(comp2.campaign.campaign_status == "defeat").is_true()
	assert_bool(comp2.campaign.is_done()).is_true()


## — 2. Бой → XP партии (07-balance §3) —

func test_battle_win_grants_party_xp() -> void:
	# MVP 1v1: warrior (cr 5) vs raider_tier_1 (cr 1) — детерминированная победа.
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1)]
	comp._request_battle({"turn": 1, "tier": 1})
	assert_bool(str(comp.last_battle_report.get("outcome", "")) == "win").is_true()
	# 100×1×(1+0.1×1) = 110 (победа) + 300 (рейд пережит) = 410.
	assert_bool(int(comp.party[0].xp) == 410).is_true()
	assert_bool(int(comp.party[0].level) == 1).is_true()


func test_record_party_xp_outcomes() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1)]
	comp.record_party_xp({"outcome": "lose"}, 1.0)
	assert_bool(int(comp.party[0].xp) == 0).override_failure_message("поражение: ни боевого XP, ни «рейд пережит»").is_true()
	comp.party = [_member(1)]
	comp.record_party_xp({"outcome": "draw"}, 1.0)
	assert_bool(int(comp.party[0].xp) == 300).override_failure_message("ничья: боевой XP 0 (07-balance §4), «рейд пережит» 300").is_true()
	comp.party = [_member(1)]
	comp.record_party_xp({"outcome": "win"}, 3.0)
	assert_bool(int(comp.party[0].xp) == 330 + 300).override_failure_message("победа: 100×3×1.1 + 300").is_true()


func test_record_party_xp_empty_party_noop() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = []  # явный пустой кейс: с T-003 старт-партия (fighter+ranger) есть по умолчанию
	comp.record_party_xp({"outcome": "win"}, 3.0)
	assert_bool(comp.party.is_empty()).is_true()


## — 3. Потери → wipe → DEFEAT (R1) —

func test_wipe_defeats_campaign_and_preserves_prestige() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1), _member(2)]
	comp.prestige_ledger.append({"turn": 5, "source_type": "battle_victory", "id": "t", "amount": 10.0})
	comp.apply_party_battle_losses({"losses": [1]})
	assert_bool(not comp.campaign.is_done()).override_failure_message("один мёртвый — не wipe").is_true()
	comp.apply_party_battle_losses({"losses": [2]})
	assert_bool(comp.campaign.is_done()).is_true()
	assert_bool(comp.campaign.campaign_status == "defeat").is_true()
	# EC1: сейв и Престиж сохраняются — нет «game over без возврата».
	assert_bool(comp.prestige_ledger.size() == 1).is_true()
	# Повторный defeat — no-op (флаг, не таймер).
	comp.campaign.defeat("again")
	assert_bool(comp.campaign.campaign_status == "defeat").is_true()


func test_losses_empty_report_noop() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1)]
	comp.apply_party_battle_losses({"losses": []})
	assert_bool(str(comp.party[0].get("state", PartySystem.STATE_READY)) == PartySystem.STATE_READY).is_true()
	assert_bool(not comp.campaign.is_done()).is_true()


## — 4. Снабжение: party_size = живые члены (02-mechanics §3.2) —

func test_starting_party_r2() -> void:
	# T-003 (R2): стартовая партия — fighter 1 + ranger 1, ур.1 (02-mechanics §3.2).
	var comp := CampaignComposition.from_campaign_config(12345)
	assert_bool(comp.party.size() == 2).is_true()
	var classes: Array = []
	for m in comp.party:
		var d: Dictionary = m
		classes.append(str(d.get("class", "")))
		assert_bool(int(d.get("level", 0)) == 1).is_true()
		assert_bool(int(d.get("xp", -1)) == 0).is_true()
		# Stats проходят гейты классов (02d §4.2) — case-insensitive (T-003).
		assert_bool(bool(CanonClasses.gate_ok(str(d.get("class", "")), d.get("stats", {})))) \
			.override_failure_message("гейт: %s" % str(d.get("class", ""))).is_true()
	assert_bool(classes.has("fighter") and classes.has("ranger")).is_true()
	# Снабжение: party_size = живые члены (1 еда/день/юнит — T-041 якорь, Q-M91).
	assert_bool(comp.settlement.party_size == 2).is_true()


func test_party_size_synced_on_advance() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	comp.party = [_member(1), _member(2), _member(3)]
	comp.party[2]["state"] = PartySystem.STATE_DEAD
	comp.advance_turn()
	assert_bool(comp.settlement.party_size == 2).is_true()
