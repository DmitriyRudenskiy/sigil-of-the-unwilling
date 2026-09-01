# Console Allowlist — допустимый вывод в консоли Godot

Единый источник «чистоты» для гейтов operability-verification
(`game/tools/shell/run_operability.sh`) и console-hygiene
(`game/tools/shell/check_console_clean.sh`). Runner читает первый столбец
таблицы как набор ERE; найденные строки не считают предупреждением.

> **Ложные срабывания (app-логгер)** — лог самого приложения, намеренные
> проверки, **не** регрессия кода. Они жёстко вырезаются из скана
> (`EXCLUDE_RE` в `run_operability.sh`) независимо от allowlist:
>
> - `ERROR: [color=gray][Save ][/color] SaveManager: parse error …`
>   (SaveManager пробует распарсить битый/тестовый save)
> - `WARNING: Unknown template: NONEXISTENT`
>   (TemplateEngine проверяет неизвестный шаблон)
> - `ERROR: Failed loading resource: … File not found` (SaveManager)

## Паттерны (ERE, первый столбец)

### App-логгер (намеренные проверки, не регрессия)

| Pattern | Description |
|---|---|
| `Unknown template` | app-логгер TemplateEngine (намеренная проверка) |
| `SaveManager: parse error` | app-логгер SaveManager (намеренная проверка) |

### App-предупреждения из юнит-тестов (легитимные)

Юнит-тесты намеренно подают некорректные данные, чтобы проверить graceful
деградацию. Приложение логирует их через `push_warning`. Тесты 4696/4696
passed — это ожидаемый вывод, а не предупреждения Godot. Допустимы:

| Pattern | Description |
|---|---|
| `: unknown slot` | HeroInventory: обработка неизвестного слота |
| `SettingsScreen: .* not found` | SettingsScreen: закрытие отсутствующего экрана |
| `Season: некорректный месяц` | Season: фолбэкс на весну для некорректного месяца |
| `DemographicTurnProcessor: registry не задан` | тест без setup() |
| `SoundManager: no file` | SoundManager: отсутствует аудиофайл |
| `SoundManager: unknown .* cue` | SoundManager: неизвестный cue |
| `SoundManager: bus '.*' not found` | SoundManager: авто-загрузка, сценарии operability
  гоняются на графическом (OpenGL) сервере отображения, а не headless —
  AudioServer еще не содержит кастомных шин `SFX`/`Music`. Не регрессия,
  не связано с изменяемым кодом (проявляется и без правок) |

## Как добавить

1. Запусти `bash game/tools/shell/run_operability.sh`.
2. Если предупреждение попало в отчёт, но оно легитимно — добавь его ERE
   в таблицу выше (или, если это app-логгер — в блок «Ложные срабывания»).
3. Перепуски `run_operability.sh` — предупреждение перестанет валить гейт.

Настоящие ошибки (`SCRIPT ERROR`, `Invalid call`, `Failed to load script`,
`Could not find type …`, `Parse error`, `E 0:` и т.д.) **в allowlist не
попадают** — их нужно чинить, а не исключать.
