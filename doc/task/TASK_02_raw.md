# Аудит и архитектурный рефакторинг задания

Я провел глубокий аудит предоставленного ТЗ. Текущий план содержит **хорошую базу по централизации**, но в нем есть **критические ошибки выполнения**, дублирование кода (файлы переписываются по 3 раза) и упущенные возможности GDScript 4.

Ниже представлен разбор ошибок, внедрение запрошенных паттернов (Стратегия, Наследование, Композиция) и **итоговая, очищенная пошаговая инструкция** для локального агента.

---

## 🚨 1. Критические ошибки и антипаттерны в исходном ТЗ

1. **Крах `ThemeIcons.apply()` (Runtime Crash)**
   В ТЗ предлагается `control.set("text", ...)`. Базовый класс `Control` **не имеет** свойства `text` (оно есть только у `Label`, `Button` и их наследников). Это вызовет ошибку или скрытое игнорирование.
   *Решение:* Проверка типа или использование `if "text" in control`.
2. **Удаленная константа `HeroNeeds.NEED_KEYS`**
   В Части 1 вы удалили строковые ключи потребностей, перейдя на `NeedType.all_ids()` (int). Но в Части 3 в `HeroStatusPanel._needs_text()` агент обращается к `HeroNeeds.NEED_KEYS`. Это сломает билд.
3. **Хрупкость `UITheme.color_name(id)` через `keys()[id]`**
   Использование `ColorID.keys()[id].to_lower()` означает, что если кто-то добавит новый цвет в *середину* enum'а, все индексы сдвинутся, и тема сломается без ошибок компиляции.
   *Решение:* Жесткий маппинг `Dictionary` или `@export` свойства.
4. **Дублирование `ResourceBar.gd`**
   Файл переписывается в Части 1, затем в Части 2, затем в Части 3. Агент запутается в порядке применения.
5. **Ручное дублирование `StyleBox` в `MainMenu.gd`**
   Код `sb_n.duplicate()` и ручная смена `bg_color` нарушает идею единой темы.
   *Решение:* Описать состояния `hover`/`pressed` для `menu_button` прямо в `.tres` и добавить их в `UITheme.BoxID`.

---

## 🏗 2. Архитектурный апгрейд (Паттерны)

### ♟ Стратегия (Strategy) для Потребностей (Needs)
Вместо гигантских `match need_id:` в `DemographicTurnProcessor` и `HeroNeeds`, мы инкапсулируем логику каждой потребности в отдельный класс. Это реализует **Open/Closed Principle** (добавление новой потребности не требует правки процессора).

```gdscript
// res://scripts/data/needs/need_strategy.gd
class_name NeedStrategy
extends RefCounted

var decay_rate: float
func _init(p_decay: float): decay_rate = p_decay
func get_recovery(city: City, pop: PopUnit) -> float: return 0.0
func get_death_cause() -> StringName: return &""

// res://scripts/data/needs/rest_strategy.gd
class_name RestStrategy
extends NeedStrategy
func _init(): super._init(0.10)
func get_recovery(city: City, pop: PopUnit) -> float:
    return 0.0 if pop and pop.state == PopUnit.State.MILITIA else 0.12
func get_death_cause() -> StringName: return &"exhaustion"
```
*В `NeedType.gd` просто храним словарь `{ ID.REST: RestStrategy.new() }`.*

### 🧬 Наследование + `@tool` для UI (Вместо рантайм-костылей)
Вместо того чтобы в каждом `_ready()` вызывать `ThemeIcons.apply(btn, IconID.CASTLE)`, мы создаем базовый класс `IconButton`. Благодаря `@tool` иконки и стили будут видны **прямо в редакторе Godot**, а `.tscn` останутся чистыми.

```gdscript
// res://scripts/ui/components/IconButton.gd
@tool
class_name IconButton
extends Button

@export var icon_id: ThemeIcons.IconID = ThemeIcons.IconID.NONE
@export var text_key: String = "":
    set(value):
        text_key = value
        _update_visuals()

func _ready() -> void:
    _update_visuals()

func _update_visuals() -> void:
    if Engine.is_editor_hint() or is_inside_tree():
        var glyph = ThemeIcons.icon(icon_id)
        text = (glyph + " " + text_key) if text_key != "" else glyph
```

### 🧩 Композиция и Глобальная Тема
Вместо ручного навешивания `UITheme.style_control()` на каждую панель, мы используем **Композицию через ThemeDB**.
1. В `project.godot` ставим `gui/theme/custom = "res://assets/theme/game_theme.tres"`.
2. Все `PanelContainer` и `Button` **автоматически** наследуют стили из `.tres`.
3. `UITheme.gd` оставляем **только** для динамических изменений (цвет MP, время суток, статусы), убирая из него статические боксы.

---

## 📋 3. Итоговая пошаговая инструкция для Локального Агента

Скопируйте этот блок и отдайте агенту. Он систематизирован, не содержит дублей и использует лучшие практики GDScript 4.

```markdown
# ЗАДАЧА: Глобальный рефакторинг Data-Layer и UI-Theme

## ЭТАП 1: Фундамент (Enum'ы и Стратегии)
1. Создай `res://scripts/data/school_type.gd`, `NeedType.gd`, `ToolType.gd` (enum'ы + статические методы `to_name/from_name`).
2. Реализуй паттерн **Стратегия** для потребностей:
   - Создай базовый класс `NeedStrategy` (`decay_rate`, `get_recovery()`, `get_death_cause()`).
   - Создай наследников: `RestStrategy`, `SocialStrategy`, `InspirationStrategy`.
   - В `NeedType.gd` добавь `const STRATEGIES: Dictionary`, маппящий `ID` на экземпляры стратегий.
3. Обнови `HeroMagic.gd`, `Character.gd`, `HeroNeeds.gd`:
   - Внутренние словари (`schools`, `needs`) должны использовать `int` (Enum ID) как ключи.
   - Методы `serialize()` конвертируют `int` -> `String` (для JSON).
   - Методы `deserialize()` читают `String` -> `int` (с поддержкой легаси-ключа `"belief"`).
4. Обнови `HeroTools.gd`:
   - Слоты должны хранить `int` (ToolType.ID), а не `StringName`.
   - В `deserialize()` добавь миграцию: если ключ строка, конвертируй его в `int` через `ToolType.from_name()`.

## ЭТАП 2: Архитектура UI (Тема и Иконки)
1. Создай `res://scripts/ui/UITheme.gd`:
   - Убери хрупкий `keys()[id].to_lower()`. Используй жесткий `Dictionary` для маппинга `ColorID` -> `StringName`.
   - Оставь только методы для **динамических** цветов (`color()`, `tint()`). Статические стили бери из глобальной темы Godot.
2. Создай `res://scripts/ui/ThemeIcons.gd`:
   - `enum IconID` и `const _GLYPHS: Dictionary`.
   - Исправь `apply()`: `if "text" in control: control.text = ...` (избегай краша на `Control`).
3. Создай `res://scripts/ui/components/IconButton.gd` (наследует `Button`, `@tool`, `@export var icon_id`).
4. Создай `res://scripts/ui/components/ThemedLabel.gd` (наследует `Label`, `@tool`, `@export var color_id`).
5. Обнови `res://assets/theme/game_theme.tres`:
   - Добавь недостающие цвета (`threat`, `btn_hover`, `btn_pressed`).
   - Убедись, что `Button/styles/hover` и `pressed` настроены для кастомных вариаций (чтобы не дублировать их в коде `MainMenu.gd`).

## ЭТАП 3: Чистка Бизнес-Логики
1. `DemographicTurnProcessor.gd`:
   - Удали все `match need_id:`. Используй `var strategy = NeedType.STRATEGIES[need_id]`.
   - Вызывай `strategy.get_recovery(...)` и `strategy.get_death_cause()`.
2. `BattleFX.gd`:
   - Исправь latent-bug: приведи `spell` к `SpellDef` (или `Resource`), убери проверку `if spell is Dictionary`, если это возможно, или оставь безопасный фоллбэк.
3. `ResourceChainService.gd` и `EconomicTurnProcessor.gd`:
   - Замени хардкод `"wood"/"stone"` на `ResourceType.to_name(ResourceType.ID.WOOD)`.

## ЭТАП 4: Очистка UI-Скриптов и Сцен (.tscn)
1. `ResourceBar.gd`, `ToolsPanel.gd`, `InfoPanel.gd`:
   - Удали локальные константы цветов (`C_BG`, `TEXT_GOLD`).
   - Используй `UITheme.color(UITheme.ColorID.X)` только для динамических элементов (MP, время суток).
   - Для статических иконок используй `ThemeIcons.icon()` или `ThemeIcons.resource_icon()`.
2. **Рефакторинг .tscn файлов** (`InfoPanel.tscn`, `BattleUI.tscn`, `MainMenu.tscn` и др.):
   - Удали все вшитые эмодзи из свойств `text`.
   - Замени стандартные `Button` на `IconButton` (через Custom Script в инспекторе).
   - Настрой `@export` свойства `icon_id` и `text_key` прямо в редакторе Godot.
   - Удали ручные вызовы `ThemeIcons.apply()` из `_ready()` — они больше не нужны благодаря `@tool`.

## ЭТАП 5: Сериализация и Сейвы
1. `WorldStateSerializer.gd` и `HeroController.gd`:
   - Убедись, что в JSON уходят **только строковые ключи** (`"air"`, `"rest"`, `"shovel"`).
   - Int-ключи используются только в оперативной памяти (Runtime) для быстрого поиска и type-safety.
```

# ЗАДАЧА: Глобальный рефакторинг Data-Layer, UI-Theme и бизнес-логики (Godot 4.7)

## 🛑 ЖЕСТКИЕ ПРАВИЛА
1. **Память vs JSON**: В рантайме (в словарях внутри классов) ключами всегда выступают `int` (Enum ID). При сериализации в JSON/сейвы ключи конвертируются в `String` (через `to_name()`/`to_key()`), чтобы не ломать существующие сейвы (кроме `HeroTools`, см. ниже).
2. **Godot 4.7**: Используй современные фичи (типизированные словари `Dictionary[K, V]`, где это не вызывает багов движка, `StringName`, typed arrays).
3. **Безопасность UI**: Не используй хрупкие конструкции вроде `Enum.keys()[id].to_lower()`. Используй жесткие словари маппинга.
4. **Очистка .tscn**: Эмодзи не должны быть захардкожены в `.tscn` файлах. Они должны назначаться из кода через `ThemeIcons`.

---

## ЭТАП 1: Фундамент (Enum'ы и Стратегии)

### 1.1. Создание базовых Enum-классов
Создай файлы в `res://scripts/data/`:
- `SchoolType.gd` (Enum `ID`: AIR, FIRE, WATER, EARTH). Методы: `to_key()`, `to_display()`, `from_key()`.
- `NeedType.gd` (Enum `ID`: REST, SOCIAL, INSPIRATION). Методы: `to_name()`, `from_name()` (с маппингом легаси "belief" -> INSPIRATION).
- `ToolType.gd` (Enum `ID`: SHOVEL, PICKAXE, CART, SKIN_PROTECTION, NET). Методы: `to_name()`, `from_name()`.

### 1.2. Паттерн "Стратегия" для потребностей (Needs)
Вместо гигантских `match` в `DemographicTurnProcessor` и `HeroNeeds`, вынеси логику в стратегии:
- Создай `res://scripts/data/needs/need_strategy.gd` (базовый класс с `decay_rate`, `get_recovery()`, `get_death_cause()`).
- Создай наследников: `RestStrategy`, `SocialStrategy`, `InspirationStrategy`.
- В `NeedType.gd` добавь `const STRATEGIES: Dictionary`, который маппит `NeedType.ID` на экземпляры стратегий.

---

## ЭТАП 2: Рефакторинг Бизнес-Логики

### 2.1. Магия и Бой (`HeroMagic`, `BattleFX`)
- **`HeroMagic.gd`**: Внутренний словарь `schools` должен иметь ключи `int` (SchoolType.ID). Методы `serialize_schools()` и `deserialize_schools()` обеспечивают мост между `int` и строками для сейвов.
- **`BattleFX.gd`**: Исправь latent-bug с приведением `SpellDef`. Заклинание может прийти как `Dictionary` (легаси) или как `Resource/Object`.
  ```gdscript
  var school_id: int = -1
  if spell is Dictionary:
      school_id = SchoolType.from_key(spell.get("school", ""))
  elif spell != null and "school_int" in spell: # Или проверка на SpellDef
      school_id = int(spell.school_int)
  ```
  Используй этот `school_id` для безопасного получения цвета из массива `SCHOOL_COLORS`.

### 2.2. Инструменты (`HeroTools`)
- Внутренние слоты хранят `int` (ToolType.ID).
- **Миграция сейвов НЕ НУЖНА**. Если старый сейв сломается, пользователь удалит его руками. В `deserialize()` просто читай новый формат.

### 2.3. Потребности и Демография (`Character`, `HeroNeeds`, `DemographicTurnProcessor`)
- Переведи словари `needs` на ключи `int` (NeedType.ID).
- В `DemographicTurnProcessor` замени `match need_id:` на вызовы стратегии:
  ```gdscript
  var strategy: NeedStrategy = NeedType.STRATEGIES[need_id]
  var delta := -strategy.decay_rate + strategy.get_recovery(city, pop)
  ```

---

## ЭТАП 3: Централизация UI (Тема и Иконки)

### 3.1. `UITheme.gd` (Динамические цвета)
Создай `res://scripts/ui/UITheme.gd`.
- Убери `keys()[id]`. Сделай жесткий маппинг:
  ```gdscript
  enum ColorID { TEXT, GOLD, DANGER, SUCCESS, TIME_DAY, TIME_NIGHT, ... }
  const COLOR_MAP := {
      ColorID.TEXT: &"text", ColorID.GOLD: &"gold",
      ColorID.DANGER: &"danger", ColorID.SUCCESS: &"success", ...
  }
  static func color(id: int, fallback: Color = Color.WHITE) -> Color:
      var name = COLOR_MAP.get(id, &"")
      if theme().has_color(name, &"Palette"): return theme().get_color(name, &"Palette")
      return fallback
  ```
- Оставь методы `tint()`, `font()`, `style_control()` только для **динамических** изменений в рантайме. Статические стили бери из глобальной темы Godot (`project.godot` -> `gui/theme/custom`).

### 3.2. `ThemeIcons.gd` (Глифы)
Создай `res://scripts/ui/ThemeIcons.gd`.
- Enum `IconID` и словарь `_GLYPHS`.
- Безопасный метод `apply()`:
  ```gdscript
  static func apply(control: Control, id: int, text: String = "") -> void:
      if control == null: return
      var glyph := icon(id)
      var final_text := (glyph + " " + text) if text != "" else glyph
      if "text" in control:
          control.set("text", final_text)
  ```
- Добавь хелперы: `classic_resource_icon()`, `need_icon()`, `tool_label()`, `building_icon()`.

### 3.3. Очистка UI-скриптов и `.tscn`
- **`ResourceBar.gd`, `ToolsPanel.gd`, `InfoPanel.gd`, `CityPanel.gd`**: Удали локальные константы цветов (`C_BG`, `TEXT_GOLD`). Используй `UITheme.color()` и `ThemeIcons`.
- **Очистка `.tscn`**: Пройдись по `InfoPanel.tscn`, `BattleUI.tscn`, `MainMenu.tscn`, `CityScreen.tscn` и удали все вшитые эмодзи из свойств `text` кнопок и лейблов. Назначай их в `_ready()` через `ThemeIcons.apply(node, ThemeIcons.IconID.X, "Текст")`.

---

## ЭТАП 4: Экономика и Сериализация

### 4.1. `ResourceBar.gd` и `ResourcesPanel.gd`
- Используй предоставленный `ResourceType.classic_ids()` для итерации.
- Иконки бери через `ThemeIcons.classic_resource_icon(id)`.

### 4.2. `WorldStateSerializer.gd` и `HeroController.gd`
- Убедись, что при сохранении в JSON словари потребностей, школ магии и ресурсов конвертируются в строковые ключи (`"air"`, `"rest"`, `"wood"`), используя методы `to_name()` / `to_key()` из соответствующих Enum-классов.
- В `EconomicTurnProcessor` и `ResourceRegistry` замени хардкод `"wood"`/`"stone"` на `ResourceType.to_name(ResourceType.ID.WOOD)`.

---

## ЧЕК-ЛИСТ ДЛЯ АГЕНТА (Порядок выполнения)
1. [ ] Создать `SchoolType`, `NeedType`, `ToolType` + Стратегии потребностей.
2. [ ] Обновить `HeroMagic`, `HeroTools`, `Character`, `HeroNeeds` (переход на int-ключи в памяти).
3. [ ] Рефакторинг `DemographicTurnProcessor` (использование `NeedStrategy`).
4. [ ] Фикс `BattleFX` (безопасное чтение `SpellDef`/`Dictionary`).
5. [ ] Создание `UITheme.gd` и `ThemeIcons.gd` (с безопасным маппингом).
6. [ ] Очистка UI-скриптов от хардкода цветов и эмодзи.
7. [ ] Удаление эмодзи из `.tscn` файлов.
8. [ ] Финальная проверка сериализации (JSON должен содержать только строки).

Начни с создания файлов ЭТАПА 1 и 3.1/3.2, так как они являются базой для всего остального. Пиши чистый, типизированный код.
```

***

### 💡 Почему это сработает идеально:
1. **Безопасность от регрессий**: Жесткий `COLOR_MAP` в `UITheme` спасает от падения игры, если кто-то случайно изменит порядок в `enum ColorID`.
2. **Чистота .tscn**: Инструкция явно запрещает агенту хардкодить эмодзи в сценах, что делает сцены легкими и позволяет менять дизайн глобально.
3. **Экономия токенов и времени**: Агент не будет писать код миграции для `HeroTools` (который вы разрешили удалить) и не будет пытаться переписать легаси-словари в `BattleFX`, а просто обернет их в безопасный адаптер.




## Сводка

Помимо `ResourceType` (внедрён ранее), текстовые константы вместо enum остались в четырёх закрытых словарях:

1. **Школы магии** — `"air"/"fire"/"water"/"earth"` в `HeroMagic`, `BattleFX`, `ArtifactInventoryScreen` (enum `SpellRegistry.School` уже существует, но не используется; в `BattleFX` заодно latent-bug: `SpellDef` приводился к `Dictionary`).
2. **Потребности** — `&"rest"/&"social"/&"inspiration"` в `Character`, `HeroNeeds`, `DemographicTurnProcessor`, `HeroStatusPanel`.
3. **Инструменты** — `"shovel"…` в `HeroTools`, `ToolsPanel`, `ResourceChainService`.
4. **Остатки `"wood"/"stone"/"gold"`** — `ResourceBar`, `ResourceIcons`, `HeroController`, `EconomicTurnProcessor`, `TerrainResourceManager`, `ResourceRegistry`, `WorldStateSerializer`.

Не трогаем (осознанно): ключи статов (`"attack"…`), id юнитов/артефактов/зданий/биомов — это data-driven ключи из JSON-реестров, enum там вредит расширяемости. Сериализация везде остаётся со строковыми ключами (сейвы не ломаются).

---

## 1. [High] Новые enum-файлы

```gdscript
// FILE: res://scripts/data/school_type.gd  (НОВЫЙ ФАЙЛ)
class_name SchoolType
extends RefCounted

