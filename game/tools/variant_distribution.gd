extends SceneTree

## Раскладка вариантов базы по клеткам (T-143). `TileAtlas.variant_for` — хеш от
## «x:y:seed» по модулю числа вариантов; инструмент отвечает на два вопроса, которые
## по пикселям кадра не различимы: с какой частотой раздаётся каждый вариант и как
## часто соседние клетки получают РАЗНЫЙ вариант (то есть сколько вообще стыков
## вариантов рисует карта).
##
##   Godot --headless --path game -s tools/variant_distribution.gd -- --seed=4242 --n=12
##
## Зачем: глазной вердикт 11.3 («налепанные заплаты») приписан стыку вариантов, а
## замер кадра (scripts/measure_variant_seam.py) показал, что тональный шаг через
## ребро клетки неотличим от внутренней полосы тайла. Прежде чем «сводить стык»,
## надо знать, что именно разложено: при косой раздаче вариантов (один почти не
## печатается) карта выглядит пятнистой по другой причине, и лечится она не маской.


func _init() -> void:
	var seed_value := 4242
	var n := 12
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
	var count := 4
	var hist := [0, 0, 0, 0]
	var cells := {}
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var v := TileAtlas.variant_for(Vector2i(x, y), seed_value, count)
			hist[v] += 1
			cells["%d,%d" % [x, y]] = v
	var total := float(hist.reduce(func(a, b): return a + b))
	var shares: Array[String] = []
	for i in range(count):
		shares.append("%d:%.3f" % [i, hist[i] / total])
	var diff := 0
	var edges := 0
	for key in cells:
		var c: Vector2i = Vector2i(int(key.split(",")[0]), int(key.split(",")[1]))
		for d in [[1, 0], [0, -1], [-1, -1]]:
			var other := "%d,%d" % [c.x + d[0], c.y + d[1]]
			if not cells.has(other):
				continue
			edges += 1
			diff += 0 if cells[other] == cells[key] else 1
	print("seed=%d n=%d вариантов=%d" % [seed_value, n, count])
	print("раздача: %s (равномерно = 0.250)" % ", ".join(shares))
	print("пар с разным вариантом (фикс. смещения): %d/%d = %.3f (независимая раздача = 0.750)"
			% [diff, edges, float(diff) / max(1, edges)])
	quit(0)
