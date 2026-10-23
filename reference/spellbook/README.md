# Иконки из книги заклинаний — прогон конвейера

Листы 3×3 для ассет-пула игры: 22 фотографии разворотов → 264 квадратных
кропа → 29 листов по 9 разнородных иконок + 3 остатка.

## Что в git и что локально

В git — только текстовые артефакты прогона:

| файл | содержимое |
| --- | --- |
| `report.md` | аудит входа, режимы детекции по листам, метрики отбора, md5 каждого листа, замены антидубля, остаток |
| `sheets.json` | состав листов (имена кропов по клеткам 00–08), метрики, пары «книга↔съёмка» |
| `detections.json` | по каждому исходному листу: разрешение, режим (`sam` / фолбэк), число масок, клетки с клампом |

Пиксели (153 МБ: `crops/`, `sheets/`, `qc/`, `residual/`, `embeddings.npz`) —
локально, `reference/*` в git не входит (правило комплекта: см. `INDEX.md`
«Почему не в git»). Контроль соответствия — md5 листов в `report.md`.

## Воспроизвести

```sh
python3 tools/spellbook_sheets/run.py \
    --input /Users/user/Downloads/__spell_book_raw --out reference/spellbook --yes
python3 tools/spellbook_sheets/check.py --out reference/spellbook
```

Нужны: SAM 3.1 (`VisionFlow/models/sam3.1_multiplex.pt`, 3.3 GB), CLIP
`laion/CLIP-ViT-L-14-laion2B-s32B-b82K` из HF-кэша, `dataset_prep.py` из
`VisionEmbed-CLI` (импортируется по пути). Прогон без кэша ≈ 2¼ мин на M2
(SAM на MPS, CLIP на CPU); с кэшем векторов ≈ 1¼ мин. Два прогона с одним seed
дают идентичные `sheets.json` и md5 листов.
