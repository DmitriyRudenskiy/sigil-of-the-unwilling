extends SceneTree

# Generates game/scenes/ui/ArtifactInventoryScreen.tscn as a pure structural
# skeleton (no theme references). Parent paths use FULL paths from root:
#   root child -> parent=".", deeper -> parent="Parent/Grandparent".

var OUT := "res://scenes/ui/ArtifactInventoryScreen.tscn"

var _ext: Array = []          # [ext_resource] blocks
var _node_lines: Array = []   # [node ...] blocks

# Doll-slot offsets (relative to Right panel origin), from the HTML mockup.
const _DOLL_X := [258, 318, 180, 6, 68, 318, 180, 318, 6, 22, 318, 46, 258, 6, 68, 318]
const _DOLL_Y := [6, 6, 66, 58, 58, 68, 146, 130, 160, 230, 218, 300, 298, 370, 370, 392]

func _ext_resource(res_type: String, path: String, uid: int) -> void:
	var rec := {"type": res_type, "path": path, "id": uid}
	_ext.append(rec)

func _add_node(name: String, typ: String, parent_path: String, extra: String = "", uid: int = 0) -> void:
	var line := "[node name=\"" + name + "\" type=\"" + typ + "\""
	if uid > 0:
		line += " unique_id=" + str(uid)
	if parent_path != "":
		line += " parent=\"" + parent_path + "\""
	line += "]"
	if extra != "":
		line += "\n" + extra
	line += "\n\n"
	_node_lines.append(line)