## Зеркало SpellRegistry.School для статического использования без autoload.
## Порядок значений ОБЯЗАН совпадать со SpellRegistry.School.
enum ID { AIR = 0, FIRE = 1, WATER = 2, EARTH = 3 }

const COUNT := 4

static func to_key(id: int) -> String:
	match id:
		ID.AIR: return "air"
		ID.FIRE: return "fire"
		ID.WATER: return "water"
		ID.EARTH: return "earth"
	return ""

static func to_display(id: int) -> String:
	return to_key(id).capitalize()

## Принимает "air"/"Air"/int; -1 если неизвестно.
static func from_key(value: Variant) -> int:
	if value is int:
		return value if is_valid(value) else -1
	match str(value).to_lower():
		"air": return ID.AIR
		"fire": return ID.FIRE
		"water": return ID.WATER
		"earth": return ID.EARTH
	return -1

static func is_valid(id: int) -> bool:
	return id >= 0 and id < COUNT

static func all_ids() -> Array[int]:
	return [ID.AIR, ID.FIRE, ID.WATER, ID.EARTH]
```

```gdscript
// FILE: res://scripts/data/need_type.gd  (НОВЫЙ ФАЙЛ)
class_name NeedType
extends RefCounted

enum ID { REST = 0, SOCIAL = 1, INSPIRATION = 2 }

const COUNT := 3

static func to_name(id: int) -> StringName:
	match id:
		ID.REST: return &"rest"
		ID.SOCIAL: return &"social"
		ID.INSPIRATION: return &"inspiration"
	return &""

## "belief" — легаси-ключ старых сейвов (мигрирует в INSPIRATION).
static func from_name(value: Variant) -> int:
	match str(value):
		"rest": return ID.REST
		"social": return ID.SOCIAL
		"inspiration": return ID.INSPIRATION
		"belief": return ID.INSPIRATION
	return -1

static func is_valid(id: int) -> bool:
	return id >= 0 and id < COUNT

static func all_ids() -> Array[int]:
	return [ID.REST, ID.SOCIAL, ID.INSPIRATION]

static func all_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in all_ids():
		out.append(to_name(id))
	return out
```

```gdscript
// FILE: res://scripts/data/tool_type.gd  (НОВЫЙ ФАЙЛ)
class_name ToolType
extends RefCounted

enum ID { SHOVEL = 0, PICKAXE = 1, CART = 2, SKIN_PROTECTION = 3, NET = 4 }

const COUNT := 5

static func to_name(id: int) -> StringName:
	match id:
		ID.SHOVEL: return &"shovel"
		ID.PICKAXE: return &"pickaxe"
		ID.CART: return &"cart"
		ID.SKIN_PROTECTION: return &"skin_protection"
		ID.NET: return &"net"
	return &""

static func from_name(value: Variant) -> int:
	match str(value):
		"shovel": return ID.SHOVEL
		"pickaxe": return ID.PICKAXE
		"cart": return ID.CART
		"skin_protection": return ID.SKIN_PROTECTION
		"net": return ID.NET
	return -1

static func is_valid(id: int) -> bool:
	return id >= 0 and id < COUNT

static func all_ids() -> Array[int]:
	return [ID.SHOVEL, ID.PICKAXE, ID.CART, ID.SKIN_PROTECTION, ID.NET]

static func all_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in all_ids():
		out.append(to_name(id))
	return out
```

---

## 2. [High] Школы магии

```gdscript
// FILE: res://scripts/entities/hero_magic.gd  (ПОЛНАЯ ЗАМЕНА)
class_name HeroMagic
extends RefCounted

signal changed

var mana_current: int = 0
var mana_max: int = 0
## Ключи — SchoolType.ID (int), значения — уровень школы.
var schools: Dictionary = {}
var spellbook: Array[StringName] = []

func init_defaults() -> void:
	mana_max = 20
	mana_current = 20
	schools = {
		SchoolType.ID.AIR: 1,
		SchoolType.ID.FIRE: 0,
		SchoolType.ID.WATER: 0,
		SchoolType.ID.EARTH: 0,
	}
	spellbook = [&"magic_arrow", &"haste"]
	changed.emit()

func knows(spell_id: StringName) -> bool:
	return spellbook.has(spell_id)

func learn(spell_id: StringName) -> bool:
	if knows(spell_id):
		return false
	spellbook.append(spell_id)
	changed.emit()
	return true

func forget(spell_id: StringName) -> bool:
	if not knows(spell_id):
		return false
	spellbook.erase(spell_id)
	changed.emit()
	return true

func school_level(school_id: int) -> int:
	return int(schools.get(school_id, 0))

func can_cast(spell) -> bool:
	var school_id: int
	var level: int
	if spell is Dictionary:
		school_id = SchoolType.from_key(spell.get("school", ""))
		level = int(spell.get("level", 1))
	else:
		school_id = int(spell.school_int)
		level = int(spell.level)
	var mana_cost := get_mana_cost(spell)
	if school_level(school_id) < level:
		return false
	if mana_current < mana_cost:
		return false
	return true

func get_mana_cost(spell) -> int:
	var base: int
	var tags: Array
	if spell is Dictionary:
		base = int(spell.get("base_mana", 5))
		tags = spell.get("tags", [])
	else:
		base = int(spell.base_mana) if "base_mana" in spell else 5
		tags = spell.tags if "tags" in spell else []
	if "anti_magic" in tags:
		return base + 2
	return base

func can_cast_def(spell: SpellRegistry.SpellDef) -> bool:
	if spell == null:
		return false
	if school_level(int(spell.school_int)) < spell.level:
		return false
	return mana_current >= get_mana_cost_def(spell)

func get_mana_cost_def(spell: SpellRegistry.SpellDef) -> int:
	if spell == null:
		return 0
	var cost := spell.base_mana
	if spell.tags.has("anti_magic"):
		cost += 2
	return cost

func spend_mana(cost: int) -> bool:
	if mana_current < cost:
		return false
	mana_current -= cost
	changed.emit()
	return true

func refund_mana(cost: int) -> void:
	mana_current = min(mana_current + cost, mana_max)
	changed.emit()

func restore_full() -> void:
	mana_current = mana_max
	changed.emit()

func tick_restore(amount: int = 1) -> void:
	mana_current = min(mana_current + amount, mana_max)
	changed.emit()

## В сейв — строковые ключи ("air": 1): формат идентичен старому.
func serialize_schools() -> Dictionary:
	var out := {}
	for id in schools:
		out[SchoolType.to_key(int(id))] = int(schools[id])
	return out

## Читает и старый формат (строки), и новый (int).
func deserialize_schools(data: Dictionary) -> void:
	schools.clear()
	for key in data:
		var id: int = SchoolType.from_key(key)
		if SchoolType.is_valid(id):
			schools[id] = int(data[key])
	for id in SchoolType.all_ids():
		if not schools.has(id):
			schools[id] = 0
```

```gdscript
// FILE: res://scripts/core/battle_fx.gd  (заменить show_spell_cast + константу цветов)
const SCHOOL_COLORS: Array[Color] = [
	Color(0.4, 0.7, 1.0),   # SchoolType.ID.AIR
	Color(1.0, 0.4, 0.2),   # SchoolType.ID.FIRE
	Color(0.2, 0.6, 0.9),   # SchoolType.ID.WATER
	Color(0.5, 0.8, 0.3),   # SchoolType.ID.EARTH
]

func show_spell_cast(cell: Vector2i, spell_id: StringName) -> void:
	if _view == null:
		return
	var color := Color.WHITE
	var reg: Node = ServiceLocator.resolve(null, &"spells")
	if reg != null and reg.has_method("get_spell"):
		var def = reg.get_spell(spell_id)
		if def != null:
			var sid: int = int(def.school_int)
			if sid >= 0 and sid < SCHOOL_COLORS.size():
				color = SCHOOL_COLORS[sid]
	_view.show_floating_text(cell, "SPELL: %s" % spell_id, color)
```

```gdscript
// FILE: res://scripts/ui/artifact_inventory_screen.gd  (заменить _magic_school)
func _magic_school() -> String:
	var schools: Dictionary = _hero.magic_schools if _hero != null else {}
	var active: Array[String] = []
	for k in schools:
		if int(schools[k]) > 0:
			active.append(SchoolType.to_display(int(k)))
	return " / ".join(active) if not active.is_empty() else "—"
```

```gdscript
// FILE: res://scripts/entities/hero_controller.gd  (замены в serialize/deserialize)
# в serialize() заменить строку:
#   "magic_schools": magic.schools.duplicate(),
# на:
		"magic_schools": magic.serialize_schools(),
# в deserialize() заменить строку:
#   magic.schools = data.get("magic_schools", magic.schools).duplicate()
# на:
	magic.deserialize_schools(data.get("magic_schools", {}))
```

---

## 3. [Medium] Потребности (needs)

```gdscript
// FILE: res://scripts/demographics/character.gd  (ПОЛНАЯ ЗАМЕНА)
class_name Character
extends RefCounted

var uid := 0
var name := ""
var icon := "🙂"
var birth_turn := 0
var city_uid := -1
var pop_uid := -1
var alive := true
## Ключи — NeedType.ID (int), значения — float 0..1.
var needs: Dictionary = {}
var traits: Array[TraitDef] = []
var need_zero_streak: Dictionary = {}
var was_critical: Dictionary = {}

func _init() -> void:
	reset_needs()

func reset_needs() -> void:
	needs.clear()
	need_zero_streak.clear()
	was_critical.clear()
	for id in NeedType.all_ids():
		needs[id] = 0.8
		need_zero_streak[id] = 0
		was_critical[id] = false

func age_in_days(turn: int) -> int:
	return maxi(turn - birth_turn, 0)

func modify_need(id: int, delta: float) -> void:
	needs[id] = clampf(float(needs.get(id, 0.5)) + delta, 0.0, 1.0)

func is_need_critical(id: int, threshold: float = 0.2) -> bool:
	return float(needs.get(id, 1.0)) < threshold

func trait_modifier(type: StringName) -> float:
	var v := 0.0
	for t in traits:
		if t != null:
			v += t.modifier_for(type)
	return v

func serialize() -> Dictionary:
	return {
		"uid": uid,
		"name": name,
		"icon": icon,
		"birth_turn": birth_turn,
		"city_uid": city_uid,
		"pop_uid": pop_uid,
		"alive": alive,
		"needs": _needs_to_str(needs),
		"traits": traits.map(func(t: TraitDef) -> Dictionary:
			return t.to_dict() if t != null else {}),
	}

static func _needs_to_str(src: Dictionary) -> Dictionary:
	var out := {}
	for id in src:
		out[String(NeedType.to_name(int(id)))] = float(src[id])
	return out

static func deserialize(data: Dictionary) -> Character:
	var ch := Character.new()
	ch.uid = int(data.get("uid", 0))
	ch.name = String(data.get("name", ""))
	ch.icon = String(data.get("icon", "🙂"))
	ch.birth_turn = int(data.get("birth_turn", 0))
	ch.city_uid = int(data.get("city_uid", -1))
	ch.pop_uid = int(data.get("pop_uid", -1))
	ch.alive = bool(data.get("alive", true))
	var raw_needs: Dictionary = data.get("needs", {})
	for key in raw_needs:
		if str(key) == "belief":
			continue  # легаси-ключ — обрабатывается ниже
		var id := NeedType.from_name(key)
		if NeedType.is_valid(id):
			ch.needs[id] = float(raw_needs[key])
	if not ch.needs.has(NeedType.ID.INSPIRATION) and raw_needs.has("belief"):
		ch.needs[NeedType.ID.INSPIRATION] = float(raw_needs["belief"])
	var raw_traits: Array = data.get("traits", [])
	for d in raw_traits:
		var t := TraitDef.from_dict(d)
		if t.id != &"":
			ch.traits.append(t)
	return ch
```

```gdscript
// FILE: res://scripts/entities/hero_needs.gd  (ПОЛНАЯ ЗАМЕНА)
class_name HeroNeeds
extends RefCounted

const DECAY: Dictionary = {
	NeedType.ID.REST: 0.10,
	NeedType.ID.SOCIAL: 0.08,
	NeedType.ID.INSPIRATION: 0.05,
}
const DEATH_STREAK := 3
const CRITICAL_THRESHOLD := 0.2

## Ключи — NeedType.ID (int).
var needs: Dictionary = {}
var zero_streak: Dictionary = {}

func _init() -> void:
	reset()

func tick(in_city: bool, city: City = null) -> StringName:
	for id in NeedType.all_ids():
		var delta := -float(DECAY[id])
		if in_city and city != null:
			delta += _recovery(id, city)
		needs[id] = clampf(float(needs.get(id, 1.0)) + delta, 0.0, 1.0)
	for id in NeedType.all_ids():
		if float(needs[id]) <= 0.0001:
			zero_streak[id] = int(zero_streak.get(id, 0)) + 1
		else:
			zero_streak[id] = 0
	for id in NeedType.all_ids():
		if int(zero_streak[id]) >= DEATH_STREAK:
			return _death_cause(id)
	return &""

func _recovery(need_id: int, city: City) -> float:
	match need_id:
		NeedType.ID.REST:
			return 0.36
		NeedType.ID.SOCIAL:
			if city.pop.size() >= 3:
				return 0.30
			return -0.05
		NeedType.ID.INSPIRATION:
			return 0.15
	return 0.0

func _death_cause(need_id: int) -> StringName:
	match need_id:
		NeedType.ID.REST:
			return &"exhaustion"
		NeedType.ID.SOCIAL:
			return &"isolation"
		NeedType.ID.INSPIRATION:
			return &"burnout"
	return &""

func get_need(id: int) -> float:
	return float(needs.get(id, 0.0))

func is_critical(id: int) -> bool:
	return float(needs.get(id, 0.0)) < CRITICAL_THRESHOLD

func reset() -> void:
	for id in NeedType.all_ids():
		needs[id] = 1.0
		zero_streak[id] = 0

func serialize() -> Dictionary:
	var out := {}
	for id in NeedType.all_ids():
		out[String(NeedType.to_name(id))] = float(needs.get(id, 1.0))
	return out

func deserialize(d: Dictionary) -> void:
	for id in NeedType.all_ids():
		var key := String(NeedType.to_name(id))
		if d.has(key):
			needs[id] = clampf(float(d[key]), 0.0, 1.0)
		else:
			needs[id] = 1.0
		zero_streak[id] = 0
```

```gdscript
// FILE: res://scripts/demographics/demographic_turn_processor.gd
# заменить константу DECAY:
const DECAY: Dictionary = {
	NeedType.ID.REST: 0.10,
	NeedType.ID.SOCIAL: 0.08,
	NeedType.ID.INSPIRATION: 0.05,
}

# заменить _process_city целиком:
func _process_city(city: City, ctx: TurnContext) -> Dictionary:
	var report := {"uid": city.uid, "ensured": 0, "critical": 0, "deaths": 0, "outbreaks": 0, "promoted": 0}
	var rng := _rng_for(ctx, city)
	for pop in city.pop.duplicate():
		if registry.get_by_pop(pop.uid) == null:
			var ch := registry.create(city.uid, pop, rng)
			report["ensured"] += 1
			character_born.emit(ch.uid, city.uid, ch.name)
	var critical_chars: Array = []
	for ch in registry.alive_in_city(city.uid).duplicate():
		var pop: PopUnit = _find_pop(city, ch.pop_uid)
		for need_id in NeedType.all_ids():
			var delta := -float(DECAY[need_id])
			delta += _recovery(need_id, city, pop)
			delta += ch.trait_modifier(NeedType.to_name(need_id))
			ch.modify_need(need_id, delta)
		for need_id in NeedType.all_ids():
			if float(ch.needs[need_id]) <= 0.0001:
				ch.need_zero_streak[need_id] = int(ch.need_zero_streak.get(need_id, 0)) + 1
			else:
				ch.need_zero_streak[need_id] = 0
		var char_critical := 0
		for need_id in NeedType.all_ids():
			var crit: bool = ch.is_need_critical(need_id, CRITICAL_THRESHOLD)
			if crit:
				char_critical += 1
				if not bool(ch.was_critical.get(need_id, false)):
					ch.was_critical[need_id] = true
					report["critical"] += 1
					character_need_critical.emit(ch.uid, NeedType.to_name(need_id))
			else:
				ch.was_critical[need_id] = false
		if char_critical >= 2:
			critical_chars.append(ch)
	for ch in registry.alive_in_city(city.uid).duplicate():
		var cause := _death_cause(ch)
		if cause == &"":
			continue
		_kill(city, ch, cause, report)
	var outbreak_due := false
	if not critical_chars.is_empty():
		var threshold := 2 if registry.alive_in_city(city.uid).size() >= 4 else 1
		if critical_chars.size() >= threshold:
			var last: int = int(_outbreak_turn.get(city.uid, -999))
			if ctx.turn_number - last >= OUTBREAK_COOLDOWN:
				outbreak_due = true
	if outbreak_due:
		_outbreak_turn[city.uid] = ctx.turn_number
		for ch in registry.alive_in_city(city.uid):
			if critical_chars.has(ch):
				ch.modify_need(NeedType.ID.REST, -0.2)
				ch.modify_need(NeedType.ID.INSPIRATION, -0.1)
		report["outbreaks"] += 1
		disease_outbreak.emit(city.uid, ch.uid)
	var promoted := 0
	var rc: ResourceContext = city.resource_ctx
	if rc != null:
		var candidate: PopUnit = _promotable_follower(city)
		while rc.amount(&"scholar_points") >= 1.0 \
			and candidate != null \
			and city.free_housing(PopUnit.State.SCHOLAR) > 0:
			rc.remove(&"scholar_points", 1.0)
			candidate.state = PopUnit.State.SCHOLAR
			city.population_changed.emit()
			promoted += 1
			candidate = _promotable_follower(city)
	if promoted > 0:
		report["promoted"] = promoted
	return report

