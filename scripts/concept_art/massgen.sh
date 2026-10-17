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
from pathlib import Path
q = json.load(open("image-clone/queue.json"))
A = Path("image-clone/attempts")
# Модель берётся из цепочки спека, а не из списка литералов: выпавшую стадию
# конвейер больше не просит доснимать
chain = json.load(open("image-clone/spec.json"))["chain"]
# Версия кадра — следующая после уже печатанной: отклонённый юнит с новыми
# словами ждёт v2, а не пропускается по признаку «v1 есть».
need = lambda uid, u, m: not (A / uid / f"{m}_{uid}_v{u.get('versions', {}).get(m, 0) + 1}.webp").exists()
print(" ".join(sorted(
    uid for uid, u in q.items()
    if u["status"] == "in-queue" and u["subject"].strip()
    and any(need(uid, u, m) for m in chain))))
PY
}

while :; do
  ids=$(pending)
  # скоуп задаётся аргументами: старая партия IMG-001..060 гонялась на qwen21,
  # без фильтра конвейер поставил бы ей krea2/ernie второй заход
  [ -n "$SCOPE" ] && ids=$(comm -12 <(printf '%s\n' $ids) <(printf '%s\n' $SCOPE) | tr '\n' ' ')
  [ -z "${ids// /}" ] && { echo "$(date +%H:%M) очередь на генерацию пуста"; break; }
  set -- $ids
  echo "$(date +%H:%M) в работе: $# юнитов, $1 .. ${@: -1}"
  for id; do
    for m in $CHAIN; do
      python3 $J next --model "$m" --id "$id" 2>&1 | tail -2 || echo "FAIL $id $m"
    done
  done
done
