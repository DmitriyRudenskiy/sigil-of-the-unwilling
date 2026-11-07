## MODIFIED Requirements

### Requirement: Каждая stateful-подсистема SHALL иметь roundtrip-покрытие
Для каждой подсистемы игрового состояния SHALL существовать запись в матрице покрытия (`docs/save-matrix.md`) и functional-тест `save → load → deep-equal` (`game/tests/functional/save_roundtrip_*.gd`).

#### Scenario: Gap не мержится
- **WHEN** новая подсистема с состоянием добавлена без roundtrip-теста
- **THEN** тест-набор проваливается (матрица требует строку)
