extends BaseTest

## T-280 — экран «Карта» надевает атлас носителей, а не ссылается на него
## словами (D-281 4.4): гард спрашивает у живого экрана, **чем** закрыта каждая
## строка реестра, и сверяет с id кадра из этой строки.
##
## Проверяется резолв темы, а не намерение: `get_theme_stylebox` возвращает то,
## что нарисует движок, то есть вариант темы `<Роль>_<кадр>` из
## `assets/theme/game_theme.tres`. Если варианта в теме нет, резолв уходит на
## базовый тип, гард падает, а не молчит — та же цена, что у
## `test_no_script_level_stylebox_overrides_outside_allowlist`, запретившего
## экрану латать тему override'ом (T-147).
##
## Второй тест держит целость атласа: кадр, который экран не надел, обязан быть
## перечислен в `NOT_WORN` с задачей. Молча лежащий в папке рисунок — тот же
## дефект, что носитель под gitignored-маской (T-262).

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const ScreenMap := preload("res://scripts/ui/campaign_screen_map.gd")
const CampaignArt := preload("res://scripts/ui/campaign_art.gd")

## Кадры атласа, у которых в экране ещё нет хозяина: кадр → задача, которая его
## наденет. Пустой словарь = атлас надет целиком.
## Иконки счётчиков, которые кампейн не ведёт (`CampaignCounters.has_carrier` —
## ложь): узел не строится, а значит и кадр надеть не на что (спека
## `campaign-hud`: ноль вместо «носителя нет» врал бы).
const NOT_WORN := {
	"icon_drop_red": "T-159",
	"icon_gem_green": "T-159",
	"icon_gold": "T-159",
}

const SLOTS := ["panel", "normal"]

var _main: Node = null


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	super.after_test()


func _boot_campaign() -> void:
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame


func _root() -> Node:
	return Engine.get_main_loop().root


## Каждая строка реестра с кадром атласа обязана быть этим кадром закрыта.
## Строки с чужим носителем (`IconRegistry` — реестр иконок города) и строки без
## носителя здесь не проверяются: у них другой источник рисунка.
func test_every_atlas_row_wears_its_frame() -> void:
	await _boot_campaign()
	var missing: Array[String] = []
	for row in ScreenMap.ROWS:
		var art := row.get("art", &"") as StringName
		if not CampaignArt.has(art):
			continue
		var node_name := String(row.get("node", ""))
		if node_name == "":
			# Строка без узла (чипы плашки, шестерня даты, знак героя): её несёт
			# тот, кто строит свой блок, а целость атласа сторожит второй тест.
			continue
		var node := _main.find_child(node_name, true, false) as Control
		if node == null:
			# Узла нет — элемент ещё не построен или скрыт по значению. Это
			# провал не состава, а покрытия: его ловит
			# `test_frame_composition_coverage_is_complete`.
			continue
		if not _wears(node, art):
			missing.append("%s: «%s» не надел кадр «%s»" % [
				row.get("id"), node.name, art])
	assert_str(", ".join(missing)).is_empty()


## Целость атласа: каждый выпущенный кадр либо лежит под экраном, либо
## перечислен с задачей.
func test_atlas_is_worn_or_listed() -> void:
	await _boot_campaign()
	var worn := {}
	_collect(_main, worn)
	var unused: Array[String] = []
	for id in CampaignArt.ids():
		if not worn.has(String(id)) and not NOT_WORN.has(String(id)):
			unused.append(String(id))
	assert_str(", ".join(unused)).is_empty()


## Чем узел закрыт кадром: своим фоном (stylebox темы с вариантом), иконкой
## кнопки или ребёнком-носителем (`CampaignArt.mount` / `overlay`). Строка
## реестра может называть чистый контейнер (`PartySlots`) — его несёт содержимое,
## поэтому дети смотрятся тоже: плита слота лежит на кнопке слота, а не на полосе.
func _wears(node: Control, id: StringName) -> bool:
	var want := String(CampaignArt.path_of(id))
	if _covers(node, want):
		return true
	for child in node.get_children():
		if _covers(child, want):
			return true
	return false


func _covers(node: Node, want: String) -> bool:
	var control := node as Control
	if control == null:
		return false
	for slot in SLOTS:
		var box := control.get_theme_stylebox(slot)
		if box is StyleBoxTexture and _is((box as StyleBoxTexture).texture, want):
			return true
	var button := control as Button
	if button != null and _is(button.icon, want):
		return true
	return _carrier_is(control, want)


func _collect(node: Node, worn: Dictionary) -> void:
	for child in node.get_children():
		var control := child as Control
		if control != null:
			for slot in SLOTS:
				var box := control.get_theme_stylebox(slot)
				if box is StyleBoxTexture:
					var tid := _tex_id((box as StyleBoxTexture).texture)
					if tid != "":
						worn[tid] = String(control.name)
			var icon_id := _tex_id((control as Button).icon) if control is Button else ""
			if icon_id != "":
				worn[icon_id] = String(control.name)
		var carrier := _carrier_id(child)
		if carrier != "":
			worn[carrier] = String(child.name)
		_collect(child, worn)


func _carrier_is(node: Node, want: String) -> bool:
	return _carrier_id(node) != "" and _is(_carrier_texture(node), want)


func _carrier_id(node: Node) -> String:
	if not (node is TextureRect) and not (node is NinePatchRect):
		return ""
	return _tex_id(_carrier_texture(node))


func _carrier_texture(node: Node) -> Texture2D:
	if node is NinePatchRect:
		return (node as NinePatchRect).texture
	return (node as TextureRect).texture


func _is(tex: Texture2D, want: String) -> bool:
	return tex != null and String(tex.resource_path) == want


## Кадр атласа по текстуре; чужая текстура (иконка города, юнит) — пустая строка.
func _tex_id(tex: Texture2D) -> String:
	if tex == null:
		return ""
	var path := String(tex.resource_path)
	if not path.begins_with("res://assets/ui/campaign_screen/"):
		return ""
	return path.get_file().get_basename()
