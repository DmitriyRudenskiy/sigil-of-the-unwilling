extends SceneTree

# Матрица различимости иконок ОДНОЙ мерой — той, которой её режет гейт
# (DhashMeasure). Нужна, чтобы числа «до/после перерисовки» были цифрами гейта,
# а не PIL-зеркала (оно удалено: расходится с Godot на 2–12 бит на пару).
#
#   godot --headless --path game -s tools/dhash_report.gd -- --dir=/tmp/asset1_before
#   godot --headless --path game -s tools/dhash_report.gd -- --atlas=/tmp/homm_atlas.png
#
# --dir   — каталог с icon_resource_*.png (по умолчанию res://assets/ui/icons/resources)
# --atlas — 4×4 атлас: снять с него 16 хэшей мерой гейта (константы A-9) и
#           прогнать A-9 по всем иконкам в двух оправках (канвас и поле).

const Measure := preload("res://tools/dhash_measure.gd")
const ICON_PREFIX := "icon_resource_"
const GRID := 4


func _init() -> void:
	var dir := "res://assets/ui/icons/resources"
	var atlas := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
		elif arg.begins_with("--atlas="):
			atlas = arg.trim_prefix("--atlas=")
	if atlas != "":
		_atlas(atlas, dir)
		quit()
		return
	var names: Array[String] = []
	var hashes := {}
	var field_hashes := {}
	for path in _pngs(dir):
		var img := _load(path)
		if img == null:
			continue
		var id := path.get_file().trim_prefix(ICON_PREFIX).get_basename()
		names.append(id)
		hashes[id] = Measure.hash_canvas(img)
		field_hashes[id] = Measure.hash_field(img)
	names.sort()
	_report("КАНВАС (мера A-9)", names, hashes, 12)
	_report("ПОЛЕ СОДЕРЖИМОГО (мера парной матрицы)", names, field_hashes, 12)
	quit()


func _report(title: String, names: Array[String], hashes: Dictionary, threshold: int) -> void:
	var pairs: Array = []
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			pairs.append([Measure.hamming(hashes[names[i]], hashes[names[j]]), names[i], names[j]])
	var dist: Array[int] = []
	for p in pairs:
		dist.append(p[0])
	print("=== %s: иконок %d, пар %d" % [title, names.size(), pairs.size()])
	if dist.is_empty():
		return
	dist.sort()
	var red := 0
	for d in dist:
		if d < threshold:
			red += 1
	print("мин %d · медиана %d · max %d · красных (<%d) %d" % [
		dist[0], dist[int(dist.size() / 2.0)], dist[dist.size() - 1], threshold, red])
	var buckets := {}
	for d in dist:
		var key := int(d / 5) * 5
		buckets[key] = int(buckets.get(key, 0)) + 1
	var keys: Array = buckets.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%d–%d: %d" % [k, k + 4, buckets[k]])
	print("распределение: ", ", ".join(parts))
	pairs.sort_custom(func(a, b):
		return a[0] < b[0] if a[0] != b[0] else str(a[1]) < str(b[1]))
	print("худшие 12: ", pairs.slice(0, 12))


