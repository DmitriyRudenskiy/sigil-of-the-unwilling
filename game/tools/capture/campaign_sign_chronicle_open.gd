# CAPTURE_SETUP для кадра «хроника с событиями Знака» (T-187, signs-prestige 2.5).
#
# Кадр нужен про ux-review: как выглядят строки выбора Знака и смены титула в
# отрендеренной ленте. События специально оставлены на первом ходу: лента
# показывает свежие ходы сверху, и на 14-м ходу (кадр D-240) строки Знака уехали
# бы в конец списка, за пределы кадра.
#
# Состояние поднимается production-методами композиции: `set_sign` — тот же
# вызов, что делает `main._apply_pending_flow` после выбора Знака в преигре,
# `perform_sign_action` — тот же, что ведёт к начислению Престижа и синхронизации
# SM (бои в кадр не берём: их исход от seed'а, а проверяется отрезок
# «событие → лента → экран», а не баланс).
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
# `Object`: кампейн-композиция — `RefCounted`, каст к `Node` отсёк бы её как null.
var composition: Object = scene.get("composition")
if composition == null:
	return {"ok": false, "reason": "кампейн-композиция не собрана"}
var chronicle_button: Button = hud.get_node_or_null("TopButtons/ChronicleButton") as Button
if chronicle_button == null:
	return {"ok": false, "reason": "кнопки хроники в полосе нет"}
if chronicle_button.disabled:
	return {"ok": false, "reason": "кнопка хроники выключена — привязка ленты не прошла"}
# Туториал первой директивы (T-186) модален и лежит ВЫШЕ хроники (130 против
# 120): в кадре проверяемой ленты он только мешает, а открывается чуть позже,
# чем исполняется этот код, поэтому закрывается дважды — снять уже показанный и
# связать пустым списком директив, чтобы он не встал поверх позже. Проверяемое
# состояние кадра — лента Знака; оверлей директивы свой кадр и свой ux-review
# получил в T-186.
var tutorial: Node = hud.get_node_or_null("TutorialOverlay") as Node
if tutorial != null:
	tutorial.dismiss()
hud.bind_tutorial({})
composition.set_sign("spark")
composition.perform_sign_action("forge", 250.0)
chronicle_button.emit_signal("pressed")
var lines: Array[String] = []
for rec in composition.chronicle.records():
	for line in rec.get("lines", []):
		lines.append(str((line as Dictionary).get("key", "")))
return {
	"ok": true,
	"sign": str(composition.sign_id),
	"rank": int(composition.prestige_rank()),
	"open": bool(hud.is_chronicle_screen_open()),
	"tutorial_open": bool(hud.is_tutorial_open()),
	"keys": lines,
}
