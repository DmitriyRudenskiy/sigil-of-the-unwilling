extends SceneTree
## Собирает `.sprite_frames` из плана `artifacts/sprite-plan.json` (задача 6.15).
##
## План пишет `tools/build_sprite_frames.py` (он же приводит кадры к общему
## pivot). Порядок такой именно поэтому: пиксели считает PIL, а ресурс сериализует
## движок — только `ResourceSaver` гарантирует, что `.sprite_frames` останется
## ссылкой на текстуры, а не встроенными пикселями (пиксели в git не идут, D-185).
##
## Запуск (текстуры должны быть импортированы):
##     godot --headless --path battle-demo --import
##     godot --headless --path battle-demo --script res://tools/build_sprite_frames.gd

const PLAN := "res://artifacts/sprite-plan.json"


func _init() -> void:
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	if typeof(plan) != TYPE_DICTIONARY:
		push_error("нет плана сборки: %s (сначала tools/build_sprite_frames.py)" % PLAN)
		quit(1)
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var missing := 0
	for animation: Dictionary in plan["animations"]:
		var name: StringName = StringName(animation["name"])
		frames.add_animation(name)
		frames.set_animation_loop(name, animation["loop"])
		frames.set_animation_speed(name, float(animation["fps"]))
		for path: String in animation["frames"]:
			var texture: Texture2D = load(path)
			if texture == null:
				push_error("текстура не найдена (нужен --import): %s" % path)
				missing += 1
				continue
			frames.add_frame(name, texture)
	if missing:
		push_error("кадров без текстуры: %d — ресурс не пишется" % missing)
		quit(1)
		return
	var error := ResourceSaver.save(frames, plan["out"])
	print("sprite_frames: %s → %s" % [plan["out"], error_string(error)])
	quit(0 if error == OK else 1)
