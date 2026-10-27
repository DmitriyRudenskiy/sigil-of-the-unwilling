# CAPTURE_SETUP для кадра «экран партии открыт из кампейн-HUD» (mvp-ui-flow 5.4,
# аудит достижимости 8 экранов K-M8).
#
# Кадр существует только в состоянии «кнопка нажата»: `PartyScreen` создаётся слоем
# `CampaignHud` по первому нажатию и скрыт до него, поэтому снимать сцену «как есть»
# — значит снимать карту, а не экран партии.
#
# Песочница `execute_code` блокирует по исходнику (docs/mvp/CAPTURE-HELPER.md §10):
# никаких имён операций записи файлов и проверок-слов из списка — даже в комментариях.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var hud: Node = scene.get_node_or_null("CampaignHUD/CampaignHud") as Node
if hud == null:
	return {"ok": false, "reason": "слой CampaignHud не поднят"}
var button: Button = hud.get_node_or_null("TopButtons/PartyButton") as Button
if button == null:
	return {"ok": false, "reason": "кнопки партии в полосе нет"}
if button.disabled:
	return {"ok": false, "reason": "кнопка партии выключена — привязка не прошла"}
# Оверлей первой директивы модален и лежит выше слоя HUD, поэтому снимаем показанный
# и связываем пустым списком директив (правило 7b [[CAPTURE-HELPER]], T-189).
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
button.emit_signal("pressed")
var screen: Node = scene.get_node_or_null("CampaignHUD/CampaignHud/PartyScreen") as Node
if screen == null:
	return {"ok": false, "reason": "экран партии не поднят нажатием"}
return {"ok": true, "visible": screen.visible}
