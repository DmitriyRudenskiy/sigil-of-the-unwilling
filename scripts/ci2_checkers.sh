#!/usr/bin/env bash
# CI-2: чекеры (CI-1-семья) — красные при любом нарушении.
# Область — индекс (git ls-files): в CI checkout = чистое дерево = индекс.
# (1) пары «скрипт+.uid» — в обе стороны (CI-1(7), Q-M25): ни .uid-сирота,
#     ни скрипт-сирота;
# (2) case-дубликаты в индексе по нормализованному пути (CI-1(8));
# (3) маркеры конфликтов (урок 67655e7: после мержа — git grep пуст);
# (4) пары «ассет+.import» — в обе стороны, только game/assets/
#     (вендорные addons/ и openspec/ — вне области: gdunit4 шипит .import
#     без .png, openspec-архив — референс-скриншоты, не игровые ассеты).
set -u
cd "$(dirname "$0")/.."
FAIL=0

echo "=== checker 1: script+.uid pairs (CI-1(7), обе стороны) ==="
ORPHAN_UIDS="$(git ls-files '*.uid' | while read -r f; do
	git ls-files --error-unmatch "${f%.uid}" >/dev/null 2>&1 || echo "$f"
done)"
GD_NO_UID="$(git ls-files '*.gd' | while read -r f; do
	git ls-files --error-unmatch "$f.uid" >/dev/null 2>&1 || echo "$f"
done)"
if [ -n "$ORPHAN_UIDS" ]; then
	echo "RED: .uid без скрипта-родителя:"; echo "$ORPHAN_UIDS"; FAIL=1
fi
if [ -n "$GD_NO_UID" ]; then
	echo "RED: .gd без .uid:"; echo "$GD_NO_UID"; FAIL=1
fi
if [ -z "$ORPHAN_UIDS" ] && [ -z "$GD_NO_UID" ]; then
	echo "OK: пары скрипт+.uid целы"
fi

echo "=== checker 2: case-дубликаты в индексе (CI-1(8)) ==="
DUPS="$(git ls-files | tr '[:upper:]' '[:lower:]' | sort | uniq -d)"
if [ -n "$DUPS" ]; then
	echo "RED: case-дубликаты (нормализованный путь):"; echo "$DUPS"; FAIL=1
else
	echo "OK: case-дубликатов нет"
fi

echo "=== checker 3: маркеры конфликтов (урок 67655e7) ==="
MARKERS="$(git grep -lE '^(<{7}|={7}|>{7})' -- . 2>/dev/null)"
if [ -n "$MARKERS" ]; then
	echo "RED: маркеры конфликтов в:"; echo "$MARKERS"; FAIL=1
else
	echo "OK: маркеров конфликтов нет"
fi

echo "=== checker 4: asset+.import pairs (game/assets/, обе стороны) ==="
ASSET_EXTS='*.png *.jpg *.jpeg *.webp *.mp3 *.wav'
ASSETS_NO_IMP="$(git ls-files $ASSET_EXTS | grep '^game/assets/' | while read -r f; do
	git ls-files --error-unmatch "$f.import" >/dev/null 2>&1 || echo "$f"
done)"
IMP_NO_ASSET="$(git ls-files 'game/assets/*.import' | while read -r f; do
	git ls-files --error-unmatch "${f%.import}" >/dev/null 2>&1 || echo "$f"
done)"
if [ -n "$ASSETS_NO_IMP" ]; then
	echo "RED: ассет без .import:"; echo "$ASSETS_NO_IMP"; FAIL=1
fi
if [ -n "$IMP_NO_ASSET" ]; then
	echo "RED: .import без ассета:"; echo "$IMP_NO_ASSET"; FAIL=1
fi
if [ -z "$ASSETS_NO_IMP" ] && [ -z "$IMP_NO_ASSET" ]; then
	echo "OK: пары ассет+.import целы"
fi

echo "=== checker 5: workflow YAML (anti zero-job, раунд 11 §2) ==="
# Урок af245eb (раунд 10): незакавыченный «name: Lint (gdtoolkit: ...)» —
# YAML-ошибка → ран с 0 jobs и conclusion=failure БЕЗ логов (недиагностируемо).
# Локальный валидатор ловит класс до пуша.
if python3 -c 'import yaml' 2>/dev/null; then
	YAML_BAD=""
	for wf in .github/workflows/*.yml; do
		[ -f "$wf" ] || continue
		python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$wf" 2>/dev/null || YAML_BAD="$YAML_BAD $wf"
	done
	if [ -n "$YAML_BAD" ]; then
		echo "RED: workflow не парсится YAML:$YAML_BAD"; FAIL=1
	else
		echo "OK: workflow-файлы парсятся YAML"
	fi
else
	echo "SKIPPED: нет PyYAML в python3 (не красим: неизвестный раннер)"
fi

echo ""
if [ "$FAIL" -ne 0 ]; then
	echo "CHECKERS: RED"
	exit 1
fi
echo "CHECKERS: GREEN"
exit 0
