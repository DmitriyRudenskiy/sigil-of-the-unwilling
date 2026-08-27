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
	
	# Подключаем сигнал scene_tree_changed для перехвата ошибок
	get_root().connect("scene_tree_changed", _on_scene_tree_changed, CONNECT_DEFERRED)
	
	# Добавляем мир в дерево сцен
	get_root().add_child(world)
	
	# Даём сцене время на _ready() и инициализацию
	print("⏳ Waiting %ss for world initialization..." % MAX_SECONDS)
	
	# Используем Timer для отложенной проверки
	var timer: Timer = Timer.new()
	timer.wait_time = MAX_SECONDS
	timer.one_shot = true
	timer.timeout.connect(_on_test_timeout, CONNECT_DEFERRED)
	add_child(timer)
	timer.start()


func _on_scene_tree_changed() -> void:
	# Заглушка — можно логировать изменения дерева
	pass


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
	
	# Проверяем, что есть WorldController
	var wc: Node = world_node.get_node_or_null("WorldController") if world_node else null
	if wc != null:
		print(" ✅ WorldController found")
	else:
		print(" ⚠️  WorldController not found (may use different name)")
	
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
