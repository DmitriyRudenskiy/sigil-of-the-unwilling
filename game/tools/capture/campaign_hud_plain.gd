# CAPTURE_SETUP для кадра «чистый кампейн-HUD» (D-281 3.9).
#
# Кадр нужен ux-review нижней полосы: блок за блоком сверяются места, состав и
# пустые слоты макета 10. Мешает только модалка первой директивы — она лежит
# выше слоя HUD (130 против 5) и закрывает ровно ту полосу, которую кадр пришёл
# показывать (урок T-187). Всё остальное — как его видит игрок: партию и
# остальное состояние поднимает хост кампейна.
#
# Песочница `execute_code` блокирует по исходнику (docs/mvp/CAPTURE-HELPER.md §10):
# имён операций записи файлов и проверок-слов здесь нет.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var hud: Node = scene.get_node_or_null("CampaignHUD/CampaignHud") as Node
if hud == null:
	return {"ok": false, "reason": "слой CampaignHud не поднят"}
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
return {"ok": true, "blocks": int(hud.get_counter_count())}
