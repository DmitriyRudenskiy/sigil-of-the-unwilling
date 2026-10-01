#!/usr/bin/env python3
"""Разбиение docs/02f-social.md (части I–LII) на тематические файлы 02f-*.
Одновременно переписывает wikilinks [[02f-social#...]] по всем файлам docs/.
Использование: python3 scripts/split_02f.py
"""
import re, os

SRC = 'docs/02f-social.md'

src = open(SRC).read()
lines = src.split('\n')

parts = []           # (lineno, title) for '# Часть ...'
for i, l in enumerate(lines):
    if l.startswith('# Часть '):
        parts.append((i + 1, l[2:].strip()))

epi_start = next(i for i, l in enumerate(lines) if l.startswith('# Эпилог')) + 1
intro = '\n'.join(lines[8:parts[0][0] - 1]).rstrip()
epilogue = '\n'.join(lines[epi_start - 1:]).rstrip()

def find(prefix):
    return next(ln for ln, t in parts if t.startswith(prefix))

order = ['a-core', 'b-new-layers', 'c-forest-city-economy', 'd-world', 'e-society', 'f-scenarios']
starts = {
    'a-core': find('Часть I.'),
    'b-new-layers': find('Часть XIII.'),
    'c-forest-city-economy': find('Часть XXVIII.'),
    'd-world': find('Часть XXXVII.'),
    'e-society': find('Часть XLIV.'),
    'f-scenarios': find('Часть L.'),
}
ends = {}
for gi, g in enumerate(order):
    nxt = starts[order[gi + 1]] if gi + 1 < len(order) else epi_start
    ends[g] = nxt - 1

titles = {
    'a-core': 'Социальная система — ядро (части I–XII)',
    'b-new-layers': 'Социальная система — новые слои (части XIII–XXVII)',
    'c-forest-city-economy': 'Социальная система — Лес, город, экономика (части XXVIII–XXXVI)',
    'd-world': 'Социальная система — мир и ритмы (части XXXVII–XLIII)',
    'e-society': 'Социальная система — общество и игрок (части XLIV–XLIX)',
    'f-scenarios': 'Социальная система — сценарии и сводки (части L–LII)',
}

def fm(title, status='draft'):
    return ('---\ntitle: %s\ntags:\n  - gdd\n  - mechanic\n  - open-question\nstatus: %s\n'
            'date: 2026-10-02\n---\n') % (title, status)

# roman -> note name
note_of_part = {}
for g in order:
    for ln, t in parts:
        if starts[g] <= ln <= ends[g]:
            note_of_part[re.match(r'Часть ([IVXL]+)\.', t).group(1)] = '02f-' + g

def heading_line_to_note(title):
    """Note containing a heading with exactly this title (part or subheading)."""
    for ln, t in parts:
        if t == title:
            for g in order:
                if starts[g] <= ln <= ends[g]:
                    return '02f-' + g
    # subheading inside a part block: search original lines
    for i, l in enumerate(lines):
        if l[2:].strip() == title and l.startswith('## '):
            owner = max((ln for ln, t in parts if ln <= i + 1), default=None)
            for g in order:
                if starts[g] <= owner <= ends[g]:
                    return '02f-' + g
    return '02f-social'  # hub sections (frame etc.)

LINK_RE = re.compile(r'\[\[02f-social#([^\]|]+)(?:\|([^\]]*))?\]\]')

def convert(text):
    def repl(m):
        title, disp = m.group(1), m.group(2)
        mm = re.match(r'Часть ([IVXL]+)\.', title)
        if mm:
            target = note_of_part.get(mm.group(1), '02f-social')
        elif title.startswith(('Пост-пивотная рамка', 'Социальная система — поселение')):
            target = '02f-social'
        else:
            target = heading_line_to_note(title)
        link = '[[%s#%s' % (target, title)
        return link + ('|%s]]' % disp if disp is not None else ']]')
    return LINK_RE.sub(repl, text)

files = {}

# --- hub file: intro + index of parts ---
rows = []
for g in order:
    for ln, t in parts:
        if starts[g] <= ln <= ends[g]:
            num = re.match(r'Часть ([IVXL]+)\.', t).group(1)
            rows.append('| %s | [[%s#%s\\|%s]] |' % (t.replace('Часть ', '', 1), '02f-' + g, t, '02f-' + g))
hub = fm('Социальная система — хаб (рамка Q16 и индекс частей I–LII)') + '\n' + intro + \
      '\n\n---\n\n## Индекс частей (I–LII)\n\n| Часть | Файл |\n|---|---|\n' + '\n'.join(rows) + \
      '\n\n*Ссылки вида «02f N.N» указывают на подсекцию N.M Части N соответствующего файла.*\n'
files[SRC] = hub

# --- split files ---
FN = {g: 'docs/02f-%s.md' % g for g in order}
for g in order:
    body = '\n'.join(lines[starts[g] - 1:ends[g]]).rstrip()
    files[FN[g]] = fm(titles[g]) + '\n' + body + '\n'

files['docs/02f-meta.md'] = fm('Социальная система — эпилог и маппинг интеграции', status='reference') + '\n' + epilogue + '\n'

# convert links everywhere (hub, splits, meta, external referencing files)
ext = ['docs/00-glossary.md', 'docs/02e-city.md', 'docs/02g-city-hex.md', 'docs/BANK.md', 'docs/QUESTIONS.md',
       'docs/04-narrative.md', 'docs/SYNC_DECISIONS.md', 'docs/MVP-scope.md', 'docs/dev-tickets.md',
       'docs/00-overview.md', 'docs/01-core-loop.md', 'docs/02-mechanics.md', 'docs/03-progression.md',
       'docs/05-content.md', 'docs/06-economy.md', 'docs/07-ui-ux.md', 'docs/08-tech.md', 'docs/09-risks.md',
       'docs/10-worldbuilding.md', 'docs/11-cards.md', 'docs/GLOSSARY.md', 'docs/STRUCTURE_AUDIT.md',
       'docs/RESTRUCTURING_LOG.md']
for p in ext:
    if os.path.exists(p):
        files[p] = convert(open(p).read())

for p in [SRC] + [FN[g] for g in order] + ['docs/02f-meta.md']:
    files[p] = convert(files[p])

for p, content in files.items():
    with open(p, 'w') as f:
        f.write(content.rstrip() + '\n')

print('written %d files:' % len(files))
for p in sorted(files):
    print(' ', p, sum(1 for _ in open(p)))
