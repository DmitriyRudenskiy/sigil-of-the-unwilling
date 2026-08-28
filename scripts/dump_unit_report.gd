extends SceneTree
## Выдаёт сводку по всем юнитам: имя, ATK, DEF, HP, SPD, теги.

func _init() -> void:
	Units.ensure_definitions()

	var lines: Array[String] = []
	lines.append("UNIT REFERENCE")
	lines.append("")
	lines.append("%-22s %4s %4s %4s %4s  %s" % ["NAME", "ATK", "DMG", "HP", "SPD", "TAGS"])
	lines.append("-".repeat(74))

	var all_tags: Dictionary = {}

	for key in Units.get_all_keys():
		var stack := Units.make_fixed_stack(key, 10)
		var s: UnitStats = stack.stats
		var tags_str: String = ", ".join(s.tags) if s.tags.size() > 0 else "-"
		lines.append("%-22s %4d %4d %4d %4d  %s" % [
			s.display_name, s.attack, s.base_damage, s.hp, s.speed, tags_str
		])
		for tag in s.tags:
			all_tags[tag] = true

	lines.append("")
	lines.append("ALL TAGS: %s" % ", ".join(all_tags.keys()))
	lines.append("")
	lines.append("TOTAL: %d units" % Units.get_all_keys().size())

	var text: String = "\n".join(lines)
	print(text)

	var file := FileAccess.open("res://UNIT_REPORT.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

	quit(0)
