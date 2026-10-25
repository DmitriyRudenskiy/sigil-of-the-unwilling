# CAPTURE_SETUP для кадра «экран города: каталог построек» (UI-AC7, T-189).
#
# Кадр нужен про ux-review кегля: ниже 16 px в живом кампейне сидели вкладки
# каталога и пять строк каждой карточки постройки (роли, подпись стоимости,
# эффекты, требования, доступность). Проверять это на выдуманной сцене нельзя:
# карточки строит `CityScreen._make_building_card`, и их содержимое зависит от
# каталога и стартового города.
#
# Вход — кнопка «Город» полосы HUD, а не `open_city_screen()` напрямую: кадр
# обязан доказывать, что путь «полоса → экран → каталог» доходит до игрока.
#
# Оверлей первой директивы (T-186) модален и лежит выше слоя HUD (130 против 5):
# его снимают те же два шага, что и в кадре хроники (T-187), — закрыть показанный
# и связать пустым списком директив, иначе в кадре была бы модалка вместо каталога.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var hud: Node = scene.get_node_or_null("CampaignHUD/CampaignHud") as Node
if hud == null:
	return {"ok": false, "reason": "слой CampaignHud не поднят"}
var city_button: Button = hud.get_node_or_null("TopButtons/CityButton") as Button
if city_button == null:
	return {"ok": false, "reason": "кнопки города в полосе нет"}
if city_button.disabled:
	return {"ok": false, "reason": "кнопка города выключена — город не привязан"}
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
city_button.emit_signal("pressed")
var screen: Node = scene.get_node_or_null("CampaignHUD/CampaignHud/CityScreen") as Node
if screen == null:
	return {"ok": false, "reason": "экран города не поднят нажатием"}
# Счётчик тонкого текста здесь не ставится намеренно: и экран, и карточки каталога
# строятся `call_deferred`-ом (`_render_catalog_cards`), то есть внутри одного
# `execute_code` их ещё нет в дереве — счётчик, снятый в этом же блоке, всегда дал
# бы ноль и выглядел как «нарушений нет». Числа снимает гард
# `tests/functional/ui/test_live_font_hygiene.gd` (он ждёт кадры), см. таблицу
# замера в билете T-189.
return {
	"ok": true,
	"open": bool(hud.is_city_screen_open()),
	"tutorial_open": bool(hud.is_tutorial_open()),
}
