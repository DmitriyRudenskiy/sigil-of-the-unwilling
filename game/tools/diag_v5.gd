extends SceneTree
## Диагностика V-5: полный герой vs босс tier 3 (ожидал lose + WOUNDED).

func _init() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	var r: String = comp._request_battle({"tier": 3})
	print("outcome: ", r, " rounds: ", str(comp.last_battle_report.get("rounds", "?")))
	print("states: ", str(comp.last_battle_report.get("states", {})))
	print("losses: ", str(comp.last_battle_report.get("losses", [])))
	print("member state: ", str(comp.party[0].get("state", "?")), " hp: ", str(comp.party[0].get("current_hp", "?")))
	for t in comp.last_battle_report.get("trace", []):
		print("trace: ", str(t))
	quit()
