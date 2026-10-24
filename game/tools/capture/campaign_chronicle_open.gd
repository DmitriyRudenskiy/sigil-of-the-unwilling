# CAPTURE_SETUP для кадра «кампанийная хроника открыта» (D-240, T-175).
#
# Кадр существует только в состоянии «кнопка нажата, ходы отыграны»: лента —
# `ChronicleLog`, которую пишут носители хода (бит 1, волна, рейд, рождение
# района), а экран поднимается слоем `CampaignHud` и скрыт до нажатия. Снимать
# сцену «как есть» — значит снимать карту с пустым экраном поверх.
#
# Ходы делаются так же, как их делает игрок: кнопкой хода (`turn_requested` →
# `main._advance_day`), а не вызовом `composition.advance_turn()`. Разница
# измерена первым прогоном кадра: прямой вызов минует `GameManager.on_day_passed`
# и счётчик даты в HUD, и на кадре лента уезжала на 11-й ход при подписи «День 1».
# Кризис модален и ход стоит — на этом цикл останавливается, а не идёт дальше.
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
# `Object`, а не `Node`: кампейн-композиция — `RefCounted`, и каст к `Node`
# отсек бы её как null (первый прогон кадра отсюда и не поднялся).
var composition: Object = scene.get("composition")
if composition == null:
	return {"ok": false, "reason": "кампейн-композиция не собрана"}
var turn_button: Button = hud.get_node_or_null("TopButtons/TurnButton") as Button
if turn_button == null:
	return {"ok": false, "reason": "кнопки хода в полосе нет"}
var chronicle_button: Button = hud.get_node_or_null("TopButtons/ChronicleButton") as Button
if chronicle_button == null:
	return {"ok": false, "reason": "кнопки хроники в полосе нет"}
if chronicle_button.disabled:
	return {"ok": false, "reason": "кнопка хроники выключена — привязка ленты не прошла"}
# 14-й день — дата рождения района (`raids.json`); к этому моменту в ленте уже
# и бит 1, и предупреждение о волне, и строки первого рейда.
var guard: int = 0
var blocked: String = ""
while int(composition.campaign.current_turn) < 14 and guard < 40:
	guard += 1
	if bool(composition.campaign.is_done()):
		blocked = "game_over"
		break
	# Ход стоит (открытый экран, кризис) — значит игрок бы дальше не пошёл.
	if turn_button.disabled:
		blocked = "turn_locked"
		break
	turn_button.emit_signal("pressed")
chronicle_button.emit_signal("pressed")
return {
	"ok": true,
	"turn": int(composition.campaign.current_turn),
	"records": int(composition.chronicle.records().size()),
	"open": bool(hud.is_chronicle_screen_open()),
	"stop": blocked,
}
