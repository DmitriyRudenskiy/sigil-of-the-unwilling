#!/usr/bin/env bash
# prepare.sh — склейка .gd и .tscn файлов в один контекст-файл
#
# Использование:
#   prepare.sh [опции]
#   prepare.sh --scripts-only
#   prepare.sh --no-addons --no-tests
#   prepare.sh --dirs scripts/ui scripts/map

set -uo pipefail

PROJECT_ROOT="${1:-.}"
if [ "$PROJECT_ROOT" = "--scripts-only" ] || [ "$PROJECT_ROOT" = "--no-addons" ] || \
   [ "$PROJECT_ROOT" = "--no-tests" ] || [ "$PROJECT_ROOT" = "--no-tools" ] || \
   [ "$PROJECT_ROOT" = "--dirs" ] || [ "$PROJECT_ROOT" = "--output" ]; then
    PROJECT_ROOT="."
fi

# Парсинг аргументов
SCRIPTS_ONLY=false
EXCLUDE_ADDONS=false
EXCLUDE_TESTS=false
EXCLUDE_TOOLS=false
SPECIFIC_DIRS=""
OUTPUT="/tmp/project_context.txt"

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --scripts-only) SCRIPTS_ONLY=true; shift ;;
            --no-addons)    EXCLUDE_ADDONS=true; shift ;;
            --no-tests)     EXCLUDE_TESTS=true; shift ;;
            --no-tools)     EXCLUDE_TOOLS=true; shift ;;
            --dirs)         SPECIFIC_DIRS="$2"; shift 2 ;;
            --output)       OUTPUT="$2"; shift 2 ;;
            *)
                if [ ! -d "$1" ]; then
                    echo "❌ Неизвестный параметр: $1"
                    exit 1
                fi
                PROJECT_ROOT="$1"
                shift
                ;;
        esac
    done
}

parse_args "$@"

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Context Prepare                                        ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Project : $PROJECT_ROOT"
echo "║  Output  : $OUTPUT"
echo "╚══════════════════════════════════════════════════════════╝"

# Запускаем find и склеиваем
run_find() {
    local dirs=()

    if [ -n "$SPECIFIC_DIRS" ]; then
        for dir in $SPECIFIC_DIRS; do
            dirs+=("$PROJECT_ROOT/$dir")
        done
    else
        dirs+=("$PROJECT_ROOT")
    fi

    local type_filter
    if [ "$SCRIPTS_ONLY" = true ]; then
        type_filter='-name "*.gd"'
    else
        type_filter='\( -name "*.gd" -o -name "*.tscn" \)'
    fi

    local excludes="-not -name '*.uid' -not -name '*.import' -not -name '.DS_Store'"
    if [ "$EXCLUDE_ADDONS" = true ]; then
        excludes="$excludes -not -path '*/addons/*'"
    fi
    if [ "$EXCLUDE_TESTS" = true ]; then
        excludes="$excludes -not -path '*/tests/*'"
    fi
    if [ "$EXCLUDE_TOOLS" = true ]; then
        excludes="$excludes -not -path '*/tools/*'"
    fi

    # Собираем директорию для поиска
    local dir_args=""
    for d in "${dirs[@]}"; do
        dir_args="$dir_args $d"
    done

    eval "find $dir_args $type_filter $excludes"
}

run_find | sort | while read -r f; do
    # Пропускаем бинарные/служебные файлы
    case "$f" in
        *.uid|*.import|.DS_Store) continue ;;
    esac

    echo ""
    echo "=========================================================================="
    echo "ПУТЬ: $f"
    echo "=========================================================================="
    cat "$f"
done > "$OUTPUT"

# Статистика
LINE_COUNT=$(wc -l < "$OUTPUT" | tr -d ' ')
FILE_SIZE=$(du -h "$OUTPUT" | cut -f1)
FILE_COUNT=$(grep -c "^ПУТЬ:" "$OUTPUT" | tr -d ' ')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Результат"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 📄 Файлов:    $FILE_COUNT"
echo " 📝 Строк:     $LINE_COUNT"
echo " 💾 Размер:    $FILE_SIZE"
echo " 📍 Путь:      $OUTPUT"
echo ""
