extends SceneTree
## Сериализация армии и ресурсов: serialize → deserialize → roundtrip.

const _HeroArmyController = preload("res://scripts/hero/HeroArmyController.gd")
const _HeroResources = preload("res://scripts/hero/HeroResources.gd")

func _init() -> void:
	var failed := 0
	failed += _test_army_serialize()
	failed += _test_resources_roundtrip()
	failed += _test_army_empty()

	if failed == 0:
		print("Hero serialize tests passed")
	else:
		printerr("Hero serialize tests failed: ", failed)
	quit(1 if failed > 0 else 0)


func _test_army_serialize() -> int:
	var errors := 0
	var army := _HeroArmyController.new()
	var data := army.serialize()

	if data.size() != army.army.size():
		printerr("serialize: expected %d entries, got %d" % [army.army.size(), data.size()])
		errors += 1

	# Deserialize into fresh controller
	var army2 := _HeroArmyController.new()
	army2.deserialize(data)

	if army2.army.size() != army.army.size():
		printerr("deserialize: expected %d stacks, got %d" % [army.army.size(), army2.army.size()])
		errors += 1

	# Verify counts match
	for i in army.army.size():
		if army2.army[i].count != army.army[i].count:
			printerr("count mismatch at %d: %d vs %d" % [i, army2.army[i].count, army.army[i].count])
			errors += 1

	return errors


func _test_resources_roundtrip() -> int:
	var errors := 0
	var res := _HeroResources.new()
	res.resources = {"wood": 100, "gold": 999, "gems": 42}

	var data := res.serialize()
	if data["wood"] != 100 or data["gold"] != 999:
		printerr("serialize: values wrong")
		errors += 1

	var res2 := _HeroResources.new()
	res2.deserialize(data)

	if res2.resources["wood"] != 100 or res2.resources["gems"] != 42:
		printerr("deserialize: values wrong")
		errors += 1

	return errors


func _test_army_empty() -> int:
	var errors := 0
	var army := _HeroArmyController.new()
	army.army = []

	var data := army.serialize()
	if data.size() != 0:
		printerr("empty army should serialize to empty array")
		errors += 1

	var army2 := _HeroArmyController.new()
	army2.deserialize(data)
	if army2.army.size() != 0:
		printerr("empty deserialize should result in empty army")
		errors += 1

	return errors
