extends SceneTree
## Headless tests for UnitRegistry, UnitStats, UnitStack

const _REGISTRY_PATH := "res://scripts/UnitRegistry.gd"
const _STACK_PATH := "res://scripts/unit_stack.gd"

func _init() -> void:
    print("=== UnitRegistry headless tests ===")
    var failed := 0
    var rng := RandomNumberGenerator.new()
    rng.seed = 123

    # make_stack
    var stack = _reg().make_stack("swordsmen", rng)
    if stack == null or not stack.is_alive():
        printerr("FAIL  make_stack swordsmen")
        failed += 1
    elif stack.stats.base_damage != 4 or stack.stats.hp != 10:
        printerr("FAIL  swordsmen stats")
        failed += 1
    else:
        print("PASS  make_stack swordsmen (count=%d)" % stack.count)

    # invalid key
    if _reg().make_stack("nonexistent_unit", rng) != null:
        printerr("FAIL  invalid key")
        failed += 1
    else:
        print("PASS  invalid key returns null")

    # make_fixed_stack
    var fixed = _reg().make_fixed_stack("archers", 36)
    if fixed == null or fixed.count != 36:
        printerr("FAIL  make_fixed_stack")
        failed += 1
    else:
        print("PASS  make_fixed_stack archers count=36")

    # to_dict
    var d = fixed.to_dict() if fixed else {}
    if d.get("key") != "archers" or d.get("count") != 36:
        printerr("FAIL  to_dict")
        failed += 1
    else:
        print("PASS  to_dict roundtrip")

    # from_dict (pass stats explicitly)
    var def_cav = _reg().get_definition("cavalry")
    var restored = _stack().from_dict({"key": "cavalry", "count": 50}, def_cav)
    if restored == null or restored.count != 50 or restored.stats.base_damage != 5:
        printerr("FAIL  from_dict")
        failed += 1
    else:
        print("PASS  from_dict roundtrip cavalry")

    # duplicate_stack
    var dup = fixed.duplicate_stack() if fixed else null
    if dup == null or dup.count != fixed.count:
        printerr("FAIL  duplicate_stack")
        failed += 1
    else:
        print("PASS  duplicate_stack")

    # is_alive
    if fixed and not fixed.is_alive():
        printerr("FAIL  is_alive true")
        failed += 1
    else:
        print("PASS  is_alive true")

    # is_alive zero count
    var dead = _reg().make_fixed_stack("mages", 0)
    if dead and dead.is_alive():
        printerr("FAIL  is_alive false for zero")
        failed += 1
    else:
        print("PASS  is_alive false for zero count")

    # get_display_name
    if fixed and fixed.get_display_name() != "Archer":
        printerr("FAIL  get_display_name")
        failed += 1
    else:
        print("PASS  get_display_name")

    # get_definition
    var def_s = _reg().get_definition("guardians")
    if def_s == null:
        printerr("FAIL  get_definition null")
        failed += 1
    elif def_s.base_damage != 6 or def_s.hp != 25:
        printerr("FAIL  get_definition stats")
        failed += 1
    else:
        print("PASS  get_definition guardians")

    print("\n=== %d failed ===" % failed)
    quit(1 if failed > 0 else 0)


func _reg():
    return load(_REGISTRY_PATH)

func _stack():
    return load(_STACK_PATH)
