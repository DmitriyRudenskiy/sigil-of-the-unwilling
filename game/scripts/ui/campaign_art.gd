class_name CampaignArt
extends RefCounted
## Атлас носителей экрана «Карта» — единственный способ достать кадр кита
## `assets/ui/campaign_screen/` и надеть его на узел экрана (T-280, D-281 4.4).
##
## Экран не знает ни путей, ни полей нарезки: путь, `kind` и `margin` читаются из
## `MANIFEST.json` — атласа экрана (4.3), того же носителя, что читает
## `scripts/check_ui_assets.py`. Узел не может сослаться на кадр, которого в
## атласе нет, и не может разойтись с его полем 9-slice (прецедент поля из
## реестра — `gen_inventory_scene._kit_margin`, D-275). Строка `art` реестра
## `CampaignScreenMap` и есть id кадра здесь: экран надевает носители строкой
## реестра, а не списком, переписанным руками.

const ATLAS_DIR := "res://assets/ui/campaign_screen/"
const MANIFEST_PATH := ATLAS_DIR + "MANIFEST.json"
## Имя узла-носителя, повешенного на хост: по нему гард кадра собирает, чем
## экран закрыт из атласа.
const ART_NODE := "Art"
const PLATE := "9-slice"
## Узлы, у которых есть собственный фон: они получают плиту вариантом темы,
## а не ребёнком (ребёнок лёг бы под собственную плашку хоста и был бы не виден,
## а `add_theme_stylebox_override` сделал бы узел недосягаемым для кита — T-147,
## гард `test_no_script_level_stylebox_overrides_outside_allowlist`).
const STYLEBOX_HOSTS := ["Button", "Panel", "PanelContainer"]

static var _entries: Dictionary = {}
static var _textures: Dictionary = {}


## Кадр атласа → {path, kind, margin, mount}. Пустой словарь — атлас не читается
## (ошибка уже сообщена), и экран остаётся работоспособным без рисунка.
static func entries() -> Dictionary:
	if not _entries.is_empty():
		return _entries
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("CampaignArt: нет атласа %s" % MANIFEST_PATH)
		return _entries
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (raw is Dictionary) or not (raw as Dictionary).has("files"):
		push_error("CampaignArt: %s не читается как атлас" % MANIFEST_PATH)
		return _entries
	var files: Dictionary = (raw as Dictionary).get("files", {})
	for path in files:
		var entry: Dictionary = files[path]
		var id := String(path).get_file().get_basename()
		_entries[StringName(id)] = {
			"path": ATLAS_DIR + id + ".png",
			"kind": String(entry.get("kind", "")),
			"margin": int(entry.get("margin", 0)),
			"mount": String(entry.get("mount", "")),
		}
	return _entries


static func ids() -> Array:
	return entries().keys()


static func has(id: StringName) -> bool:
	return id != &"" and entries().has(id)


static func is_plate(id: StringName) -> bool:
	return String(entries().get(id, {}).get("kind", "")) == PLATE


static func margin(id: StringName) -> int:
	return int(entries().get(id, {}).get("margin", 0))


static func path_of(id: StringName) -> String:
	return String(entries().get(id, {}).get("path", ""))


static func texture(id: StringName) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var path := path_of(id)
	if path == "" or not ResourceLoader.exists(path):
		push_error("CampaignArt: в атласе нет кадра %s" % id)
		return null
	_textures[id] = load(path) as Texture2D
	return _textures[id]


## Носитель на узле. Способ выбирает тип узла, а не вызывающий: узел с собственным
## фоном (`Button`, `Panel`, `PanelContainer`) получает плиту вариантом темы —
## ролью узла с дописанным именем кадра (`ButtonAction_plate_slot` в
## `game_theme.tres`, объявлен над ролью), поэтому скриптовых override'ов в экране
## нет; знак (`button_book`, кольцо медальона) кнопка держит иконкой; узел без
## своего рисунка получает ребёнка-носитель под содержимым.
static func mount(host: Control, id: StringName) -> void:
	if not has(id):
		push_error("CampaignArt: неатласный носитель «%s»" % id)
		return
	var button := host as Button
	if button != null and not _is_backing(host, id):
		button.icon = texture(id)
		button.expand_icon = true
		# Знак кнопки — сам круглый носитель (кадр включает поле и кант), поэтому
		# фон роли обязан уйти: `ButtonAction` несёт кирпичную плитку T-147, и за
		# круглой кнопкой она торчит квадратом (кадр T-280). `flat` — штатный
		# движковый способ: normal не рисуется, hover/pressed остаются.
		button.flat = true
		return
	if host.get_class() in STYLEBOX_HOSTS:
		# Имя варианта = роль + кадр; отсутствие варианта в теме дало бы фон базового
		# типа, и гард кадра (`test_campaign_screen_frame_composition`) не нашёл бы
		# там текстуры атласа — то есть промах по теме падает, а не молчит.
		host.theme_type_variation = &"%s_%s" % [host.theme_type_variation, id]
	elif host.get_node_or_null(ART_NODE) == null:
		var art := _carrier(id)
		art.name = ART_NODE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Носитель — под тем, что рисует сам хост (кольцо медальона, поле карты).
		art.show_behind_parent = true
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(art)


## Носитель, стоящий по своей строке реестра поверх прочего: чипы плашки имени,
## шестерня даты, плита столбца тайлов. Это фон группы, а не содержимое узла,
## поэтому узел живёт у общего хоста и ставится вызывающим по своей клетке.
static func overlay(parent: Control, id: StringName) -> Control:
	var art := _carrier(id)
	art.name = "%s_%s" % [ART_NODE, id]
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art


## Кадр, который надевается ПОД узел, а не рядом с подписью: плита 9-slice и
## диск кнопки (`mount: "stylebox"` в атласе) — фон, всё остальное — знак.
static func _is_backing(host: Control, id: StringName) -> bool:
	if is_plate(id):
		return true
	return String(entries()[id].get("mount", "")) == "stylebox" and host is Button


static func _carrier(id: StringName) -> Control:
	if is_plate(id):
		var patch := NinePatchRect.new()
		patch.texture = texture(id)
		var m := margin(id)
		patch.patch_margin_left = m
		patch.patch_margin_top = m
		patch.patch_margin_right = m
		patch.patch_margin_bottom = m
		# Растяжение, а не тайлинг, — оно же дефолт `axis_stretch_*`: плита в
		# макете одна, тайлинг дал бы швы (тот же приём, что `NinePatchRect`
		# листа «Герой», D-275).
		return patch
	var rect := TextureRect.new()
	rect.texture = texture(id)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect
