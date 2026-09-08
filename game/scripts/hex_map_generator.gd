extends Node2D
class_name HexMapGenerator

@export var sheet0: Texture2D          
@export var sheet1: Texture2D          
@export var map_w := 48
@export var map_h := 32
@export var noise_seed := 0
@export var smooth_passes := 2

@export_enum("noise", "blueprint", "shares") var mode := "noise"
@export var edge_jitter := 0.6          
@export var blueprint: PackedStringArray = PackedStringArray([
	"GGGGSS",
	"GGGGGS",                                
	"GGGGGG",
])
@export var biome_a := 0                 
@export var biome_b := 2                 
@export var share_map: PackedStringArray = PackedStringArray([
	"444400",
	"444400",
	"444440",
	"444440",
])
const CHAR_TO_BIOME := {"G": 0, "S": 2, "D": 6, "W": 4, "R": 5, "L": 7, "P": 8, "M": 3}

const TILE_W := 64.0
const TILE_H := 74.0
const COL_STEP := 64.0                 
const ROW_STEP := 55.0                 
const PAD := 2.0                       
const CELL := Vector2(66.0, 76.0)      
const ROT_SIGN := -1.0                 

const BIOMES := ["grass","sand","snow","swamp","water","rock","dirt","lava","road"]

const DIR_EVEN := [Vector2i(1,0),Vector2i(1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,1),Vector2i(1,1)]
const DIR_ODD  := [Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,-1),Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,1)]

var _biome := {}                       
var _cells := {}                       
var _share := {}                       
var _i100 := {}; var _i50 := {}; var _i30 := {}


var _mode_option: OptionButton

func _ready() -> void:
	_build_index_maps()
	_mode_option = get_node("../UI/ModeOption") as OptionButton
	_populate_mode_option()
	generate()

func _populate_mode_option() -> void:
	if not is_instance_valid(_mode_option):
		return
	_mode_option.clear()
	var names := ["Noise", "Blueprint", "Shares"]
	for i in 3:
		_mode_option.add_item(names[i], i)
	_mode_option.select(_mode_index())
	_mode_option.item_selected.connect(_on_mode_selected)

func _mode_index() -> int:
	match mode:
		"noise": return 0
		"blueprint": return 1
		_: return 2

func _on_mode_selected(idx: int) -> void:
	match idx:
		0: mode = "noise"
		1: mode = "blueprint"
		_: mode = "shares"
	generate()


func _on_regenerate_button_pressed() -> void:
	noise_seed = randi()
	generate()

func _on_save_button_pressed() -> void:
	_save_map()


func _build_index_maps() -> void:
	var idx := 0
	for b in 9: _i100[b] = idx; idx += 1
	for i in 9:
		for j in range(i + 1, 9): _i50[Vector2i(i, j)] = idx; idx += 1
	for i in 9:
		for j in 9:
			if i != j: _i30[Vector2i(i, j)] = idx; idx += 1   


func _tile_ref(idx: int) -> Dictionary:
	var sheet := idx / 64
	var c := idx % 64
	return {"idx": idx, "sheet": sheet,
			"region": Rect2(PAD + (c % 8) * CELL.x, PAD + (c / 8) * CELL.y, TILE_W, TILE_H)}


func generate() -> void:
	_cells.clear()
	match mode:
		"shares": _gen_shares()
		"blueprint": _gen_biomes_blueprint()
		_: _gen_biomes_noise()                  
	if mode != "shares":
		for _p in smooth_passes: _smooth()
		_assign_tiles()
	else:
		_assign_tiles_shares()
	queue_redraw()


func _gen_biomes_noise() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = noise_seed
	noise.frequency = 0.07
	_biome.clear()
	for y in map_h:
		for x in map_w:
			var n := noise.get_noise_2d(x, y * 0.9)            
			_biome[Vector2i(x, y)] = clampi(int((n + 1.0) * 0.5 * 9), 0, 8)


func _gen_biomes_blueprint() -> void:
	_biome.clear()
	var jn := FastNoiseLite.new()
	jn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	jn.seed = noise_seed + 77
	jn.frequency = 0.15                     
	for y in map_h:
		for x in map_w:
			var fx := float(x) / map_w * blueprint[0].length()
			var fy := float(y) / map_h * blueprint.size()
			var j := jn.get_noise_2d(x, y) * edge_jitter
			var bx := clampi(int(fx + j), 0, blueprint[0].length() - 1)
			var by := clampi(int(fy + j * 0.7), 0, blueprint.size() - 1)
			_biome[Vector2i(x, y)] = CHAR_TO_BIOME[blueprint[by][bx]]


func _neighbors(c: Vector2i) -> Array:
	var t := DIR_EVEN if c.y & 1 == 0 else DIR_ODD
	var res := Array()
	for d in t:
		res.append(c + d)
	return res


func _smooth() -> void:
	var next := {}
	for c in _biome:
		var cnt := {}
		cnt[_biome[c]] = 1
		for n in _neighbors(c):
			if _biome.has(n): cnt[_biome[n]] = cnt.get(_biome[n], 0) + 1
		var best: int = _biome[c]; var bv: int = 0
		for k in cnt:
			if cnt[k] > bv: bv = cnt[k]; best = k
		next[c] = best
	_biome = next


