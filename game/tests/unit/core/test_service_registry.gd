extends BaseTest

var registry: RefCounted

func before_test() -> void:
	registry = ServiceRegistry.new()

func after_test() -> void:
	registry = null

func test_register_and_resolve_singleton() -> void:
	var svc := Object.new()
	registry.register_singleton(&"test_svc", svc)
	assert_that(registry.resolve(&"test_svc")).is_equal(svc)

func test_resolve_unknown_returns_null() -> void:
	assert_that(registry.try_resolve(&"nope")).is_null()

func test_empty_key_not_registered() -> void:
	var svc := Object.new()
	registry.register_singleton(&"", svc)
	assert_that(registry.try_resolve(&"")).is_null()

func test_overwrite_singleton() -> void:
	var a := Object.new()
	var b := Object.new()
	registry.register_singleton(&"svc", a)
	registry.register_singleton(&"svc", b)
	assert_that(registry.resolve(&"svc")).is_equal(b)

func test_clear_forgets_singletons() -> void:
	var svc := Object.new()
	registry.register_singleton(&"svc", svc)
	registry.clear()
	assert_that(registry.try_resolve(&"svc")).is_null()

func test_autoload_resolution() -> void:
	var tree := get_tree_for_test()
	if tree == null:
		return
	var fake := Node.new()
	fake.name = "TestFakeAutoload"
	tree.root.add_child(fake)
	registry.register_autoload(&"fake", &"TestFakeAutoload")
	assert_that(registry.resolve(&"fake")).is_equal(fake)
	fake.queue_free()
	await get_tree().process_frame

func get_tree_for_test() -> SceneTree:
	var main_loop := Engine.get_main_loop()
	return main_loop if main_loop is SceneTree else null
