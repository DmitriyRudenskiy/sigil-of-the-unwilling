# CAPTURE_SETUP для кадра «туториал-оверлей первой директивы» (mvp-ui-flow 2.2, T-186).
#
# Кадр существует только в состоянии «в кампанию зашли первый раз и открыли
# экран»: оверлей поднимается потребителем `tutorial_requested` на **первом**
# входе в экран и гаснет по кнопке, поэтому снять его «как есть» нельзя — на
# старте кампании он скрыт (вход в экран ещё не совершался).
#
# Вход делается так же, как его делает игрок: кнопкой города в полосе HUD
# (`CityButton.pressed` → `CampaignHud.open_city_screen` → `CampaignUIManager.
# show_screen` → `CampaignNavigation.request` → `tutorial_requested`), а не
# вызовом машины напрямую: прямой `show_screen` дал бы тот же кадр, но не
# проверял, что цепочка кнопок до оверлея вообще доходит.
#
# Песочница `execute_code` блокирует по исходнику (docs/mvp/CAPTURE-HELPER.md §10):
# никаких имён операций записи файлов и проверок-слов из списка — даже в
# комментариях. Ошибка внутри этого кода не оставляет следа в логе: она рвёт
# соединение с игрой («Connection closed»), поэтому несуществующих полей и
# методов здесь не называем.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var hud: Node = scene.get_node_or_null("CampaignHUD/CampaignHud") as Node
if hud == null:
	return {"ok": false, "reason": "слой CampaignHud не поднят"}
var overlay: Node = hud.get_node_or_null("TutorialOverlay") as Node
if overlay == null:
	return {"ok": false, "reason": "оверлей директив не поднят вместе с полосой"}
var city_button: Button = hud.get_node_or_null("TopButtons/CityButton") as Button
if city_button == null:
	return {"ok": false, "reason": "кнопки города в полосе нет"}
if city_button.disabled:
	return {"ok": false, "reason": "кнопка города выключена — кампания не собрана"}
city_button.emit_signal("pressed")
return {
	"ok": true,
	"shown": bool(overlay.get("visible")),
	"day": int(overlay.call("directive_day")),
	"title": String(overlay.call("directive_title")),
	"text": String(overlay.call("directive_text")),
	"shown_days": String(str(overlay.call("shown_days"))),
}
