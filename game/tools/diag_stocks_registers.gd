extends SceneTree
## Диагностика двух регистров кампейн-запасов (T-309).
##
##   godot --headless --path game -s res://tools/diag_stocks_registers.gd
##   DIAG_SEED=12345 DIAG_DAYS=30 godot --headless --path game -s res://tools/diag_stocks_registers.gd
##
## Вопрос, ради которого написан зонд: `CampaignComposition` держит запасы дважды —
## `settlement.stocks` (`SettlementProcessor`, вектор K-D5) и `city.resource_ctx`
## (реестр города-носителя, 02g). Постановка T-309 называла читаемый сейвом и
## метрикой регистр «тем, который никто не тратит», и утверждала, что регистры
## разные уже на старте. Зонд отвечает числом, а не мнением:
##
##   1) двигается ли `settlement.stocks` на живом кампейн-тике (продукция/потребление);
##   2) двигается ли в те же дни `city.resource_ctx`;
##   3) какой регистр попадает в секцию сейва `resources` (`build_save_state`).
##
## Трату города (`request_training`) здесь не измеряют: `CampaignTrainingService` и
## `City.add_migrant` компилируются только с автозагрузками (`Services`, `Resources`),
## которых в `-s` режиме нет; трата и round-trip сейва закреплены кейсом 4 шва
## `game/tests/campaign/test_stocks_registers_seam.gd` (GdUnit, автозагрузки есть).
##
## Строка `DIAG|…` — снимок состояния, а не вердикт: вердикт выносится в тред T-309.

const RESOURCES: Array[String] = ["food", "wood", "iron"]

var _seed: int = 0
var _days: int = 0
var _every: int = 5


func _initialize() -> void:
	_seed = int(OS.get_environment("DIAG_SEED"))
	_days = int(OS.get_environment("DIAG_DAYS"))
	if _seed <= 0:
		_seed = 12345
	if _days <= 0:
		_days = 30
	_every = int(OS.get_environment("DIAG_EVERY"))
	if _every <= 0:
		_every = 5
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(_seed)
	if comp == null:
		print("DIAG|error=from_campaign_config")
		quit(2)
		return
	_snap(comp, "day0")
	for day in range(1, _days + 1):
		comp.advance_turn()
		if day % _every == 0 or day == _days:
			_snap(comp, "day%d" % day)
	var save: Dictionary = comp.build_save_state()
	_print_save(comp, save, "до_траты")
	print("DIAG-END|seed=%d|days=%d" % [_seed, _days])
	quit(0)


func _print_save(comp: CampaignComposition, save: Dictionary, label: String) -> void:
	var res: Dictionary = save.get("resources", {})
	var parts: Array[String] = []
	for r in RESOURCES:
		parts.append("%s:save=%s|ctx=%s" % [r, _f(res.get(r, 0.0)), _ctx(comp, r)])
	print("DIAG-SAVE|%s|%s" % [label, "|".join(parts)])


func _pair(comp: CampaignComposition, prefix: String) -> String:
	return "%s|food:stocks=%s|ctx=%s|iron:stocks=%s|ctx=%s" % [
		prefix,
		_f(comp.settlement.stocks.get("food", 0.0)), _ctx(comp, "food"),
		_f(comp.settlement.stocks.get("iron", 0.0)), _ctx(comp, "iron")]


## Снимок обоих регистров + что из них видит сейв.
func _snap(comp: CampaignComposition, label: String) -> void:
	var parts: Array[String] = []
	for r in RESOURCES:
		parts.append("%s:stocks=%s|ctx=%s" % [r, _f(comp.settlement.stocks.get(r, 0.0)), _ctx(comp, r)])
	print("DIAG|%s|turn=%d|%s" % [label, comp.campaign.current_turn, "|".join(parts)])


func _ctx(comp: CampaignComposition, resource_id: String) -> String:
	if comp.city == null or comp.city.resource_ctx == null:
		return "нет_города"
	return _f(comp.city.resource_ctx.amount(StringName(resource_id)))


func _f(value) -> String:
	return "%.1f" % float(value)
