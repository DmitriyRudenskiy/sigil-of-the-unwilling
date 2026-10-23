class_name CampaignCalendar
extends RefCounted
## 7.11 (ui-mockup-parity) — календарь макета «Месяц · Неделя · День» поверх
## канонического счётчика дней кампании.
##
## Это пересчёт, а не хранилище: спека `campaign-hud` требует, чтобы месяц и
## неделя пересчитывались из календарной модели, а не жили отдельным полем
## (D-200 — параллельного хранилища даты в кампейн-HUD не заводится). Вход —
## день кампании (`GameManager.get_current_day()`), выход — три числа макета.
## Ни состояния, ни побочных эффектов: тот же вход даёт ту же дату.
##
## Длины:
##   неделя = `SettlementProcessor.DAYS_PER_WEEK` (7) — единственная каноническая
##     длина недели в проекте;
##   месяц = 4 недели = 28 дней — каноном не задан, объявлен решением D-228
##     (в проекте месяц нигде не переносится: `WorldPersistence._date` хранит три
##     числа, которые никто не катит, а `TurnContext` их только показывает);
##   год = 12 месяцев — столько ожидает `Season.from_month` (1..12).


const WEEKS_PER_MONTH: int = 4
const MONTHS_PER_YEAR: int = 12


## Длина недели — из канона экономики, не отсюда: смена `DAYS_PER_WEEK`
## перекладывает сетку календаря сама.
static func days_per_week() -> int:
	return SettlementProcessor.DAYS_PER_WEEK


static func days_per_month() -> int:
	return days_per_week() * WEEKS_PER_MONTH


## День кампании (1-based) → `{year, month, week, day}`. День до первого
## включительно даёт первый день первого месяца — календарь не падает и не
## показывает нули на пустом или отмотанном состоянии.
static func date_of(day: int) -> Dictionary:
	var ordinal: int = maxi(0, day - 1)
	var week_len := days_per_week()
	var month_len := days_per_month()
	var year_len := month_len * MONTHS_PER_YEAR
	return {
		"year": int(ordinal / float(year_len)) + 1,
		"month": int(ordinal / float(month_len)) % MONTHS_PER_YEAR + 1,
		"week": int((ordinal % month_len) / float(week_len)) + 1,
		"day": (ordinal % week_len) + 1,
	}


## Подпись даты в формате макета (года в макете нет — он остаётся в `date_of`
## для сезонов).
static func date_label(day: int) -> String:
	var date := date_of(day)
	return GameText.campaign_date(date.month, date.week, date.day)
