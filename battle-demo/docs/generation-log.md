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
| spearman | idle | 1 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/idle_01.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/idle_01.png` | 17a8d502 | не смотрен |
| spearman | idle | 2 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/idle_02.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/idle_02.png` | db8a4f2c | не смотрен |
| spearman | idle | 3 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/idle_03.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/idle_03.png` | 9aae3866 | не смотрен |
| spearman | idle | 4 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/idle_04.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/idle_04.png` | 639d9330 | не смотрен |
| spearman | walk | 1 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/walk_01.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/walk_01.png` | f6b79a28 | не смотрен |
| spearman | walk | 2 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/walk_02.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/walk_02.png` | 6f8a3689 | не смотрен |
| spearman | walk | 3 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/walk_03.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/walk_03.png` | 528e57dd | не смотрен |
| spearman | walk | 4 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/walk_04.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/walk_04.png` | 73ce246a | не смотрен |
| spearman | attack | 1 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/attack_01.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/attack_01.png` | 60168a49 | не смотрен |
| spearman | attack | 2 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/attack_02.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/attack_02.png` | 4a46dbab | не смотрен |
| spearman | attack | 3 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/attack_03.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/attack_03.png` | c0be5127 | не смотрен |
| spearman | attack | 4 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/attack_04.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/attack_04.png` | 78d9a552 | не смотрен |
| spearman | hit | 1 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/hit_01.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/hit_01.png` | 62cefc76 | не смотрен |
| spearman | hit | 2 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/hit_02.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/hit_02.png` | 7190b5b6 | не смотрен |
| spearman | hit | 3 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/hit_03.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/hit_03.png` | 2edbc074 | не смотрен |
| spearman | hit | 4 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/hit_04.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/hit_04.png` | 47f151bf | не смотрен |
| spearman | turn | 1 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/turn_01.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/turn_01.png` | 731f05bd | не смотрен |
| spearman | turn | 2 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/turn_02.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/turn_02.png` | 6ba93933 | не смотрен |
| spearman | turn | 3 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/turn_03.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/turn_03.png` | a838f986 | не смотрен |
| spearman | turn | 4 | `battle-demo/assets/portraits/spearman.png` | `battle-demo/assets/poses/spearman/turn_04.png` | 1102 | 768 | `battle-demo/artifacts/gen/spearman/turn_04.png` | f92d26e5 | не смотрен |
| archer | idle | 1 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/idle_01.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/idle_01.png` | 9201e974 | не смотрен |
| archer | idle | 2 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/idle_02.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/idle_02.png` | aa030377 | не смотрен |
| archer | idle | 3 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/idle_03.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/idle_03.png` | 55e67249 | не смотрен |
| archer | idle | 4 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/idle_04.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/idle_04.png` | 23e0817f | не смотрен |
| archer | walk | 1 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/walk_01.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/walk_01.png` | bd2e2fc1 | не смотрен |
| archer | walk | 2 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/walk_02.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/walk_02.png` | 452adf0f | не смотрен |
| archer | walk | 3 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/walk_03.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/walk_03.png` | 4ecce07a | не смотрен |
| archer | walk | 4 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/walk_04.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/walk_04.png` | 8b91ddeb | не смотрен |
| archer | attack | 1 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/attack_01.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/attack_01.png` | fd7a6ab1 | не смотрен |
| archer | attack | 2 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/attack_02.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/attack_02.png` | d8914d5d | не смотрен |
| archer | attack | 3 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/attack_03.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/attack_03.png` | a46fddd5 | не смотрен |
| archer | attack | 4 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/attack_04.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/attack_04.png` | 73976631 | не смотрен |
| archer | hit | 1 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/hit_01.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/hit_01.png` | 88be645e | не смотрен |
| archer | hit | 2 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/hit_02.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/hit_02.png` | 479709aa | не смотрен |
| archer | hit | 3 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/hit_03.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/hit_03.png` | 62409758 | не смотрен |
| archer | hit | 4 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/hit_04.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/hit_04.png` | d0716741 | не смотрен |
| archer | turn | 1 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/turn_01.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/turn_01.png` | 76609392 | не смотрен |
| archer | turn | 2 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/turn_02.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/turn_02.png` | 5757e33b | не смотрен |
| archer | turn | 3 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/turn_03.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/turn_03.png` | d6077038 | не смотрен |
| archer | turn | 4 | `battle-demo/assets/portraits/archer.png` | `battle-demo/assets/poses/archer/turn_04.png` | 1103 | 768 | `battle-demo/artifacts/gen/archer/turn_04.png` | 7589751c | не смотрен |
| wizard | idle | 1 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/idle_01.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/idle_01.png` | 4a39b906 | не смотрен |
| wizard | idle | 2 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/idle_02.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/idle_02.png` | 4442d831 | не смотрен |
| wizard | idle | 3 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/idle_03.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/idle_03.png` | 81ac1a69 | не смотрен |
| wizard | idle | 4 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/idle_04.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/idle_04.png` | 4522e469 | не смотрен |
| wizard | walk | 1 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/walk_01.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/walk_01.png` | 66db4183 | не смотрен |
| wizard | walk | 2 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/walk_02.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/walk_02.png` | cf902ec6 | не смотрен |
| wizard | walk | 3 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/walk_03.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/walk_03.png` | 12051c00 | не смотрен |
| wizard | walk | 4 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/walk_04.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/walk_04.png` | 002ec4dd | не смотрен |
| wizard | attack | 1 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/attack_01.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/attack_01.png` | eff38f05 | не смотрен |
| wizard | attack | 2 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/attack_02.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/attack_02.png` | 97067308 | не смотрен |
| wizard | attack | 3 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/attack_03.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/attack_03.png` | 17cd8943 | не смотрен |
| wizard | attack | 4 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/attack_04.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/attack_04.png` | f165ae9d | не смотрен |
| wizard | hit | 1 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/hit_01.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/hit_01.png` | ce626d34 | не смотрен |
| wizard | hit | 2 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/hit_02.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/hit_02.png` | fbf929e6 | не смотрен |
| wizard | hit | 3 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/hit_03.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/hit_03.png` | b029e2cb | не смотрен |
| wizard | hit | 4 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/hit_04.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/hit_04.png` | 06a61c4d | не смотрен |
| wizard | turn | 1 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/turn_01.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/turn_01.png` | 0c90e236 | не смотрен |
| wizard | turn | 2 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/turn_02.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/turn_02.png` | f5f72e6c | не смотрен |
| wizard | turn | 3 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/turn_03.png` | 1104 | 768 | `battle-demo/artifacts/gen/wizard/turn_03.png` | 25d14f53 | не смотрен |
| sorcerer | idle | 1 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/idle_01.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/idle_01.png` | 349eadcc | не смотрен |
| wizard | turn | 4 | `battle-demo/assets/portraits/wizard.png` | `battle-demo/assets/poses/wizard/turn_04.png` | 2104 | 768 | `battle-demo/artifacts/gen/wizard/turn_04.png` | eddccb80 | не смотрен |
| sorcerer | idle | 2 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/idle_02.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/idle_02.png` | 1588c3be | не смотрен |
| sorcerer | idle | 3 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/idle_03.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/idle_03.png` | 2eee9e84 | не смотрен |
| sorcerer | idle | 4 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/idle_04.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/idle_04.png` | 6ce076ae | не смотрен |
| sorcerer | walk | 1 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/walk_01.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/walk_01.png` | 746bff97 | не смотрен |
| sorcerer | walk | 2 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/walk_02.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/walk_02.png` | 9462bafa | не смотрен |
| sorcerer | walk | 3 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/walk_03.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/walk_03.png` | 573120c0 | не смотрен |
| sorcerer | walk | 4 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/walk_04.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/walk_04.png` | d7cab2af | не смотрен |
| sorcerer | attack | 1 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/attack_01.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/attack_01.png` | 0613f018 | не смотрен |
| sorcerer | attack | 2 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/attack_02.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/attack_02.png` | a6789a4e | не смотрен |
| sorcerer | attack | 3 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/attack_03.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/attack_03.png` | 08fa932e | не смотрен |
| sorcerer | attack | 4 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/attack_04.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/attack_04.png` | 6aa6ffda | не смотрен |
| sorcerer | hit | 1 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/hit_01.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/hit_01.png` | 11e573a5 | не смотрен |
| sorcerer | hit | 2 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/hit_02.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/hit_02.png` | 0283aa37 | не смотрен |
| sorcerer | hit | 3 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/hit_03.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/hit_03.png` | 70c5c0df | не смотрен |
| sorcerer | hit | 4 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/hit_04.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/hit_04.png` | 23a22968 | не смотрен |
| sorcerer | turn | 1 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/turn_01.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/turn_01.png` | 916dc8fc | не смотрен |
| sorcerer | turn | 2 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/turn_02.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/turn_02.png` | 32957dc0 | не смотрен |
| sorcerer | turn | 3 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/turn_03.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/turn_03.png` | cb71ed5f | не смотрен |
| sorcerer | turn | 4 | `battle-demo/assets/portraits/sorcerer.png` | `battle-demo/assets/poses/sorcerer/turn_04.png` | 1105 | 768 | `battle-demo/artifacts/gen/sorcerer/turn_04.png` | b5ddbb6a | не смотрен |
| barbarian | idle | 1 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/idle_01.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/idle_01.png` | 4ce8b9f3 | не смотрен |
| barbarian | idle | 2 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/idle_02.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/idle_02.png` | 40cff186 | не смотрен |
| barbarian | idle | 3 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/idle_03.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/idle_03.png` | ebe3262e | не смотрен |
| barbarian | idle | 4 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/idle_04.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/idle_04.png` | 74bcc5dd | не смотрен |
| barbarian | walk | 1 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/walk_01.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/walk_01.png` | 6640eafc | не смотрен |
| barbarian | walk | 2 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/walk_02.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/walk_02.png` | 92873550 | не смотрен |
| barbarian | walk | 3 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/walk_03.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/walk_03.png` | 92b8fed9 | не смотрен |
| barbarian | walk | 4 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/walk_04.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/walk_04.png` | a3a02da1 | не смотрен |
| barbarian | attack | 1 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/attack_01.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/attack_01.png` | fa686eb7 | не смотрен |
| barbarian | attack | 2 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/attack_02.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/attack_02.png` | 269272c4 | не смотрен |
| barbarian | attack | 3 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/attack_03.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/attack_03.png` | b17adae4 | не смотрен |
| barbarian | attack | 4 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/attack_04.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/attack_04.png` | c5cf6e7d | не смотрен |
| barbarian | hit | 1 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/hit_01.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/hit_01.png` | 435d1e55 | не смотрен |
| barbarian | hit | 2 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/hit_02.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/hit_02.png` | b7771373 | не смотрен |
| barbarian | hit | 3 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/hit_03.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/hit_03.png` | c093e72c | не смотрен |
| barbarian | hit | 4 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/hit_04.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/hit_04.png` | b7d2eb10 | не смотрен |
| barbarian | turn | 1 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/turn_01.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/turn_01.png` | 4431f0b7 | не смотрен |
| barbarian | turn | 2 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/turn_02.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/turn_02.png` | abf8455c | не смотрен |
| barbarian | turn | 3 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/turn_03.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/turn_03.png` | 88d0b087 | не смотрен |
| barbarian | turn | 4 | `battle-demo/assets/portraits/barbarian.png` | `battle-demo/assets/poses/barbarian/turn_04.png` | 1106 | 768 | `battle-demo/artifacts/gen/barbarian/turn_04.png` | 0a2ef2e6 | не смотрен |
| stormmage | idle | 1 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/idle_01.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/idle_01.png` | 5db5a455 | не смотрен |
| stormmage | idle | 2 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/idle_02.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/idle_02.png` | dfaaac49 | не смотрен |
| stormmage | idle | 3 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/idle_03.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/idle_03.png` | bd83ba05 | не смотрен |
| stormmage | idle | 4 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/idle_04.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/idle_04.png` | be3dbd04 | не смотрен |
| stormmage | walk | 1 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/walk_01.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/walk_01.png` | d12d294e | не смотрен |
| stormmage | walk | 2 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/walk_02.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/walk_02.png` | e21421d7 | не смотрен |
| stormmage | walk | 3 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/walk_03.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/walk_03.png` | c382be2c | не смотрен |
| stormmage | walk | 4 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/walk_04.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/walk_04.png` | 4bc267b6 | не смотрен |
| stormmage | attack | 1 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/attack_01.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/attack_01.png` | 1531fb5f | не смотрен |
| stormmage | attack | 2 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/attack_02.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/attack_02.png` | fd21959a | не смотрен |
| stormmage | attack | 3 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/attack_03.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/attack_03.png` | e979efff | не смотрен |
| stormmage | attack | 4 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/attack_04.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/attack_04.png` | f6edcb82 | не смотрен |
| stormmage | hit | 1 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/hit_01.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/hit_01.png` | 1b045e59 | не смотрен |
| stormmage | hit | 2 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/hit_02.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/hit_02.png` | 641488a3 | не смотрен |
| stormmage | hit | 3 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/hit_03.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/hit_03.png` | 237a91c9 | не смотрен |
| stormmage | hit | 4 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/hit_04.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/hit_04.png` | 4c8183a0 | не смотрен |
| stormmage | turn | 1 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/turn_01.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/turn_01.png` | 122960bc | не смотрен |
| stormmage | turn | 2 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/turn_02.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/turn_02.png` | 0cb3f228 | не смотрен |
| stormmage | turn | 4 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/turn_04.png` | 1107 | 768 | `battle-demo/artifacts/gen/stormmage/turn_04.png` | 7c148f1d | не смотрен |
| stormmage | turn | 3 | `battle-demo/assets/portraits/stormmage.png` | `battle-demo/assets/poses/stormmage/turn_03.png` | 2107 | 768 | `battle-demo/artifacts/gen/stormmage/turn_03.png` | 585f7e45 | не смотрен |
| cutthroat | idle | 1 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/idle_01.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/idle_01.png` | 32ec76c1 | не смотрен |
| cutthroat | idle | 2 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/idle_02.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/idle_02.png` | b94fe1df | не смотрен |
| cutthroat | idle | 3 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/idle_03.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/idle_03.png` | 7b75d498 | не смотрен |
| cutthroat | idle | 4 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/idle_04.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/idle_04.png` | 938bd01d | не смотрен |
| cutthroat | walk | 1 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/walk_01.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/walk_01.png` | 54e7392e | не смотрен |
| cutthroat | walk | 2 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/walk_02.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/walk_02.png` | 06f32a26 | не смотрен |
| cutthroat | walk | 3 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/walk_03.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/walk_03.png` | 53d36018 | не смотрен |
| cutthroat | walk | 4 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/walk_04.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/walk_04.png` | 5c43b270 | не смотрен |
| cutthroat | attack | 1 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/attack_01.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/attack_01.png` | 4ab55ed5 | не смотрен |
| cutthroat | attack | 2 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/attack_02.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/attack_02.png` | 5b17b064 | не смотрен |
| cutthroat | attack | 3 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/attack_03.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/attack_03.png` | 253a2dc0 | не смотрен |
| cutthroat | attack | 4 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/attack_04.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/attack_04.png` | d4fa9e1a | не смотрен |
| cutthroat | hit | 1 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/hit_01.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/hit_01.png` | 3aff6779 | не смотрен |
| cutthroat | hit | 2 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/hit_02.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/hit_02.png` | b90e074d | не смотрен |
| cutthroat | hit | 4 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/hit_04.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/hit_04.png` | 88f9b845 | не смотрен |
| cutthroat | hit | 3 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/hit_03.png` | 2108 | 768 | `battle-demo/artifacts/gen/cutthroat/hit_03.png` | 81f6f902 | не смотрен |
| cutthroat | turn | 1 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/turn_01.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/turn_01.png` | 62171547 | не смотрен |
| cutthroat | turn | 2 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/turn_02.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/turn_02.png` | 713ddd4d | не смотрен |
| cutthroat | turn | 3 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/turn_03.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/turn_03.png` | c77cedb4 | не смотрен |
| cutthroat | turn | 4 | `battle-demo/assets/portraits/cutthroat.png` | `battle-demo/assets/poses/cutthroat/turn_04.png` | 1108 | 768 | `battle-demo/artifacts/gen/cutthroat/turn_04.png` | 21d05d80 | не смотрен |
| priest | idle | 1 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/idle_01.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/idle_01.png` | e21310fa | не смотрен |
| priest | idle | 2 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/idle_02.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/idle_02.png` | c95a2aa2 | не смотрен |
| priest | idle | 3 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/idle_03.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/idle_03.png` | ae25eb90 | не смотрен |
| priest | idle | 4 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/idle_04.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/idle_04.png` | 232f9481 | не смотрен |
| priest | walk | 1 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/walk_01.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/walk_01.png` | a4794e88 | не смотрен |
| priest | walk | 2 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/walk_02.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/walk_02.png` | 001f95e8 | не смотрен |
| priest | walk | 3 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/walk_03.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/walk_03.png` | fa254f7e | не смотрен |
| priest | walk | 4 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/walk_04.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/walk_04.png` | 6380d4b2 | не смотрен |
| priest | attack | 1 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/attack_01.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/attack_01.png` | 4c1547e2 | не смотрен |
| priest | attack | 2 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/attack_02.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/attack_02.png` | 65caa4d7 | не смотрен |
| priest | attack | 3 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/attack_03.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/attack_03.png` | 775ccd13 | не смотрен |
| priest | attack | 4 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/attack_04.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/attack_04.png` | e7510e00 | не смотрен |
| priest | hit | 1 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/hit_01.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/hit_01.png` | 40afbeac | не смотрен |
| priest | hit | 2 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/hit_02.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/hit_02.png` | f5b86422 | не смотрен |
| priest | hit | 3 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/hit_03.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/hit_03.png` | 12da86af | не смотрен |
| priest | hit | 4 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/hit_04.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/hit_04.png` | 840adc13 | не смотрен |
| priest | turn | 1 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/turn_01.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/turn_01.png` | 74137fe4 | не смотрен |
| priest | turn | 3 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/turn_03.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/turn_03.png` | 891d21ab | не смотрен |
| priest | turn | 2 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/turn_02.png` | 2109 | 768 | `battle-demo/artifacts/gen/priest/turn_02.png` | 07fe8f8a | не смотрен |
| priest | turn | 4 | `battle-demo/assets/portraits/priest.png` | `battle-demo/assets/poses/priest/turn_04.png` | 1109 | 768 | `battle-demo/artifacts/gen/priest/turn_04.png` | 8c88143b | не смотрен |

## Клипы (D15, `tools/gen_clip.py`)

Строка = один клип: 33 кадра движения, из них 4 после прорежки.
Машинная проверка — `measure()` и `verdict()` там же; вердикт —
`artifacts/verdicts.json` по каталогу клипа. Пиксели кадров — вне git (D-185).

| персонаж | анимация | seed | кадров | движение | резкость мин./медиана | снос корпуса | хромакей | вердикт |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| knight | walk | 1101 | 33 | 74.6 | 1111.0/1251.6 | 31.1 px | 3088 | брак: корпус уехал по полу (31.1 px за цикл); остался хромакей (3088 px, 0.100% удержанных пикселей) |
| knight | idle | 1101 | 33 | 19.7 | 1607.4/1677.3 | 1.7 px | 0 | годен: движение 19.7, резкость 1607.4/1677.3, снос 1.7 px, хромакей 0 — петля ping-pong (стык не найден) |
