#!/usr/bin/env bash
# Конвейер кадров лаборатории image-clone: пока в очереди есть юниты с описанием
# и без кадра, гонит их по цепочке krea2 -> ernie. Один юнит за раз, параллельно
# писать очередь безопасно — jobloop держит замок на queue.
#
# Перезапуск безопасен: готовый кадр первой версии пропускается, поэтому упавший
# или перезапущенный прогон продолжает с того места, где встал.
#
#   scripts/concept_art/massgen.sh IMG-073 IMG-074 ...   # только эти юниты
#   scripts/concept_art/massgen.sh            # вся очередь с описанием
#   nohup scripts/concept_art/massgen.sh IMG-061 IMG-062 >>/tmp/massgen.log 2>&1 &
set -u
cd "$(dirname "$0")/../.." || exit 1
J=scripts/concept_art/jobloop.py
SCOPE="$*"
CHAIN=$(python3 -c "import json;print(' '.join(json.load(open('image-clone/spec.json'))['chain']))")

pending() {
  python3 - <<'PY'
import json
import sys
from pathlib import Path
q = json.load(open("image-clone/queue.json"))
A = Path("image-clone/attempts")
# Модель берётся из цепочки спека, а не из списка литералов: выпавшую стадию
# конвейер больше не просит доснимать
chain = json.load(open("image-clone/spec.json"))["chain"]
# Скоуп задаётся аргументами: старая партия IMG-001..060 гонялась на qwen21,
# без фильтра конвейер поставил бы ей krea2/ernie второй заход.
scope = set(sys.argv[1:])
# Юнит ждёт вердикта, а не кадра, если у каждой стадии цепочки кадр уже есть:
# просить у него v2 с теми же словами не за чем — конвейер встал бы на стопоре
# побайтового повтора. Пересъёмка ("redraw") — единственный случай v2.
def need(uid, u, m):
    if u["status"] == "redraw":
        v = u.get("versions", {}).get(m, 0) + 1
        return not (A / uid / f"{m}_{uid}_v{v}.webp").exists()
    return not list((A / uid).glob(f"{m}_{uid}_v*.webp"))
# Печатается по модели на юнита: звать стадию, чей кадр не нужен, — рисовать
# лишний кадр и сдвигать версию.
print(" ".join(
    f"{uid}:{','.join(m for m in chain if need(uid, u, m))}"
    for uid, u in sorted(q.items())
    if (not scope or uid in scope)
    and u["status"] in ("in-queue", "redraw") and u["subject"].strip()
    and any(need(uid, u, m) for m in chain)))
PY
}

while :; do
  set -- $(pending $SCOPE)
  [ $# -eq 0 ] && { echo "$(date +%H:%M) очередь на генерацию пуста"; break; }
  last=${@: -1}
  echo "$(date +%H:%M) в работе: $# юнитов, ${1%%:*} .. ${last%%:*}"
  for job; do
    id=${job%%:*}
    IFS=, read -ra models <<< "${job##*:}"
    for m in "${models[@]}"; do
      python3 $J next --model "$m" --id "$id" 2>&1 | tail -2 || echo "FAIL $id $m"
    done
  done
done
