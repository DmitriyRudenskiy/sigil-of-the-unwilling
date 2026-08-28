extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("NOARG"); quit(1); return
	var file_path: String = args[0]
	var script: GDScript = load(file_path)
	var inst: SceneTree = script.new()
	var prev: int = 0
	for m in script.get_script_method_list():
		var mn: String = String(m["name"])
		if not mn.begins_with("test_"):
			continue
		if inst.has_method("before_each"):
			inst.call("before_each")
		inst.call(mn)
		var now: int = int(inst.get("_failed"))
		if now > prev:
			print("FAIL IN: ", mn, " (+", now - prev, ")")
		prev = now
	print("DONE failed=", prev, " passed=", int(inst.get("_passed")))
	quit(0)
