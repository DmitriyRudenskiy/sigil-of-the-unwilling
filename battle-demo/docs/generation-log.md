# Реестр прогонов спрайтов (задача 6.10)

Строка = один кадр. Источник строки — `artifacts/generation-manifest.json`
(его пишет `tools/gen_frames.py`), вердикт — `artifacts/verdicts.json`.
Пиксели кадров в git не идут (D-185); контрольные суммы — в манифесте.

| персонаж | анимация | кадр | портрет | карта позы | seed | рез. | кадр | md5 | вердикт |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| knight | idle | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_01.png` | 9998eafd | брак: поза не читается — кадр совпадает с idle_02 (мелкий сдвиг 5 px); карта переработана |
| knight | idle | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_02.png` | dfb0b8ec | брак: то же |
| knight | walk | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_01.png` | 245a3ee6 | годен: профильный шаг, идентичность и стиль держатся |
| knight | walk | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_02.png` | cfbe9c3f | годен: стойка на прямой ноге; щит круглый вместо киварного — следить |
| knight | walk | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_03.png` | abe612d1 | годен: вышаг сзади, плащ пропал — править на 6.9 |
| knight | walk | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_04.png` | 4f6c72f9 | годен: вышаг, щит круглый |
