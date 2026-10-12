extends BaseTest

## T-002 «Выбор знака»: каталог 8 Знаков (02c verbatim) + сейв-раундтрип
## секции "sign" (выбор 1 из 8 на всю игру — Q18, D12).


func test_catalog_has_eight_signs():
	var signs: Array = Signs.all()
	assert_array(signs).has_size(8)


func test_ids_unique_and_valid():
	var ids: Array = Signs.ids()
	assert_array(ids).has_size(8)
	assert_bool(ids.has("spark") and ids.has("basis")).is_true()
	for id in ids:
		assert_bool(Signs.is_valid(str(id))).is_true()
		var sign: Dictionary = Signs.by_id(str(id))
		assert_str(str(sign.get("name", ""))).is_not_empty()
		assert_str(str(sign.get("motto", ""))).is_not_empty()
	assert_bool(Signs.is_valid("no_such_sign")).is_false()
	assert_dict(Signs.by_id("no_such_sign")).is_empty()


func test_names_match_02c_verbatim():
	var expected := {
		"spark": "Искра", "time": "Время", "balance": "Равновесие",
		"primal": "Первозданность", "shadow": "Тень", "harmony": "Гармония",
		"cycle": "Цикл", "basis": "Основа",
	}
	for id in expected:
		assert_str(str(Signs.by_id(id).get("name", ""))).is_equal(expected[id])


func test_ordinals_one_through_eight():
	var seen: Array = []
	for sign in Signs.all():
		seen.append(int(sign.get("ordinal", 0)))
	seen.sort()
	assert_array(seen).is_equal([1, 2, 3, 4, 5, 6, 7, 8])


func test_save_roundtrip_preserves_sign():
	var composition = _composition()
	composition.sign_id = "harmony"
	var raw: String = JSON.stringify(composition.build_save_state())
	var restored = _composition()
	restored.load_save_state(JSON.parse_string(raw))
	assert_str(restored.sign_id).is_equal("harmony")


func test_save_roundtrip_empty_sign_stays_empty():
	var composition = _composition()
	var raw: String = JSON.stringify(composition.build_save_state())
	var restored = _composition()
	restored.load_save_state(JSON.parse_string(raw))
	assert_str(restored.sign_id).is_empty()


func _composition() -> CampaignComposition:
	return CampaignComposition.from_campaign_config(424242)
