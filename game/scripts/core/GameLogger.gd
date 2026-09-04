extends RefCounted
class_name GameLogger
## Structured logging with colored output via print_rich.

const _Platform = preload("res://scripts/core/Platform.gd")
const TAG_WIDTH := 14
const _COLOR_GRAY := "[color=gray]"
const _COLOR_GREEN := "[color=green]"
const _COLOR_YELLOW := "[color=yellow]"
const _COLOR_RED := "[color=red]"
const _RESET := "[/color]"

static func _tag(tag: String) -> String:
	var padded := "[%s]" % tag.rpad(TAG_WIDTH)
	# ponytail: headless terminals render [color=…] literally — drop color
	# markup here so info/warn/error/trace stay clean (finding #11). Single
	# shared point; callers keep print_rich/push_warning/push_error streams.
	if _Platform.is_headless():
		return padded
	return _COLOR_GRAY + padded + _RESET

static func info(msg: String, tag: String = "") -> void:
	print_rich("%s %s" % [_tag(tag), msg])

static func warn(msg: String, tag: String = "") -> void:
	push_warning("%s %s" % [_tag(tag), msg])

static func error(msg: String, tag: String = "") -> void:
	push_error("%s %s" % [_tag(tag), msg])

static func trace(msg: String, tag: String = "") -> void:
	if OS.is_debug_build():
		print_rich("%s %s" % [_tag(tag), msg])

static func battle(msg: String) -> void:
	print_rich("%s [color=cyan]%s[/color]" % [_tag("Battle"), msg])

static func world(msg: String) -> void:
	print_rich("%s %s" % [_tag("World"), msg])

static func inventory(msg: String) -> void:
	print_rich("%s %s" % [_tag("Inventory"), msg])

static func ui(msg: String) -> void:
	print_rich("%s [color=magenta]%s[/color]" % [_tag("UI"), msg])

static func hero(msg: String) -> void:
	print_rich("%s %s" % [_tag("Hero"), msg])
