extends SceneTree

func _initialize() -> void:
	await process_frame
	await process_frame
	var units: Node = Engine.get_main_loop().root.get_node("Units")
	print("units: ", units != null)
	var bs = (preload("res://scripts/BattleState.gd")).new()
	var atk_stack = units.make_fixed_stack("swordsmen", 20)
	var def_stack = units.make_fixed_stack("goblins", 20)
	print("atk_stack: ", atk_stack, " count=", atk_stack.count if atk_stack else -1, " alive=", atk_stack.is_alive() if atk_stack else -1)
	bs.place_army([atk_stack], [def_stack])
	print("atk units: ", bs.attacker_units.size())
	var dead_unit = bs.attacker_units[0]
	print("cell: ", dead_unit.cell, " stack null? ", dead_unit.stack == null)
	bs.kill_unit(dead_unit)
	print("alive after kill: ", dead_unit.is_alive(), " count=", dead_unit.get_count())
	var _Input = preload("res://scripts/BattleInput.gd")
	var inp = _Input.new()
	inp.name = "ProbeInput"
	var view = Node.new()
	view.name = "ProbeView"
	inp.setup(view, bs, {})
	inp.start_spell_targeting(&"resurrection", bs.Side.ATTACKER, true)
	print("highlight_attack: ", inp.highlight_attack)
	print("has cell: ", inp.highlight_attack.has(dead_unit.cell))
	# SpellCaster probe
	var _SpellCaster = preload("res://scripts/spells/SpellCaster.gd")
	var rng := RandomNumberGenerator.new()
	var res = _SpellCaster.cast(&"resurrection", dead_unit, {"spell_power": 10}, {}, rng)
	print("caster result: ", res)
	# apply_spell probe
	var _Resolver = preload("res://scripts/battle/BattleActionResolver.gd")
	var bs2 = (preload("res://scripts/BattleState.gd")).new()
	var atk2 = units.make_fixed_stack("swordsmen", 20)
	var def2 = units.make_fixed_stack("goblins", 5)
	bs2.place_army([atk2], [def2])
	var du2 = bs2.defender_units[0]
	bs2.kill_unit(du2)
	print("du2 count after kill: ", du2.get_count())
	var res2 = _Resolver.apply_spell(bs2, &"resurrection", bs2.attacker_units[0], du2, {}, {}, RandomNumberGenerator.new())
	print("apply_spell result: ", res2)
	print("alive now: ", du2.is_alive(), " battle_over=", bs2.battle_over)
	quit(0)
