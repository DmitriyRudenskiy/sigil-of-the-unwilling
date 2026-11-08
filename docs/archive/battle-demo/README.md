# Запись выведенного стенда `battle-demo/`

Сюда легли 21 документ и `CHANGELOG.md` демо-стенда боя, выведенного из репозитория
2026-11-09 (вопрос Q-M139, решение владельца: перенести наработки, папку удалить).
Сменой `battle-demo-retire`.

**Это запись, а не живые доки.** Тексты не правились: ни формулировки решений, ни
пути внутри них. Относительные пути здесь (`tools/gen_clip.py`,
`assets/reference/walk-sample.png`, `data/units/*.tres`) надо читать от корня
бывшего стенда, то есть от `battle-demo/`, которого в дереве больше нет. Зона
исключена из графа документов так же, как банк канона (`scripts/check_docs_links.py:
ARCHIVE_DIR`), поэтому битых ссылок и отсутствующего фронтоматтера гейты не видят.

## Куда переехали носители, на которые здесь ссылается запись

| Было в стенде | Стало |
| --- | --- |
| `assets/portraits/` (10 PNG) | `scripts/character_kit/portraits/` |
| `assets/sprites/cutthroat/` (20 PNG) | `scripts/character_kit/sprites/cutthroat/` |
| `assets/reference/walk-sample.png` | `scripts/character_kit/runs/walk-sample.png` |
| `tools/build_sprite_frames.gd` | `game/tools/build_sprite_frames.gd` |
| `docs/generation-log.md`, `docs/asset-spec.md` | `docs/archive/battle-demo/` (эта папка) |
| вывод прогонов (`artifacts/`) | `scripts/character_kit/artifacts/`, `runs/` |

Не переехало ничего: боёвка стенда, её 42 теста, `data/units/*.tres`, сцена и
`run_tests.sh`. Модель боя стенда противоречит канону `docs/02d-combat-core.md`
(бескубиковая лестница K2), а её кадры-двойники и `addons/gdunit4` уже лежат в
`game/`. Всё это видно в истории git до коммита удаления.
