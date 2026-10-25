extends BaseTest

## signs-prestige 2.3 — косметические ранги в UI: плита Знака на кампейн-HUD.
##
## Сюжет в том, что Престиж считался с первой волны (ранги, титулы, SM знака,
## якорь хода 21), но носителя на экране у него не было: `prestige_rank_name()`
## не читал никто, кроме хроники (T-187), а `faction_actions_remaining()` —
## никто вообще. Проверять ранги по `CampaignComposition` бессмысленно — они там
## и так зелёные (`test_sign_system.gd`); здесь гейтится связка «ledger →
## ранг → строка в кадре», потому что ровно на этом шве у слоя появляется
## соблазн посчитать ранг самому и разойтись с носителем (урок двух носителей
## населения, T-183).
##
## Плита привязана к состоянию: у кампании без выбранного Знака (раннер, тесты
## препрейма) её нет. «Безымянный · Престиж 0» — это статус, которого игрок ещё
## не получал, а не нулевое значение существующего (конвенция «нет
## несуществующих сущностей»), поэтому отсутствие знака проверяется первым, а не
## выводится из пустого текста.
##
## Печатаются числа композиции, а не её копии: тесты сравнивают текст плиты с
## `prestige_balance()`/`prestige_rank_name()`, а не с литералами, кроме случая,
## где литерал и есть канон (титул «Знаемый» из `prestige.json`) — иначе тест
## повторял бы реализацию.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const HUD_PATH := "CampaignHUD/CampaignHud"
const TUTORIAL_OVERLAY_PATH := HUD_PATH + "/TutorialOverlay"
const SIGN_PLAQUE_PATH := HUD_PATH + "/SignPlaque"
const SIGN_COLUMN_PATH := SIGN_PLAQUE_PATH + "/SignColumn"
const SIGN_NAME_PATH := SIGN_COLUMN_PATH + "/SignName"
const SIGN_RANK_PATH := SIGN_COLUMN_PATH + "/SignRank"
const SIGN_ROW_PATH := SIGN_COLUMN_PATH + "/SignPrestigeRow"
const SIGN_CAPTION_PATH := SIGN_ROW_PATH + "/SignPrestigeCaption"
const SIGN_PRESTIGE_PATH := SIGN_ROW_PATH + "/SignPrestige"
const PARTY_PANEL_PATH := HUD_PATH + "/PartyPanel"
const GOALS_PANEL_PATH := HUD_PATH + "/GoalsPanel"
## Id знака из `data/signs.json` и id фракционного действия — те же строки, что
## использует препрейм и `campaign_composition.perform_sign_action`.
const SIGN_ID := "spark"
const SIGN_NAME := "Искра"
## Престиж за одно фракционное действие: 250 ≥ порога второго ранга (200) и
## меньше порога третьего (500) — переход ровно через одну границу.
const ACTION_PRESTIGE := 250.0

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false
	super.after_test()


## Кампейн поднимается игроковым путём (`main.tscn` → `_init_campaign` →
## `_mount_campaign_hud`), окно — 1920×1080, туториал закрывается: его проверка
## живёт в `test_campaign_tutorial_overlay.gd`.
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay := _main.get_node_or_null(TUTORIAL_OVERLAY_PATH) as TutorialOverlay
	if overlay != null and overlay.is_open():
		overlay.dismiss()
		await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node(HUD_PATH) as CampaignHud


func _refresh() -> void:
	_hud().refresh_campaign(_main.game_manager.get_current_day())


## ── плита и её состояние ─────────────────────────────────────────────────────

## Знак не выбран — плиты нет ни в кадре, ни в доступах слоя. Если бы плита
## оставалась видимой, игрок читал бы «Безымянный 0» как стартовый ранг.
func test_plaque_is_absent_before_a_sign_is_chosen() -> void:
	var main := await _boot_campaign()
	var plaque := main.get_node_or_null(SIGN_PLAQUE_PATH) as Control
	assert_that(plaque).is_not_null()
	assert_bool(plaque.visible).is_false()
	var hud := _hud()
	assert_str(hud.get_sign_text()).is_empty()
	assert_str(hud.get_sign_rank_text()).is_empty()
	assert_str(hud.get_prestige_text()).is_empty()


## Тот же путь, что препрейм: `composition.set_sign` (DORMANT→ACTIVE), затем
## штатное обновление слоя. Плита печатает имя знака из каталога, а не id:
## «spark» на экране — тот же дефект, что и технические id в панели отряда
## (Q-M84/D-204).
func test_plaque_prints_sign_name_title_and_prestige() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	main.composition.set_sign(SIGN_ID)
	_refresh()
	await get_tree().process_frame
	var plaque := main.get_node_or_null(SIGN_PLAQUE_PATH) as Control
	assert_that(plaque).is_not_null()
	assert_bool(plaque.visible).is_true()
	assert_str(hud.get_sign_text()).is_equal(SIGN_NAME)
	assert_str(hud.get_sign_rank_text()).is_equal(str(main.composition.prestige_rank_name()))
	assert_str(hud.get_prestige_text()).is_equal(str(main.composition.prestige_balance()))


## 2.3 по сути: титул обязан следовать за ledger. Начисление идёт производческим
## путём (`perform_sign_action` — тот же вызов, что ведёт к записи в ledger),
## пересчёт — через `refresh_campaign`, то есть слой ничего не знает о рангах.
func test_rank_title_follows_the_prestige_ledger() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var composition: CampaignComposition = main.composition
	composition.set_sign(SIGN_ID)
	_refresh()
	assert_str(hud.get_sign_rank_text()).is_equal("Безымянный")
	assert_int(composition.prestige_rank()).is_equal(0)
	var granted := composition.perform_sign_action("forge", ACTION_PRESTIGE)
	assert_int(int(granted)).is_equal(int(ACTION_PRESTIGE))
	_refresh()
	await get_tree().process_frame
	# Титул — из `prestige.json → rank_names` (канонизация владельца 2026-10-04),
	# число — из ledger: плита не имеет права округлять или пересчитывать.
	assert_str(hud.get_sign_rank_text()).is_equal("Знаемый")
	assert_int(composition.prestige_rank()).is_equal(1)
	assert_str(hud.get_prestige_text()).is_equal(str(composition.prestige_balance()))
	assert_int(int(hud.get_prestige_text())).is_equal(int(ACTION_PRESTIGE))


