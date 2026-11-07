## REMOVED Requirements

### Requirement: Campaign city levels gate occupied city cells
**Reason**: Механика кампании снята с плана целиком (владелец, 2026-11-05): за месяц после cutover D-157/D-163 слой не стал играбельным путём, а играбельный цикл живёт в world/adventure-слое.

**Migration**: Механики нет и восстанавливать её нельзя — носитель запрета `campaign-lockout`. Состояние кампейна не мигрирует: сейвы с секциями `campaign.*` грузиться не будут (fail-fast с причиной).

### Requirement: Campaign level-up follows filled construction allowance
**Reason**: Механика кампании снята с плана целиком (владелец, 2026-11-05): за месяц после cutover D-157/D-163 слой не стал играбельным путём, а играбельный цикл живёт в world/adventure-слое.

**Migration**: Механики нет и восстанавливать её нельзя — носитель запрета `campaign-lockout`. Состояние кампейна не мигрирует: сейвы с секциями `campaign.*` грузиться не будут (fail-fast с причиной).
