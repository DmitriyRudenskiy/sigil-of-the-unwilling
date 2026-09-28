#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Локальный патч аддона gdUnit4 (gitignored, ставится из репозитория вендора).
#
# Вендорный gdUnit4 v6.2.1 шлёт свои self-test-фикстуры с общими class_name,
# которые ЗАГРЯЗНЯЮТ глобальный класс-кэш проекта и ломают его:
#
#   * addons/gdunit4/test/resources/core/City.gd
#         `class_name City` — конфликтует с City (scripts/world/city.gd),
#         глобальный City в кэше .godot указывает на фикстуру, из-за чего
#         `City extends CityData` не резолвится: ~150 parse-ошибок
#         (Faction, CityData, RefCounted, "Cannot infer the type" каскады).
#   * addons/gdunit4/test/core/resources/scan_testsuite_inheritance/
#         by_class_name/BaseTest.gd
#         `class_name BaseTest` — конфликтует с BaseTest
#         (tests/helpers/base_test.gd), `extends BaseTest` резолвится
#         неоднозначно и `make_node()` пропадает из тестов.
#
# Патч переименовывает фикстуры вендора в уникальные имена и обновляет их
# единственные ссылки внутри аддона. Идиампотентен: повторный запуск no-op.
#
# ЗАПУСКАТЬ после `cp -r .../addons/gdunit4 addons/gdunit4` (см. doc/testing.md)
# и автоматически делает run_all.sh перед gdUnit4-секцией.
# ---------------------------------------------------------------------------
set -uo pipefail

cd "$(dirname "$0")/.."   # -> game/
ADDON="addons/gdunit4"

if [ ! -d "$ADDON" ]; then
  echo "patch_gdunit4: аддон $ADDON не установлен — пропускаю (см. doc/testing.md)."
  exit 0
fi

patch_line() {
  local file="$1" pattern="$2" replacement="$3" label="$4"
  if [ -f "$file" ] && grep -qE "$pattern" "$file"; then
    sed -i "s/$pattern/$replacement/" "$file"
    echo "patch_gdunit4: $label"
  fi
}

# --- City fixture -> GdUnitCityFixture ---
patch_line \
  "$ADDON/test/resources/core/City.gd" \
  '^class_name City$' 'class_name GdUnitCityFixture' \
  "City.gd: class_name City -> GdUnitCityFixture"
patch_line \
  "$ADDON/test/asserts/GdUnitObjectAssertImplTest.gd" \
  'auto_free(City\.new())' 'auto_free(GdUnitCityFixture.new())' \
  "GdUnitObjectAssertImplTest.gd: City.new() -> GdUnitCityFixture.new()"

# --- BaseTest fixture -> GdUnitTestSuiteBase ---
patch_line \
  "$ADDON/test/core/resources/scan_testsuite_inheritance/by_class_name/BaseTest.gd" \
  '^class_name BaseTest$' 'class_name GdUnitTestSuiteBase' \
  "by_class_name/BaseTest.gd: class_name BaseTest -> GdUnitTestSuiteBase"
patch_line \
  "$ADDON/test/core/resources/scan_testsuite_inheritance/by_class_name/ExtendedTest.gd" \
  '^extends BaseTest$' 'extends GdUnitTestSuiteBase' \
  "by_class_name/ExtendedTest.gd: extends BaseTest -> extends GdUnitTestSuiteBase"

echo "patch_gdunit4: OK (конфликты class_name устранены)."
