# Workflow'ы клип-пути (D15)

Копия **без правок** workflow'ов из скилла `wan22-i2v-character-clip`
(`workflows/*.json`), скопирована 2026-10-24. Скилл лежит **вне репо**, а прогон
должен воспроизводиться из репозитория и переживать смену машины — отсюда копия
(требование provenance из SKILL.md скилла).

| файл | роль | кто запускает |
| --- | --- | --- |
| `01b_first_frame_pose_controlnet.json` | первый кадр: идентичность с кадра-источника + поза из DWPose-скелета через Union ControlNet (режим `Pose`) | `tools/gen_clip.py` |
| `01_first_frame_pose.json` | то же без ControlNet — фолбэк, если позу не возьмёт | вручную |
| `02_chromakey_first_frame.json` | BiRefNet → кадр на залитом зелёным поле (`#00FF00`) | `tools/gen_clip.py` |
| `03_wan22_i2v_512_frames.json` | Wan 2.2 I2V: 512×512, `length=4n+1`, два `KSamplerAdvanced` | `tools/gen_clip.py` |
| `04_unkey_frames.json` | снятие хромакея на сервере (`MaskFromColor+ threshold=60`, `GrowMask expand=2`) | **не запускается**: узлу нужен абсолютный путь на машине сервера; те же параметры воспроизводит `unkey()` в `tools/gen_clip.py` локально |

Параметры, заданные не здесь, а в `gen_clip.py`: пути картинок, сид, промпт,
`length`, префиксы сохранения.
