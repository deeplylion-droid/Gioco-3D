"""Correzioni al kit di dettagli della sala per il controllo di posizionamento severo del 22 ottobre (elenco di
ambienti-1, docs/tecnico/posizionamento/elenchi/ambienti-1.md):
  - la corsa di tubi 'corsa_453' sul muro nord (sotto la galleria) cominciava a metà muro, con il primo capo che non
    arrivava da nessuna parte: tolta, con le sue colature (i tubi devono partire e arrivare da qualche parte);
  - det_asciugamano_3 della spiaggia stava 2 cm sopra il pavimento: appoggiato.
Lavora su tutte e due le copie (godot/assets/ambiente/dettagli/ e assets_src/ambiente_dettagli/) e mette i posti
tolti, con il motivo, in assets_src/ambiente_dettagli/posizionamento_tolti_2026-10-22.json (niente si perde). Si
può rilanciare.
Uso (dalla radice): python3 tools/dettagli_sala_22ottobre.py
"""
import json, os

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
COPIE = [os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'dettagli', 'posizionamento.json'),
         os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento.json')]
TOLTI = os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento_tolti_2026-10-22.json')
GRUPPI_TOLTI = {'corsa_453': "corsa di tubi a metà del muro nord: il primo capo non arrivava da nessuna parte"}
APPOGGIA = {'det_asciugamano_3': 0.001}   # nodo: quota del pavimento (era 2 cm sopra)


def main():
    tolti = json.load(open(TOLTI)) if os.path.exists(TOLTI) else []
    for p in COPIE:
        if not os.path.exists(p):
            continue
        d = json.load(open(p))
        resto = []
        for q in d['posti']:
            if q.get('gruppo') in GRUPPI_TOLTI:
                if p == COPIE[0] and not any(t['posto'] == q for t in tolti):
                    tolti.append({'posto': q, 'motivo': GRUPPI_TOLTI[q['gruppo']]})
                continue
            if q['nodo'] in APPOGGIA and q.get('gruppo') == 'spiaggia_373':
                q['posizione'][1] = APPOGGIA[q['nodo']]
            resto.append(q)
        print(os.path.relpath(p, RADICE), len(d['posti']), '->', len(resto))
        d['posti'] = resto
        with open(p, 'w') as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
    with open(TOLTI, 'w') as f:
        json.dump(tolti, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
