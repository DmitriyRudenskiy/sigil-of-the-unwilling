# CAPTURE_SETUP для кадра «панель отряда на кампейн-HUD» (ui-mockup-parity 7.12,
# раунд 7.16/7.17).
#
# Кадр нужен «как его видит игрок»: партия привязывается хостом при поднятии
# кампейна, поэтому состояние наводится не строительством узлов, а снятием
# модалки первой директивы — она лежит выше слоя HUD (130 против 5) и в кадре
# закрывает ровно ту полосу, которую кадр и пришёл показывать (урок T-187).
#
# Песочница `execute_code` блокирует по исходнику (docs/mvp/CAPTURE-HELPER.md §10):
# имён операций записи файлов и проверок-слов здесь нет; ошибок лучше не
# допускать — они рвут соединение с игрой.
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
var panel: Node = hud.get_node_or_null("PartyPanel") as Node
if panel == null:
	return {"ok": false, "reason": "панели отряда нет"}
var row: Node = panel.get_node_or_null("PartySlots") as Node
if row == null:
	return {"ok": false, "reason": "ряда слотов нет"}
var total: int = 0
var occupied: int = 0
var labels: Array = []
for slot in row.get_children():
	var button: Button = slot as Button
	if button == null:
		continue
	total += 1
	if not button.disabled:
		occupied += 1
		labels.append(button.text)
return {
	"ok": true,
	"visible": bool(panel.visible),
	"slots": total,
	"occupied": occupied,
	"labels": ", ".join(PackedStringArray(labels)),
	"rect": str((panel as Control).get_global_rect()),
}
