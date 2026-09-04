## 1. Разведка (до правок)
- [ ] Перечислить все 18 обращений к `_hero` внутри WorldController.gd и все точки установки первого героя (bootstrap → set_hero).
- [ ] Перечислить 3 тестовых файла, подменяющих потребителей (test_hero_survival.gd, test_legend_chronicle.gd, test_worldcontroller_succession_wiring.gd): какие поля/методы они фейкуют.

## 2. Система: реестр + указатель
- [ ] `HeroLifecycleSystem`: `var active_hero: HeroController`, `register_hero_consumer(Callable)`, `_apply_hero_consumers(hero)`; `_install_hero` без жёстких ссылок на потребителей.
- [ ] Удалить `_hero_ptr()`/`_set_hero_ptr()` с обращениями к `world.get_hero()/set_hero()`; guard' `has_method` убрать.
- [ ] `_remove_hero`/`_detach_hero` работают с `active_hero` напрямую.

## 3. Координатор
- [ ] Удалить `var _hero` (WC.gd:22); `get_hero()`/`set_hero()` → делегаты подсистемы.
- [ ] Заменить 18 прямых `_hero` на `get_hero()`.
- [ ] При setup подсистемы зарегистрировать 9 потребителей (порядок D1.1); сохранить `_camera` для лямбды UI.
- [ ] Первый герой (bootstrap) — через `set_hero` → `install_hero`.

## 4. Тесты
- [ ] Обновить 3 затронутых файла под новый путь установки/реестр.
- [ ] L3-тест (wiring): после преемственности все 9 потребителей указывают на нового героя (сравнение ссылок).

## 5. Umbrella
- [ ] В `openspec/changes/world-controller-decoupling/tasks.md` пометить 1.2/1.3 «замещено: hero-lifecycle-boundary (реестр вместо IHeroConsumer)».
- [ ] В спеке umbrella пометить требование IHeroConsumer замещённым (один блок-заметка).

## 6. Gate
- [ ] Полный тест-сьют зелёный (цель: без роста числа файлов/ошибок), operability gate CLEAN.
- [ ] Коммит с точным скоупом.
