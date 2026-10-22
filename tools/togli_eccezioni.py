"""Toglie da godot/tests/posizionamento_eccezioni.json le voci di una squadra che il controllo non trova più (la lista
"Eccezioni non più trovate" in fondo a docs/tecnico/posizionamento/rapporto.md, dopo un giro del controllo), senza
riscrivere il resto del file (le altre voci restano com'erano, riga per riga).
Uso (dalla radice): python3 tools/togli_eccezioni.py <squadra>"""
import json, re, sys

squadra = sys.argv[1]
md = open('docs/tecnico/posizionamento/rapporto.md').read().split('## Eccezioni non più trovate')[1]
non_trovate = {m.groups() for m in (re.match(r'- (\w+) · (\w+) · `(.+)`', l) for l in md.splitlines()) if m}
trovate = {(x['zona'], x['problema'], x['nodo']) for x in json.load(open('docs/tecnico/posizionamento/rapporto.json'))}
P = 'godot/tests/posizionamento_eccezioni.json'
testo = open(P).read()
dec = json.JSONDecoder()
i = testo.index('[') + 1
pezzi = []          # (inizio, fine, voce)
while True:
    while testo[i] in ' \t\r\n,':
        i += 1
    if testo[i] == ']':
        break
    voce, fine = dec.raw_decode(testo, i)
    pezzi.append((i, fine, voce))
    i = fine
via = [(a, b) for a, b, v in pezzi if v.get('squadra') == squadra and (v['zona'], v['problema'], v['nodo']) in non_trovate
       and (v['zona'], v['problema'], v['nodo']) not in trovate]
for a, b in reversed(via):
    # la voce, con la virgola e lo spazio prima (o dopo, se è la prima)
    j = a
    while testo[j - 1] in ' \t\r\n':
        j -= 1
    if testo[j - 1] == ',':
        testo = testo[:j - 1] + testo[b:]
    else:
        k = b
        while testo[k] in ' \t\r\n':
            k += 1
        if testo[k] == ',':
            k += 1
        testo = testo[:a] + testo[k:]
json.loads(testo)
open(P, 'w').write(testo)
print(f'tolte {len(via)} voci di {squadra}')
