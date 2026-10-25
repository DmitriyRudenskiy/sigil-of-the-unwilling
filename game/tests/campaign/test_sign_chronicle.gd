"""signs-prestige 2.5 (T-187): хроника событий Знака.

Лента — нарративный канал MVP (D-240), а Знак до этого среза в неё не попадал
ни одним своим событием: выбор, переходы SM (ACTIVE↔SLEEPING) и титул Ф4-шкалы
существовали только как числа в `SignSystem` и `prestige_ledger`. Проверяется
связность, а не формат (формат — `test_chronicle_log`): у каждого события есть
писатель, ключ переведён, повтор не пишет вторую строку, а загрузка сейва не
выдумывает записи.
"""
extends BaseTest


func _composition() -> CampaignComposition:
	return CampaignComposition.from_campaign_config(12345)


func _keys(log: ChronicleLog) -> Array[String]:
	var out: Array[String] = []
	for rec in log.records():
		for line in rec.get("lines", []):
			out.append(str((line as Dictionary).get("key", "")))
	return out


func _count(c: CampaignComposition, key: String) -> int:
	var hits := 0
	for k in _keys(c.chronicle):
		if k == key:
			hits += 1
	return hits


## Аргумент последней записи с данным ключом (ищем с конца: нас интересует
## последнее событие, а не первое).
func _last_arg(c: CampaignComposition, key: String, arg: String) -> String:
	var records: Array = c.chronicle.records()
	records.reverse()
	for rec in records:
		for line in (rec as Dictionary).get("lines", []):
			if str((line as Dictionary).get("key", "")) == key:
				return str(((line as Dictionary).get("args", {}) as Dictionary).get(arg, ""))
	return ""


## Престиж «в обход» продюсеров: `_add_ledger` принимает только положительные
## суммы (замер — T-187), поэтому падение баланса ниже нуля моделируется прямой
## правкой ledger. Ветвь SM (`on_prestige_changed`, ≤0 → SLEEPING) живая, и
## писатель обязан быть на месте до того, как у баланса появится отрицательный
## источник.
func _set_balance(c: CampaignComposition, balance: int) -> void:
	var delta := balance - c.prestige_balance()
	if delta == 0:
		return
	c.prestige_ledger.append({
		"turn": c.campaign.current_turn, "source_type": "test_probe",
		"id": "probe", "amount": float(delta),
	})
	c._sign_system_prestige_sync()


## 1. Выбор Знака — строка ленты с именем из каталога, сразу за открывающим
## битом K-M9 («Ты не просил. Знак всё равно пришёл…»): бит про приход Знака,
## строка — про то, какой именно Знак взят.
func test_choice_writes_one_line_with_the_catalog_name() -> void:
	var c := _composition()
	c.set_sign("spark")
	assert_int(_count(c, "chronicle.sign_chosen")).is_equal(1)
	assert_str(_last_arg(c, "chronicle.sign_chosen", "sign")).is_equal("Искра")
	var keys := _keys(c.chronicle)
	assert_str(str(keys[0])).is_equal("chronicle.bit_sign")
	assert_str(str(keys[1])).is_equal("chronicle.sign_chosen")


## 2. Повторный выбор — no-op SM (один знак на носителя), значит и строка одна:
## второй Знак в ленте читался бы сменой знака, которой игра не делает.
func test_repeated_choice_writes_nothing_more() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.set_sign("shadow")
	assert_str(c.sign_id).is_equal("spark")
	assert_int(_count(c, "chronicle.sign_chosen")).is_equal(1)


## 3. Голого прогона (раннер D-157, тесты: Знак не выбирали) лента Знака касаться
## не должна: ни строки выбора, ни переходов SM — их просто не было.
func test_campaign_without_a_sign_writes_no_sign_events() -> void:
	var c := _composition()
	for i in 2:
		c.advance_turn()
	assert_int(_count(c, "chronicle.sign_chosen")).is_equal(0)
	assert_int(_count(c, "chronicle.sign_sleeping")).is_equal(0)
	assert_int(_count(c, "chronicle.sign_awakened")).is_equal(0)
	assert_str(c.sign_id).is_empty()


