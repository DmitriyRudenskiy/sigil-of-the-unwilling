extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Сериализация армии и ресурсов: serialize → deserialize → roundtrip.

const _HeroArmyController = preload("res://scripts/entities/HeroArmyController.gd")
const _HeroResources = preload("res://scripts/entities/HeroResources.gd")

func _init() -> void:
	var failed := 0
	failed += _test_army_serialize()
	failed += _test_resources_roundtrip()
	failed += _test_army_empty()
	failed += _test_army_cap()
	failed += _test_default_army_cap()

	if failed == 0:
		print("Hero serialize tests passed")
	else:
		printerr("Hero serialize tests failed: ", failed)
	_failed = failed
	_passed = 1 if failed == 0 else 0

	await process_frame
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

	army.free()  # Node: освобождение
	army2.free()  # Node: освобождение
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

	res.free()  # Node: освобождение
	res2.free()  # Node: освобождение
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

	army.free()  # Node: освобождение
	army2.free()  # Node: освобождение
	return errors

## РФ-герой: герой не может командовать более чем 7 юнитами в бою.
func _test_army_cap() -> int:
	var errors := 0
	var army := _HeroArmyController.new()
	# Наполняем армию 12 стеками — больше лимита.
	for i in 12:
		army.army.append(Units.make_fixed_stack("swordsmen", 10))

	var for_battle := army.get_army_for_battle()
	if for_battle.size() != 7:
		printerr("get_army_for_battle should cap at 7, got %d" % for_battle.size())
		errors += 1

	army.free()  # Node: освобождение
	return errors

## Стартовая армия по умолчанию не превышает лимит 7 юнитов.
func _test_default_army_cap() -> int:
	var errors := 0
	var army := _HeroArmyController.new()
	var for_battle := army.get_army_for_battle()
	if for_battle.size() > 7:
		printerr("default army should not exceed 7 units, got %d" % for_battle.size())
		errors += 1

	army.free()  # Node: освобождение
	return errors
