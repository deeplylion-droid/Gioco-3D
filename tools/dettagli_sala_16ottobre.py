"""Toglie da posizionamento.json (il kit di dettagli della sala) i posti che non vanno più bene con le scelte
dell'utente del 16 ottobre 2026, come nelle proposte approvate (godot/tests/proposte_sala.gd sul branch
lavoro/proposte-sala):
  - i dettagli appesi sotto il soppalco (zona 'sotto la galleria'): il soppalco non c'è più;
  - area bimbi, disposizione 1: i giocattoli e gli oggetti sparsi a terra nell'area, e tutto quello che
    cade sotto la struttura di gioco (spostata nell'angolo nord-ovest), la vasca piccola e i funghi;
  - la parete est dove c'è il varco della sala della torre e dove scorre il portone;
  - il muro sud dove c'è il varco della serranda del magazzino dei gonfiabili (tappa 7 B, ambienti-1).
Lavora su tutte e due le copie (godot/assets/ambiente/dettagli/ e assets_src/ambiente_dettagli/) e mette i
posti tolti, con il motivo, in assets_src/ambiente_dettagli/posizionamento_tolti_2026-10-16.json (niente si
perde). Si può rilanciare: i posti già tolti non ci sono più e il file dei tolti si aggiorna.
Uso (dalla radice): python3 tools/dettagli_sala_16ottobre.py [--prova]
"""
import json, os, sys

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
COPIE = [os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'dettagli', 'posizionamento.json'),
         os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento.json')]
TOLTI = os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento_tolti_2026-10-16.json')

# area bimbi in coordinate Godot (x, z) e i nomi dei giocattoli del kit (come nelle proposte)
AREA_BIMBI = dict(x=(-20.0, -7.4), z=(-24.0, -3.0))
GIOCATTOLI = ("det_barchetta", "det_paletta", "det_secchiello", "det_paperella", "det_pesce", "det_pistola",
              "det_maschera", "det_ciabatta", "det_asciugamano")
STRUTTURA = (-14.6, 19.6)        # centro della struttura di gioco (pianta: x est, y nord = -z di Godot)
VB2 = (-9.6, 18.2)               # centro della vasca piccola
FUNGHI = [(-17.8, 12.2, 0.45), (-12.2, 14.4, 0.35)]   # centro e mezzo ingombro del gambo
# varco della sala della torre nella parete est (pianta) e corsa del portone verso sud
VARCO = dict(x_da=19.5, y=(9.6, 18.6))
# varco della serranda del magazzino nel muro sud (ambienti-1, tappa 7 B): x -15,9..-14,1, alto 2,5 m
SERRANDA = dict(x=(-16.2, -13.8), z_da=19.8, h_sotto=3.1)


def ingombri():
    """Rettangoli (x0, y0, x1, y1) in pianta occupati dalla disposizione 1 (come in disposizioni_bimbi.py)."""
    cx, cy = STRUTTURA
    r = [(cx + x0, cy + y0, cx + x1, cy + y1) for (x0, y0, x1, y1) in ((-4.05, -2.65, 1.65, 3.05), (-3.3, -4.92, -1.9, -2.4))]
    r.append((VB2[0] - 1.75, VB2[1] - 1.75, VB2[0] + 1.75, VB2[1] + 1.75))
    r += [(x - rr, y - rr, x + rr, y + rr) for (x, y, rr) in FUNGHI]
    return r


def motivo(q):
    """Perché un posto va tolto (None se resta)."""
    x, h, z = q['posizione']
    y = -z                                              # pianta
    if q.get('zona') == 'sotto la galleria':
        return 'appeso sotto il soppalco, che non c\'è più'
    if AREA_BIMBI['x'][0] <= x <= AREA_BIMBI['x'][1] and AREA_BIMBI['z'][0] <= z <= AREA_BIMBI['z'][1]:
        if q['nodo'].startswith(GIOCATTOLI):
            return 'giocattolo nell\'area bimbi (disposizione 1)'
        if q.get('zona') in ('sala', 'angolo', 'sotto le lampade'):
            return 'sparso a terra nell\'area bimbi (disposizione 1)'
        for (a, b, c, d) in ingombri():
            if a - 0.2 < x < c + 0.2 and b - 0.2 < y < d + 0.2:
                return 'sotto la struttura di gioco, la vasca piccola o un fungo (disposizione 1)'
    if x > VARCO['x_da'] and VARCO['y'][0] < y < VARCO['y'][1] and h < 5.6:
        return 'nel varco della sala della torre o dove scorre il portone'
    if (z > SERRANDA['z_da'] and SERRANDA['x'][0] < x < SERRANDA['x'][1] and h < SERRANDA['h_sotto']
            and not q['nodo'].startswith('det_tubi')):
        return 'sul muro sud dove c\'è il varco della serranda del magazzino (tappa 7 B)'
    return None


def main():
    prova = '--prova' in sys.argv
    dati = [json.load(open(p)) for p in COPIE]
    if dati[0]['posti'] != dati[1]['posti']:
        print('ATTENZIONE: le due copie di posizionamento.json sono diverse; uso quella del gioco')
    d = dati[0]
    tenuti, tolti = [], []
    for q in d['posti']:
        m = motivo(q)
        if m:
            tolti.append(dict(q, motivo=m))
        else:
            tenuti.append(q)
    from collections import Counter
    print(f'posti: {len(d["posti"])} -> {len(tenuti)} (tolti {len(tolti)})')
    for m, n in Counter(t['motivo'] for t in tolti).most_common():
        print(f'  {n:4d}  {m}')
    if prova:
        return
    vecchi = json.load(open(TOLTI))['tolti'] if os.path.exists(TOLTI) else []
    d['posti'] = tenuti
    d['nota'] = d['nota'].split(' Il 16 ottobre')[0] + (
        " Il 16 ottobre 2026 (scelte dell'utente: niente soppalco, area bimbi disposizione 1, sala della torre a est) "
        "alcuni posti sono stati tolti con tools/dettagli_sala_16ottobre.py: sono in "
        "assets_src/ambiente_dettagli/posizionamento_tolti_2026-10-16.json.")
    r = d.get('riepilogo', {})
    r['posti'] = len(tenuti)
    r['gruppi'] = len({q['gruppo'] for q in tenuti})
    r['per_nodo'] = dict(Counter(q['nodo'] for q in tenuti).most_common())
    r['nodi_diversi'] = len(r['per_nodo'])
    r['nota_16_ottobre'] = "posti, gruppi e per_nodo ricontati dopo i tolti del 16 ottobre; il resto del riepilogo è di prima"
    for p in COPIE:
        with open(p, 'w') as f:
            json.dump(d, f, indent=1, ensure_ascii=False)
    with open(TOLTI, 'w') as f:
        json.dump(dict(nota="Posti del kit di dettagli tolti dalla sala il 16 ottobre 2026 (tools/dettagli_sala_16ottobre.py), "
                            "con il motivo. Coordinate Godot, come posizionamento.json.", tolti=vecchi + tolti),
                  f, indent=1, ensure_ascii=False)
    print('scritto:', *COPIE, TOLTI, sep='\n  ')


if __name__ == '__main__':
    main()
