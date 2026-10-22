extends BaseTest

# Контраст-гард (ui-verification-gates, задача 2.1): канон UI существует
# (арт-библия rev2 + docs/17-ui-style-guide.md §1.2), но не закреплён
# машинной проверкой. Три слоя:
# 1. PIN формулы — реализация WCAG обязана воспроизводить опубликованные
#    значения арт-библии §4.2/§4.5 (33 пары; все значения сверены
#    пересчётом 2026-10-21).
# 2. ДРЕЙФ-ГАРД — живые ThemeConfig.C_* обязаны совпадать с HEX гайда §1.2
#    (алиасы — по комментариям в theme_config.gd). Известный дрейф —
#    _KNOWN_DRIFT (T-155): печатается, не красит.
# 3. ПРАВИЛО — текст ≥ 4.5:1, нетекстовое состояние/граница ≥ 3:1 (гайд
#    §1.2 «Правило контраста»), пары из арт-библии; в сообщении падения —
#    пара и фактическое значение.
#
# Находка первого прогона (2026-10-21): колонка «Контраст к #281c0f»
# таблицы §1.2 устарела — 6 из 8 чисел неверны (C_GOLD 2.33 вместо 3.33,
# C_INK 3.42 вместо 1.19, C_PANEL 1.72 вместо 1.43 и т.д.); числа
# пересчитаны и гайд поправлен (задача 2.3), HEX-значения палитры не
# тронуты. Числа арт-библии §4.2/§4.5 — верны (29/29).

const _TOL_CHANNEL := 1.0 / 255.0
const _TOL_CONTRAST := 0.02

## Известный дрейф живых C_* ↔ гайд §1.2 (T-155): палитра — зона владельца
## (задача 2.3), гард печатает, не красит. Редкости — трёхстороннее
## расхождение: 17-ui-style-guide §1.2 (RARITY_MAJOR #9e7738,
## RARITY_GREATER #7a100c) vs арт-библия §4.4 (MAJOR #c9a227, RELIC
## #7a100c + #c9a227) vs код (C_RARITY_* = #cccc99 / #6699ff / #ffbf26).
const _KNOWN_DRIFT := {
	"C_BG_DARK": "T-155",
	"RARITY_MINOR": "T-155",
	"RARITY_MAJOR": "T-155",
	"RARITY_RELIC": "T-155",
}


# --- WCAG 2.x: relative luminance / contrast ratio ---

static func _srgb_to_lin(c: float) -> float:
	if c <= 0.04045:
		return c / 12.92
	return pow((c + 0.055) / 1.055, 2.4)


## WCAG relative luminance (sRGB 0..1; альфа не участвует).
static func relative_luminance(color: Color) -> float:
	return (
		0.2126 * _srgb_to_lin(color.r)
		+ 0.7152 * _srgb_to_lin(color.g)
		+ 0.0722 * _srgb_to_lin(color.b)
	)


## WCAG contrast ratio (1..21).
static func contrast(a: Color, b: Color) -> float:
	var la := relative_luminance(a)
	var lb := relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# --- Слой 1: pin формулы (опубликованные значения арт-библии) ---

## [fg hex, bg hex, опубликованное значение] — арт-библия §4.2 (текст)
## и §4.5 (non-text к фону тайла #281c0f).
const _PINS: Array = [
	["e8d5a8", "281c0f", 11.49], ["e8d5a8", "4a3423", 8.03],
	["e8d5a8", "3a2415", 10.06], ["e8d5a8", "090b0e", 13.62],
	["d9c48f", "281c0f", 9.69], ["d9c48f", "4a3423", 6.78],
	["d9c48f", "3a2415", 8.48], ["d9c48f", "090b0e", 11.49],
	["f5efe0", "281c0f", 14.49], ["f5efe0", "4a3423", 10.13],
	["f5efe0", "3a2415", 12.68], ["f5efe0", "090b0e", 17.17],
	["7aa85a", "281c0f", 6.00], ["7aa85a", "4a3423", 4.19],
	["7aa85a", "3a2415", 5.25], ["7aa85a", "090b0e", 7.11],
	["e05a4a", "281c0f", 4.54], ["e05a4a", "4a3423", 3.17],
	["e05a4a", "3a2415", 3.97], ["e05a4a", "090b0e", 5.38],
	["7ab0d0", "281c0f", 7.08], ["7ab0d0", "4a3423", 4.95],
	["7ab0d0", "3a2415", 6.20], ["7ab0d0", "090b0e", 8.40],
	["9e7738", "281c0f", 4.08], ["9e7738", "090b0e", 4.83],
	["e8d5a8", "7a100c", 7.61], ["e05a4a", "7a100c", 3.01],
	["f5efe0", "7a100c", 9.60],
	["8a6a3a", "281c0f", 3.33], ["c9a227", "281c0f", 6.87],
	["7a100c", "281c0f", 1.51],
]


func test_wcag_formula_reproduces_published_values() -> void:
	for pin in _PINS:
		var got := contrast(Color("#" + pin[0]), Color("#" + pin[1]))
		assert_bool(absf(got - float(pin[2])) <= _TOL_CONTRAST).is_true() \
			.override_failure_message(
				"WCAG-формула: #%s на #%s = %.2f, опубликовано %s — формула сломана"
				% [pin[0], pin[1], got, str(pin[2])]
			)


# --- Слой 2: дрейф-гард (живые ThemeConfig.C_* ↔ гайд §1.2) ---

