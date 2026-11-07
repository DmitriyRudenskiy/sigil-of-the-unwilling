extends BaseTest
## Q-M91: старт кампании не должен быть тупиком. Плейсхолдер-еда `RegionMap`
## стартовала с 0, а стоимость перехода — `партия × дни` > 0, поэтому на первом же
## ходе ни у одного соседа не было `available`: экран карты показывал «мало провизии
## (0/2)», и после создания героя нельзя было сделать ни одного хода.

const CampaignComposition := preload("res://scripts/campaign/campaign_composition.gd")
const MapScreenModel := preload("res://scripts/ui/map_screen_model.gd")


func _fresh_map() -> RegionMap:
	return CampaignComposition.from_campaign_config(12345).region_map


func test_fresh_campaign_starts_with_supply() -> void:
	assert_int(int(_fresh_map().food)).is_greater(0)


func test_fresh_campaign_has_at_least_one_move() -> void:
	var available := 0
	for opt in MapScreenModel.travel_options(_fresh_map()):
		if bool(opt["available"]):
			available += 1
	assert_int(available).is_greater(0)


func test_fresh_campaign_hero_stands_in_the_city() -> void:
	# снабжение снабжением, а стартовая позиция — то, что видит игрок: герой в R01
	var map := _fresh_map()
	assert_str(map.hero_region).is_equal(map.start_region)
	assert_str(map.hero_state).is_equal(map.STATE_EXPLORE)
