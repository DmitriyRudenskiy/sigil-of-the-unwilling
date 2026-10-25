# CAPTURE_SETUP для кадра «кампанийный HUD с открытыми настройками» (D-238).
#
# Кадр существует только в состоянии «кнопка нажата»: `SettingsScreen` поднимается
# слоем `CampaignHud` и скрыт до нажатия, поэтому снимать сцену «как есть» — значит
# снимать карту, а не настройки.
#
# Песочница `execute_code` блокирует по исходнику (docs/mvp/CAPTURE-HELPER.md §10):
# никаких имён операций записи файлов и `assert` — даже в комментариях.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var hud: Node = scene.get_node_or_null("CampaignHUD/CampaignHud")
if hud == null:
	return {"ok": false, "reason": "слой CampaignHud не поднят"}
var button: Button = hud.get_node_or_null("TopButtons/SettingsButton") as Button
if button == null:
	return {"ok": false, "reason": "кнопки настроек в полосе нет"}
if button.disabled:
	return {"ok": false, "reason": "кнопка настроек выключена — привязка не прошла"}
# Оверлей первой директивы (T-186) модален и лежит выше слоя HUD (130 против 5),
# а открывается он отложенным запросом — уже после execute_code. Поэтому снимаем
# показанный и связываем пустым списком директив: иначе в кадре модалка вместо
# того экрана, который кадр обещает (правило 7b [[CAPTURE-HELPER]], билет T-189).
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
button.emit_signal("pressed")
return {"ok": true, "open": bool(hud.is_settings_screen_open())}
