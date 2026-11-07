extends SceneTree

# Протокол мерки глифов маркерного слоя (T-344, фаза Ф1) — продакшн-канал.
# Рисование — CanvasItem.draw_string в ОТРЕНДЕРЕННОМ кадре (Node2D, живое окно,
# не headless, не Image.draw_string_at — владелец, 2026-11-06: тот канал ≠ продакшн).
# Параметры 1:1 marker_layer.gd: ThemeDB.fallback_font, size 14,
# HORIZONTAL_ALIGNMENT_CENTER, W = 1.6·hex (глифы ✗/⛏️, marker_layer:186-191) и
# W = 2.0·hex (подпись города, marker_layer:178-181), hex = HexCellArt.HEX_SIZE.y·0.5.
# Мерка дифференциальная (как в test_marker_fog_visual.py): кадр без чернил и кадр
# с чернилами одного раннера; разность — маска чернил, цвет шрифта не участвует.
# Выход по каждому варианту: bbox_left/right, bbox_center_x, box_center_x,
# Δcenter_box (= bbox − центр бокса), Δcenter_cell (= bbox − центр клетки),
# бинарный факт пересечения альфа-маски (чернила вне гексагона носителя: да/нет,
# с вылетом в px по нормалям HexCellArt).
# Запуск (НЕ headless): Godot --path game -s tools/probe_glyph.gd -- --out=tmp/shots/probe_glyph.png
# Пиксели в git не идут (D-185): артефакт — tmp/shots/, числа — в протокол/тикет.

const OUT_DEFAULT := "tmp/shots/probe_glyph.png"

## Варианты мерки: текст, ширина бокса в долях hex, имя в протоколе.
## ✗ — истощённый ресурс (C_MARKER_EXHAUSTED), ⛏️ — активный (C_MARKER_ACTIVE),
## «Камень» — образец подписи города (C_MARKER_LABEL, W=2.0·hex).
const VARIANTS := [
		{"name": "cross", "text": "✗", "w_hex": 1.6, "label": "✗ (W=1.6·hex)"},
		{"name": "pick", "text": "⛏️", "w_hex": 1.6, "label": "⛏️ (W=1.6·hex)"},
		{"name": "city", "text": "Камень", "w_hex": 2.0, "label": "«Камень» (W=2.0·hex)"},
]

const FONT_SIZE := 14
const CELL_XS := [180.0, 480.0, 780.0]
const ROW_YS := [100.0, 210.0, 320.0]
const BG := Color(0.302, 0.302, 0.302)  # void 77,77,77 — как пустой фон мира
const EDGE := 60.0  # полупрозрачный контур гексагона на артефакте (в мерку не входит)


class ProbeNode:
		extends Node2D
		var draw_ink := false
		var variants := []
		var cells_x := []
		var rows_y := []
		var hex := 47.5
		var apothem := 41.0
		var normals: Array[Vector2] = []

		func _draw() -> void:
				# Фон: как пустой (неисследованный) фон мира.
				draw_rect(Rect2(Vector2.ZERO, Vector2(1024, 420)), BG_IF_OUTSIDE, true)
				# Контур гексагона клетки — только для чтения артефакта глазами.
				for i in variants.size():
						var center := Vector2(cells_x[i], rows_y[i])
						var pts := PackedVector2Array()
						for k in 6:
								var ang := deg_to_rad(60.0 * k + 30.0)
								pts.append(center + Vector2(cos(ang), sin(ang)) * (hex))
						pts.append(pts[0])
						draw_polyline(pts, Color(1, 1, 1, 0.35), 1.0)
				if not draw_ink:
						return
				for i in variants.size():
						var v: Dictionary = variants[i]
						var pos := Vector2(cells_x[i], rows_y[i])
						var w := float(v.w_hex) * hex
						# 1:1 с marker_layer.gd после ступени 1 (центрирование бокса):
						# бокс сдвинут на −W/2, у подписи города — на −W/2 и −0.30·hex.
						var base_off := Vector2(-w / 2.0, 0.0)
						if String(v.name) == "city":
								base_off = Vector2(-w / 2.0, -hex * 0.30)
						draw_string(ThemeDB.fallback_font, pos + base_off, String(v.text),
								HORIZONTAL_ALIGNMENT_CENTER, w, FONT_SIZE,
								INK_COLOR[i % INK_COLOR.size()])

		const BG_IF_OUTSIDE := Color(0.302, 0.302, 0.302)
		const INK_COLOR := [Color(0.7, 0.7, 0.75, 0.9), Color(0.95, 0.85, 0.4, 0.95), Color(1.0, 0.96, 0.85, 0.95)]


func _initialize() -> void:
		_run()


func _normals() -> Array[Vector2]:
		# Носитель: SIDE_ANGLES 0/60/.../300, апотема = HEX_SIZE.x/2 (hex_cell_art.gd).
		var angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]
		var out: Array[Vector2] = []
		for a in angles:
				var rad := deg_to_rad(a)
				out.append(Vector2(cos(rad), sin(rad)))
		return out


