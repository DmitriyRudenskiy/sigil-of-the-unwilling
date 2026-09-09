extends SceneTree

const TUNE_FILE := "res://scripts/constants/GameNumbers.gd"
const RESOURCES: Array[StringName] = [&"food", &"industry", &"dust", &"science", &"influence"]

const TUNED_BUILDINGS: Array[StringName] = [
	&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
	&"trade_post", &"school", &"market", &"shack", &"walls",
]

const YIELD_BOUNDS: Array = [
	[0.0, 8.0], [0.0, 6.0], [0.0, 2.0], [0.0, 2.0], [0.0, 2.0],
]
const BONUS_BOUNDS: Array = [[0.0, 0.6]]
const YIELD_STEP: Array = [0.5, 0.5, 0.25, 0.25, 0.25]
const BONUS_STEP := 0.05
const NO_IMPROVE_LIMIT := 1500

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var evals := 8000
	var seed := 42
	var turns := 48
	var dry_run := false
	var report_path := "user://tune_report.txt"
	for i in args.size():
		match args[i]:
			"--evals":
				evals = int(args[i + 1])
			"--seed":
				seed = int(args[i + 1])
			"--turns":
				turns = int(args[i + 1])
			"--dry-run":
				dry_run = true
			"--report":
				report_path = args[i + 1]

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var baseline: Dictionary = _current_tables()
	var yield_cur: Array = _deep_copy_yield(baseline.yield_table)
	var bonus_cur: Dictionary = _deep_copy_bonus(baseline.bonus_table)
	var best_yield: Array = _deep_copy_yield(yield_cur)
	var best_bonus: Dictionary = _deep_copy_bonus(bonus_cur)
	var best_score: float = _evaluate(yield_cur, bonus_cur, turns)
	var base_score: float = best_score
	print("BASE score=%.3f (evals=%d turns=%d seed=%d)" % [base_score, evals, turns, seed])

	var t0 := Time.get_ticks_msec()
	var no_improve := 0
	var evals_done := 1
	var accepted := 0
	for e in range(1, evals + 1):
		var stuck: float = float(no_improve) / float(NO_IMPROVE_LIMIT)
		var jolt := 1 if rng.randf() < 0.5 * stuck else 0
		var changes: Array = _mutate(rng, yield_cur, bonus_cur,
			1 + 3 * jolt, 1.0 + 3.0 * float(jolt))
		var score: float = _evaluate(yield_cur, bonus_cur, turns)
		evals_done += 1
		if score > best_score:
			var prev_best := best_score
			best_score = score
			best_yield = _deep_copy_yield(yield_cur)
			best_bonus = _deep_copy_bonus(bonus_cur)
			no_improve = 0
			accepted += 1
			print("  [%.1f%%] #%d ACCEPT%s score=%.3f (+%.3f)" % [
				100.0 * float(e) / float(evals), e, " (jolt)" if jolt else "",
				score, score - prev_best])
		else:
			no_improve += 1
			_undo(yield_cur, bonus_cur, changes)
		if e % 500 == 0:
			print("  [%.1f%%] eval=%d best=%.3f accepted=%d no_improve=%d elapsed=%.1fs" % [
				100.0 * float(e) / float(evals), e, best_score, accepted, no_improve,
				(float(Time.get_ticks_msec() - t0)) / 1000.0])
		if no_improve >= NO_IMPROVE_LIMIT:
			print("  Сход: %d итераций без улучшения на eval=%d" % [no_improve, e])
			break

	var ms := Time.get_ticks_msec() - t0
	print("DONE evals=%d time=%.1fs base=%.3f best=%.3f gain=%.3f" % [
		evals_done, float(ms) / 1000.0, base_score, best_score, best_score - base_score])

	var lines: Array[String] = []
	lines.append("City Arena tuner report")
	lines.append("seed=%d evals=%d turns=%d time_ms=%d" % [seed, evals_done, turns, ms])
	lines.append("base_score=%.4f best_score=%.4f gain=%.4f" % [base_score, best_score, best_score - base_score])
	lines.append("")
	lines.append("RING_YIELD (rings 1..5, [food, industry, dust, science, influence]):")
	for r in range(1, 6):
		lines.append("  ring%d: %s" % [r, _fmt_row(best_yield[r])])
	lines.append("")
	lines.append("RING_BONUS (building: ring->bonus):")
	for bid in TUNED_BUILDINGS:
		var rowd: Dictionary = best_bonus[bid]
		var parts: Array[String] = []
		for r in range(1, 6):
			parts.append("%d:%.2f" % [r, float(rowd.get(r, 0.0))])
		lines.append("  %s: %s" % [String(bid), ", ".join(parts)])
	var report_text := "\n".join(lines)
	print(report_text)
	var rf := FileAccess.open(report_path, FileAccess.WRITE)
	if rf != null:
		rf.store_string(report_text + "\n")
		rf.close()
		print("report -> ", report_path)

	if not dry_run:
		_write_balance_file(best_yield, best_bonus)
		print("rewrote ", TUNE_FILE)
	else:
		print("dry-run: ", TUNE_FILE, " НЕ изменён")
	quit()

