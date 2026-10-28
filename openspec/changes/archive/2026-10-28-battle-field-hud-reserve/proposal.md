# battle-field-hud-reserve

## Why

`T-220` (замер по кадрам ux-review `mvp-ui-flow` 4.1): при 1920×1080 поле боя
занимало **долю кадра 1.000**, а нижняя панель HUD — `CanvasLayer`, она рисуется
поверх мира всегда — лежала на последних рядах: иконки на y≈955..1010, подписи на
y≈1030..1050. Юнит нижнего ряда уходил под кнопку.

Срез 4.1 (D-266) закрыл это множителем `×0.8` по порогу «высота окна ≤ 720»
(`BattleView.field_fit_scale`, `GameNumbers.BATTLE_LOWRES_*`). Множитель по порогу
не лечит Full HD **по определению**, а при честном запасе превратился бы во второе,
независимое сжатие: 720p получил бы 0.708 × 0.8 = 0.57 кадра.

## What Changes

- **Снимается** множитель `field_fit_scale` и константы `BATTLE_LOWRES_MAX_HEIGHT` /
  `BATTLE_LOWRES_FIT_SCALE` (**BREAKING** для требования `Low resolution support`:
  формулировка «battle field at 720p SHALL use scale x0.8» заменена).
- **Добавляется** запас, прочитанный с полос HUD: `BattleUI.hud_bands() -> Vector2`
  (верх = нижняя граница полос `hero_cards`/`initiative_bar`, низ = высота
  `bottom_bar`) из `scenes/ui/battle_ui.tscn`. Носитель числа — сцена: правка панели
  правит и запас, константы разрешения не появляется.
- **Добавляется** внедрение приёмника хостом: `BattleController._apply_hud_reserve()` →
  `BattleView.set_hud_reserve(top, bottom)` (тот же приём, что `mood_sink` у канала
  настроения). `BattleView` про `BattleUI` не знает.
- **Меняется** формула `BattleView.fit_camera()`: `avail_y = vp.y − top − bottom`,
  `z = min(vp.x/field.x, avail_y/field.y)`, центр поля сдвигается на
  `(top − bottom) / (2·z)` — без сдвига поле вписалось бы в полосу, но осталось бы
  отцентровано по всему кадру и нижней половиной легло бы на HUD.
- **Снимается** резерв под бейдж таймера хода (158 px по центру, нижняя граница 295):
  резервировать его на всю ширину — съесть ещё ~140 px поля. Наложение бейджа на
  верхний ряд принимается осознанно и вынесено в `T-230`.

## Impact

- `game/scripts/systems/battle_view.gd`, `game/scripts/ui/battle_ui.gd`,
  `game/scripts/systems/battle_controller.gd`,
  `game/scripts/constants/game_numbers{,_battle}.gd`
- `game/tests/unit/systems/test_battle_field_fit_720p.gd` → `test_battle_field_fit.gd`
  (проверка значения зума заменена проверкой доли кадра и нижней границы поля,
  добавлена связка «панель ↔ запас»)
- `game/tools/mut_battle_fit.sh` — батарея переписана целиком (M1′…M6′ про связку
  «панель → запас → формула»)
- Живой spec: `openspec/specs/mvp-ui-flow/spec.md` (требование `Low resolution support`)
- Кадры: `~/.local/share/sigil-reserve/battle-hud-reserve-{1080,720}/`
