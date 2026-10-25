# CAPTURE_SETUP для кадра «плита Знака в кампейн-HUD» (signs-prestige 2.3).
#
# Кадр нужен про ux-review: титул ранга и число Престижа впервые появились на
# экране, и проверять их по модели бессмысленно — видно ли их в кадре, не
# залезает ли плита на панель отряда и не режет ли их край окна.
#
# Состояние поднимается production-методами: `set_sign` — тот же вызов, что
# делает `main._apply_pending_flow` после выбора Знака в преигре,
# `perform_sign_action` — тот же, что ведёт к начислению Престижа (250 ≥ порога
# второго ранга, «Знаемый»). Функциональный тест (`test_campaign_sign_plaque.gd`)
# поднимает то же состояние — кадр и тест спорят об одном и том же контракте.
#
# Песочница `execute_code` блокирует по исходнику имена операций записи файлов
# и проверки-слова (docs/mvp/CAPTURE-HELPER.md §10); ошибка внутри этого кода
# рвёт соединение с игрой без следа в логе.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var hud: Node = scene.get_node_or_null("CampaignHUD/CampaignHud") as Node
if hud == null:
	return {"ok": false, "reason": "слой CampaignHud не поднят"}
var composition: Object = scene.get("composition")
if composition == null:
	return {"ok": false, "reason": "кампейн-композиция не собрана"}
# Туториал первой директивы модален и лежит выше слоя; в кадре плиты он лишний
# (свой кадр и свой ux-review он получил в T-186).
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
composition.set_sign("spark")
composition.perform_sign_action("forge", 250.0)
# Слой пересчитывается штатным путём хоста: плита (как и панель отряда) живёт на
# `refresh_campaign`, а в игровом пути её делает `main.gd` при поднятии кампейна
# и на каждом ходе. Без этого шага кадр снял бы «плиту до первого хода», то есть
# ровно то состояние, которого в игре не бывает.
var game_manager: Node = scene.get("game_manager")
var day: int = int(game_manager.call("get_current_day")) if game_manager != null else 1
hud.call("refresh_campaign", day)
var plaque: Node = hud.get_node_or_null("SignPlaque") as Node
return {
	"ok": true,
	"plaque_exists": plaque != null,
	"plaque_visible": plaque != null and plaque.visible,
	"sign": str(hud.call("get_sign_text")),
	"rank": str(hud.call("get_sign_rank_text")),
	"prestige": str(hud.call("get_prestige_text")),
	"prestige_model": int(composition.prestige_balance()),
}
