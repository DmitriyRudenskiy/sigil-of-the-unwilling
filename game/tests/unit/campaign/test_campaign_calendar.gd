extends BaseTest

## 7.11 (ui-mockup-parity) — календарь макета «Месяц · Неделя · День».
##
## Макет карты требует дату вида «Month 2 Week 1 Day 1», а спека `campaign-hud`
## требует, чтобы месяц и неделя **пересчитывались** из календарной модели, а не
## хранились отдельным полем. В проекте переноса даты нет ни у кого:
## `WorldPersistence._date` хранит три числа, которые никто не катит, а
## `TurnContext` их только показывает. Поэтому здесь проверяется сам пересчёт:
## сетка недели, перенос месяца, длина месяца и то, что ни одно состояние не
## изобретено — вход один, выход детерминированный.
##
## Длины не хардкод теста: неделя сверяется с `SettlementProcessor.DAYS_PER_WEEK`
## (сменишь экономику — календарь переедет сам), год — с ожиданием
## `Season.from_month` (1..12).

const Calendar := preload("res://scripts/campaign/campaign_calendar.gd")


func test_first_day_is_month_one_week_one_day_one() -> void:
	var date: Dictionary = Calendar.date_of(1)
	assert_int(int(date.month)).is_equal(1)
	assert_int(int(date.week)).is_equal(1)
	assert_int(int(date.day)).is_equal(1)
	assert_int(int(date.year)).is_equal(1)


func test_week_length_comes_from_economy() -> void:
	assert_int(Calendar.days_per_week()).is_equal(SettlementProcessor.DAYS_PER_WEEK)
	assert_int(Calendar.days_per_month()).is_equal(
		SettlementProcessor.DAYS_PER_WEEK * Calendar.WEEKS_PER_MONTH)


func test_day_seven_is_last_day_of_first_week() -> void:
	var last := Calendar.date_of(Calendar.days_per_week())
	assert_int(int(last.week)).is_equal(1)
	assert_int(int(last.day)).is_equal(Calendar.days_per_week())


func test_week_rolls_after_the_week_length() -> void:
	var date: Dictionary = Calendar.date_of(Calendar.days_per_week() + 1)
	assert_int(int(date.month)).is_equal(1)
	assert_int(int(date.week)).is_equal(2)
	assert_int(int(date.day)).is_equal(1)


func test_month_rolls_after_four_weeks() -> void:
	var date: Dictionary = Calendar.date_of(Calendar.days_per_month() + 1)
	assert_int(int(date.month)).is_equal(2)
	assert_int(int(date.week)).is_equal(1)
	assert_int(int(date.day)).is_equal(1)
	# Ровно последний день месяца — не нулевой и не первого следующего.
	var edge: Dictionary = Calendar.date_of(Calendar.days_per_month())
	assert_int(int(edge.month)).is_equal(1)
	assert_int(int(edge.week)).is_equal(Calendar.WEEKS_PER_MONTH)
	assert_int(int(edge.day)).is_equal(Calendar.days_per_week())


func test_year_stays_inside_twelve_months() -> void:
	# `Season.from_month` ждёт 1..12: за пределы сезона календарь выводить не должен.
	var date: Dictionary = Calendar.date_of(Calendar.days_per_month() * Calendar.MONTHS_PER_YEAR + 1)
	assert_int(int(date.year)).is_equal(2)
	assert_int(int(date.month)).is_equal(1)
	for day in range(1, Calendar.days_per_month() * Calendar.MONTHS_PER_YEAR + 2):
		var month := int(Calendar.date_of(day).month)
		# месяц за пределами 1..12 обронил бы сезон (`Season.from_month` даёт
		# предупреждение и пружину) — ловим здесь, а не в экономике.
		assert_bool(month >= 1 and month <= Calendar.MONTHS_PER_YEAR).is_true()


func test_empty_or_wound_back_state_does_not_break() -> void:
	# Сейв без прожитых дней и отмотка назад не имеют права показывать нули.
	for day in [-5, 0, 1]:
		var date: Dictionary = Calendar.date_of(day)
		assert_int(int(date.month)).is_equal(1)
		assert_int(int(date.week)).is_equal(1)
		assert_int(int(date.day)).is_equal(1)


func test_date_advances_monotonically() -> void:
	var previous := -1
	for day in range(1, Calendar.days_per_month() * 2 + 1):
		var date: Dictionary = Calendar.date_of(day)
		var ordinal := (int(date.year) - 1) * Calendar.days_per_month() * Calendar.MONTHS_PER_YEAR \
			+ (int(date.month) - 1) * Calendar.days_per_month() \
			+ (int(date.week) - 1) * Calendar.days_per_week() + int(date.day)
		assert_int(ordinal).is_greater(previous)
		previous = ordinal


func test_label_is_locale_string_with_the_three_numbers() -> void:
	var date: Dictionary = Calendar.date_of(Calendar.days_per_month() + 1)
	var label := Calendar.date_label(Calendar.days_per_month() + 1)
	assert_str(label).not_contains("{")
	assert_str(label).not_contains("}")
	assert_str(label).contains(str(int(date.month)))
	assert_str(label).contains(str(int(date.week)))
	assert_str(label).contains(str(int(date.day)))
