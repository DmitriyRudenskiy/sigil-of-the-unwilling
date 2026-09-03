## Why

На карте героя при сборе/добыче ресурса игроку не показывается, что именно он получил — сбор происходит «вслепую» (только звук `resource_collected` и скрытое изменение остатков). Нужно маленькое всплывающее окно с картинкой ресурса, количеством и кнопкой OK, чтобы обратная связь была видимой.

## What Changes

- Новое маленькое модальное всплывающее окно «ресурс собран» (напр. `ResourceCollectPopup`), которое появляется по центру экрана и содержит: картинку/иконку ресурса, количество и кнопку OK.
- Окно показывается при каждой успешной добыче/сборе ресурса на карте героя.
- В окне отображается **текстурная иконка ресурса** (из спрайта/атласа, который предоставляет заказчик, с маппингом `resource_id → текстура/регион`), количество и короткое название; закрытие — по OK и/или авто-исчезание через короткое время (~4 с).
- Привязка к уже существующему глобальному сигналу `GameEventBus.resource_extracted(cell, resource_id, amount)` (путь богатых узлов `ResourceNodeManager.try_extract`) и к пути простого сбора `WorldInteractionController.collect_resource_at` (в т.ч. команда `COLLECT_HERE` через SocketController) — оба пути.
- Повторное использование готовых паттернов UI: `ArtifactChestDialog.gd` (модальное окно с margin/vbox/кнопками) и `AdventureUI._on_options` (маленький `popup_centered`); звук `resource_collected`.

## Capabilities

### New Capabilities
- `resource-collection-popup`: всплывающее окно награды за сбор ресурса (картинка + количество + OK), показ по событию сбора с обеих путей (богатые узлы и простой сбор), с откатом и верификацией операбильности.

### Modified Capabilities
- (нет — специкабельное поведение не меняет существующие specs `audio` / `documentation`.)

## Impact

- **Системы**: `game/scripts/autoload/GameEventBus.gd` (подписка попапа на `resource_extracted`); `game/scripts/world/WorldInteractionController.gd` (`collect_resource_at` — подписать на событие/сигнал); `game/scripts/ui/AdventureUI.gd` или `WorldEventRouter.gd` (координатор, держит окно); `game/scripts/world/ResourceNodeManager.gd` (источник сигнала `resource_extracted`).
- **UI-паттерны**: новый `ResourceCollectPopup` (Control) — зеркало `ArtifactChestDialog`.
- **Зависимости**: спрайт/атлас иконок ресурсов предоставляет заказчик; добавляется маппинг `resource_id → текстура/регион` (данные, не код). Новых внешних зависимостей нет.
- **Риски**: показ окна должен быть неблокирующим/быстрым и не ломать поток игры и сохранение; митигация — модалка только на overlay-слое, отключается кнопкой OK, верификация `run_operability.sh`.