# заменить _recovery и _death_cause:
func _recovery(need_id: int, city: City, pop: PopUnit) -> float:
	match need_id:
		NeedType.ID.REST:
			if pop != null and pop.state == PopUnit.State.MILITIA:
				return 0.0
			return 0.12
		NeedType.ID.SOCIAL:
			if city.pop.size() >= 3:
				return 0.10
			return -0.05
		NeedType.ID.INSPIRATION:
			return 0.05
	return 0.0

func _death_cause(ch: Character) -> StringName:
	for need_id in NeedType.all_ids():
		if int(ch.need_zero_streak.get(need_id, 0)) >= DEATH_STREAK:
			match need_id:
				NeedType.ID.REST:
					return &"exhaustion"
				NeedType.ID.SOCIAL:
					return &"isolation"
				NeedType.ID.INSPIRATION:
					return &"burnout"
	return &""
```

```gdscript
// FILE: res://scripts/ui/hero_status_panel.gd  (заменить _NEED_ICONS и _needs_text)
const _NEED_ICONS: Array[String] = ["😴", "", "💡"]

func _needs_text(n: HeroNeeds) -> String:
	var parts: Array[String] = []
	for id in NeedType.all_ids():
		var mark := "⚠️" if n.is_critical(id) else ""
		parts.append("%s%s %.0f%%" % [_NEED_ICONS[id], mark, n.get_need(id) * 100.0])
	return "\n".join(parts)
```

---

## 4. [Low] Инструменты

```gdscript
// FILE: res://scripts/entities/hero_tools.gd  (ПОЛНАЯ ЗАМЕНА)
class_name HeroTools
extends RefCounted

signal tools_changed

const MAX_SLOTS := 8

var slots: Array[Dictionary] = []

func _init() -> void:
	for i in MAX_SLOTS:
		slots.append({})

static func tool_types() -> Array[StringName]:
	return ToolType.all_names()

func has_tool(tool_id: StringName) -> bool:
	for slot in slots:
		if slot.has("id") and slot.id == tool_id:
			return true
	return false

func get_tool_count(tool_id: StringName) -> int:
	var count := 0
	for slot in slots:
		if slot.has("id") and slot.id == tool_id:
			count += slot.get("quantity", 1)
	return count

