#!/usr/bin/env python3
"""T-123 guard: полупустые assert-* в game/tests (без check-метода).

GdUnit4: assert_that(x) / assert_bool(x) без is_true()/is_equal()/... НЕ
проверяет ничего — тест зелёный всегда. Сканер: скобки/строки/комментарии/
переносы цепочек (в т.ч. backslash-continuation). Allowlist —
scripts/ci2_vacuous_allowlist.txt, формат `path:line`, пусто = строго.
Выход: 0 чисто; 1 найдено (stdout — список).
"""
import re
import subprocess
import sys
import pathlib

CHECKS = re.compile(
    r'\.(is_[a-z_]+|has_[a-z_]+|contains[a-z_]*|not_[a-z_]+|ends_with'
    r'|starts_with|does_not_contain[a-z_]*|instanceof|compare)\b')
PAT = re.compile(
    r'assert_(?:that|that_bool|bool|int|str|float|array|dict|object)[ \t]*\(')


def vacuous(src):
    for m in PAT.finditer(src):
        ls = src.rfind('\n', 0, m.start()) + 1
        if src[ls:m.start()].lstrip().startswith('#'):
            continue
        i, depth, instr, esc, ok = m.end() - 1, 0, None, False, True
        while i < len(src):
            c = src[i]
            if instr:
                if esc:
                    esc = False
                elif c == '\\':
                    esc = True
                elif c == instr:
                    instr = None
            elif c in '"\'':
                instr = c
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        else:
            ok = False
        if not ok:
            continue
        j, chain = i + 1, ''
        for _ in range(25):
            nl = src.find('\n', j)
            if nl == -1:
                nl = len(src)
            chain += src[j:nl]
            if chain.rstrip().endswith('\\'):
                j = nl + 1
                continue
            # открытая скобка (multiline-аргумент) или цепочка через '.' — идём дальше
            if chain.count('(') > chain.count(')'):
                j = nl + 1
                continue
            k = nl
            while k < len(src) and src[k] in ' \t':
                k += 1
            if k < len(src) and src[k] == '.':
                j = k
                continue
            break
        if not CHECKS.search(chain):
            yield src[:m.start()].count('\n') + 1


def main():
    allow = set()
    ap = pathlib.Path('scripts/ci2_vacuous_allowlist.txt')
    if ap.exists():
        allow = {l.strip() for l in ap.read_text().splitlines()
                 if l.strip() and not l.startswith('#')}
    files = subprocess.run(
        ['git', 'ls-files', 'game/tests/*.gd'],
        capture_output=True, text=True).stdout.split()
    bad = []
    for p in files:
        try:
            src = open(p, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        for line in vacuous(src):
            loc = f'{p}:{line}'
            if loc not in allow:
                bad.append(loc)
    print('\n'.join(bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
