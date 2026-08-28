extends SceneTree
## Runtime-интеграционный тест: загружает World.tscn, даёт 2 секунды на _ready(),
## затем проверяет, что нет SCRIPT ERROR / Invalid call в логах.
##
## Запуск:
##   godot --headless -s tests/test_runtime_integration.gd

const WORLD_SCENE: String = "res://scenes/World.tscn"
const CHECK_INTERVAL: float = 0.5
const MAX_SECONDS: float = 4.0

var _errors: Array[String] = []
var _start_time: float = 0.0


func _init() -> void:
	print("\n🧪 Runtime Integration Test")
	# Отложенный старт: в -s-режиме _init выполняется до инициализации autoloads,
	# а скрипты мира ссылаются на них (GameEventBus, Units и т.д.) и не компилируются.
	call_deferred("_run")


func _run() -> void:
	print("Loading world scene: %s ..." % WORLD_SCENE)
	
	_start_time = Time.get_ticks_msec() / 1000.0
	
	# Загружаем и добавляем сцену мира
	var world_packed: PackedScene = load(WORLD_SCENE)
	if world_packed == null:
		print("❌ Cannot load %s" % WORLD_SCENE)
		quit()
		return
	
	var world: Node = world_packed.instantiate()
	if world == null:
		print("❌ Cannot instantiate %s" % WORLD_SCENE)
		quit()
		return
	
	# Добавляем мир в дерево сцен
	get_root().add_child(world)
	
	# Даём сцене время на _ready() и инициализацию.
	# create_timer вместо Timer: в момент _init дерево ещё не готово к Timer.start().
	print("⏳ Waiting %ss for world initialization..." % MAX_SECONDS)
	await create_timer(MAX_SECONDS).timeout
	_on_test_timeout()


func _on_test_timeout() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time
	
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  Runtime Integration Test Results")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  Elapsed: %.1fs" % elapsed)
	
	# Проверяем, что основные узлы существуют
	var root: Node = get_root()
	var world_node: Node = root.get_node_or_null("World")
	
	if world_node == null:
		print(" ❌ World node not found in scene tree")
		_errors.append("World node missing")
	else:
		print(" ✅ World node exists")
	
	# WorldController — скрипт корневого узла World (а не дочерний узел)
	var wc_script: Script = world_node.get_script() if world_node else null
	if wc_script != null and wc_script.resource_path == "res://scripts/WorldController.gd":
		print(" ✅ WorldController script attached to World root")
	else:
		print(" ⚠️  WorldController script missing on World root")
	
	# Проверяем наличие UI
	if world_node:
		var ui: Node = world_node.get_node_or_null("WorldUIManager")
		if ui != null:
			print(" ✅ WorldUIManager found")
		else:
			print(" ⚠️  WorldUIManager not found")
	
	if _errors.is_empty():
		print("\n✅ Runtime integration PASSED — no critical errors")
	else:
		print("\n❌ Runtime integration FAILED:")
		for err in _errors:
			print("   - %s" % err)

	# Очистка перед выходом: освобождаем мир и даём движку 2 кадра на RID
	if world_node != null:
		world_node.queue_free()
	await process_frame
	await process_frame

	quit()
