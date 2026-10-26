class_name SurvivalRole
extends ScenarioRole
## Когорта выживания (задача 7.1, `scenario-matrix-behavior-reliability`): цель —
## дожить до последнего хода заказа, ничего не «достигая».
##
## Роль намеренно **не переопределяет** `act()`, `collect_target()` и `enemy_target()`.
## Когорта меряет базовый автопилот `BalanceProbe` на фиксированных картах: как только
## здесь появится политика, «8/10 выжили» начнёт описывать политику, а не мир.
##
## Смерть — измеряемый исход, а не техсбой (спека `balance-probe`): `death_turn` и
## `death_cause` печатаются в строке прогона наравне с выжившими.
##
## `trades` — всегда 0, и это измерение, а не забытое поле: сделку в мире совершает
## `TraderRole` (`MarketSystem.trade`), базовая политика за стол не садится. Числом
## «торговля была» когорта обязана отвечать «не было», а не молчать.
##
## `recovery_turns` — сколько снимков показали рост `combat_hp` относительно
## предыдущего: отдельных сигналов лечения в игре нет, а «восстановление» из задачи 7.1
## обязано мериться по факту изменения состояния, а не по намерению автопилота
## отдохнуть. Подсчёт — по всем снимкам, а не «подряд»: подряд означает серию, а серии
## роста из разных концов прогона — тоже восстановление.

func goal_met(_pilot: Node) -> bool:
	# Выживание не достигается раньше срока: прогон обязан отходить все заказанные
	# ходы или умереть. Ранний финиш здесь означал бы, что когорта считает выжившими
	# прогоны, которые просто перестали считаться.
	return false

func metrics(pilot: Node) -> Dictionary:
	var snaps: Array = pilot.snapshots
	var recovery := 0
	for i in range(1, snaps.size()):
		var prev: int = int(snaps[i - 1].get("combat_hp", 0))
		if int(snaps[i].get("combat_hp", 0)) > prev:
			recovery += 1
	var last_hostility: float = float(snaps[-1].get("hostility", 0.0)) if not snaps.is_empty() else 0.0
	# Наследования читаются у сессии игры, а не через pilot.report(): report() сам зовёт
	# metrics(), и обращение к нему отсюда — вечная рекурсия.
	var sess: Variant = pilot._world.get_session() if pilot._world != null else null
	var successions: int = int(sess.successions) if sess != null else 0
	return {
		"turns_alive": int(pilot.turn),
		"survived": survived(pilot),
		"gathers": int(pilot.extracted_nodes),
		"builds": int(pilot.builds_done),
		"recruits": int(pilot.recruits_done),
		"trades": 0,
		"battles": int(pilot.battles_fought),
		"losses": int(pilot.losses),
		"death_turn": int(pilot.hero_death_turn),
		"death_cause": str(pilot.hero_death_cause),
		"successions": successions,
		"recovery_turns": recovery,
		"hostility": last_hostility,
	}
