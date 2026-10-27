extends BaseTest

## Гард состава экрана кампании по карте элементов макета 10 (`CampaignScreenMap`,
## D-281).
##
## Прежняя сверка экрана была списком узлов `CampaignHud`: экран мог не иметь
## половины макета и оставаться зелёным, потому что список описывал то, что
## уже есть. Теперь знаменатель задан макетом: `COVERAGE n/m`, где `m` — строки
## карты элементов, `n` — строки, у которых есть узел-носитель в живом экране.
##
## Рэтчет, а не уровень (тот же приём, что `scripts/testmap.py` и D-278): падает
## только падение покрытия ниже зафиксированной строки. Ноль скрытых элементов —
## задача групп 2–3 этой смены, а не обещание, висящее красным в `main`.
##
## Гард печатает два списка приёмки: **скрытые элементы** (строка карты без узла
## → задача из реестра) и **вне-макетные носители** (узлы слоя, которых в макете
## нет: `GoalsPanel` D-241, экраны, оверлей обучения). Вне-макетные в знаменатель
## не входят — это наше, а не недокопированное.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const ScreenMap := preload("res://scripts/ui/campaign_screen_map.gd")

## Покрытие на момент ввода гарда (2026-10-28): узлы есть для счётчиков, двух
## кнопок правого верхнего угла, панели отряда, таблички, кнопки хода, даты и
## трёх тайлов полосы (последние три лежат в `TopButtons` текстовыми кнопками).
## Расти должно по группам 2–3 смены; правка числа вниз = падение состава.
const BASELINE_COVERED := 16


var _main: Node = null


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	super.after_test()


func _boot_campaign() -> Node:
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


## Узел-носитель элемента: поиск по имени от корня кампании — узлы экрана лежат
## и в слое `CampaignHud`, и в сцене (`CampaignMapField` появится в `main.tscn`).
func _carrier(main: Node, row: Dictionary) -> Node:
	var node_name := String(row.get("node", ""))
	if node_name == "":
		return null
	return main.find_child(node_name, true, false)


func test_coverage_is_reported_and_does_not_regress() -> void:
	await _boot_campaign()
	var covered: Array[String] = []
	var hidden: Array[String] = []
	for row in ScreenMap.ROWS:
		var id := String(row.get("id", &""))
		if _carrier(_main, row) != null:
			covered.append(id)
		else:
			hidden.append("%s (%s → %s)" % [id, String(row.get("cell", "")),
				String(row.get("ticket", ""))])
	print("COVERAGE %d/%d" % [covered.size(), ScreenMap.ROWS.size()])
	print("HIDDEN (элемент макета без узла-носителя):")
	for line in hidden:
		print("  - " + line)
	print("OFF-MOCKUP (носители экрана, которых нет в макете):  " + ", ".join(_off_mockup()))
	assert_int(covered.size()).is_greater_equal(BASELINE_COVERED)


## Прямые носители слоя, не названные ни одной строкой карты: их обязан видеть
## человек, молча добавлять их в знаменатель нельзя.
func _off_mockup() -> Array[String]:
	var named: Dictionary = {}
	for row in ScreenMap.ROWS:
		named[String(row.get("node", ""))] = true
	var out: Array[String] = []
	for child in (_main.get_node("CampaignHUD/CampaignHud") as Node).get_children():
		var child_name := String(child.name)
		if not named.has(child_name) and child_name != "TopButtons":
			out.append(child_name)
	for child in (_main.find_child("TopButtons", true, false) as Node).get_children():
		if not named.has(String(child.name)):
			out.append(String(child.name))
	return out


## Пустой `node` у строки карты — обещание задачи, а не «так и задумано»: без
## носителя элемент обязан быть зарегистрирован (иначе он исчезает из приёмки).
func test_hidden_elements_are_registered() -> void:
	for row in ScreenMap.ROWS:
		if String(row.get("node", "")) != "":
			continue
		assert_str(String(row.get("ticket", ""))).is_not_empty()
