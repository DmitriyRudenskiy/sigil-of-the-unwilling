extends SceneTree

# [AI]: сгенерировано по задаче 9.9 tasks.md, проверено человеком.
#
# Дымовой прогон обоих наборов от первого хода до экрана результата (спека
# `battle-demo-ui`, «Оба набора проходят бой»). Только логика боя, без картинок:
# экраны дымом снимаются `capture_screens.tscn`, а здесь важно, что бой
# доходит до исхода и исход — победа.
#
#     godot --headless --path battle-demo -s res://tools/smoke_battle.gd
#
# Код выхода: 0 — оба набора дошли до победы, 1 — хоть один нет.

## Страховка от «бой никогда не кончится» — та же, что у ядра, но своей строкой:
## ядро на лимите молча ставит `NO_RESULT`, и дым обязан это увидеть.
const MAX_ACTIONS := 500
const SEED := 3


func _init() -> void:
	var units := DataLibrary.load_units()
	var failed := 0
	for id in DataLibrary.ROSTER_IDS:
		var combat := CombatState.new()
		combat.setup(
			DataLibrary.load_roster(String(id)), [units[DataLibrary.ENEMY_ID]], SEED
		)
		combat.start()
		var actions := 0
		while not combat.finished and actions < MAX_ACTIONS:
			combat.perform(_greedy(combat))
			actions += 1
		var survivors := combat.alive(BattleUnit.SIDE_PLAYER).size()
		var won := combat.finished and combat.result == BattleUnit.SIDE_PLAYER
		print(
			"набор %s: дошёл=%s победа=%s ходов=%d действий=%d живых=%d/%d" % [
				String(id),
				combat.finished,
				won,
				combat.turn_index,
				actions,
				survivors,
				DataLibrary.ROSTER_SIZE,
			]
		)
		if not won:
			failed += 1
	if failed:
		print("SMOKE: FAIL (победных наборов %d из %d)" % [2 - failed, 2])
	quit(1 if failed else 0)


## Первый не-пас из разрешённых — тот же выбор, что делает автобой тестов: дым
# обязан идти путём игрока (`legal_actions` + `perform`), а не прямым вызовом
## правил.
func _greedy(combat: CombatState) -> BattleAction:
	var chosen := BattleAction.skip(combat.current)
	for candidate in combat.legal_actions(combat.current):
		if candidate.kind != BattleAction.Kind.PASS:
			return candidate
	return chosen
