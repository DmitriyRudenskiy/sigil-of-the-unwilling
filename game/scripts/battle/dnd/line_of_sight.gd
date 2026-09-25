class_name DNDLineOfSight

## D&D 5e 3D Line of Sight
# Bresenham line between two cells; a cell blocks the line when its
# elevation (in feet) is strictly above the interpolated line-of-fire
# height at that cell. Endpoints never block.

## True if the attacker can see the target.
static func has_line_of_sight(elev: DNDElevationSystem, from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	var cells := _bresenham(from, to)
	var h0 := elev.height_feet(from)
	var h1 := elev.height_feet(to)
	var n := cells.size() - 1
	for i in range(1, n):
		var cell: Vector2i = cells[i]
		var t := float(i) / float(n)
		var line_h := lerpf(h0, h1, t)
		# A wall taller than the line of fire blocks sight.
		if elev.height_feet(cell) > line_h:
			return false
	return true


## Minimum clearance (in feet) of the line of fire above every intermediate
## cell. Negative means the line is blocked. Used by cover calculation.
static func min_clearance(elev: DNDElevationSystem, from: Vector2i, to: Vector2i) -> float:
	var cells := _bresenham(from, to)
	var h0 := elev.height_feet(from)
	var h1 := elev.height_feet(to)
	var n := cells.size() - 1
	var best := INF
	# Pure ground (level 0) is not cover; only raised cells can shield.
	for i in range(1, n):
		var cell: Vector2i = cells[i]
		var wall_h := elev.height_feet(cell)
		if wall_h <= 0:
			continue
		var t := float(i) / float(n)
		var line_h := lerpf(h0, h1, t)
		best = minf(best, line_h - wall_h)
	return best


## Integer Bresenham line, inclusive of both endpoints.
static func _bresenham(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var cur := a
	while true:
		out.append(cur)
		if cur == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			cur.x += sx
		if e2 <= dx:
			err += dx
			cur.y += sy
	return out
