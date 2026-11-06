# CAPTURE_SETUP для кадра «герой идёт» (T-344 AC3).
#
# AC3 требует кадр живого экрана мира: карта, туман, дороги и герой в движении.
# Носитель — `scenes/archive/world.tscn` (`WorldController` → `WorldUIManager` →
# `$WorldUILayer/AdventureUI`): это единственный носитель, где `MapRenderer`
# вообще поднят (экран кампейна рисует `CampaignMapField`, не он).
#
# Шаг — через тот же API, чем ходит игрок (`HeroController.move_to_cell`), а не
# телепортом: кандидат выбирается `can_reach`, он проверяет и рельеф, и очки
# движения (фикстура не изобретает правил движения). Берётся самая дальняя
# достижимая клетка в радиусе 4: ход на одну клетку в кадре не отличить от
# стояния, длинный путь виден — герой в середине пути.
#
# Почему отложенно: `WorldController._ready()` спотыкается о `await process_frame`
# посередине, и в момент фикстуры герой есть, но ещё не поставлен на карту
# (клетка (0,0), `can_reach` молчит). Поэтому шаг ставится на таймер и происходит
# уже во время `--frames=`. Успех/отказ печатается строкой `[world_hero_step]`:
# кадр без этой строки — не кадр шага.
#
# Песочница `execute_code` блокирует по исходнику (docs/mvp/CAPTURE-HELPER.md §10):
# имён операций записи файлов и проверок-слов здесь нет.
var scene: Node = get_tree().current_scene
if scene == null or not scene.has_method("get_hero"):
	return {"ok": false, "reason": "сцена мира не поднялась (нет WorldController.get_hero)"}
if scene.get_hero() == null:
	return {"ok": false, "reason": "герой не поднят (мир ещё бутится)"}
var timer: SceneTreeTimer = get_tree().create_timer(4.0)
timer.timeout.connect(func() -> void:
	var hero: Node = scene.get_hero()
	var from: Vector2i = hero.current_cell
	var cells: Array[Vector2i] = []
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			if dx != 0 or dy != 0:
				cells.append(from + Vector2i(dx, dy))
	cells.sort_custom(func(a, b): return a.distance_squared_to(from) > b.distance_squared_to(from))
	for c in cells:
		if hero.can_reach(c) and hero.move_to_cell(c):
			print("[world_hero_step] шаг %s → %s" % [from, c])
			return
	print("[world_hero_step] ОТКАЗ: из %s ни одной достижимой клетки в радиусе 4" % [from])
)
return {"ok": true, "note": "шаг отложен на 3.5 с — снимай с --frames>=400"}
