# CAPTURE_SETUP для кадра «хроника после первого рейда» (vertical-slice 2.1, остаток).
#
# Кадр закрывает ux-review строки угрозы: смысл задачи — «угрозовые строки видны
# игроку», а проверяется он на живом кадре, а не на словаре отчёта угроз. Состояние
# поднимается ходом: семь нажатий кнопки хода (пол первого рейда K-R3 — 7-й ход),
# затем кнопка «Хроника». Прямых записей в хронику нет: либо строка пришла из рейда,
# либо её в кадре не будет — иначе кадр врал бы.
#
# Оговорка 7c: возврат отчитывается и о ходах, и о ленте, и о строке на экране,
# потому что ровно на таком кадре уже случалось молчаливое «состояние не применилось».
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
var turn_button: Button = hud.get_node_or_null("TopButtons/TurnButton") as Button
var chronicle_button: Button = hud.get_node_or_null("TopButtons/ChronicleButton") as Button
if turn_button == null or chronicle_button == null:
	return {"ok": false, "reason": "кнопок хода/хроники в полосе нет"}
# Директива туториала (T-186) модална и лежит выше ленты: в этом кадре проверяется
# строка рейда, поэтому оверлей снимается так же, как в кадре T-187.
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
var pressed: int = 0
var blocked_at: int = -1
for _i in range(7):
	if turn_button.disabled:
		# Кризис: панель модальна, кнопка хода выключена — ходов будет меньше, и
		# читать кадр нужно с этой оговоркой, а не как «пройдено семь ходов».
		blocked_at = int(composition.campaign.current_turn)
		break
	turn_button.emit_signal("pressed")
	pressed += 1
chronicle_button.emit_signal("pressed")
var raid_key: String = "chronicle.bit_first_raid"
var raid_line: String = GameText.chronicle_line(raid_key, {})
var keys: Array[String] = []
for rec in composition.chronicle.records():
	for line in rec.get("lines", []):
		keys.append(str((line as Dictionary).get("key", "")))
var rendered: Array[String] = []
var list: VBoxContainer = hud.get_node_or_null(
	"ChronicleScreen/Root/Panel/VBox/Scroll/List") as VBoxContainer
if list != null:
	for child in list.get_children():
		if child is Label:
			rendered.append((child as Label).text)
return {
	"ok": true,
	"turn": int(composition.campaign.current_turn),
	"turns_pressed": pressed,
	"turn_blocked_at": blocked_at,
	"open": bool(hud.is_chronicle_screen_open()),
	"raid_bit_in_feed": keys.has(raid_key),
	"raid_line": raid_line,
	"raid_line_on_screen": rendered.has(raid_line),
	"records": keys.size(),
}