func _build() -> void:
	# ext resources (script only)
	_ext_resource("Script", "res://scripts/ui/ArtifactInventoryScreen.gd", 1)

	var uid := 1000

	# ---- Root: ArtifactInventoryScreen (Control) ----
	_add_node("ArtifactInventoryScreen", "Control", "", "", uid)
	uid += 1

	# ---- Center (CenterContainer) -- parent "." ----
	_add_node(
		"Center", "CenterContainer", ".",
		"offset_left = 10.0\noffset_top = 10.0\noffset_right = 990.0\noffset_bottom = 690.0\n"
		+ "custom_minimum_size = Vector2(980, 680)\n"
		+ "theme_override_constants/separation = 8\n", uid)
	uid += 1

	# ---- Window (Control) -- parent Center ----
	_add_node(
		"Window", "Control", "Center",
		"anchors_preset = 15\noffset_left = 10.0\noffset_top = 10.0\noffset_right = 970.0\noffset_bottom = 670.0\n", uid)
	uid += 1

	# ---- Outline (PanelContainer) -- parent Center/Window ----
	_add_node("Outline", "PanelContainer", "Center/Window", "", uid)
	uid += 1

	# === LEFT PANEL (portrait, stats, mana/exp/school, skills) ===
	# ---- Left (Control) -- parent Center/Window ----
	_add_node(
		"Left", "Control", "Center/Window",
		"anchors_preset = 15\noffset_left = 10.0\noffset_top = 10.0\noffset_right = 310.0\noffset_bottom = 650.0\n", uid)
	uid += 1

	# ---- Left/Portrait (TextureRect) -- parent Center/Window/Left ----
	_add_node(
		"Portrait", "TextureRect", "Center/Window/Left",
		"offset_left = 11.0\noffset_top = 11.0\noffset_right = 91.0\noffset_bottom = 91.0\nstretch_mode = 5\n", uid)
	uid += 1

	# ---- Left/Name (Label) -- parent Center/Window/Left ----
	_add_node(
		"Name", "Label", "Center/Window/Left",
		"offset_left = 100.0\noffset_top = 31.0\noffset_right = 300.0\noffset_bottom = 60.0\n", uid)
	uid += 1

	# ---- Left/StatIcon_0..3 (TextureRect) -- parent Center/Window/Left ----
	for i in 4:
		_add_node(
			"StatIcon_" + str(i), "TextureRect", "Center/Window/Left",
			"offset_left = " + str(20 + i * 101) + ".0\noffset_top = 95.0\noffset_right = " + str(66 + i * 101) + ".0\noffset_bottom = 141.0\n", uid)
		uid += 1

	# ---- Left/StatName_0..3 (Label) -- parent Center/Window/Left ----
	for i in 4:
		_add_node(
			"StatName_" + str(i), "Label", "Center/Window/Left",
			"offset_left = " + str(20 + i * 101) + ".0\noffset_top = 143.0\noffset_right = " + str(121 + i * 101) + ".0\noffset_bottom = 161.0\n", uid)
		uid += 1

	# ---- Left/StatValue_0..3 (Label) -- parent Center/Window/Left ----
	for i in 4:
		_add_node(
			"StatValue_" + str(i), "Label", "Center/Window/Left",
			"offset_left = " + str(12 + i * 101) + ".0\noffset_top = 168.0\noffset_right = " + str(109 + i * 101) + ".0\noffset_bottom = 189.0\n", uid)
		uid += 1

	# ---- Left/Mana_lbl (Label) -- parent Center/Window/Left ----
	_add_node(
		"Mana_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 191.0\noffset_right = 162.0\noffset_bottom = 211.0\n", uid)
	uid += 1
	# ---- Left/Mana_val (Label) -- parent Center/Window/Left ----
	_add_node(
		"Mana_val", "Label", "Center/Window/Left",
		"offset_left = 204.0\noffset_top = 191.0\noffset_right = 300.0\noffset_bottom = 211.0\n", uid)
	uid += 1
	# ---- Left/Exp_lbl (Label) -- parent Center/Window/Left ----
	_add_node(
		"Exp_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 240.0\noffset_right = 162.0\noffset_bottom = 260.0\n", uid)
	uid += 1
	# ---- Left/Exp_val (Label) -- parent Center/Window/Left ----
	_add_node(
		"Exp_val", "Label", "Center/Window/Left",
		"offset_left = 204.0\noffset_top = 240.0\noffset_right = 300.0\noffset_bottom = 260.0\n", uid)
	uid += 1
	# ---- Left/School_lbl (Label) -- parent Center/Window/Left ----
	_add_node(
		"School_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 289.0\noffset_right = 162.0\noffset_bottom = 309.0\n", uid)
	uid += 1
	# ---- Left/School_val (Label) -- parent Center/Window/Left ----
	_add_node(
		"School_val", "Label", "Center/Window/Left",
		"offset_left = 204.0\noffset_top = 289.0\noffset_right = 300.0\noffset_bottom = 309.0\n", uid)
	uid += 1

	# ---- Left/Skills_lbl (Label) -- parent Center/Window/Left ----
	_add_node(
		"Skills_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 320.0\noffset_right = 132.0\noffset_bottom = 340.0\n", uid)
	uid += 1

	# ---- Left/Skill_0..5 (Button) -- parent Center/Window/Left ----
	for i in 6:
		_add_node(
			"Skill_" + str(i), "Button", "Center/Window/Left",
			"offset_left = " + str(22 + (i % 2) * 190) + ".0\noffset_top = " + str(352 + (i / 2) * 82) + ".0\noffset_right = " + str(142 + (i % 2) * 190) + ".0\noffset_bottom = " + str(422 + (i / 2) * 82) + ".0\n", uid)
		uid += 1

	# === RIGHT PANEL (figure, doll slots, inventory, actions) ===
	# ---- Right (Control) -- parent Center/Window ----
	_add_node(
		"Right", "Control", "Center/Window",
		"anchors_preset = 3\noffset_left = 510.0\noffset_top = 10.0\noffset_right = 950.0\noffset_bottom = 340.0\n", uid)
	uid += 1

	# ---- Right/Figure (TextureRect) -- parent Center/Window/Right ----
	_add_node(
		"Figure", "TextureRect", "Center/Window/Right",
		"offset_left = 607.0\noffset_top = 13.0\noffset_right = 847.0\noffset_bottom = 373.0\nstretch_mode = 5\n", uid)
	uid += 1

	# ---- Right/DollSlot_0..15 (TextureRect) -- parent Center/Window/Right ----
	for i in 16:
		_add_node(
			"DollSlot_" + str(i), "TextureRect", "Center/Window/Right",
			"offset_left = " + str(510 + _DOLL_X[i]) + ".0\noffset_top = " + str(10 + _DOLL_Y[i]) + ".0\noffset_right = " + str(566 + _DOLL_X[i]) + ".0\noffset_bottom = " + str(66 + _DOLL_Y[i]) + ".0\n", uid)
		uid += 1

	# ---- Right/Inventory (HBoxContainer) -- parent Center/Window/Right ----
	_add_node(
		"Inventory", "HBoxContainer", "Center/Window/Right",
		"offset_left = 511.0\noffset_top = 461.0\noffset_right = 938.0\noffset_bottom = 529.0\ntheme_override_constants/separation = 6\n", uid)
	uid += 1
	# ---- Right/Inventory/Prev (Button) -- parent Center/Window/Right/Inventory ----
	_add_node(
		"Prev", "Button", "Center/Window/Right/Inventory",
		"offset_left = 6.0\noffset_top = 9.0\noffset_right = 28.0\noffset_bottom = 65.0\n", uid)
	uid += 1
	# ---- Right/Inventory/Next (Button) -- parent Center/Window/Right/Inventory ----
	_add_node(
		"Next", "Button", "Center/Window/Right/Inventory",
		"offset_left = 375.0\noffset_top = 9.0\noffset_right = 397.0\noffset_bottom = 65.0\n", uid)
	uid += 1
	# ---- Right/Inventory/BackpackSlot_0..5 (TextureRect) -- parent Center/Window/Right/Inventory ----
	for i in 6:
		_add_node(
			"BackpackSlot_" + str(i), "TextureRect", "Center/Window/Right/Inventory",
			"offset_left = " + str(49 + i * 61) + ".0\noffset_top = 9.0\noffset_right = " + str(105 + i * 61) + ".0\noffset_bottom = 65.0\n", uid)
		uid += 1

	# ---- Right/Equip (Button) -- parent Center/Window/Right ----
	_add_node(
		"Equip", "Button", "Center/Window/Right",
		"offset_left = 6.0\noffset_top = 531.0\noffset_right = 64.0\noffset_bottom = 577.0\n", uid)
	uid += 1
	# ---- Right/Remove (Button) -- parent Center/Window/Right ----
	_add_node(
		"Remove", "Button", "Center/Window/Right",
		"offset_left = 184.0\noffset_top = 531.0\noffset_right = 242.0\noffset_bottom = 577.0\n", uid)
	uid += 1
	# ---- Right/Dispose (Button) -- parent Center/Window/Right ----
	_add_node(
		"Dispose", "Button", "Center/Window/Right",
		"offset_left = 362.0\noffset_top = 531.0\noffset_right = 420.0\noffset_bottom = 577.0\n", uid)
	uid += 1

	# === SIDE PANEL (banner, mini, side slots, ok) ===
	# ---- Side (Control) -- parent Center/Window ----
	_add_node(
		"Side", "Control", "Center/Window",
		"anchors_preset = 8\noffset_left = 320.0\noffset_top = 10.0\noffset_right = 500.0\noffset_bottom = 650.0\n", uid)
	uid += 1

	# ---- Side/Banner (TextureRect) -- parent Center/Window/Side ----
	_add_node(
		"Banner", "TextureRect", "Center/Window/Side",
		"offset_left = 329.0\noffset_top = 19.0\noffset_right = 391.0\noffset_bottom = 81.0\nstretch_mode = 5\n", uid)
	uid += 1
	# ---- Side/Mini (TextureRect) -- parent Center/Window/Side ----
	_add_node(
		"Mini", "TextureRect", "Center/Window/Side",
		"offset_left = 329.0\noffset_top = 89.0\noffset_right = 391.0\noffset_bottom = 135.0\nstretch_mode = 5\n", uid)
	uid += 1
	# ---- Side/SideSlot_0..5 (TextureRect) -- parent Center/Window/Side ----
	for i in 6:
		_add_node(
			"SideSlot_" + str(i), "TextureRect", "Center/Window/Side",
			"offset_left = 329.0\noffset_top = " + str(132 + i * 50) + ".0\noffset_right = 391.0\noffset_bottom = " + str(174 + i * 50) + ".0\n", uid)
		uid += 1
	# ---- Side/Ok (Button) -- parent Center/Window/Side ----
	_add_node(
		"Ok", "Button", "Center/Window/Side",
		"offset_left = 329.0\noffset_top = 542.0\noffset_right = 391.0\noffset_bottom = 588.0\n", uid)
	uid += 1

	# === BOTTOM PANEL (army, formations) ===
	# ---- Bottom (PanelContainer) -- parent Center/Window ----
	_add_node(
		"Bottom", "PanelContainer", "Center/Window",
		"anchors_preset = 10\noffset_left = 10.0\noffset_top = 470.0\noffset_right = 950.0\noffset_bottom = 650.0\n", uid)
	uid += 1

	# ---- Bottom/ArmySlot_0..6 (TextureRect) -- parent Center/Window/Bottom ----
	for i in 7:
		_add_node(
			"ArmySlot_" + str(i), "TextureRect", "Center/Window/Bottom",
			"offset_left = " + str(10 + i * 82) + ".0\noffset_top = 10.0\noffset_right = " + str(86 + i * 82) + ".0\noffset_bottom = 86.0\n", uid)
		uid += 1

	# ---- Bottom/Formations (Control) -- parent Center/Window/Bottom ----
	_add_node(
		"Formations", "Control", "Center/Window/Bottom",
		"offset_left = 783.0\noffset_top = 11.0\noffset_right = 916.0\noffset_bottom = 84.0\n", uid)
	uid += 1
	# ---- Bottom/Formations/Form_0..3 (Button) -- parent Center/Window/Bottom/Formations ----
	for i in 4:
		_add_node(
			"Form_" + str(i), "Button", "Center/Window/Bottom/Formations",
			"offset_left = " + str(6 + (i % 2) * 66) + ".0\noffset_top = " + str(6 + (i / 2) * 36) + ".0\noffset_right = " + str(66 + (i % 2) * 66) + ".0\noffset_bottom = " + str(38 + (i / 2) * 36) + ".0\n", uid)
		uid += 1

func _emit() -> void:
	var out := ""
	out += "[gd_scene load_steps=" + str(_ext.size() + 1) + " format=3]\n"
	for e in _ext:
		out += '[ext_resource type="' + e.type + '" path="' + e.path + '" id="' + str(e.id) + '"]\n'
	for l in _node_lines:
		out += l + "\n"
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		print("GEN ERROR: cannot open " + OUT)
		return
	f.store_string(out)
	f.close()
	print("WROTE " + str(_node_lines.size()) + " nodes, " + str(_ext.size()) + " ext_resources -> " + OUT)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_build()
	_emit()
	quit(0)
