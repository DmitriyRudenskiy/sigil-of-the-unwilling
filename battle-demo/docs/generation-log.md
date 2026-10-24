# Реестр прогонов спрайтов (задача 6.10)

Строка = один кадр. Источник строки — `artifacts/generation-manifest.json`
(его пишет `tools/gen_frames.py`), вердикт — `artifacts/verdicts.json`.
Пиксели кадров в git не идут (D-185); контрольные суммы — в манифесте.
Один кадр может стоять несколькими строками — это перегенерация после брака;
вердикт относится к последней строке (последнему прогону).

| персонаж | анимация | кадр | портрет | карта позы | seed | рез. | кадр | md5 | вердикт |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| knight | idle | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_01.png` | 9998eafd | годен: стойка уже, корпус прямо |
| knight | idle | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_02.png` | dfb0b8ec | годен: ноги шире, вес перенесён — кадр 1 и 2 различаются |
| knight | walk | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_01.png` | 245a3ee6 | годен: профильный шаг, идентичность и стиль держатся |
| knight | walk | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_02.png` | cfbe9c3f | годен: стойка на прямой ноге; щит круглый вместо киварного — следить |
| knight | walk | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_03.png` | abe612d1 | годен: вышаг сзади, плащ пропал — править на 6.9 |
| knight | walk | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/walk_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/walk_04.png` | 4f6c72f9 | годен: вышаг, щит круглый |
| knight | idle | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_03.png` | 1866f356 | брак: совпадает с idle_01 (перенос веса 14 px модель выпрямила) |
| knight | idle | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_04.png` | efc6dee7 | брак: совпадает с idle_01; вывод: idle держит два кадра, дальше — bob в движке |
| knight | attack | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/attack_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/attack_01.png` | 0f12999e | годен: молот вперёд двумя руками, поза читается |
| knight | attack | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/attack_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/attack_02.png` | 1f0120e2 | годен: молот опущен, корпус собран — замах |
| knight | attack | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/attack_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/attack_03.png` | ab9b0725 | брак: дальняя рука пуста — молот потерян, щит круглый; правка 6.9 |
| knight | attack | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/attack_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/attack_04.png` | 421b85ce | годен: удар снизу, наклон читается |
| knight | hit | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/hit_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/hit_01.png` | 703048d9 | годен: сильный наклон вперёд, колени согнуты |
| knight | hit | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/hit_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/hit_02.png` | ae2f80f2 | годен: наклон меньше — отход |
| knight | hit | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/hit_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/hit_03.png` | dcbfa848 | годен: стойка почти прямая (возврат в покой) |
| knight | hit | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/hit_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/hit_04.png` | 90950dc8 | годен: возврат в покой; 03 и 04 близки — это хвост анимации |
| knight | turn | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/turn_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/turn_01.png` | 4780dff4 | годен: три четверти |
| knight | turn | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/turn_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/turn_02.png` | 01cf0e51 | годен: полный профиль — сжатие корпуса прочиталось как поворот |
| knight | turn | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/turn_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/turn_03.png` | 097be5ad | брак: кадр совпадает с turn_04 (0.68 слишком близко к 1.0) |
| knight | turn | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/turn_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/turn_04.png` | f5cb10d7 | брак: то же — кадр 3 и 4 не различаются |
| knight | idle | 1 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_01.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_01.png` | 9998eafd | годен: стойка уже, корпус прямо |
| knight | idle | 2 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_02.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_02.png` | a78bdec2 | годен: ноги шире, вес перенесён — кадр 1 и 2 различаются |
| knight | idle | 3 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_03.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_03.png` | dbb30cbb | брак: совпадает с idle_01 (перенос веса 14 px модель выпрямила) |
| knight | idle | 4 | `battle-demo/assets/portraits/knight.png` | `battle-demo/assets/poses/knight/idle_04.png` | 1101 | 768 | `battle-demo/artifacts/gen/knight/idle_04.png` | 12dc161e | брак: совпадает с idle_01; вывод: idle держит два кадра, дальше — bob в движке |
