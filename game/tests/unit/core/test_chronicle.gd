# TASK_18 B2.6: Chronicle — поколения, дублирование, сериализация, шина событий.
extends BaseTest


class BusStub:
	signal chronicle_entry_added(id: StringName, text: String)
	var entries: Array = []
	func _on_added(id: StringName, text: String) -> void:
		entries.append([id, text])


var _ch: Chronicle = null
var _bus: BusStub = null

func before_test() -> void:
	_ch = Chronicle.new()
	_bus = BusStub.new()
	_bus.chronicle_entry_added.connect(_bus._on_added)
	_ch.bus = _bus

func after_test() -> void:
	_ch = null
	_bus = null

func test_append_assigns_generation() -> void:
	_ch.append({"hero_name": "A", "outcome": "x", "glory": 1})
	_ch.append({"hero_name": "B", "outcome": "y", "glory": 2})
	assert_int(_ch.entries.size()).is_equal(2)
	assert_int(_ch.entries[0]["generation"]).is_equal(1)
	assert_int(_ch.entries[1]["generation"]).is_equal(2)

func test_append_duplicates_entry() -> void:
	var src := {"hero_name": "A", "outcome": "x", "glory": 1}
	_ch.append(src)
	src["hero_name"] = "MUTATED"
	assert_that(str(_ch.entries[0]["hero_name"])).is_equal("A")

func test_append_emits_bus_event_with_text() -> void:
	_ch.append({"hero_name": "Герой", "path": "path", "outcome": "вышел", "glory": 7})
	assert_int(_bus.entries.size()).is_equal(1)
	assert_that(str(_bus.entries[0][0])).is_equal("g1")
	assert_that(str(_bus.entries[0][1])).is_equal("Поколение 1: Герой (path) — вышел, слава 7")

func test_to_array_is_deep_copy() -> void:
	_ch.append({"hero_name": "A", "glory": 1})
	var arr := _ch.to_array()
	arr[0]["hero_name"] = "MUTATED"
	assert_that(str(_ch.entries[0]["hero_name"])).is_equal("A")

func test_from_array_filters_non_dicts() -> void:
	_ch.from_array([{"a": 1}, "junk", 42, {"b": 2}])
	assert_int(_ch.entries.size()).is_equal(2)
	assert_that(int(_ch.entries[0]["a"])).is_equal(1)

func test_from_array_clears_previous() -> void:
	_ch.append({"hero_name": "old"})
	_ch.from_array([])
	assert_int(_ch.entries.size()).is_equal(0)

func test_roundtrip_preserves_entries() -> void:
	_ch.append({"hero_name": "A", "glory": 5})
	_ch.append({"hero_name": "B", "glory": 9})
	var other := Chronicle.new()
	other.from_array(_ch.to_array())
	assert_int(other.entries.size()).is_equal(2)
	assert_that(str(other.entries[1]["hero_name"])).is_equal("B")
	assert_int(other.entries[1]["generation"]).is_equal(2)
