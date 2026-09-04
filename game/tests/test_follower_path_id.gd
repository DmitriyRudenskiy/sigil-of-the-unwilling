extends "res://tests/gut_base.gd"
## succession-sigil: PopUnit.path_id round-trips через serialize/deserialize.
## path_id — источник истины для наследования (наследник того же пути).

const _PopUnit = preload("res://scripts/world/PopUnit.gd")

func test_popunit_path_id_roundtrip() -> void:
	var u: _PopUnit = _PopUnit.new()
	u.uid = 7
	u.path_id = &"archivist"

	var d: Dictionary = u.serialize()
	assert_true(d.has("path_id"), "serialize() includes path_id")
	assert_eq(d.get("path_id"), "archivist", "path_id serialized as string")

	var back: _PopUnit = _PopUnit.deserialize(d)
	assert_eq(back.path_id, &"archivist", "path_id round-trips through serialize/deserialize")
	assert_eq(back.uid, 7, "uid preserved alongside path_id")


func test_popunit_path_id_default_empty() -> void:
	var u: _PopUnit = _PopUnit.new()
	var d: Dictionary = u.serialize()
	assert_eq(d.get("path_id", ""), "", "default path_id serializes as empty string")

	var back: _PopUnit = _PopUnit.deserialize(d)
	assert_true(back.path_id.is_empty(), "default path_id deserializes empty")


func test_popunit_path_id_missing_key_stays_default() -> void:
	## Старый сэйв (v3) без path_id: десериализация не падает, остаётся дефолт.
	var back: _PopUnit = _PopUnit.deserialize({"uid": 3, "state": 1})
	assert_true(back.path_id.is_empty(), "missing path_id → default empty, no crash")
