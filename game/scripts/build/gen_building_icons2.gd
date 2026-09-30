extends SceneTree
## Догенерация иконок зданий (Task 3/10): все id из buildings.json
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://assets/ui/icons/buildings"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var specs := [
		{"id": "great_temple", "c": Color(0.9, 0.85, 0.5), "shape": "temple"},
		{"id": "market", "c": Color(0.8, 0.6, 0.3), "shape": "stall"},
		{"id": "ancient_vault", "c": Color(0.5, 0.5, 0.6), "shape": "vault"},
		{"id": "walls", "c": Color(0.6, 0.6, 0.65), "shape": "walls"},
		{"id": "mill", "c": Color(0.7, 0.6, 0.4), "shape": "mill"},
		{"id": "bakery", "c": Color(0.9, 0.75, 0.5), "shape": "loaf"},
		{"id": "school", "c": Color(0.4, 0.6, 0.9), "shape": "book"},
		{"id": "trade_post", "c": Color(0.6, 0.8, 0.5), "shape": "scales"},
		{"id": "shack", "c": Color(0.55, 0.45, 0.3), "shape": "house"},
		{"id": "manor", "c": Color(0.7, 0.5, 0.4), "shape": "manor"},
		{"id": "range", "c": Color(0.9, 0.5, 0.3), "shape": "flame"},
		{"id": "library", "c": Color(0.5, 0.4, 0.7), "shape": "books"},
		{"id": "stables", "c": Color(0.65, 0.5, 0.35), "shape": "horse"},
	]
	for s in specs:
		_draw(s, dir)
	print("[BuildingIcons2] done")
	quit(0)

func _draw(spec: Dictionary, dir: String) -> void:
	var c: Color = spec.c
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var shape: String = spec.shape
	for y in 32:
		for x in 32:
			var col := Color(0, 0, 0, 0)
			match shape:
				"temple":
					if y >= 10 and y < 26 and x >= 6 and x < 26:
						col = c if (y >= 14) else c.lightened(0.3)
					elif y >= 6 and y < 10 and absi(x - 15) <= (9 - (y - 6)):
						col = c.lightened(0.5)
				"stall":
					if y >= 8 and y < 12 and x >= 4 and x < 28:
						col = c if (y % 4 < 2) else Color(0.9, 0.9, 0.85)
					elif y >= 12 and y < 24 and (x >= 6 and x < 26):
						col = c.darkened(0.3)
				"vault":
					if x >= 8 and x < 24 and y >= 8 and y < 26:
						col = c.darkened(0.3)
					if x >= 12 and x < 20 and y >= 12 and y < 22:
						col = c
					if absf(x - 15.5) < 2 and absf(y - 16.5) < 2:
						col = Color(1, 0.9, 0.4)
				"walls":
					if y >= 8 and y < 26:
						var row := (y - 8) / 4
						var off := 0 if row % 2 == 0 else 4
						if fmod(float(x - off), 8.0) < 6:
							col = c if (row % 2 == 0) else c.darkened(0.2)
				"mill":
					var dx := float(x - 15)
					var dy := float(y - 16)
					var dist := sqrt(dx * dx + dy * dy)
					if dist < 12 and dist > 3:
						var ang := fmod(atan2(dy, dx) * 2.0 + float(x), PI)
						col = c if fmod(ang, PI / 2.0) < PI / 4 else c.darkened(0.4)
					elif dist <= 3:
						col = c.darkened(0.5)
				"loaf":
					if x >= 6 and x < 26 and y >= 12 and y < 24:
						col = c
						if y < 16:
							col = c.lightened(0.3)
						if x == 12 or x == 19:
							col = c.darkened(0.4)
				"book":
					if x >= 6 and x < 26 and y >= 8 and y < 26:
						col = c.lightened(0.5)
					if x == 15 and y >= 8 and y < 26:
						col = c.darkened(0.5)
					if x >= 6 and x < 15 and y >= 8 and y < 26:
						col = c
					if x >= 16 and x < 26 and y >= 8 and y < 26:
						col = c
				"scales":
					if x == 15 and y >= 6 and y < 26:
						col = c.darkened(0.4)
					if y == 10 and x >= 6 and x < 26:
						col = c.darkened(0.4)
					if (x >= 6 and x < 12 and y >= 10 and y < 16) or (x >= 19 and x < 25 and y >= 10 and y < 16):
						col = c
				"house":
					if y >= 12 and y < 24 and x >= 8 and x < 24:
						col = c.darkened(0.2)
					elif y >= 6 and y < 12 and absi(x - 15) <= (y - 6) + 2:
						col = c
				"manor":
					if y >= 10 and y < 26 and x >= 4 and x < 28:
						col = c.darkened(0.1)
					elif y >= 4 and y < 10 and absi(x - 15) <= (y - 4) + 3:
						col = c.lightened(0.2)
					if (x == 10 or x == 20) and y >= 14 and y < 22:
						col = Color(0.3, 0.2, 0.1)
				"flame":
					var dx := float(x - 15)
					var dy := float(y - 20)
					var dist := sqrt(dx * dx + dy * dy * 0.5)
					if dist < 9 and y < 24:
						col = c if dist > 4 else Color(1, 0.9, 0.4)
				"books":
					for i in 3:
						var bx := 5 + i * 7
						if x >= bx and x < bx + 6 and y >= 8 + (i % 2) * 2 and y < 26:
							col = [c, c.lightened(0.3), c.darkened(0.3)][i]
				"horse":
					if (x >= 8 and x < 24 and y >= 14 and y < 22) or (x >= 20 and x < 26 and y >= 8 and y < 16):
						col = c
					if (x == 10 or x == 20) and y >= 22 and y < 26:
						col = c.darkened(0.3)
			img.set_pixel(x, y, col)
	img.save_png("%s/%s.png" % [dir, spec.id])