## Плита обновляется и без повторной привязки: `bind_sign` хост вызывает один раз
## при поднятии кампейна, а Престиж меняется ходами.
func test_plaque_survives_rebind_without_duplicates() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	hud.bind_sign(main.composition)
	var before := hud.get_sign_text()
	main.composition.set_sign(SIGN_ID)
	_refresh()
	assert_str(hud.get_sign_text()).is_equal(SIGN_NAME)
	assert_str(before).is_empty()
	# Узел один: повторная привязка не должна плодить вторую плиту.
	var plates := 0
	for child in hud.get_children():
		if child.name == "SignPlaque":
			plates += 1
	assert_int(plates).is_equal(1)


## ── строки и тема ────────────────────────────────────────────────────────────

## Подпись числа — перевод, а не ключ: голый `campaign.prestige_label` на экране
## был бы тем же классом дефекта, что цель без перевода (T-182).
func test_prestige_caption_is_translated_not_a_key() -> void:
	var main := await _boot_campaign()
	main.composition.set_sign(SIGN_ID)
	_refresh()
	var caption := main.get_node_or_null(SIGN_CAPTION_PATH) as Label
	assert_that(caption).is_not_null()
	assert_str(caption.text).is_equal(GameText.campaign_prestige_label())
	assert_bool(caption.text.contains("campaign.")).is_false()
	assert_str(caption.text).is_not_empty()
	assert_str(caption.text).is_equal("Престиж")


## 7.17 заодно по новой плите: имена и кегли берутся из темы проекта, а не из
## локальных оверрайдов. Эталон — `game_theme.tres`, потому что
## `ThemeDB.get_default_theme()` отдаёт движковский fallback без проектных ролей.
func test_plaque_resolves_from_theme_roles() -> void:
	var main := await _boot_campaign()
	main.composition.set_sign(SIGN_ID)
	_refresh()
	await get_tree().process_frame
	var base := load("res://assets/theme/game_theme.tres") as Theme
	var plaque := main.get_node(SIGN_PLAQUE_PATH) as Control
	var sign_name := main.get_node(SIGN_NAME_PATH) as Label
	var rank := main.get_node(SIGN_RANK_PATH) as Label
	var prestige := main.get_node(SIGN_PRESTIGE_PATH) as Label
	assert_str(str(plaque.theme_type_variation)).is_equal("PanelCard")
	assert_str(str(sign_name.theme_type_variation)).is_equal("LabelStrong")
	assert_str(str(rank.theme_type_variation)).is_equal("LabelSecondary")
	assert_str(str(prestige.theme_type_variation)).is_equal("LabelNumber")
	assert_int(sign_name.get_theme_font_size("font_size")).is_equal(
		int(base.get_font_size(&"font_size", &"LabelStrong")))
	assert_int(rank.get_theme_font_size("font_size")).is_equal(
		int(base.get_font_size(&"font_size", &"LabelSecondary")))
	assert_int(prestige.get_theme_font_size("font_size")).is_equal(
		int(base.get_font_size(&"font_size", &"LabelNumber")))
	# Локальных оверрайдов на плите нет: цвет и гарнитура резолвятся из роли,
	# а не перекрашены на месте (дефект «мёртвый theme_override_*» снят в T-191).
	assert_str(str(prestige.get_theme_font("font").resource_path)).contains("PT_Mono")
	assert_bool(prestige.get_theme_color("font_color")
			== base.get_color(&"font_color", &"LabelNumber")).is_true() \
			.override_failure_message(
				"Число Престижа перекрашено мимо роли LabelNumber: %s" % [
						prestige.get_theme_color("font_color")])
	assert_bool(rank.get_theme_color("font_color")
			== base.get_color(&"font_color", &"LabelSecondary")).is_true() \
			.override_failure_message(
				"Титул перекрашен мимо роли LabelSecondary: %s" % [
						rank.get_theme_color("font_color")])


## ── место в кадре ────────────────────────────────────────────────────────────

## Плита занимает свободный правый нижний угол и не наступает на панель отряда и
## панель целей: три носителя в одном углу кадра — это «текст есть, но его не
## видно», тот же дефект, что нулевой прямоугольник строки даты (7.11).
func test_plaque_sits_in_the_free_corner() -> void:
	var main := await _boot_campaign()
	main.composition.set_sign(SIGN_ID)
	_refresh()
	await get_tree().process_frame
	var plaque := main.get_node(SIGN_PLAQUE_PATH) as Control
	assert_bool(plaque.get_global_rect().size.x > 0.0).is_true()
	assert_bool(plaque.get_global_rect().size.y > 0.0).is_true()
	var window := _root() as Window
	var frame := Rect2(Vector2.ZERO, Vector2(window.size))
	assert_bool(frame.encloses(plaque.get_global_rect())).is_true()
	assert_bool(frame.has_point(plaque.get_global_rect().end)).is_true()
	for other_path in [PARTY_PANEL_PATH, GOALS_PANEL_PATH]:
		var other := main.get_node_or_null(NodePath(String(other_path))) as Control
		assert_that(other).is_not_null()
		assert_bool(plaque.get_global_rect().intersects(other.get_global_rect())).is_false()