func _atlas(atlas_path: String, icons_dir: String) -> void:
	var img := Image.new()
	var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(atlas_path))
	if err != OK:
		print("не читается атлас: ", atlas_path)
		return
	var cw := img.get_width() / GRID
	var ch := img.get_height() / GRID
	var canvas_cells: Array[String] = []
	var field_cells: Array[String] = []
	var cells: Array = []
	for i in range(GRID * GRID):
		var cell := img.get_region(Rect2i((i % GRID) * cw, (i / GRID) * ch, cw, ch))
		cells.append(cell)
		# оправка «перекрас целиком»: ячейка — в канвас 32×32;
		var to32 := cell.duplicate()
		to32.resize(32, 32)
		canvas_cells.append(_hex(Measure.hash_canvas(to32)))
		# оправка «перекрас в поле §7.1»: у ячейки берётся то же поле, что у иконки.
		field_cells.append(_hex(Measure.hash_field(_in_field(cell))))
	print("HOMM_DHASH_CANVAS (мера гейта, 4×4, ячейка %d×%d): [" % [cw, ch])
	print(_hex_list(canvas_cells))
	print("]")
	print("HOMM_DHASH_FIELD (мера гейта, поле ячейки → 16 px в канвас): [")
	print(_hex_list(field_cells))
	print("]")
	var names: Array[String] = []
	for path in _pngs(icons_dir):
		if _load(path) != null:
			names.append(path.get_file().trim_prefix(ICON_PREFIX).get_basename())
	names.sort()
	print("A-9 по %d иконкам (минимальное расстояние до 16 ячеек, порог 12):" % names.size())
	for framing in ["канвас", "поле"]:
		var refs: Array[String] = canvas_cells if framing == "канвас" else field_cells
		var red: Array[String] = []
		var worst := 64
		for id in names:
			var icon := _load(icons_dir.path_join(ICON_PREFIX + id + ".png"))
			var h := Measure.hash_canvas(icon) if framing == "канвас" else Measure.hash_field(icon)
			var m := 64
			for cell in refs:
				m = mini(m, Measure.hamming(h, Measure.hex64(cell)))
			worst = mini(worst, m)
			if m < 12:
				red.append("%s(%d)" % [id, m])
		var head := "оправка %s: худшее %d · красных (<12) %d" % [framing, worst, red.size()]
		print("%s %s" % [head, ", ".join(red)])
	_theft_proof(cells, canvas_cells, field_cells)


# Доказательство, что A-9 ловит подсовывание чужой ячейки. Каждая оправка ловит
# свой вектор: канвас — когда ячейку положили целиком в 32×32, поле — когда её
# вставили в поле §7.1. Чужой вектор в чужой оправке даёт большое расстояние,
# поэтому проверяются обе, со своим порогом на каждую.
func _theft_proof(cells: Array, canvas_refs: Array[String], field_refs: Array[String]) -> void:
	var worst := {"канвас/канвас": 0, "канвас/поле": 0, "поле/канвас": 0, "поле/поле": 0}
	for cell in cells:
		var full: Image = cell.duplicate()
		full.resize(32, 32)
		worst["канвас/канвас"] = maxi(int(worst["канвас/канвас"]), _nearest(full, canvas_refs, true))
		worst["канвас/поле"] = maxi(int(worst["канвас/поле"]), _nearest(full, field_refs, false))
		var placed := _in_field(cell)
		worst["поле/канвас"] = maxi(int(worst["поле/канвас"]), _nearest(placed, canvas_refs, true))
		worst["поле/поле"] = maxi(int(worst["поле/поле"]), _nearest(placed, field_refs, false))
	print("ловля подсовывания (худшее из 16 ячеек; «вектор/оправка», 0 = точно та же форма):")
	print("\tподсована целиком: канвас %d · поле %d" % [worst["канвас/канвас"], worst["канвас/поле"]])
	print("\tподсована в поле:   канвас %d · поле %d" % [worst["поле/канвас"], worst["поле/поле"]])


func _nearest(icon: Image, refs: Array[String], canvas_framing: bool) -> int:
	var h := Measure.hash_canvas(icon) if canvas_framing else Measure.hash_field(icon)
	var best := 64
	for cell in refs:
		best = mini(best, Measure.hamming(h, Measure.hex64(cell)))
	return best


# Ячейка атласа → канвас 32×32 с полем §7.1.
func _in_field(cell: Image) -> Image:
	var small := cell.duplicate()
	small.resize(Measure.FIELD * 2, Measure.FIELD * 2)
	var canvas := Image.create(32, 32, true, Image.FORMAT_RGBA8)
	canvas.blit_rect(small, Rect2i(0, 0, Measure.FIELD * 2, Measure.FIELD * 2),
		Vector2i(Measure.FIELD, Measure.FIELD))
	return canvas


func _hex(v: int) -> String:
	var out := ""
	for i in range(16):
		out = Measure._HEX_DIGITS[v & 15] + out
		v >>= 4
	return out


func _hex_list(values: Array[String]) -> String:
	return "\n\t" + ",\n\t".join(values)


func _pngs(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		print("не открывается каталог: ", dir)
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with(ICON_PREFIX) and f.get_extension().to_lower() == "png":
			out.append(dir.path_join(f))
		f = d.get_next()
	out.sort()
	return out


func _load(path: String) -> Image:
	var img := Image.new()
	return img if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK else null
