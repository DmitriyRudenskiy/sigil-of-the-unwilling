# Workflow'ы клип-пути (D15)

Рабочие носители прогона: четыре файла — **копия без правок** workflow'ов скилла
`wan22-i2v-character-clip` (`workflows/*.json`), скопирована 2026-10-24; один —
граф первого кадра владельца (`qwen21_union_pose_reference_edit.json`) и его
API-форма. Скилл и файл лежат **вне репо**, а прогон должен воспроизводиться из
репозитория и переживать смену машины — отсюда копии (требование provenance из
SKILL.md скилла).

| файл | роль | кто запускает |
| --- | --- | --- |
| `qwen21_union_pose_reference_edit.json` | **первый кадр (граф владельца, 2026-10-24)**: идентичность с reference + поза из скелета через Union ControlNet, режим `Pose`; `resolution=1024`, `steps=40` | — (editor-форма, человек) |
| `01b_first_frame_pose_controlnet.json` | **то же, API-форма** для `POST /prompt`: узлы и связи сверены с `links` исходника пофайлово, вид полей — с `/object_info` сервера (`reference_image`, `control_image`, `control_mode`) | `tools/gen_clip.py` |
| `01_first_frame_pose.json` | то же без ControlNet — фолбэк, если позу не возьмёт | вручную |
| `02_chromakey_first_frame.json` | BiRefNet → кадр на залитом зелёным поле (`#00FF00`), `ImageCropByMaskAndResize base_resolution=512` (после первого кадра 1024 — это и есть сведение к 512) | `tools/gen_clip.py` |
| `03_wan22_i2v_512_frames.json` | Wan 2.2 I2V: 512×512, `length=4n+1`, два `KSamplerAdvanced` | `tools/gen_clip.py` |
| `04_unkey_frames.json` | снятие хромакея на сервере (`MaskFromColor+ threshold=60`, `GrowMask expand=2`) | **не запускается**: узлу нужен абсолютный путь на машине сервера; те же параметры воспроизводит `unkey()` в `tools/gen_clip.py` локально |

Параметры, заданные не в workflow'ах, а в `gen_clip.py`: картинки (портрет, скелет
позы, кадры клипа), **сид (фиксирован на персонажа — `seed` из `spec.json`, у
исходного графа он был `43`)**, промпт движения, `length`, префиксы сохранения.
