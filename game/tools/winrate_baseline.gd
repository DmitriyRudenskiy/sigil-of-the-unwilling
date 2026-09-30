extends SceneTree
## One-shot win-rate baseline (tactical-combat-implementation, task 1.1).
## Mirror auto-battles through BattleEmulator with fixed army composition
## and per-battle seeds. Run:
##   godot --headless --path game -s res://tools/winrate_baseline.gd
##
## The army composition below is the FIXED baseline reference — do not change
## it without re-baselining (record the new numbers in the change's tasks.md).
##
## RECALIBRATION (tactical-combat-implementation, фаза 8.1):
## Цепочка перекалибровки (все замеры — 200 боёв, фиксированный состав,
## seed 70000+i):
## 1. 0.840 — исходный baseline: старый бой + старый эмулятор (одно действие
##    за ход). Старый эмулятор не повторял игровое поведение (в игре юнит
##    может сдвинуться и атаковать в тот же ход; выживший защитник
##    контратакует).
## 2. Эмулятор доведён до игрового поведения: move+attack в тот же ход +
##    контратака выжившего защитника (одна за бой, как BattleAttackSequence).
##    Старый бой + полный эмулятор = 0.995 (перекалиброванный baseline).
##    (Промежуточный замер без контратаки: 0.985.)
## 3. Баги геометрии facing (do_move/classify не нормализовали направление;
##    terrain_elevation вызывал несуществующий set_height) давали 0.800 —
##    артефакт, исправлен; фронт/тыл теперь классифицируются корректно.
## 4. Новый бой (дальний бой: дальность 4 + штраф 10%/гекс; фланги/тыл)
##    + полный эмулятор = 0.755. Дельта от перекалиброванного baseline:
##    −0.240. Причина — осознанный дизайн-сдвиг: неограниченная дальность
##    старого боя давала лучникам «бесплатную» чип-фазу с первого хода
##    (стартовая дистанция ~15 гексов ≤ старая дальность); при дальности ≤ 8
##    чип-фазы нет, бой решается мeel-контактом и контратаками. Зеркальный
##    бой стал конкурентным (75/25 вместо 99/1) — атакующий сохраняет
##    перевес инициативы, но атака теперь рискованна. См. tasks.md 8.1.
## NOTE: all game scripts are loaded at runtime (after the first frame)
## because in `-s` mode autoload identifiers (Services, ...) are only
## resolvable once the autoloads are registered.

const BATTLES := 200
const SEED_OFFSET := 70000

# Representative early-game mirror army (melee militia + archers + heavy).
const ARMY_SPEC: Array = [
	{"id": "militia", "name": "Militia", "attack": 4, "base_damage": 4, "hp": 40, "speed": 5, "defense": 3, "count": 12},
	{"id": "archer", "name": "Archer", "attack": 4, "base_damage": 3, "hp": 30, "speed": 6, "defense": 2, "count": 6, "tags": ["ranged"]},
	{"id": "heavy", "name": "Heavy", "attack": 5, "base_damage": 6, "hp": 70, "speed": 4, "defense": 5, "count": 4},
]


func _initialize() -> void:
	await process_frame
	_run()


func _run() -> void:
	var emu: RefCounted = load("res://scripts/autoload/battle_emulator.gd").new()
	var battle_state_c: GDScript = load("res://scripts/systems/battle_state.gd")
	var atk_wins := 0
	var def_wins := 0
	var not_over := 0
	var total_turns := 0
	for i in BATTLES:
		var atk_stacks: Array[UnitStack] = []
		var def_stacks: Array[UnitStack] = []
		for s in ARMY_SPEC:
			atk_stacks.append(emu.army_stack(s.duplicate(true)) as UnitStack)
			def_stacks.append(emu.army_stack(s.duplicate(true)) as UnitStack)
		var state: RefCounted = battle_state_c.new()
		state.place_army(atk_stacks, def_stacks)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED_OFFSET + i
		var report: Dictionary = emu.run_auto_battle(state, rng)
		total_turns += int(report.get("turns", 0))
		var winner: String = str(report.get("winner", ""))
		if winner == "attacker":
			atk_wins += 1
		elif winner == "defender":
			def_wins += 1
		else:
			not_over += 1
	var decided: int = atk_wins + def_wins
	print("=== win-rate baseline (tactical-combat-implementation 1.1) ===")
	print("battles: %d | attacker wins: %d | defender wins: %d | not over: %d" % [BATTLES, atk_wins, def_wins, not_over])
	if decided > 0:
		print("attacker win rate: %.3f" % (float(atk_wins) / float(decided)))
		print("avg turns: %.1f" % (float(total_turns) / float(BATTLES)))
	print("=== end baseline ===")
	quit(0)
