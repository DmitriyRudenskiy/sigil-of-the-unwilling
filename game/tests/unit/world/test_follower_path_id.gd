extends BaseTest


func test_popunit_path_id_roundtrip() -> void:
	var u: PopUnit = PopUnit.new()
	u.uid = 7
	u.path_id = &"archivist"

	var d: Dictionary = u.serialize()
	assert_bool(d.has("path_id")).is_true()
	assert_that(d.get("path_id")).is_equal("archivist")

	var back: PopUnit = PopUnit.deserialize(d)
	assert_that(back.path_id).is_equal(&"archivist")
	assert_that(back.uid).is_equal(7)

func test_popunit_path_id_default_empty() -> void:
	var u: PopUnit = PopUnit.new()
	var d: Dictionary = u.serialize()
	assert_that(d.get("path_id", "")).is_equal("")

	var back: PopUnit = PopUnit.deserialize(d)
	assert_bool(back.path_id.is_empty()).is_true()

func test_popunit_path_id_missing_key_stays_default() -> void:
	var back: PopUnit = PopUnit.deserialize({"uid": 3, "state": 1})
	assert_bool(back.path_id.is_empty()).is_true()
