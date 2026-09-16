extends SceneTree
func _init():
	var c: RefCounted = load("res://scripts/entities/hero/components/HeroStatsComponent.gd").new()
	var data := {
		"hero_name": "Old",
		"stats": {"attack": 5, "defense": 2, "spell_power": 8, "knowledge": 4},
		"hero_race": "elf", "hero_class": "wizard",
		"hero_culture": "aedyr", "hero_background": "scholar",
	}
	c.deserialize(data)
	print("STATS: ", JSON.stringify(c.stats))
	var p: RefCounted = load("res://scripts/data/HeroBuildProfile.gd").new()
	p.race = "elf"; p.character_class = "wizard"; p.culture = "aedyr"; p.background = "scholar"
	print("PROFILE: ", JSON.stringify(p.get_stats()))
	quit()
