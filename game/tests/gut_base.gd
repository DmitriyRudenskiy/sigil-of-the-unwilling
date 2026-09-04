extends GutTest
## Общая база всех GUT-тестов: воссоздаёт headless-окружение, которое раньше
## выставлял tests/run_tests.gd (ServiceContainer + layout аудиобусов).
## GUT дёргает before_all() один раз на каждый тест-файл — инстанс
## ServiceContainer свежий на каждый сьюйт (изоляция лучше, чем в старом раннере).

const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")

func before_all() -> void:
	# ServiceContainer для headless-тестов: корневые ноды Units/Resources/…
	# в -s-режиме не существуют — get_node_or_null честно даёт null, как раньше.
	var services := ServiceContainer.new()
	var root := get_tree().root
	services.units = root.get_node_or_null("Units")
	services.resources = root.get_node_or_null("Resources")
	services.spells = root.get_node_or_null("Spells")
	services.artifacts = root.get_node_or_null("Artifacts")
	services.spellbook = root.get_node_or_null("Spellbook")
	ServiceContainer.setup_global(services)

	# Godot 4.7 -s-режим сбрасывает layout AudioServer до дефолта (только Master)
	# после инициализации дерева — пере-применяем layout из audio/buses
	# (иначе test_audio видит только Master).
	if AudioServer.get_bus_index("SFX") == -1:
		var layout_path := String(ProjectSettings.get_setting("audio/buses", ""))
		if layout_path != "":
			var layout = load(layout_path) as AudioBusLayout
			if layout != null:
				AudioServer.set_bus_layout(layout)


# ============== Compat-шимы старого test_base API ==============

## Старый assert_approx(a, b, eps, msg) — в GUT 9 это assert_almost_eq.
func assert_approx(a: Variant, b: Variant, eps: float = 0.0001, msg: String = "") -> void:
	assert_almost_eq(a, b, eps, msg)

## Старый check(name, cond, detail) — локальный хелпер SceneTree-раннера.
func check(name: String, condition: bool, detail: String = "") -> void:
	assert_true(condition, name + (" — " + detail if detail != "" else ""))

## Старый assert_not_empty(val, msg) — в GUT 9 нет встроенного.
func assert_not_empty(val: Variant, msg: String = "") -> void:
	var empty := false
	if val is Array:
		empty = (val as Array).is_empty()
	elif val is Dictionary:
		empty = (val as Dictionary).is_empty()
	elif val is String:
		empty = (val as String).is_empty()
	assert_false(empty, msg if msg != "" else "expected not empty, got: %s" % str(val))
