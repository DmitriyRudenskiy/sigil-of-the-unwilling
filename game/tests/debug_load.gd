extends SceneTree
## Тест загрузки скриптов + базовая runtime-проверка методов.
##
## Запуск:
##   godot --headless -s tests/debug_load.gd

func _init() -> void:
	print("\n🧪 Script Load Test")
	var scripts = [
		"res://core/Logger.gd",
		"res://core/Settings.gd",
		"res://data/ResourceDef.gd",
		"res://data/ResourceRegistry.gd",
		"res://data/Artifact.gd",
		"res://ui/components/ItemSlotUI.gd",
		"res://ui/ArtifactInventoryScreen.gd",
		"res://world/WorldSpawner.gd",
		"res://world/ResourceNodeManager.gd",
		"res://ui/MarkerLayer.gd",
		"res://world/WorldController.gd",
		"res://core/SocketController.gd",
		"res://entities/HeroController.gd",
		"res://ui/InfoPanel.gd",
	]
	
	var errors: int = 0
	for s in scripts:
		print("Loading %s..." % s)
		var res = load(s)
		if res == null:
			print("❌ Failed to load %s" % s)
			errors += 1
		else:
			print("✅ Successfully loaded %s" % s)
	
	# === Runtime-проверки ключевых методов ===
	print("\n🔍 Runtime method checks...")
	
	# HeroController.get_avatar_texture() — проверка через Callable
	var hc_script: Script = load("res://entities/HeroController.gd")
	if hc_script != null:
		# Проверяем через скрипт-класс (get_script_method_list)
		var method_found: bool = false
		var script_methods: Array = hc_script.get_script_method_list()
		for method_info: Dictionary in script_methods:
			if method_info.get("name") == "get_avatar_texture":
				method_found = true
				break
		if method_found:
			print("✅ HeroController.get_avatar_texture() exists")
		else:
			print("❌ HeroController.get_avatar_texture() MISSING")
			errors += 1
	else:
		print("⚠️  HeroController.gd not loaded, skipping runtime checks")
	
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	if errors == 0:
		print("✅ All checks passed")
	else:
		print("❌ %d error(s) found" % errors)
	
	quit()
