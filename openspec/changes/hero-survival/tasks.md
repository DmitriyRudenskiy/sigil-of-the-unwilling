# Tasks: hero-survival

## 1. HeroNeeds — компонент потребностей

- [ ] 1.1 `scripts/entities/HeroNeeds.gd` (RefCounted, class_name): `needs`/`zero_streak` (все 4 `Character.NEED_KEYS` = 1.0), константы распада/восстановления (таблица demographics: распад 0.05–0.10, recovery hunger +0.20/−0.10 starving, rest +0.12, social +0.10 при pop≥3 иначе −0.05, inspiration +0.05), `DEATH_STREAK := 3`
- [ ] 1.2 `tick(in_city: bool, city: City = null) -> StringName`: распад всегда, recovery только в городе; zero-streak; cause-маппинг hunger→starvation, rest→exhaustion, social→isolation, inspiration→burnout; `&""` если жив
- [ ] 1.3 `reset()`, `get_need(id)`, `serialize()`/`deserialize()` (дефолты для старых сейвов)

## 2. HeroController — тик и смерть

- [ ] 2.1 `var needs := HeroNeeds.new()`, `var resurrected_once := false`; доступ к CityManager (есть/подать в `setup()`)
- [ ] 2.2 В `end_turn()`: `tick(in_city...)` по `city_at(current_cell)`; при cause — `is_alive = false` + `GameEventBus.hero_died.emit(cause)`
- [ ] 2.3 `revive_at(city: City)`: `is_alive = true`, `combat_hp = max_combat_hp`, `needs.reset()`, инвентарь → шаблон (equipped/backpack clear), `movement.current_cell = city.cell`
- [ ] 2.4 `serialize()`/`deserialize()` += `needs`, `resurrected_once` (через `data.get`, дефолты; SaveData-версия не меняется)

## 3. WorldController — поток воскрешения

- [ ] 3.1 `_find_resurrection_city(deceased)`: первый город с `can_resurrect(стоимость по умолчанию)` и `deceased.resurrected_once == false`
- [ ] 3.2 В `_on_hero_died`: если есть кандидат — труп не free, держать `_deceased_hero`; иначе — текущее поведение
- [ ] 3.3 `DeathSequence` получить `res_city` (кнопка «Воскресить (500⚙ + 100💰)», сигнал `resurrection_chosen`)
- [ ] 3.4 `_on_resurrection_chosen()`: `resurrect_hero(city)` (списание), `revive_at`, `resurrected_once = true`, вернуть героя в мир, освободить pending-преемника и труп-реф; летопись/`hero_successor` **не** трогаем
- [ ] 3.5 «Знак переходит»/«В меню»: освободить `_deceased_hero` перед текущим потоком

## 4. UI

- [ ] 4.1 `DeathSequence.gd`: третья кнопка (видна только с `res_city != null`), явный `.name` на нодах
- [ ] 4.2 `HeroStatusPanel.gd`: строка потребностей (🍞/😴/🤝/💡, %), замена placeholder-блока `if "inspiration" in h`; критический (<25%) — подсветка

## 5. Тесты

- [ ] 5.1 `tests/test_hero_survival.gd`: HeroNeeds — init (4×1.0), распад в поле, recovery в городе, starving-город, zero-streak → 4 cause, serialize roundtrip
- [ ] 5.2 `test_hero_survival.gd`: HeroController — тик в end_turn, смерть по needs → `hero_died` emit, `revive_at` (HP/needs/инвентарь/позиция), сериализация (старый сейв без needs → дефолты)
- [ ] 5.3 `test_hero_survival.gd`: WorldController — кандидат есть → кнопка, труп не free; воскрешение (ресурсы списаны, герой жив, `resurrected_once`, преемник освобождён, летопись пуста); повторная смерть в цикле → без кнопки; после succession → кнопка снова
- [ ] 5.4 Полный прогон: `test_hero_survival` green, весь набор green, 0 SCRIPT ERROR, ObjectDB ≤ 20, 0 RID

## 6. Сценарий и гейт

- [x] 6.1 `tools/scenarios/scenario_12_hero_survival.py`: hero needs → 0, 3 end_turn → смерть по needs, `GET_STATE` = DEFEAT (без преемника) или смерть с преемником (сценарий по факту wiring'а), консоль clean; добавить в `SCENARIOS` в `run_operability.sh`
- [x] 6.2 `run_operability.sh` — CLEAN (сценарии + full suite + console cleanliness)

## 7. Финализация

- [x] 7.1 Прогнать полный тест-набор + гейт; ObjectDB/RID в рамках allowlist
- [x] 7.2 Коммит (только файлы change + сценарий, без чужих untracked) — 1b11888