func _evaluate(yield_table: Array, bonus_table: Dictionary, turns: int) -> float:
	var overrides := {
		&"ring_yield": yield_table,
		&"ring_bonus": bonus_table,
	}
	var rep: Dictionary = CityArenaModel.run_demo_plan(turns, overrides)
	return float(rep.get("score", 0.0))

func _mutate(rng: RandomNumberGenerator, yield_cur: Array, bonus_cur: Dictionary,
			 k: int, strength: float) -> Array:
	var changes: Array = []
	var n_params := 25 + TUNED_BUILDINGS.size() * 5
	for _j in k:
		var idx := rng.randi_range(0, n_params - 1)
		if idx < 25:
			var ring := idx / 5 + 1
			var res := idx % 5
			var row: Array = yield_cur[ring]
			var before := float(row[res])
			var delta: float = YIELD_STEP[res] * strength * (1.0 if rng.randf() < 0.5 else -1.0)
			row[res] = _clamp(before + delta, YIELD_BOUNDS[res][0], YIELD_BOUNDS[res][1])
			changes.append([0, ring, res, before])
		else:
			var bi := (idx - 25) / 5
			var ring := (idx - 25) % 5 + 1
			var bid: StringName = TUNED_BUILDINGS[bi]
			var rowd: Dictionary = bonus_cur[bid]
			var before := float(rowd.get(ring, 0.0))
			var delta: float = BONUS_STEP * strength * (1.0 if rng.randf() < 0.5 else -1.0)
			rowd[ring] = _clamp(before + delta, BONUS_BOUNDS[0][0], BONUS_BOUNDS[0][1])
			changes.append([1, bi, ring, before])
	return changes

func _undo(yield_cur: Array, bonus_cur: Dictionary, changes: Array) -> void:
	for ch in changes:
		if int(ch[0]) == 0:
			yield_cur[int(ch[1])][int(ch[2])] = ch[3]
		else:
			bonus_cur[TUNED_BUILDINGS[int(ch[1])]][int(ch[2])] = ch[3]

func _current_tables() -> Dictionary:
	var yt: Array = []
	for r in range(6):
		var src: Array = GameNumbers.RING_YIELD[r]
		var row: Array = []
		for i in range(5):
			row.append(float(src[i]))
		yt.append(row)
	var bt: Dictionary = {}
	for bid in TUNED_BUILDINGS:
		var src: Dictionary = GameNumbers.RING_BONUS.get(bid, {})
		var rowd: Dictionary = {}
		for r in range(1, 6):
			rowd[r] = float(src.get(r, 0.0))
		bt[bid] = rowd
	return {"yield_table": yt, "bonus_table": bt}

func _deep_copy_yield(t: Array) -> Array:
	var out: Array = []
	for row in t:
		var r: Array = row
		var nr: Array = []
		for v in r:
			nr.append(float(v))
		out.append(nr)
	return out

func _deep_copy_bonus(t: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in t:
		var src: Dictionary = t[k]
		var rowd: Dictionary = {}
		for rk in src:
			rowd[rk] = float(src[rk])
		out[k] = rowd
	return out

func _clamp(v: float, lo: float, hi: float) -> float:
	return clampf(v, lo, hi)

func _fmt_row(row: Array) -> String:
	var parts: Array[String] = []
	for i in range(5):
		parts.append("%.2f" % float(row[i]))
	return "[ " + ", ".join(parts) + " ]"

func _write_balance_file(yield_table: Array, bonus_table: Dictionary) -> void:

	var f := FileAccess.open(TUNE_FILE, FileAccess.READ)
	if f == null:
		push_error("Не удалось открыть %s для чтения" % TUNE_FILE)
		return
	var lines: PackedStringArray = f.get_as_text().split("\n")
	f.close()
	var out: Array[String] = []
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		if line.begins_with("const RING_YIELD"):
			out.append("const RING_YIELD: Array = [")
			for r in range(6):
				var row: Array = yield_table[r]
				var parts: Array[String] = []
				for c in range(5):
					parts.append("%.2f" % float(row[c]))
				out.append("\t[" + ", ".join(parts) + "],")
			out.append("]")
			while i < lines.size() and lines[i] != "]":
				i += 1
			i += 1
			continue
		if line.begins_with("const RING_BONUS"):
			out.append("const RING_BONUS: Dictionary = {")
			for bid in TUNED_BUILDINGS:
				var rowd: Dictionary = bonus_table[bid]
				var parts: Array[String] = []
				for r in range(1, 6):
					parts.append("%d: %.2f" % [r, float(rowd.get(r, 0.0))])
				out.append('\t&\"%s\": { %s },' % [String(bid), ", ".join(parts)])
			out.append("}")
			while i < lines.size() and lines[i] != "}":
				i += 1
			i += 1
			continue
		out.append(line)
		i += 1
	var w := FileAccess.open(TUNE_FILE, FileAccess.WRITE)
	if w == null:
		push_error("Не удалось открыть %s для записи" % TUNE_FILE)
		return
	w.store_string("\n".join(out))
	w.close()
