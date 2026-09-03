# Design: hero-survival

## Decisions

### D1. `HeroNeeds` — чистый RefCounted-компонент, паттерн `HeroMagic`/`HeroSkills`

Новый `scripts/entities/HeroNeeds.gd` (`extends RefCounted`, `class_name HeroNeeds`):

```gdscript
var needs: Dictionary = {}            # StringName -> float 0..1
var zero_streak: Dictionary = {}      # StringName -> int
const DEATH_STREAK := 3

func _init() -> void:                 # все 4 ключа = 1.0, streak = 0
func tick(in_city: bool, city: City = null) -> StringName   # cause или &""
func reset() -> void                  # все 1.0, streak 0
func get_need(id: StringName) -> float
func serialize() -> Dictionary / deserialize(d: Dictionary)
```

- Ключи: **реused** `Character.NEED_KEYS` (hunger/rest/social/inspiration) — один канонический набор на весь проект.
- Формула тика = формула гражданина из `DemographicTurnProcessor` (`DECAY` + `_recovery`), но без trait-модификаторов (у героя трейтов потребностей нет):
  - `delta = -DECAY[need] + recovery`
  - `recovery` = 0 вне города (поле — только распад); в городе: hunger +0.20 (−0.10 если `city.starving`), rest +0.12, social +0.10 при `city.pop.size() >= 3` иначе −0.05, inspiration +0.05. Значения дублируются локальными константами `HeroNeeds` (как `DECAY` дублирован в demographics) — ponytail: не тащить demographics-класс в entities, константы в одном месте.
- Zero-streak и маппинг cause — те же, что demographics: hunger→`&"starvation"`, rest→`&"exhaustion"`, social→`&"isolation"`, inspiration→`&"burnout"`; `DEATH_STREAK := 3`.
- `tick()` **только считает** — смерть (emit `hero_died`) делает `HeroController`, не компонент.

### D2. Тик в `HeroController.end_turn()`, смерть через существующий `hero_died`

- `var needs := HeroNeeds.new()`, `var resurrected_once := false`.
- В `end_turn()` (после `_apply_daily_resource_effects`):
  ```gdscript
  var in_city := _city_manager != null and _city_manager.city_at(movement.current_cell) != null
  var cause := needs.tick(in_city, _city_manager.city_at(movement.current_cell) if in_city else null)
  if cause != "":
      mark_need_dead()
      GameEventBus.hero_died.emit(cause)
  ```
  `CityManager` у героя есть через `get_map_gen()`/`setup()` — проверяется при реализации (у героя уже есть ссылки на мир; если CityManager не подан — подать в `setup()`).
- **Весь downstream уже работает**: `WorldController._on_hero_died` → EndgameController (sticky DEFEAT без преемника) → выбор преемника → DeathSequence → летопись. Боевая смерть (`hero_died(&"battle")`) через `WorldBattleCoordinator` не меняется.
- `mark_need_dead()` — как `mark_combat_dead()`, но по needs: `is_alive = false` (единый флаг живости уже есть).

### D3. Воскресение — третий выбор в DeathSequence, труп не освобождать, пока выбор не сделан

Ключевое отличие от текущего потока: сейчас `_remove_hero(deceased)` освобождает труп **сразу**. При возможном воскрешении труп должен дожить до выбора игрока.

- В `_on_hero_died`: **до** `_remove_hero` вычислить кандидата на воскрешение:
  ```gdscript
  var res_city := _find_resurrection_city(deceased)   # null, если unusable
  ```
  Критерии: `_resurrection_used == false` (т.е. `deceased.resurrected_once == false`) и город с `can_resurrect(стоимость по умолчанию)`. Из нескольких — любой (первый по порядку `CityManager.cities`).
- Если `res_city != null`: труп **не освобождать**, держать в `_deceased_hero: HeroController` (убираем из сцены/ввода, но не `free`), `DeathSequence.show_death(..., successor, res_city)`.
  Если `res_city == null`: текущее поведение (свободный труп).
- `DeathSequence`: опциональная третья кнопка «Воскресить (500⚙ + 100💰)» (видна только если `res_city != null`), сигнал `resurrection_chosen`. Кнопки «Знак переходит»/«В меню» не скрываются — игрок всегда может выбрать преемника вместо воскрешения.
- `WorldController._on_resurrection_chosen()`:
  1. `SuccessionController.resurrect_hero(res_city)` (списывает 500 industry + 100 gold из `city.storage`; повторная проверка `can_resurrect` — защита от состояния за экраном).
  2. `hero.revive_at(res_city)`: `is_alive = true`, `combat_hp = max_combat_hp`, `needs.reset()`, **инвентарь → шаблон** (`inventory.equipped.clear()` + `backpack.clear()` — шаблонное снаряжение героя, как у свежего `HeroInventory.new()`), позиция `movement.current_cell = res_city.cell` (возврат в храм).
  3. `hero.resurrected_once = true`.
  4. Перевозвращаем героя в мир (`_add_hero`-эквивалент), `_deceased_hero = null`, закрываем DeathSequence. **Летопись не получаем** (цикл не оборвался) и **`hero_successor` не emit'им** (преемник не взошёл).
  5. Pending-преемник (уже построенный в `_plan_succession`) освобождается.
- «Знак переходит»/«В меню» при живом в памяти трупе → сначала `free(_deceased_hero)`, дальше текущий поток.
- **Once per cycle** = `hero.resurrected_once` (флаг живёт на герое, сериализуется с ним). Новый цикл (преемник) = новый `HeroController` с `resurrected_once = false`. Сессийный флаг не нужен — состояние цикла и есть состояние героя.

### D4. Шаблоно-снаряжение = чистый инвентарь

Спек: «only the path, spellbook and template gear return». Шаблонное снаряжение героя — то, что даёт свежий `HeroInventory.new()` (пустые слоты). Воскрешение: `equipped.clear()`, `backpack.clear()`; path/spellbook/schools/mana/скиллы/стратегические ресурсы/последователи **сохраняются** (они и есть легенда; инвентарь — личное имущество, гибнущее с героем).

### D5. Сериализация без бампа версии

- `HeroController.serialize()` += `"needs": needs.serialize()`, `"resurrected_once": resurrected_once`; `deserialize` — через `data.get` с дефолтами (старые сейвы v6: needs → свежие 1.0, resurrected_once → false). `SaveData.CURRENT_VERSION` не меняется (hero-дикт свободный).
- `resurrected_once` не сериализуется в `SaveData` отдельно — только внутри hero-дикта.

### D6. HeroStatusPanel — четыре потребности

Замена placeholder-блока `if "inspiration" in h` на реальный: строка «Потребности: 🍞 80% 😴 90% 🤝 70% 💡 55%» (иконки hunger/rest/social/inspiration), показывается когда `h.needs != null` (всегда после этого change, но проверка на null — деградация). Критический порог (< 25%) — подсветка цветом.

## Risks / open questions

- **Труп в памяти**: `_deceased_hero` должен быть недоступен для ввода/камеры до выбора. Mitigation: существующий паттерн «труп убран из мира» (`_remove_hero` без `free`) — вынести `free` в отдельный шаг.
- **Два города-кандидата**: первый подходящий — ок (спек не требует выбора; UI-кнопка одна).
- **Hero в городе при смерти**: смерть по needs в городе почти невозможна (восстановление > распад, кроме starving-города) — логично: город кормит.
- Воскрешение не восстанавливает army (army — часть мира, осталась как была; `mark_need_dead` не трогает армию). Осознанно: спектр молчит, army не инвентарь.