func add_tool(tool_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if tool_id == ToolType.to_name(ToolType.ID.SKIN_PROTECTION) \
		or tool_id == ToolType.to_name(ToolType.ID.NET):
		for slot in slots:
			if slot.has("id") and slot.id == tool_id:
				slot.quantity += quantity
				tools_changed.emit()
				return true
	for i in MAX_SLOTS:
		if slots[i].is_empty():
			slots[i] = {"id": tool_id, "quantity": quantity}
			tools_changed.emit()
			return true
	return false

func remove_tool(tool_id: StringName, quantity: int = 1) -> bool:
	var remaining := quantity
	for i in MAX_SLOTS:
		if remaining <= 0:
			break
		if slots[i].has("id") and slots[i].id == tool_id:
			var avail: int = int(slots[i].get("quantity", 1))
			if avail <= remaining:
				remaining -= avail
				slots[i] = {}
			else:
				slots[i].quantity -= remaining
				remaining = 0
	if remaining == 0:
		tools_changed.emit()
		return true
	return false

func get_empty_slots() -> int:
	var count := 0
	for slot in slots:
		if slot.is_empty():
			count += 1
	return count

func get_all() -> Array[Dictionary]:
	return slots.duplicate(true)

func clear() -> void:
	for i in MAX_SLOTS:
		slots[i] = {}
	tools_changed.emit()

func serialize() -> Array[Dictionary]:
	return slots.duplicate(true)

func deserialize(data: Array) -> void:
	slots.clear()
	for i in MAX_SLOTS:
		if i < data.size():
			slots.append(data[i].duplicate())
		else:
			slots.append({})
	tools_changed.emit()
```

```gdscript
// FILE: res://scripts/ui/tools_panel.gd  (ПОЛНАЯ ЗАМЕНА)
class_name ToolsPanel
extends PanelContainer

const _TOOL_LABELS: Dictionary = {
	ToolType.ID.SHOVEL: "🔧 Лопата",
	ToolType.ID.PICKAXE: "⛏️ Кирка",
	ToolType.ID.CART: "🛒 Телега",
	ToolType.ID.SKIN_PROTECTION: "🛡️ Защита кожи",
	ToolType.ID.NET: "🥅 Сеть",
}

var _slot_labels: Array[Label] = []

func _ready() -> void:
	var title := $VBox/Title as Label
	title.add_theme_font_size_override("font_size", 14)
	var container := $VBox/ToolContainer as VBoxContainer
	for i in MapConfig.TOOL_INVENTORY_SLOTS:
		var row := container.get_node("Slot%d" % i) as HBoxContainer
		if row == null:
			continue
		var label := row.get_node("SlotLabel") as Label
		if label != null:
			label.add_theme_font_size_override("font_size", 12)
		_slot_labels.append(label)

func update_tools(tools: Array[Dictionary]) -> void:
	for i in MapConfig.TOOL_INVENTORY_SLOTS:
		if i >= _slot_labels.size():
			break
		var slot: Dictionary = tools[i] if i < tools.size() else {}
		if slot.is_empty():
			_slot_labels[i].text = "[%d] Пусто" % (i + 1)
		else:
			var id: StringName = slot.get("id", "")
			var qty: int = slot.get("quantity", 1)
			var tool_id: int = ToolType.from_name(id)
			var label_text: String = _TOOL_LABELS.get(tool_id, str(id))
			_slot_labels[i].text = "[%d] %s x%d" % [i + 1, label_text, qty]
```

```gdscript
// FILE: res://scripts/world/resource_chain_service.gd
# в build_extraction_keys() и _extraction_fingerprint() заменить:
#   for tool_type in HeroTools.TOOL_TYPES:
# на:
	for tool_type in ToolType.all_names():
```

---

## 5. [High/Medium] Дожим ResourceType

```gdscript
// FILE: res://scripts/ui/resource_bar.gd  (ПОЛНАЯ ЗАМЕНА)
class_name ResourceBar
extends HBoxContainer

const C_TEXT := Color(0.95, 0.89, 0.72)
## Порядок = ResourceType.ID (0..6). Имена узлов сцены: Wood..Gold.
const ICONS: Array[String] = ["🪵", "", "", "🟡", "🔷", "", "🪙"]

var _labels: Dictionary = {}

func _ready() -> void:
	for id in ResourceType.classic_ids():
		var l := get_node(ResourceType.to_key(id).capitalize()) as Label
		if l == null:
			continue
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", C_TEXT)
		_labels[id] = l

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		_labels[id].text = "%s%d" % [ICONS[int(id)], int(resources.get(id, 0))]
```

```gdscript
// FILE: res://scripts/data/resource_icons.gd  (ПОЛНАЯ ЗАМЕНА)
class_name ResourceIcons
extends RefCounted

const _RT := preload("res://scripts/data/resource_type.gd")

const DATA: Dictionary = {
	_RT.ID.WOOD:    {"texture": "", "name": "Дерево",    "color": Color(0.62, 0.44, 0.24)},
	_RT.ID.MERCURY: {"texture": "", "name": "Ртуть",     "color": Color(0.64, 0.67, 0.74)},
	_RT.ID.ORE:     {"texture": "", "name": "Руда",      "color": Color(0.50, 0.40, 0.34)},
	_RT.ID.SULFUR:  {"texture": "", "name": "Сера",      "color": Color(0.87, 0.80, 0.30)},
	_RT.ID.CRYSTAL: {"texture": "", "name": "Кристалл",  "color": Color(0.40, 0.63, 0.88)},
	_RT.ID.GEMS:    {"texture": "", "name": "Самоцветы", "color": Color(0.52, 0.80, 0.62)},
	_RT.ID.GOLD:    {"texture": "", "name": "Золото",    "color": Color(0.92, 0.77, 0.28)},
}

static func res_type_id(res_type: int) -> StringName:
	return _RT.to_name(res_type)

static func res_type_amount(res_type: int) -> int:
	return _RT.pickup_amount(res_type)

static func _entry_for(resource_id: StringName) -> Dictionary:
	return DATA.get(_RT.from_name(resource_id), {})

static func get_texture(resource_id: StringName) -> Texture2D:
	var entry := _entry_for(resource_id)
	var path: String = str(entry.get("texture", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func resource_name(resource_id: StringName) -> String:
	var entry := _entry_for(resource_id)
	if entry.has("name"):
		return str(entry["name"])
	var def: ResourceDef = _registry_def(resource_id)
	if def != null and not def.display_name.is_empty():
		return def.display_name
	return str(resource_id)

static func get_color(resource_id: StringName) -> Color:
	var entry := _entry_for(resource_id)
	if entry.has("color"):
		return entry["color"]
	return _hash_color(resource_id)

static func _registry_def(resource_id: StringName) -> ResourceDef:
	var reg := _registry()
	if reg == null:
		return null
	return reg.get_resource(resource_id)

static func _registry() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null(^"Resources")
	return null

static func _hash_color(resource_id: StringName) -> Color:
	var h := absi((resource_id as String).hash())
	var hue := fmod(float(h) / 2147483647.0, 1.0)
	return Color.from_hsv(hue, 0.45, 0.75)
```

```gdscript
// FILE: res://scripts/data/terrain_resource_manager.gd  (ПОЛНАЯ ЗАМЕНА)
extends Node
class_name TerrainResourceManager

const HexUtils = preload("res://scripts/core/hex_utils.gd")
const GameLogger = preload("res://scripts/core/game_logger.gd")

## Значения — ResourceType.ID (int), не строки.
const TERRAIN_RESOURCE_MAP: Dictionary = {
	HexUtils.Terrain.FOREST: ResourceType.ID.WOOD,
	HexUtils.Terrain.MOUNTAIN: ResourceType.ID.STONE,
}
const HARVEST_AMOUNT := 2
signal terrain_harvested(cell: Vector2i, res_id: StringName, amount: int)
signal terrain_exhausted(cell: Vector2i, res_id: StringName)

var cells: Dictionary = {}   # cell -> {"res": int(ResourceType.ID), "exhausted": bool}
var density: float = 1.0
var _world_delta: Variant = null

func attach_delta(delta: Variant) -> void:
	_world_delta = delta

func _ready() -> void:
	pass

func generate(map_data: Dictionary, density: float = -1.0) -> void:
	cells.clear()
	if density < 0.0:
		density = self.density
	elif density >= 0.0:
		self.density = density
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(map_data.get("seed", 0))
	var terrain_map: Dictionary = map_data.get("terrain", {})
	var width: int = map_data.get("width", 0)
	var height: int = map_data.get("height", 0)
	if width == 0 or height == 0:
		return
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if not terrain_map.has(cell):
				continue
			var terrain_id: int = int(terrain_map[cell])
			var res_id: Variant = TERRAIN_RESOURCE_MAP.get(terrain_id)
			if res_id == null:
				continue
			if rng.randf() <= density:
				cells[cell] = {"res": int(res_id), "exhausted": false}

func is_harvestable(cell: Vector2i) -> bool:
	var c: Variant = cells.get(cell, null)
	return c != null and not c.get("exhausted", false)

func res_id_at(cell: Vector2i) -> Variant:
	var c: Variant = cells.get(cell, null)
	if c == null:
		return null
	return ResourceType.to_name(int(c["res"]))

func harvest(cell: Vector2i) -> Dictionary:
	var c = cells.get(cell, null)
	if c == null or c.get("exhausted", false):
		return {"res_id": null, "amount": 0}
	var res_id: StringName = ResourceType.to_name(int(c["res"]))
	c["exhausted"] = true
	if _world_delta != null and _world_delta.has_method("add_terrain_exhausted"):
		_world_delta.add_terrain_exhausted(cell)
	terrain_harvested.emit(cell, res_id, HARVEST_AMOUNT)
	terrain_exhausted.emit(cell, res_id)
	GameLogger.world("Terrain resource harvested at %s: %s" % [cell, res_id])
	return {"res_id": res_id, "amount": HARVEST_AMOUNT}

func mark_exhausted(cells_list: Array) -> void:
	for cell in cells_list:
		if cell is Vector2i and cells.has(cell):
			cells[cell]["exhausted"] = true

func to_dict() -> Dictionary:
	var out := {}
	for cell in cells:
		var c: Dictionary = cells[cell]
		if c.get("exhausted", false):
			out[str(cell)] = int(c["res"])
	return out

func restore_from_dict(data: Dictionary) -> void:
	for key in data:
		var cell := _parse_cell(str(key))
		if cell is Vector2i and cells.has(cell):
			cells[cell]["exhausted"] = true

func _parse_cell(s: String) -> Vector2i:
	var inner := s.trim_prefix("(").trim_suffix(")")
	var parts: Array = inner.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

func is_exhausted(cell: Vector2i) -> bool:
	var c: Variant = cells.get(cell, null)
	return c != null and c.get("exhausted", false)
```

Точечные замены:

```gdscript
// FILE: res://scripts/entities/hero_controller.gd  (заменить _apply_daily_resource_effects)
func _apply_daily_resource_effects() -> void:
	resources.apply_daily_effects()
	strategic_resources._add_internal(
		ResourceType.to_name(ResourceType.ID.WOOD), MapConfig.RESOURCE_AUTO_WOOD_PER_DAY)
	strategic_resources._add_internal(
		ResourceType.to_name(ResourceType.ID.STONE), MapConfig.RESOURCE_AUTO_STONE_PER_DAY)
	strategic_resources.emit_changed()
```

```gdscript
// FILE: res://scripts/economy/economic_turn_processor.gd  (заменить блок auto в _process_city)
	var auto: Dictionary = {}
	var wood_id: StringName = ResourceType.to_name(ResourceType.ID.WOOD)
	var stone_id: StringName = ResourceType.to_name(ResourceType.ID.STONE)
	auto[wood_id] = res.add(
		wood_id, float(MapConfig.RESOURCE_AUTO_WOOD_PER_DAY) * city.auto_resource_mult)
	auto[stone_id] = res.add(
		stone_id, float(MapConfig.RESOURCE_AUTO_STONE_PER_DAY) * city.auto_resource_mult)
	report["auto"] = auto
```

```gdscript
// FILE: res://scripts/autoload/resource_registry.gd
# регистрации wood/stone в ensure_definitions() заменить на:
	_add(ResourceType.to_name(ResourceType.ID.WOOD), "Дерево", ["grass", "forest"], Rarity.COMMON,
		"", &"", &"worker", "", "", false,
		2, 2, 0.0, "🌲")
	_add(ResourceType.to_name(ResourceType.ID.STONE), "Камень", ["mountain"], Rarity.COMMON,
		"", &"", &"worker", "", "", false,
		2, 2, 0.0, "🪨")
# is_hidden_resource() заменить на:
func is_hidden_resource(id: StringName) -> bool:
	return id != ResourceType.to_name(ResourceType.ID.WOOD) \
		and id != ResourceType.to_name(ResourceType.ID.STONE) \
		and not CITY_RESOURCE_CAPACITIES.has(id)
```

```gdscript
// FILE: res://scripts/autoload/world_state_serializer.gd
# в get_state() заменить:
#   state.basic_resources = hero.resources.resources.duplicate()
# на (int-ключи не должны уходить в JSON-телеметрию):
			state.basic_resources = hero.resources.to_string_dict()
```

---

## Runbook

1. Создать `SchoolType.gd`, `NeedType.gd`, `ToolType.gd` в `res://scripts/data/`.
2. Перезаписать файлы: `HeroMagic.gd`, `Character.gd`, `HeroNeeds.gd`, `HeroTools.gd`, `ToolsPanel.gd`, `ResourceBar.gd`, `ResourceIcons.gd`, `TerrainResourceManager.gd`.
3. Внести точечные замены: `BattleFX.gd`, `ArtifactInventoryScreen.gd`, `HeroStatusPanel.gd`, `DemographicTurnProcessor.gd`, `ResourceChainService.gd`, `HeroController.gd` (3 места), `EconomicTurnProcessor.gd`, `ResourceRegistry.gd`, `WorldStateSerializer.gd`.
4. Проверка headless: `godot --headless --script res://tests/run_tests.gd` (если есть), затем в редакторе: новая игра → подобрать ресурс (ResourceBar с int-ключами отображает счётчики), открыть инвентарь (школы магии), довести потребность до критической (иконки в HeroStatusPanel), сохранить/загрузить (строковые ключи сейвов читаются через `from_key/from_name`).

## Итоговая таблица

| № | Файл | Суть изменения | Приоритет |
|---|------|----------------|-----------|
| 1 | `scripts/data/SchoolType.gd` | Новый enum школ магии | High |
| 2 | `scripts/entities/HeroMagic.gd` | `schools` keyed by enum; serialize совместим | High |
| 3 | `scripts/core/BattleFX.gd` | Цвета школ по enum; фикс приведения SpellDef→Dictionary | High |
| 4 | `scripts/ui/ArtifactInventoryScreen.gd` | `_magic_school` через enum | Medium |
| 5 | `scripts/data/NeedType.gd` | Новый enum потребностей (+миграция "belief") | Medium |
| 6 | `scripts/demographics/Character.gd` | `needs` keyed by enum | Medium |
| 7 | `scripts/entities/HeroNeeds.gd` | `needs`/DECAY keyed by enum | Medium |
| 8 | `scripts/demographics/DemographicTurnProcessor.gd` | DECAY/причины смерти по enum | Medium |
| 9 | `scripts/ui/HeroStatusPanel.gd` | Иконки потребностей по enum | Low |
| 10 | `scripts/data/ToolType.gd` | Новый enum инструментов | Low |
| 11 | `scripts/entities/HeroTools.gd` | STACKABLE/типы через enum | Low |
| 12 | `scripts/ui/ToolsPanel.gd` | Лейблы через enum | Low |
| 13 | `scripts/world/ResourceChainService.gd` | Циклы инструментов через enum | Low |
| 14 | `scripts/ui/ResourceBar.gd` | ResourceType вместо строк | High |
| 15 | `scripts/data/ResourceIcons.gd` | DATA/RES_TYPE_IDS через ResourceType | High |
| 16 | `scripts/entities/HeroController.gd` | `&"wood"/&"stone"` → ResourceType; школы в serialize | High |
| 17 | `scripts/economy/EconomicTurnProcessor.gd` | auto-доход через ResourceType | Medium |
| 18 | `scripts/data/TerrainResourceManager.gd` | TERRAIN_RESOURCE_MAP хранит enum | Medium |
| 19 | `scripts/autoload/ResourceRegistry.gd` | wood/stone через ResourceType | Medium |
| 20 | `scripts/autoload/WorldStateSerializer.gd` | `basic_resources` через `to_string_dict()` | Medium |


## Сводка

Сейчас цвета и StyleBox-и размазаны по ~15 скриптам (`C_BG`, `C_BORDER`, `C_TEXT`, `StyleBoxFlat.new()` в `_ready`, `add_theme_color_override` с литералами). При этом в проекте **уже есть** `res://assets/theme/game_theme.tres`, но он используется точечно и не является источником правды.

Решение — единая тема + тонкий статический доступор:

1. **`game_theme.tres`** становится единственным местом, где определены цвета палитры, размеры шрифтов и все StyleBox-и (включая дефолтные для `Label`, `Button`, `PanelContainer` — тогда большинство ручных override вообще не нужно).
2. **`UITheme.gd`** — статический фасад для мест, где стиль нужен программно (вариации панелей, цвета для canvas-оверлеев).
3. Тема подключается **глобально** через `project.godot` (`gui/theme/custom`) — наследование стилей работает во всех сценах без правок `.tscn`.
4. Скрипты теряют цветовые константы и берут всё из темы.

---

## 1. [High] НОВЫЙ ФАЙЛ `res://scripts/ui/UITheme.gd`

```gdscript
// FILE: res://scripts/ui/UITheme.gd
class_name UITheme
extends RefCounted

## Единственная точка доступа к оформлению из кода.
## Все цвета/StyleBox/размеры живут в game_theme.tres.
const THEME_PATH := "res://assets/theme/game_theme.tres"

const PALETTE := &"Palette"
const FONT_SIZES := &"FontSizes"
const BOX_TYPE := &"Panel"

static var _cache: Theme = null

static func theme() -> Theme:
	if _cache == null:
		var t := load(THEME_PATH) as Theme
		if t == null:
			push_error("UITheme: тема не найдена: %s" % THEME_PATH)
			t = Theme.new()
		_cache = t
	return _cache

static func color(id: StringName, fallback: Color = Color.WHITE) -> Color:
	var t := theme()
	if t.has_color(id, PALETTE):
		return t.get_color(id, PALETTE)
	push_warning("UITheme: нет цвета '%s' в палитре" % id)
	return fallback

static func fsize(id: StringName, fallback: int = 14) -> int:
	var t := theme()
	if t.has_constant(id, FONT_SIZES):
		return t.get_constant(id, FONT_SIZES)
	return fallback

static func box(id: StringName) -> StyleBox:
	var t := theme()
	if t.has_stylebox(id, BOX_TYPE):
		return t.get_stylebox(id, BOX_TYPE)
	return null

## Применить вариацию панели (PanelContainer/Panel).
static func style_control(ctrl: Control, box_id: StringName) -> void:
	if ctrl == null:
		return
	var sb := box(box_id)
	if sb != null:
		ctrl.add_theme_stylebox_override("panel", sb)

static func tint(ctrl: Control, color_id: StringName) -> void:
	if ctrl == null:
		return
	ctrl.add_theme_color_override("font_color", color(color_id))

static func font(ctrl: Control, size_id: StringName) -> void:
	if ctrl == null:
		return
	ctrl.add_theme_font_size_override("font_size", fsize(size_id))

## StyleBox кнопки по состоянию (normal/hover/pressed/disabled) из дефолта темы.
static func button_box(state: StringName) -> StyleBox:
	return theme().get_stylebox(state, &"Button")
```

---

## 2. [High] ПОЛНАЯ ЗАМЕНА `res://assets/theme/game_theme.tres`

```
// FILE: res://assets/theme/game_theme.tres
[gd_resource type="Theme" load_steps=16 format=3]

[sub_resource type="StyleBoxFlat" id="sb_panel"]
bg_color = Color(0.16, 0.11, 0.06, 0.95)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.62, 0.47, 0.22, 1)

[sub_resource type="StyleBoxFlat" id="sb_panel_dark"]
bg_color = Color(0.08, 0.06, 0.04, 0.95)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.5, 0.38, 0.18, 1)

[sub_resource type="StyleBoxFlat" id="sb_panel_mid"]
bg_color = Color(0.3, 0.2, 0.12, 1)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.62, 0.47, 0.22, 1)

[sub_resource type="StyleBoxFlat" id="sb_slot"]
bg_color = Color(0.35, 0.24, 0.15, 1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.62, 0.47, 0.22, 0.6)

[sub_resource type="StyleBoxFlat" id="sb_slot_dark"]
bg_color = Color(0.12, 0.09, 0.06, 0.9)
corner_radius_top_left = 2
corner_radius_top_right = 2
corner_radius_bottom_right = 2
corner_radius_bottom_left = 2
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.62, 0.47, 0.22, 1)

[sub_resource type="StyleBoxFlat" id="sb_army"]
bg_color = Color(0.2, 0.15, 0.1, 0.9)
corner_radius_top_left = 2
corner_radius_top_right = 2
corner_radius_bottom_right = 2
corner_radius_bottom_left = 2
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.62, 0.47, 0.22, 1)

[sub_resource type="StyleBoxFlat" id="sb_btn"]
bg_color = Color(0.15, 0.35, 0.75, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.5, 0.9, 1)

[sub_resource type="StyleBoxFlat" id="sb_btn_hover"]
bg_color = Color(0.2, 0.45, 0.9, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.5, 0.9, 1)

[sub_resource type="StyleBoxFlat" id="sb_btn_pressed"]
bg_color = Color(0.1, 0.25, 0.6, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.5, 0.9, 1)

[sub_resource type="StyleBoxFlat" id="sb_btn_disabled"]
bg_color = Color(0.12, 0.12, 0.15, 0.6)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.35, 0.35, 0.4, 1)

[sub_resource type="StyleBoxFlat" id="sb_menu"]
bg_color = Color(0.15, 0.35, 0.75, 1)
corner_radius_top_left = 10
corner_radius_top_right = 10
corner_radius_bottom_right = 10
corner_radius_bottom_left = 10
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.3, 0.5, 0.9, 1)
shadow_color = Color(0.1, 0.2, 0.5, 0.5)
shadow_size = 4

[sub_resource type="StyleBoxFlat" id="sb_menu_hover"]
bg_color = Color(0.2, 0.45, 0.9, 1)
corner_radius_top_left = 10
corner_radius_top_right = 10
corner_radius_bottom_right = 10
corner_radius_bottom_left = 10
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.3, 0.5, 0.9, 1)
shadow_color = Color(0.1, 0.2, 0.5, 0.5)
shadow_size = 4

[sub_resource type="StyleBoxFlat" id="sb_menu_pressed"]
bg_color = Color(0.1, 0.25, 0.6, 1)
corner_radius_top_left = 10
corner_radius_top_right = 10
corner_radius_bottom_right = 10
corner_radius_bottom_left = 10
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.3, 0.5, 0.9, 1)

[sub_resource type="StyleBoxFlat" id="sb_outline"]
bg_color = Color(0, 0, 0, 0)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.9, 0.75, 0.4, 1)

[sub_resource type="StyleBoxFlat" id="sb_portrait"]
bg_color = Color(0.1, 0.08, 0.06, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.62, 0.47, 0.22, 1)

[resource]
default_font_size = 14
Label/colors/font_color = Color(0.95, 0.89, 0.72, 1)
Button/colors/font_color = Color(0.9, 0.95, 1, 1)
Button/colors/font_hover_color = Color(1, 1, 1, 1)
Button/colors/font_pressed_color = Color(0.9, 0.95, 1, 1)
Button/styles/normal = SubResource("sb_btn")
Button/styles/hover = SubResource("sb_btn_hover")
Button/styles/pressed = SubResource("sb_btn_pressed")
Button/styles/disabled = SubResource("sb_btn_disabled")
PanelContainer/styles/panel = SubResource("sb_panel")
Panel/styles/panel = SubResource("sb_panel")
Panel/styles/panel_dark = SubResource("sb_panel_dark")
Panel/styles/panel_mid = SubResource("sb_panel_mid")
Panel/styles/slot = SubResource("sb_slot")
Panel/styles/doll_slot = SubResource("sb_slot_dark")
Panel/styles/backpack_slot = SubResource("sb_slot_dark")
Panel/styles/side_slot = SubResource("sb_slot_dark")
Panel/styles/army_slot = SubResource("sb_army")
Panel/styles/action_button = SubResource("sb_btn")
Panel/styles/menu_button = SubResource("sb_menu")
Panel/styles/outline = SubResource("sb_outline")
Panel/styles/portrait = SubResource("sb_portrait")
FontSizes/constants/fs_tiny = 10
FontSizes/constants/fs_small = 12
FontSizes/constants/fs_body = 13
FontSizes/constants/fs_label = 14
FontSizes/constants/fs_heading = 16
FontSizes/constants/fs_big = 18
FontSizes/constants/fs_title = 22
FontSizes/constants/fs_hero = 26
FontSizes/constants/fs_huge = 30
Palette/colors/text = Color(0.95, 0.89, 0.72, 1)
Palette/colors/text_light = Color(0.85, 0.9, 1, 1)
Palette/colors/gold = Color(1, 0.85, 0.4, 1)
Palette/colors/gold_soft = Color(0.902, 0.812, 0.604, 1)
Palette/colors/gold_lighter = Color(0.941, 0.863, 0.678, 1)
Palette/colors/victory_gold = Color(0.92, 0.84, 0.55, 1)
Palette/colors/danger_muted = Color(0.75, 0.3, 0.28, 1)
Palette/colors/danger = Color(0.9, 0.2, 0.2, 1)
Palette/colors/warning = Color(1, 0.85, 0.1, 1)
Palette/colors/success = Color(0.2, 0.85, 0.2, 1)
Palette/colors/info_blue = Color(0.3, 0.7, 1, 1)
Palette/colors/attacker = Color(0.7, 0.85, 1, 1)
Palette/colors/defender = Color(1, 0.75, 0.7, 1)
Palette/colors/time_day = Color(0.4, 0.9, 0.4, 1)
Palette/colors/time_noon = Color(0.9, 0.9, 0.3, 1)
Palette/colors/time_evening = Color(0.9, 0.6, 0.2, 1)
Palette/colors/time_night = Color(0.3, 0.3, 0.8, 1)
Palette/colors/marker_green = Color(0.2, 0.85, 0.2, 0.75)
Palette/colors/marker_yellow = Color(1, 0.85, 0.1, 0.8)
Palette/colors/marker_red = Color(0.9, 0.2, 0.2, 0.6)
Palette/colors/city_fill = Color(0.62, 0.47, 0.9, 0.25)
Palette/colors/city_line = Color(0.8, 0.65, 1, 0.95)
Palette/colors/city_name = Color(1, 0.96, 0.85, 0.95)
Palette/colors/terrain_glyph = Color(0.95, 0.85, 0.4, 0.95)
Palette/colors/terrain_exhausted = Color(0.7, 0.7, 0.75, 0.9)
Palette/colors/hl_unreach = Color(0.9, 0.15, 0.15, 0.35)
Palette/colors/hl_move_fill = Color(0.2, 0.7, 1, 0.28)
Palette/colors/hl_move_line = Color(0.3, 0.9, 1, 0.95)
Palette/colors/hl_atk = Color(1, 0.25, 0.2, 0.95)
Palette/colors/cursor_default = Color(0.3, 0.7, 1, 0.9)
Palette/colors/cursor_attack = Color(1, 0.3, 0.22, 0.95)
Palette/colors/cursor_ranged = Color(1, 0.68, 0.2, 0.95)
Palette/colors/cursor_spell = Color(0.78, 0.42, 1, 0.95)
Palette/colors/cursor_move = Color(0.35, 1, 0.55, 0.98)
```

---

## 3. [High] Отключение цветовых констант в скриптах

### `AdventureUI.gd`
```gdscript
// FILE: res://scripts/ui/adventure_ui.gd  (заменить константы и функции)
# УДАЛИТЬ: const C_BG / const C_BORDER

func _ready() -> void:
	layer = 10
	# Панель теперь стилизуется дефолтом темы (PanelContainer/styles/panel).
	_border_check = _options_popup.get_node("BorderCheck/BorderCheckBox") as CheckBox
	if not _border_check.is_connected("toggled", _on_border_toggled):
		_border_check.toggled.connect(_on_border_toggled)
	var settings_btn := _options_popup.get_node("BorderCheck/SettingsButton") as Button
	if not settings_btn.is_connected("pressed", _on_open_settings):
		settings_btn.pressed.connect(_on_open_settings)
	var glory_box := get_node("RightColumn/Box/GloryBox") as VBoxContainer
	_glory_label = glory_box.get_node("GloryLabel") as Label
	_glory_bar = glory_box.get_node("GloryBar") as ProgressBar
	refresh_glory()
	if not GameEventBus.resource_extracted.is_connected(_on_resource_extracted):
		GameEventBus.resource_extracted.connect(_on_resource_extracted)

func _update_mp_display(current: float, max_val: float) -> void:
	var text := "🚶 %.1f / %.0f" % [current, max_val]
	var ratio: float = current / max_val if max_val > 0 else 0.0
	var col: Color
	if ratio >= 0.4:
		col = UITheme.color(&"success")
	elif ratio >= 0.1:
		col = UITheme.color(&"warning")
	else:
		col = UITheme.color(&"danger")
	_info.set_status_colored(text, col)
```

### `ArmyPanel.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/army_panel.gd
class_name ArmyPanel
extends PanelContainer

var _slots: Array[Panel] = []

func _ready() -> void:
	UITheme.style_control(self, &"panel_mid")
	var grid := get_node("Grid") as GridContainer
	for i in 8:
		var slot := grid.get_node("Slot%d" % i) as Panel
		UITheme.style_control(slot, &"slot")
		var ct := slot.get_node("HBox/Count") as Label
		UITheme.tint(ct, &"text")
		_slots.append(slot)

func update_army(army: Array[UnitStack]) -> void:
	for i in range(8):
		var hbox: HBoxContainer = _slots[i].get_node("HBox")
		var ic: TextureRect = hbox.get_node("Icon")
		var ct: Label = hbox.get_node("Count")
		if i < army.size():
			var stack = army[i]
			var key: String = stack.get_key()
			if key == "":
				key = stack.get_display_name().to_lower().replace(" ", "_")
			var portrait := UnitSprites.find_portrait_small(key)
			if portrait != "":
				ic.texture = load(portrait)
			else:
				ic.texture = null
			ct.text = str(stack.count)
		else:
			ic.texture = null
			ct.text = "0"
```

### `InfoPanel.gd`
```gdscript
// FILE: res://scripts/ui/info_panel.gd  (заменить константы и функции)
# УДАЛИТЬ: const THEME_PATH / const C_TEXT / const C_GOLD

func _apply_theme() -> void:
	for slot in _get_slot_nodes():
		UITheme.style_control(slot, &"slot")

func _connect_buttons() -> void:
	_end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
	UITheme.tint(_end_turn_btn, &"gold")
	_options_btn.pressed.connect(func(): options_requested.emit())

func set_time(hour: float) -> void:
	var h := int(floor(hour))
	var m := int(round((hour - floor(hour)) * 60))
	_time_label.text = "🕐 %02d:%02d" % [h, m]
	if hour >= 21.0:
		UITheme.tint(_time_label, &"time_night")
	elif hour >= 17.0:
		UITheme.tint(_time_label, &"time_evening")
	elif hour >= 11.0:
		UITheme.tint(_time_label, &"time_noon")
	else:
		UITheme.tint(_time_label, &"time_day")

func add_city(city_name: String) -> void:
	for i in _town_slots.size():
		var slot := get_node_or_null("columns/town_col/town_slot_%d" % i)
		if slot == null:
			continue
		if slot.get_child_count() == 0:
			var icon_node := slot.get_node_or_null("Icon")
			var name_node := slot.get_node_or_null("Name")
			if icon_node != null:
				icon_node.visible = false
			if name_node != null:
				name_node.text = "🏰 " + city_name
				UITheme.tint(name_node, &"text")
				name_node.clip_text = true
			return

func fill_hero_slot(idx: int, hero: HeroController) -> void:
	if idx >= _hero_slots.size():
		return
	var slot := get_node_or_null("columns/hero_col/hero_slot_%d" % idx)
	if slot == null:
		return
	var avatar_node := slot.get_node_or_null("Avatar") as TextureRect
	var name_node := slot.get_node_or_null("Name") as Label
	var av: Texture2D = hero.get_avatar_texture()
	if avatar_node != null:
		avatar_node.texture = av
		avatar_node.visible = av != null
	if name_node != null:
		name_node.text = hero.hero_name
		UITheme.tint(name_node, &"gold")
		name_node.clip_text = true
```

### `ResourceBar.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/resource_bar.gd
class_name ResourceBar
extends HBoxContainer

const ICONS := {
	"wood": "🪵", "mercury": "🧪", "ore": "🪨", "sulfur": "🟡",
	"crystal": "🔷", "gems": "💎", "gold": "🪙",
}

var _labels: Dictionary = {}

func _ready() -> void:
	for key in ICONS:
		var l := get_node(key.capitalize()) as Label
		UITheme.font(l, &"fs_small")
		UITheme.tint(l, &"text")
		_labels[key] = l

func update_resources(resources: Dictionary) -> void:
	for k in _labels:
		_labels[k].text = "%s%d" % [ICONS[k], resources.get(k, 0)]
```

### `CityPanel.gd`
```gdscript
// FILE: res://scripts/ui/CityPanel.gd  (заменить константы и кусок _ready)
# УДАЛИТЬ: const C_BG / const C_BORDER
# в _ready() заменить блок создания StyleBoxFlat на:
	UITheme.style_control(get_node("Panel") as Control, &"panel")
```

### `SettingsScreen.gd`
```gdscript
// FILE: res://scripts/ui/settings_screen.gd  (заменить константы и функции)
# УДАЛИТЬ: C_BG, C_BORDER, C_TEXT, C_TITLE, C_BTN_BG, C_BTN_HOVER, C_BTN_PRESS

func _apply_style() -> void:
	UITheme.style_control(get_node("Panel") as Control, &"panel_dark")
	var box := get_node("Panel/Box")
	for btn_name in ["ApplyButton", "ResetButton", "CancelButton"]:
		_style_button(box.get_node("ButtonRow/" + btn_name) as Button)

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", UITheme.button_box(&"normal"))
	btn.add_theme_stylebox_override("hover", UITheme.button_box(&"hover"))
	btn.add_theme_stylebox_override("pressed", UITheme.button_box(&"pressed"))
```

### `MainMenu.gd`
```gdscript
// FILE: res://scripts/ui/main_menu.gd  (заменить _style_buttons)
func _style_buttons() -> void:
	var buttons: Array[Button] = [
		_new_game_btn, _load_game_btn, _arena_btn,
		_model_warrior_btn, _model_mage_btn, _settings_btn,
		_chronicle_btn, _exit_btn
	]
	var sb_n := UITheme.box(&"menu_button")
	var sb_h := UITheme.box(&"menu_button")
	if sb_h != null:
		sb_h = sb_h.duplicate()
		(sb_h as StyleBoxFlat).bg_color = UITheme.color(&"btn_hover", Color(0.2, 0.45, 0.9))
	var sb_p := UITheme.box(&"menu_button")
	if sb_p != null:
		sb_p = sb_p.duplicate()
		(sb_p as StyleBoxFlat).bg_color = UITheme.color(&"btn_pressed", Color(0.1, 0.25, 0.6))
	for btn in buttons:
		if sb_n != null:
			btn.add_theme_stylebox_override("normal", sb_n)
		if sb_h != null:
			btn.add_theme_stylebox_override("hover", sb_h)
		if sb_p != null:
			btn.add_theme_stylebox_override("pressed", sb_p)
		btn.mouse_entered.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_hover"))
		btn.pressed.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_click"))
		_UIAnimator.setup_button(btn)
```
(цвета `btn_hover`/`btn_pressed` добавить в палитру темы — см. runbook; fallback в вызове защищает от пропуска.)

Дополнить палитру в `game_theme.tres`:
```
Palette/colors/btn_hover = Color(0.2, 0.45, 0.9, 1)
Palette/colors/btn_pressed = Color(0.1, 0.25, 0.6, 1)
```

### `BattleUI.gd`
```gdscript
// FILE: res://scripts/ui/battle_ui.gd  (заменить цветовой блок в _connect_skeleton)
	if _status != null:
		UITheme.tint(_status, &"text")
	if _active_info != null:
		UITheme.tint(_active_info, &"text_light")
	if _preview != null:
		UITheme.tint(_preview, &"gold")
```
Также `_apply_theme` можно упростить до `UITheme.style_control(tp, &"panel")` / `UITheme.style_control(ip, &"panel")`.

### `ArtifactInventoryScreen.gd`
```gdscript
// FILE: res://scripts/ui/artifact_inventory_screen.gd  (заменить константы)
# УДАЛИТЬ: const TEXT_GOLD / const TEXT_LIGHT
var TEXT_GOLD: Color = UITheme.color(&"gold_soft")
var TEXT_LIGHT: Color = UITheme.color(&"gold_lighter")
```
(в `_ready` и `_build_bottom` использование без изменений — теперь берётся из темы.)

### `BattleSpellbookPanel.gd`
```gdscript
// FILE: res://scripts/ui/battle_spellbook_panel.gd  (заменить в _refresh)
		btn.add_theme_color_override("font_color", UITheme.color(&"gold_soft"))
```
и `_apply_theme`: `var sb := UITheme.box(&"panel")`.

### `DeathSequence.gd` / `GameOverScreen.gd`
```gdscript
// FILE: res://scripts/ui/death_sequence.gd  (заменить цвета заголовка в show_death)
	if successor == null:
		title.text = "%s — цикл оборвался" % deceased_name
		UITheme.tint(title, &"danger_muted")
	else:
		title.text = "%s — цикл продолжится" % deceased_name
		UITheme.tint(title, &"victory_gold")

// FILE: res://scripts/ui/game_over_screen.gd  (заменить в show_result)
	UITheme.tint(title, &"victory_gold") if result == "VICTORY" else UITheme.tint(title, &"danger_muted")
```
(тернарник с вызовами допустим; если стиль требует — развернуть в if/else.)

### Оверлеи мира (canvas-цвета из палитры)

```gdscript
// FILE: res://scripts/ui/marker_layer.gd  (заменить константы)
# УДАЛИТЬ: _COLOR_GREEN / _COLOR_YELLOW / _COLOR_RED
# в _draw() использовать:
	UITheme.color(&"marker_green") / (&"marker_yellow") / (&"marker_red")
	UITheme.color(&"city_fill") / (&"city_line") / (&"city_name")
	UITheme.color(&"terrain_glyph") / (&"terrain_exhausted")

// FILE: res://scripts/ui/highlight_overlay.gd  (заменить в _draw)
	UITheme.color(&"hl_unreach") / (&"hl_move_fill") / (&"hl_move_line") / (&"hl_atk")

// FILE: res://scripts/ui/cursor_overlay.gd  (заменить в _draw)
	UITheme.color(&"cursor_default") / (&"cursor_attack") / (&"cursor_ranged") / (&"cursor_spell") / (&"cursor_move")
```

---

## Runbook

1. Создать `res://scripts/ui/UITheme.gd`; перезаписать `res://assets/theme/game_theme.tres` (добавить `btn_hover`/`btn_pressed` в палитру).
2. `project.godot` — подключить тему глобально:
   ```
   [gui]
   theme/custom="res://assets/theme/game_theme.tres"
   ```
3. Применить замены скриптов по списку выше; удалить цветовые константы (`C_BG`, `C_BORDER`, `C_TEXT`, `C_GOLD`, `C_SLOT_BG`, `TEXT_GOLD`, `TEXT_LIGHT`, `_COLOR_*`).
4. Проверка:
   - `godot --headless --script res://tests/run_tests.gd` (если есть) — регрессий нет.
   - В редакторе: MainMenu → все кнопки синие с тенью; World → правая панель пергаментная, слоты героя/городов с рамкой; бой → статус/превью окрашены, инициатива читается; Settings → тёмная панель; инвентарь → золотой текст.
   - Сменить любой цвет в `game_theme.tres` (например, `Palette/colors/gold`) → все места, включая маркеры досягаемости и MP-индикатор, меняются без правок кода.

## Итоговая таблица

| № | Файл | Суть изменения | Приоритет |
|---|------|----------------|-----------|
| 1 | `scripts/ui/UITheme.gd` | Новый статический фасад темы (color/fsize/box/tint/style_control) | High |
| 2 | `assets/theme/game_theme.tres` | Единая палитра, размеры шрифтов, все StyleBox + дефолты Label/Button/PanelContainer | High |
| 3 | `project.godot` | `gui/theme/custom` — глобальное наследование стилей | High |
| 4 | `scripts/ui/AdventureUI.gd` | Убраны C_BG/C_BORDER и StyleBoxFlat; MP-цвета из палитры | High |
| 5 | `scripts/ui/ArmyPanel.gd` | StyleBox/цвета из темы | Medium |
| 6 | `scripts/ui/InfoPanel.gd` | Цвета текста/времени из палитры | Medium |
| 7 | `scripts/ui/ResourceBar.gd` | Цвет/размер из темы | Medium |
| 8 | `scripts/ui/CityPanel.gd` | StyleBox из темы | Medium |
| 9 | `scripts/ui/SettingsScreen.gd` | Константы → тема | Medium |
| 10 | `scripts/ui/MainMenu.gd` | Кнопки из вариации `menu_button` | Medium |
| 11 | `scripts/ui/BattleUI.gd` | Цвета статусов из палитры | Medium |
| 12 | `scripts/ui/ArtifactInventoryScreen.gd` | TEXT_GOLD/TEXT_LIGHT из палитры | Medium |
| 13 | `scripts/ui/BattleSpellbookPanel.gd` | Цвет кнопок заклинаний из палитры | Low |
| 14 | `scripts/ui/DeathSequence.gd`, `GameOverScreen.gd` | Цвета заголовков из палитры | Low |
| 15 | `scripts/ui/MarkerLayer.gd`, `HighlightOverlay.gd`, `CursorOverlay.gd` | Canvas-цвета оверлеев из палитры | Medium |

Не трогал осознанно: `MinimapPanel.MINIMAP_COLORS` — это данные визуализации terrain-id→цвет, а не оформление UI; при желании выносятся в `Palette` тем же механизмом.


Принято, исправляю: все идентификаторы палитры/стилей/размеров становятся **enum'ами**. Строковые имена для `Theme` выводятся из имён enum (`keys()[id].to_lower()`) — это единственный мост, сосредоточенный внутри `UITheme`; в вызовах и в `.tres`-логике текстовых констант больше нет.

---

## 1. [High] ПОЛНАЯ ЗАМЕНА `res://scripts/ui/UITheme.gd`

```gdscript
// FILE: res://scripts/ui/UITheme.gd
class_name UITheme
extends RefCounted

## Единая точка доступа к оформлению. Все идентификаторы — enum'ы;
## строковые ключи Theme выводятся из имён enum, текстовых констант нет.
const THEME_PATH := "res://assets/theme/game_theme.tres"

const PALETTE_TYPE := &"Palette"
const SIZES_TYPE := &"FontSizes"
const BOX_TYPE := &"Panel"

enum ColorID {
	TEXT, TEXT_LIGHT,
	GOLD, GOLD_SOFT, GOLD_LIGHTER, VICTORY_GOLD,
	DANGER, DANGER_MUTED, WARNING, SUCCESS, INFO_BLUE,
	ATTACKER, DEFENDER, THREAT,
	TIME_DAY, TIME_NOON, TIME_EVENING, TIME_NIGHT,
	MARKER_GREEN, MARKER_YELLOW, MARKER_RED,
	CITY_FILL, CITY_LINE, CITY_NAME,
	TERRAIN_GLYPH, TERRAIN_EXHAUSTED,
	HL_UNREACH, HL_MOVE_FILL, HL_MOVE_LINE, HL_ATK,
	CURSOR_DEFAULT, CURSOR_ATTACK, CURSOR_RANGED, CURSOR_SPELL, CURSOR_MOVE,
	BTN_HOVER, BTN_PRESSED,
}

enum SizeID {
	FS_TINY, FS_SMALL, FS_BODY, FS_LABEL, FS_HEADING,
	FS_BIG, FS_TITLE, FS_HERO, FS_HUGE,
}

enum BoxID {
	PANEL, PANEL_DARK, PANEL_MID,
	SLOT, SLOT_DARK, ARMY_SLOT,
	DOLL_SLOT, BACKPACK_SLOT, SIDE_SLOT,
	ACTION_BUTTON, MENU_BUTTON, OUTLINE, PORTRAIT,
}

enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED, FOCUS }

static var _cache: Theme = null

static func theme() -> Theme:
	if _cache == null:
		var t := load(THEME_PATH) as Theme
		if t == null:
			push_error("UITheme: тема не найдена: %s" % THEME_PATH)
			t = Theme.new()
		_cache = t
	return _cache

static func color_name(id: int) -> StringName:
	if id < 0 or id >= ColorID.size():
		push_error("UITheme: неизвестный ColorID %d" % id)
		return &""
	return StringName(ColorID.keys()[id].to_lower())

static func size_name(id: int) -> StringName:
	if id < 0 or id >= SizeID.size():
		return &""
	return StringName(SizeID.keys()[id].to_lower())

static func box_name(id: int) -> StringName:
	if id < 0 or id >= BoxID.size():
		return &""
	return StringName(BoxID.keys()[id].to_lower())

static func color(id: int, fallback: Color = Color.WHITE) -> Color:
	var t := theme()
	var n := color_name(id)
	if n == &"" or not t.has_color(n, PALETTE_TYPE):
		return fallback
	return t.get_color(n, PALETTE_TYPE)

static func fsize(id: int, fallback: int = 14) -> int:
	var t := theme()
	var n := size_name(id)
	if n == &"" or not t.has_constant(n, SIZES_TYPE):
		return fallback
	return t.get_constant(n, SIZES_TYPE)

static func box(id: int) -> StyleBox:
	var t := theme()
	var n := box_name(id)
	if n == &"" or not t.has_stylebox(n, BOX_TYPE):
		return null
	return t.get_stylebox(n, BOX_TYPE)

static func style_control(ctrl: Control, box_id: int) -> void:
	if ctrl == null:
		return
	var sb := box(box_id)
	if sb != null:
		ctrl.add_theme_stylebox_override("panel", sb)

static func tint(ctrl: Control, color_id: int) -> void:
	if ctrl == null:
		return
	ctrl.add_theme_color_override("font_color", color(color_id))

static func font(ctrl: Control, size_id: int) -> void:
	if ctrl == null:
		return
	ctrl.add_theme_font_size_override("font_size", fsize(size_id))

static func button_box(state: int) -> StyleBox:
	var n := StringName(ButtonState.keys()[state].to_lower())
	return theme().get_stylebox(n, &"Button")
```

## 2. [Medium] Доп. ключ в `game_theme.tres`

Добавить одну строку в секцию `[resource]` (имя = `ColorID.THREAT`.to_lower()):

```
// FILE: res://assets/theme/game_theme.tres  (добавить в [resource])
Palette/colors/threat = Color(0.95, 0.25, 0.2, 0.85)
```

---

## 3. [High] Исправленные вызовы (без текстовых ключей)

### `AdventureUI.gd`
```gdscript
// FILE: res://scripts/ui/adventure_ui.gd  (заменить константы C_BG/C_BORDER и функции)
func _ready() -> void:
	layer = 10
	UITheme.style_control(get_node("RightColumn") as Control, UITheme.BoxID.PANEL)
	_border_check = _options_popup.get_node("BorderCheck/BorderCheckBox") as CheckBox
	if not _border_check.is_connected("toggled", _on_border_toggled):
		_border_check.toggled.connect(_on_border_toggled)
	var settings_btn := _options_popup.get_node("BorderCheck/SettingsButton") as Button
	if not settings_btn.is_connected("pressed", _on_open_settings):
		settings_btn.pressed.connect(_on_open_settings)
	var glory_box := get_node("RightColumn/Box/GloryBox") as VBoxContainer
	_glory_label = glory_box.get_node("GloryLabel") as Label
	_glory_bar = glory_box.get_node("GloryBar") as ProgressBar
	refresh_glory()
	if not GameEventBus.resource_extracted.is_connected(_on_resource_extracted):
		GameEventBus.resource_extracted.connect(_on_resource_extracted)

func _update_mp_display(current: float, max_val: float) -> void:
	var text := "🚶 %.1f / %.0f" % [current, max_val]
	var ratio: float = current / max_val if max_val > 0 else 0.0
	var col_id: int
	if ratio >= 0.4:
		col_id = UITheme.ColorID.SUCCESS
	elif ratio >= 0.1:
		col_id = UITheme.ColorID.WARNING
	else:
		col_id = UITheme.ColorID.DANGER
	_info.set_status_colored(text, UITheme.color(col_id))
```

### `ArmyPanel.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/army_panel.gd
class_name ArmyPanel
extends PanelContainer

var _slots: Array[Panel] = []

func _ready() -> void:
	UITheme.style_control(self, UITheme.BoxID.PANEL_MID)
	var grid := get_node("Grid") as GridContainer
	for i in 8:
		var slot := grid.get_node("Slot%d" % i) as Panel
		UITheme.style_control(slot, UITheme.BoxID.SLOT)
		UITheme.tint(slot.get_node("HBox/Count") as Label, UITheme.ColorID.TEXT)
		_slots.append(slot)

func update_army(army: Array[UnitStack]) -> void:
	for i in range(8):
		var hbox: HBoxContainer = _slots[i].get_node("HBox")
		var ic: TextureRect = hbox.get_node("Icon")
		var ct: Label = hbox.get_node("Count")
		if i < army.size():
			var stack = army[i]
			var key: String = stack.get_key()
			if key == "":
				key = stack.get_display_name().to_lower().replace(" ", "_")
			var portrait := UnitSprites.find_portrait_small(key)
			ic.texture = load(portrait) if portrait != "" else null
			ct.text = str(stack.count)
		else:
			ic.texture = null
			ct.text = "0"
```

### `ResourceBar.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/resource_bar.gd
class_name ResourceBar
extends HBoxContainer

const ICONS: Array[String] = ["🪵", "", "", "🟡", "", "", "🪙"]

var _labels: Dictionary = {}

func _ready() -> void:
	for id in ResourceType.classic_ids():
		var l := get_node(ResourceType.to_key(id).capitalize()) as Label
		UITheme.font(l, UITheme.SizeID.FS_SMALL)
		UITheme.tint(l, UITheme.ColorID.TEXT)
		_labels[id] = l

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		_labels[id].text = "%s%d" % [ICONS[int(id)], int(resources.get(id, 0))]
```

### `InfoPanel.gd`
```gdscript
// FILE: res://scripts/ui/info_panel.gd  (удалить C_TEXT/C_GOLD; заменить функции)
func _apply_theme() -> void:
	for slot in _get_slot_nodes():
		UITheme.style_control(slot, UITheme.BoxID.SLOT)

func _connect_buttons() -> void:
	_end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
	UITheme.tint(_end_turn_btn, UITheme.ColorID.GOLD)
	_options_btn.pressed.connect(func(): options_requested.emit())

func set_time(hour: float) -> void:
	var h := int(floor(hour))
	var m := int(round((hour - floor(hour)) * 60))
	_time_label.text = "🕐 %02d:%02d" % [h, m]
	var col_id: int
	if hour >= 21.0:
		col_id = UITheme.ColorID.TIME_NIGHT
	elif hour >= 17.0:
		col_id = UITheme.ColorID.TIME_EVENING
	elif hour >= 11.0:
		col_id = UITheme.ColorID.TIME_NOON
	else:
		col_id = UITheme.ColorID.TIME_DAY
	UITheme.tint(_time_label, col_id)

func add_city(city_name: String) -> void:
	for i in _town_slots.size():
		var slot := get_node_or_null("columns/town_col/town_slot_%d" % i)
		if slot == null:
			continue
		if slot.get_child_count() == 0:
			var icon_node := slot.get_node_or_null("Icon")
			var name_node := slot.get_node_or_null("Name")
			if icon_node != null:
				icon_node.visible = false
			if name_node != null:
				name_node.text = "🏰 " + city_name
				UITheme.tint(name_node, UITheme.ColorID.TEXT)
				name_node.clip_text = true
			return

func fill_hero_slot(idx: int, hero: HeroController) -> void:
	if idx >= _hero_slots.size():
		return
	var slot := get_node_or_null("columns/hero_col/hero_slot_%d" % idx)
	if slot == null:
		return
	var avatar_node := slot.get_node_or_null("Avatar") as TextureRect
	var name_node := slot.get_node_or_null("Name") as Label
	var av: Texture2D = hero.get_avatar_texture()
	if avatar_node != null:
		avatar_node.texture = av
		avatar_node.visible = av != null
	if name_node != null:
		name_node.text = hero.hero_name
		UITheme.tint(name_node, UITheme.ColorID.GOLD)
		name_node.clip_text = true
```

### `CityPanel.gd`
```gdscript
// FILE: res://scripts/ui/CityPanel.gd  (удалить C_BG/C_BORDER; в _ready() заменить блок StyleBoxFlat)
	UITheme.style_control(get_node("Panel") as Control, UITheme.BoxID.PANEL)
```

### `SettingsScreen.gd`
```gdscript
// FILE: res://scripts/ui/settings_screen.gd  (удалить все C_*; заменить функции)
func _apply_style() -> void:
	UITheme.style_control(get_node("Panel") as Control, UITheme.BoxID.PANEL_DARK)
	var box := get_node("Panel/Box")
	for btn_name in ["ApplyButton", "ResetButton", "CancelButton"]:
		_style_button(box.get_node("ButtonRow/" + btn_name) as Button)

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ButtonState.NORMAL))
	btn.add_theme_stylebox_override("hover", UITheme.button_box(UITheme.ButtonState.HOVER))
	btn.add_theme_stylebox_override("pressed", UITheme.button_box(UITheme.ButtonState.PRESSED))
```

### `MainMenu.gd`
```gdscript
// FILE: res://scripts/ui/main_menu.gd  (заменить _style_buttons)
func _style_buttons() -> void:
	var buttons: Array[Button] = [
		_new_game_btn, _load_game_btn, _arena_btn,
		_model_warrior_btn, _model_mage_btn, _settings_btn,
		_chronicle_btn, _exit_btn
	]
	var sb_n := UITheme.box(UITheme.BoxID.MENU_BUTTON)
	var sb_h: StyleBox = sb_n.duplicate() if sb_n != null else null
	if sb_h != null:
		(sb_h as StyleBoxFlat).bg_color = UITheme.color(UITheme.ColorID.BTN_HOVER)
	var sb_p: StyleBox = sb_n.duplicate() if sb_n != null else null
	if sb_p != null:
		(sb_p as StyleBoxFlat).bg_color = UITheme.color(UITheme.ColorID.BTN_PRESSED)
	for btn in buttons:
		if sb_n != null:
			btn.add_theme_stylebox_override("normal", sb_n)
		if sb_h != null:
			btn.add_theme_stylebox_override("hover", sb_h)
		if sb_p != null:
			btn.add_theme_stylebox_override("pressed", sb_p)
		UITheme.tint(btn, UITheme.ColorID.TEXT_LIGHT)
		btn.mouse_entered.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_hover"))
		btn.pressed.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_click"))
		_UIAnimator.setup_button(btn)
```

### `BattleUI.gd`
```gdscript
// FILE: res://scripts/ui/battle_ui.gd  (заменить _apply_theme и цветовой блок _connect_skeleton)
func _apply_theme() -> void:
	UITheme.style_control(get_node_or_null("top_panel") as Control, UITheme.BoxID.PANEL)
	UITheme.style_control(get_node_or_null("initiative_panel") as Control, UITheme.BoxID.PANEL)

# внутри _connect_skeleton() заменить три add_theme_color_override на:
	if _status != null:
		UITheme.tint(_status, UITheme.ColorID.TEXT)
	if _active_info != null:
		UITheme.tint(_active_info, UITheme.ColorID.TEXT_LIGHT)
	if _preview != null:
		UITheme.tint(_preview, UITheme.ColorID.GOLD)
```

### `BattleSpellbookPanel.gd`
```gdscript
// FILE: res://scripts/ui/battle_spellbook_panel.gd  (заменить _apply_theme и строки _refresh)
func _apply_theme() -> void:
	UITheme.style_control(self, UITheme.BoxID.PANEL)

# в _refresh() заменить stylebox/цвет кнопки:
		var bsb := UITheme.box(UITheme.BoxID.ACTION_BUTTON)
		if bsb != null:
			btn.add_theme_stylebox_override("panel", bsb)
		btn.add_theme_color_override("font_color", UITheme.color(UITheme.ColorID.GOLD_SOFT))
```

### `ArtifactInventoryScreen.gd`
```gdscript
// FILE: res://scripts/ui/artifact_inventory_screen.gd
# УДАЛИТЬ: const TEXT_GOLD / const TEXT_LIGHT — заменить на:
var TEXT_GOLD: Color = UITheme.color(UITheme.ColorID.GOLD_SOFT)
var TEXT_LIGHT: Color = UITheme.color(UITheme.ColorID.GOLD_LIGHTER)

# заменить _apply_theme / _style / _theme_font_size / _set_style_slot:
func _apply_theme() -> void:
	UITheme.style_control(get_node_or_null("Center/Window"), UITheme.BoxID.PANEL)
	UITheme.style_control(get_node_or_null("Center/Window/Outline"), UITheme.BoxID.OUTLINE)
	UITheme.style_control(get_node_or_null("Center/Window/Left"), UITheme.BoxID.PANEL)
	UITheme.style_control(get_node_or_null("Center/Window/Right"), UITheme.BoxID.PANEL)
	UITheme.style_control(get_node_or_null("Center/Window/Side"), UITheme.BoxID.PANEL)
	UITheme.style_control(get_node_or_null("Center/Window/Bottom"), UITheme.BoxID.PANEL)
	UITheme.style_control(get_node_or_null("Center/Window/Left/Portrait"), UITheme.BoxID.PORTRAIT)
	for i in 4:
		UITheme.style_control(get_node_or_null("Center/Window/Left/StatIcon_%d" % i), UITheme.BoxID.SLOT)
	for i in 16:
		UITheme.style_control(get_node_or_null("Center/Window/Right/DollSlot_%d" % i), UITheme.BoxID.DOLL_SLOT)
	for i in 6:
		UITheme.style_control(get_node_or_null("Center/Window/Right/Inventory/BackpackSlot_%d" % i), UITheme.BoxID.BACKPACK_SLOT)
	for p in ["Center/Window/Right/Equip", "Center/Window/Right/Remove",
			"Center/Window/Right/Dispose", "Center/Window/Right/Inventory/Prev",
			"Center/Window/Right/Inventory/Next", "Center/Window/Side/Ok"]:
		UITheme.style_control(get_node_or_null(p), UITheme.BoxID.ACTION_BUTTON)
	for i in 6:
		UITheme.style_control(get_node_or_null("Center/Window/Side/SideSlot_%d" % i), UITheme.BoxID.SIDE_SLOT)
	for i in 7:
		UITheme.style_control(get_node_or_null("Center/Window/Bottom/ArmySlot_%d" % i), UITheme.BoxID.ARMY_SLOT)
	for i in 4:
		UITheme.style_control(get_node_or_null("Center/Window/Bottom/Formations/Form_%d" % i), UITheme.BoxID.ACTION_BUTTON)

func _theme_font_size(path: String, size_id: int) -> void:
	UITheme.font(get_node_or_null(path), size_id)

func _set_style_slot(slot: Button, has: bool) -> void:
	UITheme.style_control(slot, UITheme.BoxID.ACTION_BUTTON if has else UITheme.BoxID.SLOT)
```
Во всех вызовах `_theme_font_size(...)` заменить строковые аргументы: `"small"` → `UITheme.SizeID.FS_LABEL`, `"default"`/`"stat"` → `UITheme.SizeID.FS_HEADING`, `"large"` → `UITheme.SizeID.FS_TITLE`.

### `DeathSequence.gd` / `GameOverScreen.gd`
```gdscript
// FILE: res://scripts/ui/death_sequence.gd  (в show_death заменить цвета заголовка)
	if successor == null:
		title.text = "%s — цикл оборвался" % deceased_name
		UITheme.tint(title, UITheme.ColorID.DANGER_MUTED)
	else:
		title.text = "%s — цикл продолжится" % deceased_name
		UITheme.tint(title, UITheme.ColorID.VICTORY_GOLD)

// FILE: res://scripts/ui/game_over_screen.gd  (в show_result)
	UITheme.tint(title, UITheme.ColorID.VICTORY_GOLD if result == "VICTORY" else UITheme.ColorID.DANGER_MUTED)
```

### `MarkerLayer.gd`
```gdscript
// FILE: res://scripts/ui/marker_layer.gd  (удалить _COLOR_*; заменить цвета в _draw)
func _draw() -> void:
	if not _map_gen or not _map_gen.has_valid_tilemap():
		return
	var pulse_t: float = Time.get_ticks_msec() / 1000.0
	for pos in _threat_pos:
		var ring_r: float = _hex_size * (0.30 + 0.08 * sin(pulse_t * 4.0))
		draw_arc(pos, ring_r, 0.0, TAU, 32, UITheme.color(UITheme.ColorID.THREAT), 2.5)
	for m in _city_marks:
		var pos: Vector2 = m.pos
		draw_circle(pos, _hex_size * 0.22, UITheme.color(UITheme.ColorID.CITY_FILL))
		draw_arc(pos, _hex_size * 0.22, 0.0, TAU, 32, UITheme.color(UITheme.ColorID.CITY_LINE), 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(0.0, -_hex_size * 0.30),
			m.city.display_name, HORIZONTAL_ALIGNMENT_CENTER,
			int(_hex_size * 2.0), 14, UITheme.color(UITheme.ColorID.CITY_NAME))
	for cell in _terrain_pos:
		var m: Dictionary = _terrain_pos[cell]
		var glyph: String = "✗" if m["exhausted"] else "⛏️"
		var col_id: int = UITheme.ColorID.TERRAIN_EXHAUSTED if m["exhausted"] else UITheme.ColorID.TERRAIN_GLYPH
		draw_string(ThemeDB.fallback_font, m["pos"], glyph, HORIZONTAL_ALIGNMENT_CENTER,
			int(_hex_size * 1.6), 14, UITheme.color(col_id))
	if not _visible:
		return
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 0.15
	var r_green: float = _hex_size * 0.18 * pulse
	for pos in _green_pos:
		draw_circle(pos, r_green, UITheme.color(UITheme.ColorID.MARKER_GREEN))
	for pos in _yellow_pos:
		draw_circle(pos, _hex_size * 0.10, UITheme.color(UITheme.ColorID.MARKER_YELLOW))
	for pos in _red_pos:
		draw_circle(pos, _hex_size * 0.08, UITheme.color(UITheme.ColorID.MARKER_RED))
```

### `HighlightOverlay.gd` / `CursorOverlay.gd`
```gdscript
// FILE: res://scripts/ui/highlight_overlay.gd  (заменить _draw)
func _draw() -> void:
	if tm == null:
		return
	for k in unreachable_cells:
		_hex_fill(tm.map_to_local(k), UITheme.color(UITheme.ColorID.HL_UNREACH))
	for k in move_cells:
		_hex_fill(tm.map_to_local(k), UITheme.color(UITheme.ColorID.HL_MOVE_FILL))
	for k in move_cells:
		_hex(tm.map_to_local(k), UITheme.color(UITheme.ColorID.HL_MOVE_LINE))
	for k in atk_cells:
		_hex(tm.map_to_local(k), UITheme.color(UITheme.ColorID.HL_ATK))

// FILE: res://scripts/ui/cursor_overlay.gd  (заменить _draw)
func _draw() -> void:
	if not visible_flag:
		return
	match mode:
		BattleView.CursorMode.DEFAULT:
			_reticle()
		BattleView.CursorMode.ATTACK:
			_sword(UITheme.color(UITheme.ColorID.CURSOR_ATTACK))
		BattleView.CursorMode.RANGED:
			_arrow(UITheme.color(UITheme.ColorID.CURSOR_RANGED))
		BattleView.CursorMode.SPELL:
			_wand(UITheme.color(UITheme.ColorID.CURSOR_SPELL))
		BattleView.CursorMode.MOVE:
			_boot(UITheme.color(UITheme.ColorID.CURSOR_MOVE))

func _reticle() -> void:
	var col := UITheme.color(UITheme.ColorID.CURSOR_DEFAULT)
	var pts := PackedVector2Array()
	for i in 20:
		var ang := deg_to_rad(18.0 * i)
		pts.append(mouse_pos + Vector2(cos(ang), sin(ang)) * 13.0)
	draw_polyline(pts, col, 2.0)
	draw_circle(mouse_pos, 2.5, col)
```

---

## Runbook

1. Перезаписать `res://scripts/ui/UITheme.gd` (enum'ы ColorID/SizeID/BoxID/ButtonState).
2. В `res://assets/theme/game_theme.tres` добавить `Palette/colors/threat`; остальные ключи уже совпадают с `enum.to_lower()` (text, gold_soft, gold_lighter, fs_*, panel_* и т.д.).
3. Применить замены вызовов по списку выше; grep-проверка: `rg "&\"gold|&\"text|&\"panel|&\"slot|&\"marker|&\"cursor|&\"hl_|&\"time_|&\"city_|&\"terrain_|&\"btn_|&\"fs_" scripts/ui` должен вернуть 0 совпадений (строки остались только внутри `UITheme` через `keys().to_lower()`).
4. Приёмка: открыть MainMenu, World, бой, инвентарь — оформление идентично прошлому; изменение значения `gold_lighter` в `.tres` меняет цвет текста инвентаря без правок кода.

## Итоговая таблица

| № | Файл | Суть изменения | Приоритет |
|---|------|----------------|-----------|
| 1 | `scripts/ui/UITheme.gd` | Enum'ы ColorID/SizeID/BoxID/ButtonState; имена Theme выводятся из enum | High |
| 2 | `assets/theme/game_theme.tres` | Добавлен ключ `threat` | Medium |
| 3 | `scripts/ui/AdventureUI.gd` | Удалены C_BG/C_BORDER; вызовы через enum | High |
| 4 | `scripts/ui/ArmyPanel.gd` | Полная замена: стили/цвета через enum | High |
| 5 | `scripts/ui/ResourceBar.gd` | Полная замена: ResourceType + UITheme enum | High |
| 6 | `scripts/ui/InfoPanel.gd` | C_TEXT/C_GOLD → enum | High |
| 7 | `scripts/ui/CityPanel.gd` | C_BG/C_BORDER → BoxID.PANEL | Medium |
| 8 | `scripts/ui/SettingsScreen.gd` | C_* → BoxID/ButtonState | Medium |
| 9 | `scripts/ui/MainMenu.gd` | StyleBox-литералы → BoxID.MENU_BUTTON + BTN_* | Medium |
| 10 | `scripts/ui/BattleUI.gd` | Цвета статусов → ColorID | Medium |
| 11 | `scripts/ui/BattleSpellbookPanel.gd` | GOLD_SOFT + ACTION_BUTTON через enum | Medium |
| 12 | `scripts/ui/ArtifactInventoryScreen.gd` | TEXT_GOLD/TEXT_LIGHT и все style-строки → enum | High |
| 13 | `scripts/ui/DeathSequence.gd`, `GameOverScreen.gd` | Цвета заголовков → ColorID | Low |
| 14 | `scripts/ui/MarkerLayer.gd` | _COLOR_* → ColorID | Medium |
| 15 | `scripts/ui/HighlightOverlay.gd`, `CursorOverlay.gd` | Цвета оверлеев → ColorID | Medium |

Принято: глифы — это тоже оформление. Создаю единый класс `ThemeIcons` (enum `IconID` + единственный словарь глифов) и переписываю все места, где эмодзи захардкожены: скрипты берут глифы только из `ThemeIcons`, а `.tscn` очищаются от вшитых эмодзи и получают их в рантайме — меняешь глиф в одном месте, обновляется всё дерево.

---

## 1. [High] НОВЫЙ ФАЙЛ `res://scripts/ui/ThemeIcons.gd`

```gdscript
// FILE: res://scripts/ui/ThemeIcons.gd
class_name ThemeIcons
extends RefCounted

## Единый источник глифов оформления. Замена глифа здесь меняет все UI сразу.
enum IconID {
	# Классические ресурсы (подбор на карте)
	WOOD, MERCURY, ORE, SULFUR, CRYSTAL, GEMS, GOLD,
	# Стратегические / скрытые ресурсы
	TREE, STONE, SILVER, QUARTZ, SALTPETER, TURQUOISE,
	LIMONITE, COAL, GOLD_ORE, BOG_IRON, CINNABAR,
	# Потребности
	REST, SOCIAL, INSPIRATION,
	# Характеристики
	ATTACK, DEFENSE, KNOWLEDGE, SPELL_POWER, HP, MANA, MOVEMENT,
	# Население
	WORKER, MILITIA, FOLLOWER, SCHOLAR, PATROL, HERO, POPULATION,
	# Здания арены
	CENTER, FARM, MILL, BAKERY, MINE, SMITHY, TAVERN,
	TRADE_POST, MARKET, SHACK, WALLS, DISTRICT,
	# Выходы
	FOOD, INDUSTRY, DUST, SCIENCE, INFLUENCE,
	# Панели
	CLOCK, CROWN, STAR, PROSPERITY, REPUTATION,
	STORM, FAMINE, CLUSTER, STORAGE, SKILLS, TOOLS,
	# Действия
	CASTLE, FLAG, CAMP, STABLE, SHIP, FORGE, SCOUT, ARMY,
	JOURNAL, END_TURN, KINGDOM, OPTIONS,
	RETREAT, WAIT, SPELLBOOK,
	TURN_NEXT, AUTO_PLAY, HIRE, LEVEL_UP, RESET, HOME, CLOSE,
	FLAG_CAPTURED, TAKE,
	# Инструменты
	SHOVEL, PICKAXE, CART, SKIN_PROTECTION, NET,
	# Исходы
	VICTORY, DEFEAT, SUCCESSION,
	# Карта / бой
	OBSTACLE_ROCK, OBSTACLE_TREE, MARK_EXHAUSTED, MARK_PICK,
	COST_INDUSTRY, COST_GOLD,
	# Меню
	ARENA, MODEL_WARRIOR, MODEL_MAGE, CHRONICLE,
}

## ЕДИНСТВЕННОЕ место, где живут глифы.
const _GLYPHS: Dictionary = {
	IconID.WOOD: "🪵", IconID.MERCURY: "🧪", IconID.ORE: "🪨",
	IconID.SULFUR: "🟡", IconID.CRYSTAL: "🔷", IconID.GEMS: "💎",
	IconID.GOLD: "🪙",
	IconID.TREE: "🌲", IconID.STONE: "🪨", IconID.SILVER: "🥈",
	IconID.QUARTZ: "💎", IconID.SALTPETER: "🧪", IconID.TURQUOISE: "🟢",
	IconID.LIMONITE: "🟤", IconID.COAL: "⬛", IconID.GOLD_ORE: "🥇",
	IconID.BOG_IRON: "🔩", IconID.CINNABAR: "🔴",
	IconID.REST: "😴", IconID.SOCIAL: "🤝", IconID.INSPIRATION: "💡",
	IconID.ATTACK: "⚔️", IconID.DEFENSE: "🛡️", IconID.KNOWLEDGE: "📖",
	IconID.SPELL_POWER: "🧪", IconID.HP: "❤️", IconID.MANA: "✨",
	IconID.MOVEMENT: "🚶",
	IconID.WORKER: "⚙", IconID.MILITIA: "🛡", IconID.FOLLOWER: "👤",
	IconID.SCHOLAR: "🎓", IconID.PATROL: "🐎", IconID.HERO: "🧙",
	IconID.POPULATION: "👥",
	IconID.CENTER: "🏰", IconID.FARM: "🌾", IconID.MILL: "🌀",
	IconID.BAKERY: "🍞", IconID.MINE: "⛏", IconID.SMITHY: "⚒",
	IconID.TAVERN: "🍺", IconID.TRADE_POST: "⚖", IconID.MARKET: "🏪",
	IconID.SHACK: "🛖", IconID.WALLS: "🧱", IconID.DISTRICT: "🏘",
	IconID.FOOD: "🌾", IconID.INDUSTRY: "🏭", IconID.DUST: "🌫",
	IconID.SCIENCE: "🔬", IconID.INFLUENCE: "🕊",
	IconID.CLOCK: "🕐", IconID.CROWN: "👑", IconID.STAR: "★",
	IconID.PROSPERITY: "⭐", IconID.REPUTATION: "💠",
	IconID.STORM: "🌪", IconID.FAMINE: "🍂", IconID.CLUSTER: "⚡",
	IconID.STORAGE: "📦", IconID.SKILLS: "🔮", IconID.TOOLS: "🧰",
	IconID.CASTLE: "🏰", IconID.FLAG: "🚩", IconID.CAMP: "⛺",
	IconID.STABLE: "🐎", IconID.SHIP: "🚢", IconID.FORGE: "⚒️",
	IconID.SCOUT: "🔍", IconID.ARMY: "🪖", IconID.JOURNAL: "📜",
	IconID.END_TURN: "⏳", IconID.KINGDOM: "🏰", IconID.OPTIONS: "⚙️",
	IconID.RETREAT: "🏕️", IconID.WAIT: "🏃", IconID.SPELLBOOK: "📖",
	IconID.TURN_NEXT: "⏭", IconID.AUTO_PLAY: "▶", IconID.HIRE: "🧑🌾",
	IconID.LEVEL_UP: "🏛", IconID.RESET: "↺", IconID.HOME: "⌂",
	IconID.CLOSE: "✕", IconID.FLAG_CAPTURED: "🏳️", IconID.TAKE: "✋",
	IconID.SHOVEL: "🔧", IconID.PICKAXE: "⛏️", IconID.CART: "🛒",
	IconID.SKIN_PROTECTION: "🛡️", IconID.NET: "🥅",
	IconID.VICTORY: "👑", IconID.DEFEAT: "💀", IconID.SUCCESSION: "🔁",
	IconID.OBSTACLE_ROCK: "🪨", IconID.OBSTACLE_TREE: "🌳",
	IconID.MARK_EXHAUSTED: "✗", IconID.MARK_PICK: "⛏️",
	IconID.COST_INDUSTRY: "⚙", IconID.COST_GOLD: "💰",
	IconID.ARENA: "🏙", IconID.MODEL_WARRIOR: "🗡", IconID.MODEL_MAGE: "✨",
	IconID.CHRONICLE: "📜",
}

## Лица персонажей (CharacterRegistry) — тоже часть оформления.
const FACES: Array[String] = ["🙂", "🧔", "👩", "", "", "👧", "🧙", "‍", "👵", "🧑‍🌾"]

static func icon(id: int) -> String:
	return str(_GLYPHS.get(id, ""))

static func label(id: int, text: String) -> String:
	var g := icon(id)
	return (g + " " + text) if g != "" else text

## Установить текст Control (Button/Label) из единого источника.
static func apply(control: Control, id: int, text: String = "") -> void:
	if control == null:
		return
	if text.is_empty():
		control.set("text", icon(id))
	else:
		control.set("text", label(id, text))

static func classic_resource_icon(res_type: int) -> String:
	var ids := [IconID.WOOD, IconID.MERCURY, IconID.ORE, IconID.SULFUR,
		IconID.CRYSTAL, IconID.GEMS, IconID.GOLD]
	if res_type >= 0 and res_type < ids.size():
		return icon(ids[res_type])
	return ""

static func resource_icon(res_id: StringName) -> String:
	match res_id:
		&"wood", &"oak": return icon(IconID.TREE)
		&"stone": return icon(IconID.STONE)
		&"silver": return icon(IconID.SILVER)
		&"quartz": return icon(IconID.QUARTZ)
		&"saltpeter": return icon(IconID.SALTPETER)
		&"turquoise": return icon(IconID.TURQUOISE)
		&"limonite": return icon(IconID.LIMONITE)
		&"coal": return icon(IconID.COAL)
		&"coal_swamp": return icon(IconID.COAL)
		&"gold_ore": return icon(IconID.GOLD_ORE)
		&"bog_iron": return icon(IconID.BOG_IRON)
		&"cinnabar": return icon(IconID.CINNABAR)
		&"mercury": return icon(IconID.MERCURY)
		&"ore": return icon(IconID.ORE)
		&"sulfur": return icon(IconID.SULFUR)
		&"crystal": return icon(IconID.CRYSTAL)
		&"gems": return icon(IconID.GEMS)
		&"gold": return icon(IconID.GOLD)
		_: return ""

static func need_icon(need_id: StringName) -> String:
	match need_id:
		&"rest": return icon(IconID.REST)
		&"social": return icon(IconID.SOCIAL)
		&"inspiration": return icon(IconID.INSPIRATION)
		_: return ""

static func tool_label(tool_id: StringName) -> String:
	match tool_id:
		&"shovel": return label(IconID.SHOVEL, "Лопата")
		&"pickaxe": return label(IconID.PICKAXE, "Кирка")
		&"cart": return label(IconID.CART, "Телега")
		&"skin_protection": return label(IconID.SKIN_PROTECTION, "Защита кожи")
		&"net": return label(IconID.NET, "Сеть")
		_: return str(tool_id)

static func building_icon(def_id: StringName) -> String:
	match def_id:
		&"farm": return icon(IconID.FARM)
		&"mill": return icon(IconID.MILL)
		&"bakery": return icon(IconID.BAKERY)
		&"mine": return icon(IconID.MINE)
		&"smithy": return icon(IconID.SMITHY)
		&"tavern": return icon(IconID.TAVERN)
		&"trade_post": return icon(IconID.TRADE_POST)
		&"market": return icon(IconID.MARKET)
		&"shack": return icon(IconID.SHACK)
		&"walls": return icon(IconID.WALLS)
		&"district": return icon(IconID.DISTRICT)
		&"great_temple": return icon(IconID.CENTER)
		_: return ""

static func yield_icon(key: StringName) -> String:
	match key:
		&"food": return icon(IconID.FOOD)
		&"industry": return icon(IconID.INDUSTRY)
		&"dust": return icon(IconID.DUST)
		&"science": return icon(IconID.SCIENCE)
		&"influence": return icon(IconID.INFLUENCE)
		_: return ""

static func face(i: int) -> String:
	if i >= 0 and i < FACES.size():
		return FACES[i]
	return ""
```

---

## 2. [High] Скрипты: замена хардкода глифов

### `ResourceBar.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/resource_bar.gd
class_name ResourceBar
extends HBoxContainer

var _labels: Dictionary = {}

func _ready() -> void:
	for id in ResourceType.classic_ids():
		var l := get_node(ResourceType.to_key(id).capitalize()) as Label
		UITheme.font(l, UITheme.SizeID.FS_SMALL)
		UITheme.tint(l, UITheme.ColorID.TEXT)
		_labels[id] = l

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		_labels[id].text = "%s%d" % [
			ThemeIcons.classic_resource_icon(int(id)), int(resources.get(id, 0))]
```

### `WorldSpawner.gd` (заменить функции)
```gdscript
// FILE: res://scripts/world/world_spawner.gd
func _spawn_villages() -> void:
	for cell in map.village_cells:
		var v := Node2D.new()
		v.set_meta("cell", cell)
		var sp := Sprite2D.new()
		sp.texture = _cached_texture("village", func() -> ImageTexture:
			var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
			for y in 20:
				var half_w := int((24 - y) * 0.8)
				if half_w > 0:
					img.fill_rect(Rect2i(24 - half_w, y, half_w * 2, 1), Color(0.7, 0.2, 0.1))
			img.fill_rect(Rect2i(10, 20, 29, 22), Color(0.6, 0.5, 0.3))
			return ImageTexture.create_from_image(img))
		sp.z_index = 5
		v.add_child(sp)
		var flag := Label.new()
		flag.name = "Flag"
		flag.text = ThemeIcons.icon(ThemeIcons.IconID.FLAG)
		flag.add_theme_font_size_override("font_size", 16)
		flag.position = Vector2(18, -20)
		v.add_child(flag)
		v.position = map.map_to_local(cell)
		add_child(v)
		_village_nodes[cell] = v

func _spawn_resources() -> void:
	for cell in map.resource_cells:
		var res_type: int = map.resource_cells[cell]
		var r := Node2D.new()
		r.set_meta("cell", cell)
		r.set_meta("res_type", res_type)
		var lbl := Label.new()
		lbl.text = ThemeIcons.classic_resource_icon(res_type)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.position = Vector2(-12, -12)
		r.add_child(lbl)
		r.position = map.map_to_local(cell)
		r.z_index = 6
		add_child(r)
		_resource_nodes[cell] = r

func capture_village(cell: Vector2i) -> bool:
	if not _village_nodes.has(cell):
		return false
	var node: Node2D = _village_nodes[cell]
	var flag := node.get_node_or_null("Flag")
	if flag != null:
		flag.text = ThemeIcons.icon(ThemeIcons.IconID.FLAG_CAPTURED)
		return true
	return false
```

### `ResourcesPanel.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/resources_panel.gd
extends PanelContainer
class_name ResourcesPanel
const ResourceDef = preload("res://scripts/data/resource_def.gd")

var _labels: Dictionary = {}
var _resource_registry: Node = null
const ROW_NAMES: Dictionary = {
	&"oak": "OakRow", &"silver": "SilverRow", &"quartz": "QuartzRow",
	&"saltpeter": "SaltpeterRow", &"turquoise": "TurquoiseRow",
	&"limonite": "LimoniteRow", &"coal": "CoalRow", &"gold_ore": "GoldOreRow",
	&"coal_swamp": "CoalSwampRow", &"bog_iron": "BogIronRow",
	&"cinnabar": "CinnabarRow", &"wood": "WoodRow", &"stone": "StoneRow",
}

func setup_registry(registry: Node) -> void:
	_resource_registry = registry

func _ready() -> void:
	var title := $VBox/Title as Label
	title.text = ThemeIcons.label(ThemeIcons.IconID.STORAGE, "Ресурсы")
	UITheme.font(title, UITheme.SizeID.FS_LABEL)
	var container := $VBox/ResourceContainer as VBoxContainer
	var reg: Node = _resource_registry if _resource_registry != null else Resources
	for def in reg.get_all():
		var row_name: String = ROW_NAMES.get(def.id, "")
		if row_name.is_empty():
			continue
		var row := container.get_node(row_name) as HBoxContainer
		if row == null:
			continue
		var label := row.get_node("Label") as Label
		if label == null:
			continue
		label.text = "%s %d/%d" % [ThemeIcons.resource_icon(def.id), 0, MapConfig.RESOURCE_CAPACITY]
		label.tooltip_text = def.display_name
		UITheme.font(label, UITheme.SizeID.FS_SMALL)
		_labels[def.id] = label

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		var label: Label = _labels[id]
		var amount: int = int(resources.get(id, 0))
		label.text = "%s %d/%d" % [
			ThemeIcons.resource_icon(id), amount, MapConfig.RESOURCE_CAPACITY]
```

### `ToolsPanel.gd` (полная замена)
```gdscript
// FILE: res://scripts/ui/tools_panel.gd
extends PanelContainer
class_name ToolsPanel

var _slot_labels: Array[Label] = []

func _ready() -> void:
	var title := $VBox/Title as Label
	title.text = ThemeIcons.label(ThemeIcons.IconID.TOOLS, "Инструменты")
	UITheme.font(title, UITheme.SizeID.FS_LABEL)
	var container := $VBox/ToolContainer as VBoxContainer
	for i in MapConfig.TOOL_INVENTORY_SLOTS:
		var row := container.get_node("Slot%d" % i) as HBoxContainer
		if row == null:
			continue
		var label := row.get_node("SlotLabel") as Label
		if label != null:
			UITheme.font(label, UITheme.SizeID.FS_SMALL)
		_slot_labels.append(label)

func update_tools(tools: Array[Dictionary]) -> void:
	for i in MapConfig.TOOL_INVENTORY_SLOTS:
		if i >= _slot_labels.size():
			break
		var slot: Dictionary = tools[i] if i < tools.size() else {}
		if slot.is_empty():
			_slot_labels[i].text = "[%d] Пусто" % (i + 1)
		else:
			var id: StringName = slot.get("id", "")
			var qty: int = slot.get("quantity", 1)
			_slot_labels[i].text = "[%d] %s x%d" % [i + 1, ThemeIcons.tool_label(id), qty]
```

### `HeroStatusPanel.gd` (заменить константу и текстовые функции)
```gdscript
// FILE: res://scripts/ui/hero_status_panel.gd
# УДАЛИТЬ const _NEED_ICONS. Заменить:
func _wire() -> void:
	if _wired:
		return
	_wired = true
	_title = get_node("VBox/Title") as Label
	_cond_label = get_node("VBox/ConditionLabel") as Label
	_stats_label = get_node("VBox/StatsLabel") as Label
	_followers_label = get_node("VBox/FollowersLabel") as Label
	_title.text = ThemeIcons.label(ThemeIcons.IconID.HERO, "Герой")
	UITheme.font(_title, UITheme.SizeID.FS_LABEL)
	UITheme.font(_cond_label, UITheme.SizeID.FS_SMALL)
	UITheme.font(_stats_label, UITheme.SizeID.FS_SMALL)
	UITheme.font(_followers_label, UITheme.SizeID.FS_SMALL)

func refresh() -> void:
	_wire()
	if _hero == null or not is_instance_valid(_hero):
		_title.text = ThemeIcons.label(ThemeIcons.IconID.HERO, "Герой")
		_cond_label.text = ""
		_stats_label.text = ""
		_followers_label.text = ""
		return
	var h: HeroController = _hero
	_title.text = "%s %s — %s" % [
		ThemeIcons.icon(ThemeIcons.IconID.HERO), h.hero_name, _path_name(h.path_id)]
	_cond_label.text = _condition_text(h)
	_stats_label.text = _stats_text(h)
	_followers_label.text = _followers_text(h)

func _condition_text(h: HeroController) -> String:
	var parts: Array[String] = []
	if h.max_combat_hp > 0:
		parts.append("%s %d/%d" % [ThemeIcons.icon(ThemeIcons.IconID.HP), h.combat_hp, h.max_combat_hp])
	if h.mana_max > 0:
		parts.append("%s %d/%d" % [ThemeIcons.icon(ThemeIcons.IconID.MANA), h.mana_current, h.mana_max])
	if h.needs != null:
		parts.append(_needs_text(h.needs))
	if parts.is_empty():
		return ""
	return "\n".join(parts)

func _needs_text(n: HeroNeeds) -> String:
	var parts: Array[String] = []
	for k in HeroNeeds.NEED_KEYS:
		var mark := "⚠️" if n.is_critical(k) else ""
		parts.append("%s%s %.0f%%" % [ThemeIcons.need_icon(k), mark, n.get_need(k) * 100.0])
	return "\n".join(parts)

func _stats_text(h: HeroController) -> String:
	var s: Dictionary = h.stats
	return "%s %d  %s %d  %s %d  %s %d" % [
		ThemeIcons.icon(ThemeIcons.IconID.ATTACK), int(s.get("attack", 0)),
		ThemeIcons.icon(ThemeIcons.IconID.DEFENSE), int(s.get("defense", 0)),
		ThemeIcons.icon(ThemeIcons.IconID.KNOWLEDGE), int(s.get("knowledge", 0)),
		ThemeIcons.icon(ThemeIcons.IconID.SPELL_POWER), int(s.get("spell_power", 0)),
	]

func _followers_text(h: HeroController) -> String:
	var fs: Array = h.followers
	if fs.is_empty():
		return "%s Последователи: нет" % ThemeIcons.icon(ThemeIcons.IconID.POPULATION)
	var lines: Array[String] = []
	var shown := mini(fs.size(), _MAX_FOLLOWERS_SHOWN)
	var registry = FollowerSystem.registry()
	for i in shown:
		lines.append("• " + fs[i].describe(registry))
	if fs.size() > shown:
		lines.append("+%d ещё" % (fs.size() - shown))
	return "\n".join(lines)
```

### `InfoPanel.gd` (заменить функции)
```gdscript
// FILE: res://scripts/ui/info_panel.gd
# УДАЛИТЬ локальные эмодзи. Добавить в _ready() после _connect_buttons():
	_apply_action_icons()

func _apply_action_icons() -> void:
	var icons := {
		"CastleButton": ThemeIcons.IconID.CASTLE, "FlagButton": ThemeIcons.IconID.FLAG,
		"CampButton": ThemeIcons.IconID.CAMP, "StableButton": ThemeIcons.IconID.STABLE,
		"ShipButton": ThemeIcons.IconID.SHIP, "ForgeButton": ThemeIcons.IconID.FORGE,
		"ScoutButton": ThemeIcons.IconID.SCOUT, "ArmyButton": ThemeIcons.IconID.ARMY,
		"JournalButton": ThemeIcons.IconID.JOURNAL, "EndTurnButton": ThemeIcons.IconID.END_TURN,
		"KingdomButton": ThemeIcons.IconID.KINGDOM, "OptionsButton": ThemeIcons.IconID.OPTIONS,
	}
	for name in icons:
		ThemeIcons.apply(get_node_or_null("actions/%s" % name), icons[name])

func set_time(hour: float) -> void:
	var h := int(floor(hour))
	var m := int(round((hour - floor(hour)) * 60))
	_time_label.text = "%s %02d:%02d" % [ThemeIcons.icon(ThemeIcons.IconID.CLOCK), h, m]
	# цвета времени — из UITheme (enum ColorID), как в прошлой итерации

func add_city(city_name: String) -> void:
	for i in _town_slots.size():
		var slot := get_node_or_null("columns/town_col/town_slot_%d" % i)
		if slot == null:
			continue
		if slot.get_child_count() == 0:
			var icon_node := slot.get_node_or_null("Icon")
			var name_node := slot.get_node_or_null("Name")
			if icon_node != null:
				icon_node.visible = false
			if name_node != null:
				name_node.text = ThemeIcons.label(ThemeIcons.IconID.CASTLE, city_name)
				UITheme.tint(name_node, UITheme.ColorID.TEXT)
				name_node.clip_text = true
			return
```

### `CityPanel.gd` (заменить в `_ready` тексты кнопок и в `_refresh` теги)
```gdscript
// FILE: res://scripts/ui/CityPanel.gd
# в _ready() после подключения сигналов:
	ThemeIcons.apply(_btn_worker, ThemeIcons.IconID.WORKER, "Рабочий")
	ThemeIcons.apply(_btn_militia, ThemeIcons.IconID.MILITIA, "Ополченец")
	ThemeIcons.apply(get_node("Panel/Box/Row/ReserveButton") as Button, ThemeIcons.IconID.FOLLOWER, "Резерв")
	ThemeIcons.apply(_btn_patrol, ThemeIcons.IconID.PATROL, "Патруль")

# в _refresh(): теги фигурок
	match u.state:
		PopUnit.State.WORKER:
			tag = ThemeIcons.icon(ThemeIcons.IconID.WORKER)
			extra = " %s" % u.tile
		PopUnit.State.MILITIA:
			tag = ThemeIcons.icon(ThemeIcons.IconID.MILITIA)
			extra = " патруль" if u.patrol else ""
	# строка голода:
	("  %s ГОЛОД" % ThemeIcons.icon(ThemeIcons.IconID.FAMINE)) if c.starving else ""

# в _update_buttons():
	_btn_patrol.text = ("%s Патруль: ВЫКЛ" % ThemeIcons.icon(ThemeIcons.IconID.PATROL)) if _btn_patrol.disabled \
		else (("%s Патруль: ВЫКЛ" % ThemeIcons.icon(ThemeIcons.IconID.PATROL)) if not u.patrol \
		else ("%s Патруль: ВКЛ" % ThemeIcons.icon(ThemeIcons.IconID.PATROL)))
```

### `CityScreen.gd` (заменить `_ready` кнопки и `refresh`)
```gdscript
// FILE: res://scripts/ui/city_screen.gd
# в _ready() после подключения сигналов:
	ThemeIcons.apply(buttons.get_node("BuildFarm") as Button, ThemeIcons.IconID.FARM, "Построить ферму")
	ThemeIcons.apply(buttons.get_node("BuildMine") as Button, ThemeIcons.IconID.PICKAXE, "Построить шахту")
	ThemeIcons.apply(buttons.get_node("LevelUp") as Button, ThemeIcons.IconID.LEVEL_UP, "Улучшить")
	ThemeIcons.apply(buttons.get_node("Hire") as Button, ThemeIcons.IconID.FOLLOWER, "Нанять")
	ThemeIcons.apply(buttons.get_node("Close") as Button, ThemeIcons.IconID.CLOSE, "Выход из города")

# в refresh():
	lines.append("%s Население: %d (свободные последователи: %d)" % [
		ThemeIcons.icon(ThemeIcons.IconID.POPULATION), city.pop_capped(), city.free_followers()])
	lines.append("%s Еда: %.0f (нетто %+.1f в ход)" % [
		ThemeIcons.icon(ThemeIcons.IconID.FOOD), city.food_stockpile, city.net_food()])
	lines.append("%s Промышленность: %.0f   %s Золото: %.0f" % [
		ThemeIcons.icon(ThemeIcons.IconID.INDUSTRY), _storage_industry(),
		ThemeIcons.icon(ThemeIcons.IconID.GOLD), _gold()])
	lines.append("%s Процветание: %.0f   %s Репутация: %d" % [
		ThemeIcons.icon(ThemeIcons.IconID.PROSPERITY), city.prosperity,
		ThemeIcons.icon(ThemeIcons.IconID.REPUTATION), city.reputation])
```

### `CityArenaView.gd` + `ArenaHexCell.gd`
```gdscript
// FILE: res://scripts/world/city_arena_view.gd
# УДАЛИТЬ эмодзи из PALETTE и _building_emoji. Заменить:
func _wire_palette() -> void:
	var palette := _ui.get_node("Palette") as VBoxContainer
	_palette_buttons.clear()
	for btn_name in PALETTE_BUTTON_NAMES:
		var btn := palette.get_node(btn_name) as Button
		if btn == null:
			continue
		_palette_buttons.append(btn)
	for i in _palette_buttons.size():
		if i < PALETTE.size():
			var id: StringName = PALETTE[i][0]
			var bname: String = PALETTE[i][2]
			var cost: String = _cost_label(id)
			_palette_buttons[i].text = "%s %s %s" % [
				ThemeIcons.building_icon(id), bname, cost]
			_palette_buttons[i].pressed.connect(_on_palette_pressed.bind(id))

func _wire_ui() -> void:
	var bar := _ui.get_node("Bar") as HBoxContainer
	ThemeIcons.apply(bar.get_node("TurnButton") as Button, ThemeIcons.IconID.TURN_NEXT, "Ход")
	_auto_btn = bar.get_node("AutoButton") as Button
	_auto_btn.pressed.connect(_on_auto_pressed)
	ThemeIcons.apply(bar.get_node("HireButton") as Button, ThemeIcons.IconID.HIRE, "Нанять")
	ThemeIcons.apply(bar.get_node("LevelButton") as Button, ThemeIcons.IconID.LEVEL_UP, "Уровень")
	ThemeIcons.apply(bar.get_node("ResetButton") as Button, ThemeIcons.IconID.RESET, "Заново")
	ThemeIcons.apply(bar.get_node("MenuButton") as Button, ThemeIcons.IconID.HOME, "Меню")
	# ...подключения сигналов без изменений

func _building_emoji(id: StringName) -> String:
	return ThemeIcons.building_icon(id)

func _ring_yield_short(ring: int) -> String:
	var y: Dictionary = ArenaBalance.ring_yield(ring)
	var parts: Array[String] = []
	if float(y.get(&"food", 0.0)) > 0.0:
		parts.append(ThemeIcons.yield_icon(&"food") + ("%.1f" % float(y.get(&"food", 0.0))))
	if float(y.get(&"industry", 0.0)) > 0.0:
		parts.append(ThemeIcons.yield_icon(&"industry") + ("%.1f" % float(y.get(&"industry", 0.0))))
	return ", ".join(parts)

# в _advance_turn() / _refresh() / _on_auto_pressed():
	warn = ("  %s ШТОРМ: ..." % ThemeIcons.icon(ThemeIcons.IconID.STORM)) + warn
	warn = ("  %s ГОЛОД (день %d)" % [ThemeIcons.icon(ThemeIcons.IconID.FAMINE), _starve_days]) + warn
	var cl_note := ("   %s кластеры: %d" % [ThemeIcons.icon(ThemeIcons.IconID.CLUSTER), clusters]) if clusters > 0 else ""
	_auto_btn.text = ThemeIcons.label(ThemeIcons.IconID.RESET, "Стоп") if _auto else ThemeIcons.label(ThemeIcons.IconID.AUTO_PLAY, "Авто")
# _refresh():
	var storm_mark := ("   " + ThemeIcons.icon(ThemeIcons.IconID.STORM) + " ШТОРМ") if CityArenaModel.is_storm_turn(_turn) else ""
	var cluster_mark := ("   %s×4: %d" % [ThemeIcons.icon(ThemeIcons.IconID.CLUSTER), clusters]) if clusters > 0 else ""
	_top_hud.text = "Ход: %d   %s %.0f (нетто %+.1f)   %s %.0f   %s %.0f   %s %d   %s %.0f   Уровень %d%s%s" % [
		_turn, ThemeIcons.yield_icon(&"food"), food, net, ThemeIcons.yield_icon(&"industry"), industry,
		ThemeIcons.icon(ThemeIcons.IconID.GOLD), gold, ThemeIcons.icon(ThemeIcons.IconID.POPULATION),
		_city.pop_total(), ThemeIcons.icon(ThemeIcons.IconID.PROSPERITY), _city.prosperity,
		_city.level, storm_mark, cluster_mark]
```

```gdscript
// FILE: res://scripts/ui/arena_hex_cell.gd
func _mark_label_text() -> String:
	if ring == 0:
		return ThemeIcons.icon(ThemeIcons.IconID.CENTER)
	return mark_id

func _ring_yield_short(ring: int) -> String:
	var y: Dictionary = _ArenaBalance.ring_yield(ring)
	var parts: Array[String] = []
	if float(y.get(&"food", 0.0)) > 0.0:
		parts.append(ThemeIcons.yield_icon(&"food") + ("%.1f" % float(y.get(&"food", 0.0))))
	if float(y.get(&"industry", 0.0)) > 0.0:
		parts.append(ThemeIcons.yield_icon(&"industry") + ("%.1f" % float(y.get(&"industry", 0.0))))
	return ", ".join(parts)
```

### `AdventureUI.gd`, `ChronicleScreen.gd`, `DeathSequence.gd`, `MarkerLayer.gd`, `CharacterRegistry.gd`, `BattleController.gd`, `HeroMovementController.gd`, `BattleTurnExecutor.gd`, `ArtifactChestDialog.gd`, `SkillsPanel.gd`, `MainMenu.gd`, `BattleUI.gd`
```gdscript
// FILE: res://scripts/ui/adventure_ui.gd
func refresh_glory() -> void:
	...
	_glory_label.text = "%s Слава: %d / %d" % [
		ThemeIcons.icon(ThemeIcons.IconID.CROWN), int(total), int(target)]

func _update_mp_display(current: float, max_val: float) -> void:
	var text := "%s %.1f / %.0f" % [ThemeIcons.icon(ThemeIcons.IconID.MOVEMENT), current, max_val]
	...

// FILE: res://scripts/ui/chronicle_screen.gd
func _entry_line(e: Dictionary) -> String:
	var outcome := str(e.get("outcome", "?"))
	var icon := ThemeIcons.icon(ThemeIcons.IconID.VICTORY) if outcome == "VICTORY" \
		else ThemeIcons.icon(ThemeIcons.IconID.DEFEAT) if outcome == "DEFEAT" \
		else ThemeIcons.icon(ThemeIcons.IconID.SUCCESSION)
	...

// FILE: res://scripts/ui/death_sequence.gd
	if res_city != null:
		resurrection_btn.text = "Воскресить (%d%s + %d%s)" % [
			res_cost, ThemeIcons.icon(ThemeIcons.IconID.COST_INDUSTRY),
			res_gold, ThemeIcons.icon(ThemeIcons.IconID.COST_GOLD)]

// FILE: res://scripts/ui/marker_layer.gd
	var glyph: String = ThemeIcons.icon(ThemeIcons.IconID.MARK_EXHAUSTED) if m["exhausted"] \
		else ThemeIcons.icon(ThemeIcons.IconID.MARK_PICK)

// FILE: res://scripts/demographics/character_registry.gd
# УДАЛИТЬ const _ICONS. Заменить:
func _pick_icon(rng: RandomNumberGenerator) -> String:
	return ThemeIcons.face(rng.randi_range(0, ThemeIcons.FACES.size() - 1))

// FILE: res://scripts/systems/battle_controller.gd
	var emoji := ThemeIcons.icon(ThemeIcons.IconID.OBSTACLE_ROCK) if rng.randf() > 0.5 \
		else ThemeIcons.icon(ThemeIcons.IconID.OBSTACLE_TREE)

// FILE: res://scripts/entities/hero_movement_controller.gd
		path_previewed.emit(ThemeIcons.label(ThemeIcons.IconID.ATTACK, "Контакт с врагом — начинается бой"))
		path_previewed.emit("Нет очков движения — нажмите " + ThemeIcons.icon(ThemeIcons.IconID.END_TURN))

// FILE: res://scripts/systems/battle_turn_executor.gd
	status_updated.emit(ThemeIcons.label(ThemeIcons.IconID.DEFENSE, "Защита: +20% DEF до конца раунда."))

// FILE: res://scripts/ui/artifact_chest_dialog.gd
# в _connect_skeleton() после получения узлов:
	ThemeIcons.apply(take, ThemeIcons.IconID.TAKE, "Artifact")
	ThemeIcons.apply(gold, ThemeIcons.IconID.COST_GOLD, "Gold")

// FILE: res://scripts/ui/skills_panel.gd
# в _ready():
	title.text = ThemeIcons.label(ThemeIcons.IconID.SKILLS, "Навыки")

// FILE: res://scripts/ui/main_menu.gd
# в _ready() после _style_buttons():
	ThemeIcons.apply(_arena_btn, ThemeIcons.IconID.ARENA, "Арена города")
	ThemeIcons.apply(_model_warrior_btn, ThemeIcons.IconID.MODEL_WARRIOR, "Модель: Рыцарь")
	ThemeIcons.apply(_model_mage_btn, ThemeIcons.IconID.MODEL_MAGE, "Модель: Маг")
	ThemeIcons.apply(_chronicle_btn, ThemeIcons.IconID.CHRONICLE, "Летопись")

// FILE: res://scripts/ui/battle_ui.gd
# в _connect_skeleton() после получения кнопок:
	ThemeIcons.apply(get_node_or_null("bottom_bar/retreat_btn"), ThemeIcons.IconID.RETREAT)
	ThemeIcons.apply(get_node_or_null("bottom_bar/wait_btn"), ThemeIcons.IconID.WAIT)
	ThemeIcons.apply(get_node_or_null("bottom_bar/attack_btn"), ThemeIcons.IconID.ATTACK)
	ThemeIcons.apply(get_node_or_null("bottom_bar/defend_btn"), ThemeIcons.IconID.DEFENSE)
	ThemeIcons.apply(get_node_or_null("bottom_bar/skip_btn"), ThemeIcons.IconID.END_TURN)
	ThemeIcons.apply(get_node_or_null("bottom_bar/spellbook_btn"), ThemeIcons.IconID.SPELLBOOK)
	ThemeIcons.apply(get_node_or_null("bottom_bar/settings_btn"), ThemeIcons.IconID.OPTIONS)
```

---

## 3. [High] Очистка `.tscn` от вшитых эмодзи (дерево получает глифы из ThemeIcons)

Замены `text = "..."` (старое → новое):

- **`scenes/ui/InfoPanel.tscn`**: `"🏰"→""`, `"🚩"→""`, `"⛺"→""`, `"🐎"→""`, `"🚢"→""`, `"⚒️"→""`, `"🔍"→""`, `"🪖"→""`, `"📜"→""`, `"⏳"→""`, `"⚙️"→""` (12 кнопок `actions/*`; tooltips оставить).
- **`scenes/ui/BattleUI.tscn`**: `retreat_btn "🏕️"→""`, `wait_btn "🏃"→""`, `attack_btn "⚔️"→""`, `defend_btn "🛡️"→""`, `skip_btn "⏳"→""`, `spellbook_btn "📖"→""`, `settings_btn "⚙️"→""`.
- **`scenes/MainMenu.tscn`**: `"🏙 Арена города"→"Арена города"`, `"🗡 Модель: Рыцарь"→"Модель: Рыцарь"`, `"✨ Модель: Маг"→"Модель: Маг"`, `"📜 Летопись"→"Летопись"`.
- **`scenes/CityArena.tscn`**: `"⏭ Ход"→"Ход"`, `"▶ Авто"→"Авто"`, `"🧑‍🌾 Нанять"→"Нанять"`, `"🏛 Уровень"→"Уровень"`, `"↺ Заново"→"Заново"`, `"⌂ Меню"→"Меню"`.
- **`scenes/ui/CityScreen.tscn`**: `"🌾 Построить ферму"→"Построить ферму"`, `"⛏️ Построить шахту"→"Построить шахту"`, `"⬆️ Улучшить"→"Улучшить"`, `"👤 Нанять"→"Нанять"`, `"✕ Выход из города"→"Выход из города"`.
- **`scenes/ui/ResourcesPanel.tscn`**: `Title "📦 Ресурсы"→"Ресурсы"`.
- **`scenes/ui/SkillsPanel.tscn`**: `Title "🔮 Навыки"→"Навыки"`.
- **`scenes/ui/ToolsPanel.tscn`**: `Title "🧰 Инструменты"→"Инструменты"`.
- **`scenes/ui/HeroStatusPanel.tscn`**: `Title "🧙 Герой"→"Герой"`.

---

## Runbook

1. Создать `res://scripts/ui/ThemeIcons.gd`.
2. Применить замены скриптов (п. 2) и `.tscn` (п. 3).
3. Проверка: `rg "🪵|🧪||💎||🌲|⚔️|🛡️|🏰||⏳|📖|⚙️|🔮||🧙" scripts/ scenes/ --glob "*.gd" --glob "*.tscn"` должен вернуть 0 совпадений вне `ThemeIcons.gd`.
4. Приёмка: заменить в `_GLYPHS` глиф `IconID.GOLD` (например на «🥇») → золото меняется в ResourceBar, CityScreen, сундуках и арене одновременно; поменять `IconID.END_TURN` → кнопки InfoPanel/BattleUI/текст движения обновятся без правок дерева.

## Итоговая таблица

| № | Файл | Суть | Приоритет |
|---|------|------|-----------|
| 1 | `scripts/ui/ThemeIcons.gd` | Новый единый класс глифов: enum IconID + _GLYPHS + хелперы | High |
| 2 | `scripts/ui/ResourceBar.gd` | ICONS → ThemeIcons.classic_resource_icon | High |
| 3 | `scripts/world/WorldSpawner.gd` | Флаги/иконки ресурсов → ThemeIcons | High |
| 4 | `scripts/ui/ResourcesPanel.gd` | def.icon → ThemeIcons.resource_icon | High |
| 5 | `scripts/ui/ToolsPanel.gd` | _tool_names → ThemeIcons.tool_label | Medium |
| 6 | `scripts/ui/HeroStatusPanel.gd` | _NEED_ICONS/статы → ThemeIcons | Medium |
| 7 | `scripts/ui/InfoPanel.gd` | Время/города/кнопки действий → ThemeIcons | Medium |
| 8 | `scripts/ui/CityPanel.gd` | Теги фигурок/кнопки → ThemeIcons | Medium |
| 9 | `scripts/ui/CityScreen.gd` | Статы/кнопки → ThemeIcons | Medium |
| 10 | `scripts/world/CityArenaView.gd` + `ArenaHexCell.gd` | Палитра/эмодзи зданий/выходы → ThemeIcons | Medium |
| 11 | `scripts/ui/AdventureUI.gd` | Слава/MP → ThemeIcons | Low |
| 12 | `ChronicleScreen/DeathSequence/MarkerLayer/CharacterRegistry` | Исходы/маркеры/лица → ThemeIcons | Low |
| 13 | `BattleController/HeroMovementController/BattleTurnExecutor` | Препятствия/превью/статусы → ThemeIcons | Low |
| 14 | 9 `.tscn` | Удалены вшитые эмодзи; глифы ставятся в рантайме | High |