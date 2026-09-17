# smoldering-city Specification

## Purpose
Определяет Smoldering City (Тлеющий город) — постоянную
meta-столицу: Citadel-ресурсы из поселений, перманентные апгрейды,
ункилоки видов/зданий/улучшений и meta-сейв.
## Requirements
### Requirement: Citadel-ресурсы из поселений
Завершённое поселение (победа или поражение) SHALL передавать
Citadel-ресурсы (Ancient Tablets и доля ресурсов) в Smoldering City.

#### Scenario: Поражение
- **WHEN** поселение проиграно
- **THEN** доля ресурсов зачисляется в Smoldering City
- **AND** следующая попытка легче (meta-принцип: "не бойся
  ошибаться")

#### Scenario: Победа
- **WHEN** поселение выиграно
- **THEN** бонусная доля сверх поражения

### Requirement: Перманентные апгрейды
Smoldering City SHALL хранить перманентные апгрейды (новые
стартовые здания, улучшения видов, бонусы ресурсов), покупаемые за
Citadel-ресурсы; апгрейды переживают прогоны.

#### Scenario: Покупка
- **WHEN** достаточно Citadel-ресурсов
- **THEN** апгрейд покупается, применяется к следующему поселению
- **AND** сохраняется между прогонами

#### Scenario: Стартовое здание
- **WHEN** куплен апгрейд "доп. стартовое здание"
- **THEN** новое поселение стартует с ним

### Requirement: Ункилоки видов и зданий
Уровни Smoldering City SHALL открывать: frog (L9, "Keepers of the
Stone"), bat (L11, "Nightwatchers"), Unified/Commons (L6),
улучшения домов (Brass Forge L11, Pioneer Gates L12), дома видов
(Vanguard Spire L1–L6).

#### Scenario: Унлок frog
- **WHEN** SC L9 + DLC "Keepers of the Stone"
- **THEN** frog доступен в караване
- **AND** без DLC — недоступен

#### Scenario: Унлок дома
- **WHEN** Vanguard Spire L3
- **THEN** Lizard House доступен
- **AND** до L3 — нет

#### Scenario: Унлок улучшений
- **WHEN** Brass Forge L11
- **THEN** улучшения домов доступны
- **AND** до L11 — нет

### Requirement: Meta-сейв
Состояние Smoldering City (Citadel-ресурсы, апгрейды, уровни, DLC)
SHALL сохраняться отдельно от прогона поселения.

#### Scenario: Мета-сейв
- **WHEN** игра сохраняется
- **THEN** meta-состояние — в отдельном ключе сейва
- **AND** восстанавливается независимо от сейва поселения

