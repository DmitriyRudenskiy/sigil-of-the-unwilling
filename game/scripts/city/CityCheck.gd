class_name CityCheck
extends RefCounted

var ok := false
var reason := ""
var payload: Dictionary = {}

static func success(p: Dictionary = {}) -> CityCheck:
	var c := CityCheck.new()
	c.ok = true
	c.payload = p
	return c

static func fail(r: String, p: Dictionary = {}) -> CityCheck:
	var c := CityCheck.new()
	c.ok = false
	c.reason = r
	c.payload = p
	return c

func to_dict() -> Dictionary:
	var d := {"ok": ok, "reason": reason}
	for k in payload:
		d[k] = payload[k]
	return d
