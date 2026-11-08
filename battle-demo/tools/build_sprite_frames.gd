extends SceneTree
## Собирает `.sprite_frames` из плана `runs/sprite-plan.json` (задача 6.15).
##
## План пишет `scripts/character_kit/build_sprite_frames.py` — с 2026-11-09 он
## живёт в основном проекте, а не в стенде (перенос конвейера кадров): скрипт
## считает пиксели, здесь остаётся только сериализация ресурса. Порядок такой
## именно поэтому: пиксели считает PIL, а ресурс сериализует движок — только
## `ResourceSaver` гарантирует, что `.sprite_frames` останется ссылкой на
## текстуры, а не встроенными пикселями (пиксели в git не идут, D-185).
##
## Запуск (текстуры должны быть импортированы):
##     python3 scripts/character_kit/build_sprite_frames.py --char knight
##     godot --headless --path battle-demo --import
##     godot --headless --path battle-demo --script res://tools/build_sprite_frames.gd

const PLAN := "res://artifacts/sprite-plan.json"


## План пишется носителем конвейера, а не стендом; old адрес остаётся прочитанным,
## пока в стенде лежит план прежнего прогона.
func plan_path() -> String:
	var here := ProjectSettings.globalize_path(PLAN)
	if FileAccess.file_exists(here):
		return here
	return here.get_base_dir().get_base_dir() + "/scripts/character_kit/runs/sprite-plan.json"


func _init() -> void:
	var path := plan_path()
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(plan) != TYPE_DICTIONARY:
		push_error("нет плана сборки: %s (сначала python3 scripts/character_kit/build_sprite_frames.py)" % path)
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