func _run() -> void:
		var uargs := OS.get_cmdline_user_args()
		var out_path := OUT_DEFAULT
		for u in uargs:
				if u.begins_with("--out="):
						out_path = u.substr(6)
		if not out_path.begins_with("res://") and not out_path.is_absolute_path():
				out_path = ProjectSettings.globalize_path("res://").path_join(out_path)
		if DisplayServer.get_name() == "headless":
				print("[probe_glyph] ERROR: headless — рендера нет; канал съёмки = отрендеренный кадр")
				quit(2)
				return
		var hex_size := HexCellArt.HEX_SIZE
		var hex := hex_size.y * 0.5
		var apothem := hex_size.x * 0.5
		var normals := _normals()

		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1024, 420)
		await process_frame
		await process_frame

		var probe := ProbeNode.new()
		probe.variants = VARIANTS
		probe.cells_x = CELL_XS
		probe.rows_y = ROW_YS
		probe.hex = hex
		probe.apothem = apothem
		probe.normals = normals
		root.add_child(probe)
		for i in 6:
				await process_frame

		# Кадр базы (чернил нет) и кадр с чернилами — один раннер, одна камера.
		# Переключение флага НЕ перерисовывает узел само по себе: без queue_redraw()
		# второй кадр — копия первого (снято и проверено: разность пустая).
		probe.draw_ink = false
		probe.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var base: Image = root.get_texture().get_image()
		probe.draw_ink = true
		probe.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var ink: Image = root.get_texture().get_image()
		if base.get_size() != ink.get_size():
				print("[probe_glyph] ERROR: размеры кадров разошлись")
				quit(3)
				return
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		ink.save_png(out_path)

		var bd := base.get_data()
		var idd := ink.get_data()
		var w := ink.get_width()
		var h := ink.get_height()
		print("[probe_glyph] кадр %dx%d, hex=%.1f, апотема=%.1f, шрифт=%s" % [
				w, h, hex, apothem, ThemeDB.fallback_font.get_class()])
		print("[probe_glyph] протокол мерки (пиксели — в координатах кадра):")
		for i in VARIANTS.size():
				var v: Dictionary = VARIANTS[i]
				var cx := float(CELL_XS[i])
				var cy := float(ROW_YS[i])
				var bw := float(v.w_hex) * hex
				# Окно поиска чернил: бокс ± запас, ряд ± запас.
				var x0 := int(cx) - 80
				var x1 := mini(int(cx + bw) + 60, w - 1)
				var y0 := maxi(int(cy) - 60, 0)
				var y1 := mini(int(cy) + 60, h - 1)
				var minx := 1 << 30
				var maxx := -1
				var miny := 1 << 30
				var maxy := -1
				var ink_px := 0
				var outside := 0
				var overshoot := 0.0
				var yy := y0
				while yy <= y1:
						var xx := x0
						while xx <= x1:
								var j := (yy * w + xx) * 4
								var dr := absf(idd[j] - bd[j])
								var dg := absf(idd[j + 1] - bd[j + 1])
								var db := absf(idd[j + 2] - bd[j + 2])
								if dr + dg + db > 45.0:
										ink_px += 1
										minx = mini(minx, xx)
										maxx = maxi(maxx, xx)
										miny = mini(miny, yy)
										maxy = maxi(maxy, yy)
										# Альфа-маска носителя: гексагон с центром клетки,
										# апотемой a и нормалями 0/60/... (t>1 — вне клетки).
										var dx := float(xx) + 0.5 - cx
										var dy := float(yy) + 0.5 - cy
										var tmax := -1.0
										for n in normals:
												tmax = maxf(tmax, absf((dx * n.x + dy * n.y) / apothem))
										if tmax > 1.0:
												outside += 1
												overshoot = maxf(overshoot, (tmax - 1.0) * apothem)
								xx += 1
						yy += 1
				if ink_px == 0:
						print("[probe_glyph] %s: ЧЕРНИЛ НЕТ — глиф не отрисовался (глиф/шрифт машины)" % v.label)
						continue
				var bbox_center := (minx + maxx) / 2.0
				var box_center := cx + bw / 2.0
				var line := "[probe_glyph] %s: bbox=[%d..%d] w=%d Δcenter_box=%.1f " % [
						v.label, minx, maxx, maxx - minx + 1, box_center - bbox_center]
				line += " Δcenter_cell=%.1f ink_px=%d маска=%s outside_px=%d вылет=%.1fpx" % [
						bbox_center - cx, ink_px, "ДА" if outside > 0 else "нет", outside, overshoot]
				print(line)
		var fa := FileAccess.open(out_path, FileAccess.READ)
		print("[probe_glyph] артефакт: %s (%d Б) — пиксели в git не идут (D-185)" % [
				out_path, fa.get_length() if fa != null else -1])
		quit(0)
