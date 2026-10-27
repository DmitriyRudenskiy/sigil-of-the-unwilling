extends BaseTest

# Хотфикс «forgeable icons» (docs/15 §5): 6 кузнечных id достижимы forge() ещё до
# сета 29 — файл иконки обязан существовать и быть непустым, иначе инвентарь
# (artifacts/%s.png) отдаёт пустую текстуру. С 2026-10-29 носители рисует контур
# `scripts/concept_art/hero_screen_spec.json` (128×128 с альфой), поэтому размер
# проверяется как «не меньше клетки и квадратная», а не как ровно 64 — ровно 64
# было свойством плоской заглушки.
const _ICON_MIN := 64      # клетка сумки ~76 px, носитель обязан её покрывать
const _FORGEABLE_IDS: Array[String] = [
	"club", "stone_axe", "iron_sword", "steel_longsword", "runic_blade", "rune_sword",
]


func test_forgeable_ids_have_non_empty_icons() -> void:
	for id: String in _FORGEABLE_IDS:
		var path := "res://assets/artifacts/%s.png" % id
		assert_bool(ResourceLoader.exists(path)).is_true().override_failure_message(
			"forge даёт id `%s`, а файла иконки нет (%s) — пустая текстура в инвентаре" % [id, path]
		)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		assert_int(tex.get_width()).is_greater_equal(_ICON_MIN)
		assert_int(tex.get_height()).is_equal(tex.get_width()).override_failure_message(
			"иконка `%s` не квадратная — TextureRect растянет рисунок" % id
		)
		var used: Rect2i = tex.get_image().get_used_rect()
		assert_bool(used.has_area()).is_true().override_failure_message(
			"иконка `%s` загружается, но пуста (used_rect пуст)" % id
		)
