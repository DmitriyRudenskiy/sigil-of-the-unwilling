extends SceneTree
## Тест загрузки скриптов + базовая runtime-проверка методов.
##
## Запуск:
##   godot --headless -s tests/debug_load.gd

func _init() -> void:
	print("\n🧪 Script Load Test")
	var scripts = [
		"res://scripts/core/Logger.gd",
		"res://scripts/autoload/Settings.gd",
		"res://scripts/data/ResourceDef.gd",
		"res://scripts/autoload/ResourceRegistry.gd",
		"res://scripts/data/Artifact.gd",
		"res://scripts/ui/components/ItemSlotUI.gd",
		"res://scripts/ui/ArtifactInventoryScreen.gd",
		"res://scripts/world/WorldSpawner.gd",
		"res://scripts/world/ResourceNodeManager.gd",
		"res://scripts/ui/MarkerLayer.gd",
		"res://scripts/world/WorldController.gd",
		"res://scripts/autoload/SocketController.gd",
		"res://scripts/entities/HeroController.gd",
		"res://scripts/ui/InfoPanel.gd",
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
	var hc_script: Script = load("res://scripts/entities/HeroController.gd")
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
