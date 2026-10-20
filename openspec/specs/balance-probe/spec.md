# balance-probe Specification

## Purpose
Делает калибровку баланса воспроизводимой: MCP-автопрогонка играет каноническую раннюю игру, собирает метрики и позволяет сравнивать до/после изменения чисел без ручной игры.
## Requirements
### Requirement: MCP-автопрогонка ранней игры
Система SHALL предоставлять сценарий прогонки, который через MCP запускает новую игру и ведёт её канонической стратегией ранней игры (сбор узлов → выгрузка в городе → строительство → рекрутка → бой с 1-м кольцом) без участия человека, на фиксированном seed.

#### Scenario: Прогонка завершается
- **WHEN** запущен сценарий прогонки
- **THEN** он проходит всю каноническую последовательность действий до последней метрики или до лимита ходов
- **AND** результат детерминирован для фиксированного seed

#### Scenario: Прогонка воспроизнима
- **WHEN** сценарий запущен дважды с одним seed
- **THEN** последовательность событий и метрики совпадают

### Requirement: Метрики прогонки
Сценарий SHALL фиксировать: ход первого построенного здания, ход первой успешной рекрутки, ход первой победы в бою, число проигранных боёв, число ходов без любого прогресса (затыки), состояние рюкзака/хранилища/уровня города в контрольных точках.

#### Scenario: Отчёт генерируется
- **WHEN** прогонка завершена
- **THEN** доступен машиночитаемый отчёт со всеми метриками
- **AND** человек читаемая сводка «до/после» доступна для вставки в отчёт калибровки

### Requirement: Прогонка не блокирует CI по метрикам
Сценарий SHALL завершаться с ошибкой только при техническом сбое (смерть героя, застревание автоигрока, ошибка MCP); нарушение целевых порогов метрик SHALL сообщаться как warning и записываться в отчёт, а не ронять тест.

#### Scenario: Техсбой роняет тест
- **WHEN** герой погиб или автоигрок не смог выполнить действие N раз подряд
- **THEN** сценарий завершается с ошибкой

#### Scenario: Метрика выше порога
- **WHEN** например, первая рекрутка произошла на 20-м ходу вместо целевых 10
- **THEN** тест завершается успехом, а отчёт содержит warning с фактическим значением

### Requirement: Калибровка чисел по метрикам
После прогонки SHALL быть выполнена калибровка констант ранней игры так, чтобы целевые пороги метрик выполнялись: первое здание ≤ 5 ходов, первая рекрутка ≤ 10 ходов, первая победа ≤ 3 ходов после первого столкновения; сезон «Буря» не увеличивает средний затык более чем в 2 раза относительно «Ясного сезона».

#### Scenario: Пороги выполняются
- **WHEN** прогонка выполнена после калибровки
- **THEN** все целевые метрики в пределах порогов (или отчёт содержит обоснованное исключение)

#### Scenario: Повторная прогонка после изменения
- **WHEN** константы баланса изменены
- **THEN** прогонку можно повторить и сравнить метрики с предыдущим отчётом


### Requirement: Balance reports include campaign-city economy outcomes
The deterministic balance run SHALL report the canonical city's selected building counts and construction days, cumulative costs, workers assigned, daily production and consumption by MVP resource, ending stock, and milestone attainment through day 21. A run SHALL distinguish an unaffordable plan or missed balance target from a technical simulation failure and SHALL preserve enough baseline data for a before/after comparison.

#### Scenario: Review city balance metrics
- **WHEN** a canonical campaign-city balance run completes
- **THEN** its machine-readable report contains the building plan and per-day `food`, `wood`, and `iron` flows and stocks
- **AND** its human-readable summary identifies the first farm/barracks, first raid, and day-21 economy/defense milestones
- **AND** a repeated run with the same seed and actions has identical metrics

#### Scenario: A balance target is missed
- **WHEN** the run completes technically but a stock, affordability, or milestone target is missed
- **THEN** the report records a warning with the expected and actual values
- **AND** it does not report the balance as passing or fail the test solely for a tunable target miss
