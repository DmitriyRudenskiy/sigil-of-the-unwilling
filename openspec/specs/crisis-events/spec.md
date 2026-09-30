# crisis-events Specification

## Purpose

Описывает схему event/crisis-шаблонов (JSON, `game/data/events/`) и правила селектора событий в `CrisisEventSystem`: сезонная совместимость, взвешенный детерминированный выбор, редкость. Базовое поведение системы (триггеры, cooldown, эффекты) — в speках `crisis-manager`/`event-manager`.

## Requirements

### Requirement: Селектор событий SHALL учитывать сезон и вес
При выборе кандидата событие фильтруется по совместимости с текущим сезоном (метеорологические сезоны `Season.ID`: spring/summer/autumn/winter, источник — инжектируемый season provider) и выбирается взвешенно по `weight`; редкие события ограничены `rarity: rare` и весом ≤0.05. Выбор детерминирован по seed RNG (инжектируемый `RandomNumberGenerator`).

#### Scenario: Сезонное окно
- **WHEN** текущий сезон winter и в пуле есть событие с `seasons: ["summer"]`
- **THEN** это событие не может быть выбрано

#### Scenario: Без сезонных тегов
- **WHEN** событие имеет пустое поле `seasons`
- **THEN** оно доступно в любом сезоне (backward compat со старым контентом)

#### Scenario: Неизвестный сезон
- **WHEN** season provider не установлен (путь без календаря)
- **THEN** сезонный фильтр не блокирует ни одно событие

#### Scenario: Редкость
- **WHEN** симулируется 10 000 взвешенных выборов по полному пулу шаблонов
- **THEN** доля событий с `rarity: rare` отличается от ожидаемой (сумма их весов / общий вес) не более чем на ±2%

#### Scenario: Детерминизм
- **WHEN** два прогона с одинаковым seed
- **THEN** последовательность выбранных событий идентична

### Requirement: Схема шаблона SHALL поддерживать seasons/weight/rarity с backward compat
JSON-шаблон события/кризиса принимает необязательные поля: `seasons: Array[String]` (пусто = любой сезон), `weight: float` (default 1.0), `rarity: String` (default "common", допустимы "common"|"rare"). Файлы без новых полей читаются без изменений.

#### Scenario: Старый файл
- **WHEN** JSON без полей seasons/weight/rarity загружается
- **THEN** шаблон получает defaults: seasons=[], weight=1.0, rarity="common"

#### Scenario: Невалидный сезон
- **WHEN** `seasons` содержит значение вне {spring, summer, autumn, winter}
- **THEN** файл отклоняется с ошибкой загрузки (push_error, шаблон не добавляется)

#### Scenario: Невалидная rarity
- **WHEN** `rarity` не входит в {common, rare}
- **THEN** warning + fallback на "common" (шаблон загружается)