## 4. Титул — событие, а не молчаливое число: пересечение порога 200 даёт
## «Знаемого» (Ф4-шкала, prestige.json rank_names).
func test_rank_change_is_recorded_with_the_title() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.perform_sign_action("forge", 250.0)
	assert_int(c.prestige_rank()).is_equal(1)
	assert_int(_count(c, "chronicle.rank_changed")).is_equal(1)
	assert_str(_last_arg(c, "chronicle.rank_changed", "rank")).is_equal("Знаемый")


## 5. Одно начисление может пересечь два порога — строка всё равно одна и с
## итоговым титулом: лента показывает итог, а не перебор рангов.
func test_crossing_two_thresholds_writes_single_line() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.perform_sign_action("forge", 1200.0)
	assert_int(c.prestige_rank()).is_equal(3)
	assert_int(_count(c, "chronicle.rank_changed")).is_equal(1)
	assert_str(_last_arg(c, "chronicle.rank_changed", "rank")).is_equal("Славный")


## 6. ACTIVE→SLEEPING и SLEEPING→ACTIVE — по строке, и обе проговаривают, что
## поселение живёт дальше (K-M16: SLEEPING ≠ game over; молчание ленты здесь
## читалось бы как конец партии).
func test_sleeping_and_awakening_are_recorded_and_campaign_survives() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.perform_sign_action("forge", 250.0)
	# Смены баланса — на следующих ходах: дневной лимит ленты (5 записей, EC2)
	# не должен прятать проверяемую строку в сводку.
	c.advance_turn()
	_set_balance(c, 0)
	assert_str(c.sign_system.sign_state).is_equal(SignSystem.STATE_SLEEPING)
	assert_int(_count(c, "chronicle.sign_sleeping")).is_equal(1)
	assert_bool(c.campaign.is_done()).is_false()
	c.advance_turn()
	_set_balance(c, 120)
	assert_str(c.sign_system.sign_state).is_equal(SignSystem.STATE_ACTIVE)
	assert_int(_count(c, "chronicle.sign_awakened")).is_equal(1)
	assert_bool(c.campaign.is_done()).is_false()


## 7. Дёрганье SM на том же балансе не плодит строк: писатель висит на переходе
## состояния, а не на факте синхронизации (иначе каждое начисление Престижа
## давало бы строку «Знак уснул/проснулся» мимо реальной смены).
func test_sync_without_transition_writes_nothing() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.perform_sign_action("forge", 250.0)
	c._sign_system_prestige_sync()
	c._sign_system_prestige_sync()
	assert_int(_count(c, "chronicle.sign_sleeping")).is_equal(0)
	assert_int(_count(c, "chronicle.sign_awakened")).is_equal(0)
	assert_int(_count(c, "chronicle.rank_changed")).is_equal(1)


## 8. Загрузка сейва не выдумывает ленту: SM пересинхронизируется из баланса
## молча, а лента приезжает из файла ровно той же, какой её сохранили.
func test_load_replays_no_sign_events() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.perform_sign_action("forge", 250.0)
	var saved := c.build_save_state()
	var loaded := _composition()
	loaded.load_save_state(saved)
	assert_int(loaded.chronicle.records().size()) \
			.override_failure_message("загрузка изменила ленту").is_equal(
				c.chronicle.records().size())
	assert_int(_count(loaded, "chronicle.sign_chosen")).is_equal(1)
	assert_int(_count(loaded, "chronicle.rank_changed")).is_equal(1)


## 9. Закрытый набор ключей хроники обязан иметь перевод в обоих языках:
## `ChronicleLog` прячет неизвестный ключ (иначе игрок читает сырой ключ), а
## перевод — вторая половина той же монеты: ключ в KNOWN_KEYS без строки в po
## дал бы в кадре пустую строку вместо предложения.
func test_every_chronicle_key_is_translated_in_both_locales() -> void:
	var previous := TranslationServer.get_locale()
	for key in ChronicleLog.KNOWN_KEYS:
		for locale in ["ru", "en"]:
			TranslationServer.set_locale(str(locale))
			var text := TranslationServer.translate(str(key))
			# На неизвестный ключ TranslationServer возвращает сам ключ — значит
			# «переведено» здесь проверяется одним предикатом, а не двумя.
			assert_bool(text != "" and text != str(key)) \
					.override_failure_message("нет перевода: %s @ %s" % [key, locale]).is_true()
	TranslationServer.set_locale(previous)