func test_live_palette_matches_guide() -> void:
	var matched := {}
	# Токены гайда §1.2, у которых есть живой носитель (алиас — по
	# комментариям в theme_config.gd).
	_check_drift(ThemeConfig.C_BTN_TEXT, "e8d5a8", "C_TEXT", matched)
	_check_drift(ThemeConfig.C_BTN_PRESSED, "281c0f", "C_BG", matched)
	_check_drift(ThemeConfig.C_BTN_HOVER, "4a3423", "C_PANEL", matched)
	_check_drift(ThemeConfig.C_BTN_NORMAL, "3a2415", "C_PANEL_BORDER", matched)
	_check_drift(ThemeConfig.C_BTN_BORDER, "8a6a3a", "C_GOLD", matched)
	_check_drift(ThemeConfig.C_GOLD_OUTLINE, "9e7738", "C_GOLD_BRIGHT", matched)
	_check_drift(ThemeConfig.C_BTN_SHADOW, "16100a", "C_SHADOW", matched)
	_check_drift(ThemeConfig.C_TEXT_SUCCESS, "7aa85a", "C_OK", matched)
	# Известный дрейф (T-155).
	_check_drift(ThemeConfig.C_BG_DARK, "201006", "C_BG_DARK", matched)
	_check_drift(ThemeConfig.C_RARITY_MINOR, "8a6a3a", "RARITY_MINOR", matched)
	_check_drift(ThemeConfig.C_RARITY_MAJOR, "9e7738", "RARITY_MAJOR", matched)
	_check_drift(ThemeConfig.C_RARITY_RELIC, "7a100c", "RARITY_RELIC", matched)
	# Устаревшие known-записи: предупреждение, не падение.
	for token in _KNOWN_DRIFT:
		if not matched.has(token):
			print(
				"contrast-canon: известный дрейф '%s' (%s) не воспроизводится — запись устарела, удалить"
				% [token, _KNOWN_DRIFT[token]]
			)


func _check_drift(live: Color, guide_hex: String, token: String, matched: Dictionary) -> void:
	var guide := Color("#" + guide_hex)
	var ok := (
		absf(live.r - guide.r) <= _TOL_CHANNEL
		and absf(live.g - guide.g) <= _TOL_CHANNEL
		and absf(live.b - guide.b) <= _TOL_CHANNEL
	)
	if ok:
		return
	if _KNOWN_DRIFT.has(token):
		matched[token] = true
		print(
			"contrast-canon: известный дрейф '%s': код %s, гайд §1.2 #%s (%s) — не красит"
			% [token, live.to_html(false), guide_hex, _KNOWN_DRIFT[token]]
		)
		return
	assert_bool(false).is_true().override_failure_message(
		"дрейф палитры: %s — код %s, гайд §1.2 #%s" % [token, live.to_html(false), guide_hex]
	)


# --- Слой 3: правило (текст ≥ 4.5:1, non-text ≥ 3:1) из живых значений ---

func test_text_pairs_meet_wcag() -> void:
	# Гайд §1.2 «Правило контраста»; пары — арт-библия §4.2.
	_check_text(ThemeConfig.C_BTN_TEXT, ThemeConfig.C_BTN_PRESSED, "C_TEXT на C_BG")
	_check_text(ThemeConfig.C_BTN_TEXT, ThemeConfig.C_BTN_HOVER, "C_TEXT на C_PANEL")
	_check_text(ThemeConfig.C_BTN_TEXT, ThemeConfig.C_BTN_NORMAL, "C_TEXT на C_PANEL_BORDER")
	_check_text(ThemeConfig.C_TEXT_SUCCESS, ThemeConfig.C_BTN_PRESSED, "C_OK на C_BG")
	_check_text(ThemeConfig.C_TEXT_SUCCESS, ThemeConfig.C_BTN_NORMAL, "C_OK на C_PANEL_BORDER")
	# Документированное исключение: C_OK на C_PANEL = 4.19 (гайд: только ≥ 18 px
	# или с иконкой) — пиним значение, порог 4.5 к паре не применяем.
	_check_pinned(ThemeConfig.C_TEXT_SUCCESS, ThemeConfig.C_BTN_HOVER, "C_OK на C_PANEL", 4.19)


func test_non_text_pairs_meet_wcag() -> void:
	# Арт-библия §4.5 (WCAG 1.4.11): состояние/граница к фону тайла #281c0f.
	_check_non_text(ThemeConfig.C_BTN_BORDER, ThemeConfig.C_BTN_PRESSED, "C_GOLD на C_BG")
	_check_non_text(ThemeConfig.C_GOLD_OUTLINE, ThemeConfig.C_BTN_PRESSED, "C_GOLD_BRIGHT на C_BG")


func _check_text(fg: Color, bg: Color, label: String) -> void:
	var c := contrast(fg, bg)
	assert_bool(c >= 4.5).is_true().override_failure_message(
		"контраст текста < 4.5:1 — %s: %.2f" % [label, c]
	)


func _check_non_text(fg: Color, bg: Color, label: String) -> void:
	var c := contrast(fg, bg)
	assert_bool(c >= 3.0).is_true().override_failure_message(
		"контраст нетекстового носителя < 3:1 — %s: %.2f" % [label, c]
	)


func _check_pinned(fg: Color, bg: Color, label: String, expected: float) -> void:
	var c := contrast(fg, bg)
	assert_bool(absf(c - expected) <= _TOL_CONTRAST).is_true().override_failure_message(
		"документированное исключение уехало: %s: %.2f (гайд: %.2f)" % [label, c, expected]
	)
