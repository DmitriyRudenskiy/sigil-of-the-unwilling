@tool
extends EditorScript
## Нарезка листов 5x5 из res://assets/raw/binom/ в processed/
## Автоопределение биома по среднему цвету; самый "пустой" гекс -> {biome}_base.png

const SRC := "res://assets/raw/binom/"
const OUT := "res://tilesets/processed/"
const TILE := 82
const GRID := 5


func _run() -> void:
  var dir := DirAccess.open(SRC)
  if dir == null:
    printerr("ERROR: no ", SRC)
    return
  dir.list_dir_begin()
  var f := dir.get_next()
  while f != "":
    var low := f.to_lower()
    if low.ends_with(".png") or low.ends_with(".jpeg") or low.ends_with(".jpg"):
      _process_sheet(SRC + f)
    f = dir.get_next()
  dir.list_dir_end()
  print("=== binom cutter done ===")


func _process_sheet(path: String) -> void:
  var img := Image.load_from_file(path)
  if img == null:
    return
  if img.get_format() != Image.FORMAT_RGBA8:
    img.convert(Image.FORMAT_RGBA8)
  # кроп в квадрат + ресайз до 410x410
  var side := mini(img.get_width(), img.get_height())
  if img.get_width() != side or img.get_height() != side:
    var off := Vector2i((img.get_width() - side) / 2, (img.get_height() - side) / 2)
    var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
    sq.blit_rect(img, Rect2i(off.x, off.y, side, side), Vector2i(0, 0))
    img = sq
  img.resize(TILE * GRID, TILE * GRID, Image.INTERPOLATE_LANCZOS)

  var biome := _classify(img)
  var plain_idx := 0
  var plain_score := 1e9
  var idx := 0
  for ry in GRID:
    for rx in GRID:
      var cell := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
      cell.blit_rect(img, Rect2i(rx * TILE, ry * TILE, TILE, TILE), Vector2i(0, 0))
      var score := _clean(cell)
      if score < plain_score:
        plain_score = score
        plain_idx = idx
      cell.save_png(OUT + "%s_v%02d.png" % [biome, idx])
      idx += 1
  # самый пустой -> base
  var base := Image.load_from_file(OUT + "%s_v%02d.png" % [biome, plain_idx])
  if base != null:
    base.save_png(OUT + "%s_base.png" % biome)
  print("sheet %s -> %s (%d tiles, base=v%02d)" % [path, biome, idx, plain_idx])


func _classify(img: Image) -> String:
  var sum := Color(0, 0, 0, 0)
  var n := 0
  for y in range(0, img.get_height(), 10):
    for x in range(0, img.get_width(), 10):
      var px := img.get_pixel(x, y)
      if px.r + px.g + px.b > 0.15:
        sum += px
        n += 1
  if n == 0:
    return "grass"
  var r := sum.r / float(n)
  var g := sum.g / float(n)
  var b := sum.b / float(n)
  var lum := (r + g + b) / 3.0
  if lum > 0.72:
    return "snow"
  if r > 0.6 and b < 0.45 and g < r * 0.88:
    return "sand"
  if lum < 0.5 and g >= r * 0.8:
    return "swamp"
  return "grass"


## чистит чёрный фон + маска гекса; возвращает "пустоту" (разброс яркости)
func _clean(img: Image) -> float:
  var cx := float(TILE) / 2.0
  var R := cx * 0.96  # отступ 2% от кромки
  var mn := 1.0
  var mx := 0.0
  for y in TILE:
    for x in TILE:
      var px := img.get_pixel(x, y)
      if px.r < 0.06 and px.g < 0.06 and px.b < 0.06:
        img.set_pixel(x, y, Color(0, 0, 0, 0))
        continue
      var pxx := float(x) - cx + 0.5
      var pyy := float(y) - cx + 0.5
      var q := (sqrt(3.0) / 3.0 * pxx - 1.0 / 3.0 * pyy) / R
      var s := (2.0 / 3.0 * pyy) / R
      if maxf(absf(q), maxf(absf(s), absf(-q - s))) > 1.0:
        img.set_pixel(x, y, Color(0, 0, 0, 0))
        continue
      var l := (px.r + px.g + px.b) / 3.0
      mn = minf(mn, l)
      mx = maxf(mx, l)
  return mx - mn