func _assign_tiles() -> void:
	_cells.clear()
	for c in _biome:
		var own: int = _biome[c]
		var cnt := {}; var dirs := {}
		for i in 6:
			var n: Vector2i = _neighbors(c)[i]
			var nb: int = _biome.get(n, own)                        
			if nb != own:
				cnt[nb] = cnt.get(nb, 0) + 1
				dirs[nb] = dirs.get(nb, []) + [i]
		if cnt.is_empty():                                      
			var t := _tile_ref(_i100[own])
			t.rot = randi() % 6
			_cells[c] = t
			continue
		var B := 0; var bc := 0
		for k in cnt:
			if cnt[k] > bc: bc = cnt[k]; B = k
		var ds: Array = dirs[B]
		if bc >= 3:                                             
			var d := _centroid_dir(ds)
			var key := Vector2i(mini(own, B), maxi(own, B))
			var t := _tile_ref(_i50[key])
			t.rot = (d + 5) % 6                                 
			_cells[c] = t
		else:                                                   
			var t := _tile_ref(_i30[Vector2i(B, own)])
			t.rot = ds[0] if ds.size() == 1 else _adj_rot(ds)
			_cells[c] = t


func _gen_shares() -> void:
	_share.clear()
	for y in share_map.size():
		for x in share_map[y].length():
			_share[Vector2i(x, y)] = share_map[y][x].to_int()
	var has_mid := false
	for c in _share:
		if _share[c] in [1, 2, 3]: has_mid = true
	if not has_mid: _auto_ladder()


func _bfs(from_val: int) -> Dictionary:  
	var dist := {}; var q := []
	for c in _share:
		if _share[c] == from_val: dist[c] = 0; q.append(c)
	var head := 0
	while head < q.size():
		var c = q[head]; head += 1
		for n in _neighbors(c):
			if _share.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1; q.append(n)
	return dist


func _auto_ladder() -> void:
	var d_snow := _bfs(biome_a)                 
	var d_for := _bfs(biome_b)                  
	for c in _share:
		if _share[c] == 4:
			var d: int = d_snow.get(c, 99)
			_share[c] = 3 if d == 1 else 4
		elif _share[c] == 0:
			var d: int = d_for.get(c, 99)
			_share[c] = 2 if d == 1 else (1 if d == 2 else 0)


func _orient(c: Vector2i, cls: int) -> int:
	var own: int = _share[c]
	var targets := []
	for i in 6:
		var s: int = _share.get(_neighbors(c)[i], own)
		if cls >= 2 and s < own: targets.append(i)     
		elif cls == 1 and s > own: targets.append(i)   
	if targets.is_empty(): return 0
	if cls == 2: return (_centroid_dir(targets) + 5) % 6   
	return _adj_rot(targets) if targets.size() > 1 else targets[0]


func _assign_tiles_shares() -> void:
	_cells.clear()
	var half_key := Vector2i(mini(biome_a, biome_b), maxi(biome_a, biome_b))
	for c in _share:
		var t: Dictionary
		match _share[c]:
			4: t = _tile_ref(_i100[biome_a]); t.rot = randi() % 6
			0: t = _tile_ref(_i100[biome_b]); t.rot = randi() % 6
			3: t = _tile_ref(_i30[Vector2i(biome_b, biome_a)]); t.rot = _orient(c, 3)
			2: t = _tile_ref(_i50[half_key]);                  t.rot = _orient(c, 2)
			1: t = _tile_ref(_i30[Vector2i(biome_a, biome_b)]); t.rot = _orient(c, 1)
		_cells[c] = t


func _centroid_dir(ds: Array) -> int:
	var sx := 0.0; var sy := 0.0
	for i in ds:
		var a := deg_to_rad(i * 60.0)
		sx += cos(a); sy += sin(a)
	var best := 0; var bd := -2.0
	for i in 6:
		var a := deg_to_rad(i * 60.0)
		var d := (sx * cos(a) + sy * sin(a)) / maxf(1.0, ds.size())
		if d > bd: bd = d; best = i
	return best


func _adj_rot(ds: Array) -> int:
	for a in ds:
		if ds.has((a + 1) % 6): return a                        
	return ds[0]


func _serialize_map() -> String:
	var out := PackedStringArray()
	out.append("# HexMap v1")
	out.append("mode=%s" % mode)
	out.append("seed=%d" % noise_seed)
	out.append("size=%dx%d" % [map_w, map_h])
	out.append("smooth=%d" % smooth_passes)
	out.append("# biomes (rows top->bottom, cols left->right; digit = biome index):")
	for y in map_h:
		var row := ""
		for x in map_w:
			var c := Vector2i(x, y)
			var b: int = 9 if not _biome.has(c) else _biome[c]
			row += str(b)
		out.append(row)
	out.append("# tiles (row col sheet idx rot):")
	var keys := _cells.keys()
	keys.sort()
	for c in keys:
		var t: Dictionary = _cells[c]
		out.append("%d %d %d %d %d" % [c.x, c.y, t.sheet, t.idx, int(t.rot)])
	return "\n".join(out)

func _save_map() -> void:
	var path := OS.get_user_data_dir() + "/hexmap_save.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("HexMapGenerator: could not open file for writing: %s" % path)
		return
	file.store_string(_serialize_map())
	file.close()
	print("HexMapGenerator: saved map (%d cells) to %s" % [_cells.size(), path])


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * COL_STEP + (c.y & 1) * COL_STEP * 0.5, c.y * ROW_STEP)


func _draw() -> void:
	for c in _cells:
		var t: Dictionary = _cells[c]
		var tex := sheet0 if t.sheet == 0 else sheet1
		if tex == null:
			continue
		draw_set_transform(_cell_pos(c), t.rot * PI / 3.0 * ROT_SIGN, Vector2.ONE)
		draw_texture_rect_region(tex, Rect2(-TILE_W/2, -TILE_H/2, TILE_W, TILE_H), t.region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
