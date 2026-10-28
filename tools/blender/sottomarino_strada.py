"""La strada del tunnel del viaggio sottomarino (l'inseguimento allungato, scelte dell'utente del 24 ottobre, GDD
"Il tunnel del viaggio sottomarino").

Qui c'è solo la linea: la curva del canale, le quote, le misure della sezione e gli ambienti lungo la strada. La
usano il generatore del tunnel (Blender) e la scena del gioco, e la leggono mascotte (lei che fluttua sopra il
canale) e grafica (i tentacoli morbidi) dal JSON che scrive questo script.

Dove: oltre la porta di servizio della passerella del bacino dell'inseguimento (muro ovest della sala delle
condotte, x 40, piano a -30, y 5 di Blender). Il tunnel sta tutto sotto i -22 m: lì nel livello non c'è niente,
tranne le colonne della torre (x 20-40, y 4-26) e della sala delle condotte (x 40-78,5, y -2-32), che si evitano
(misurato con godot/tests/sonda_ingombri_mondo.gd). È una serpentina di quattro rami nord-sud collegati da tre
curve a U, con una S in ogni ramo: circa 550 m, otto ambienti diversi uno dopo l'altro.

Coordinate di Blender (x, y, z in su); in Godot (x, y, z) = (x, z, -y).

Uso: /home/user/tools/blender-venv/bin/python tools/blender/sottomarino_strada.py
     (scrive godot/assets/ambiente/sottomarino/sottomarino_strada.json; non serve Blender)
"""
import json
import math
import os

# --- quote (Blender, z in su) ----------------------------------------------------------------------------------
PIANO = -30.0             # il piano della passerella e della porta del bacino: le banchine stanno qui
ACQUA = -30.42            # il pelo dell'acqua del canale (42 cm sotto le banchine)
FONDO = -30.92            # il fondo del canale: acqua al ginocchio, 50 cm
VOLTA = ACQUA + 8.0       # la chiave della volta: lei (4,5 m) fluttua sopra il canale coi tentacoli alti
VOLTA_MIN = ACQUA + 6.5   # mai sotto: la regola dell'utente è almeno 6 m sopra il canale
IMPOSTA = ACQUA + 4.6     # dove i muri dritti diventano volta

# --- sezione (metri, misurati dall'asse del canale) --------------------------------------------------------------
CANALE = 3.7              # mezza larghezza del canale (7,4 m): lei coi tentacoli aperti sta tutta sopra il canale
BANCHINA = 2.6            # larghezza di ogni banchina
MURO = CANALE + BANCHINA  # dall'asse al muro: 6,3 m (tunnel largo 12,6 m)
SPESSORE = 0.5            # muri e volta

# lei: alta 4,5 m, fluttua sopra il canale; i tentacoli si allargano di circa 2 m per lato
LEI_MEZZA = 3.6           # mezza larghezza di lei coi tentacoli aperti
LEI_BASSO = ACQUA + 1.2   # il punto più basso dei tentacoli: sopra i gommoni (tubolare a 50 cm dall'acqua)
LEI_ALTO = LEI_BASSO + 4.5 + 0.5

PASSO = 0.5               # passo dei campioni della linea

# --- la linea: rami e curve -------------------------------------------------------------------------------------
# la testa del tunnel: il canale comincia alla presa d'acqua profonda (da cui sale lei), a nord, e corre verso sud
TESTA = (33.0, 7.0)
X_RAMI = [33.0, 3.0, -27.0, -57.0]  # i quattro rami (30 m l'uno dall'altro)
Y_SUD = -108.0                         # dove i rami girano in basso
Y_NORD = -6.0                          # dove girano in alto
Y_FINE = -22.0                         # dove finisce l'ultimo ramo (l'approdo col portello)
S_SCARTO = 5.0                         # quanto si sposta di lato la S in mezzo a ogni ramo


def _ramo_s(x, y0, y1, scarto):
    """Un ramo con una S vera: a metà la linea si sposta di lato di `scarto` e poi torna, in due curve morbide."""
    pts = []
    n = int(abs(y1 - y0) / PASSO)
    lung = abs(y1 - y0)
    for k in range(n + 1):
        f = k / n
        y = y0 + (y1 - y0) * f
        # spostamento: 0 nel primo terzo, sale a `scarto` nel secondo terzo, torna a 0 nell'ultimo
        if f < 0.3 or f > 0.7:
            dx = 0.0
        else:
            u = (f - 0.3) / 0.4
            dx = scarto * math.sin(math.pi * u) ** 2
        pts.append((x + dx, y))
    return pts


def _arco(centro, r, a0, a1):
    """Arco di cerchio da a0 ad a1 (radianti), campionato a PASSO."""
    lung = abs(a1 - a0) * r
    n = max(2, int(lung / PASSO))
    return [(centro[0] + r * math.cos(a0 + (a1 - a0) * k / n), centro[1] + r * math.sin(a0 + (a1 - a0) * k / n))
            for k in range(n + 1)]


def linea():
    """I punti (x, y) dell'asse del canale, dalla presa all'approdo."""
    r_u = (X_RAMI[0] - X_RAMI[1]) / 2
    pts = _ramo_s(X_RAMI[0], TESTA[1], Y_SUD, -S_SCARTO)
    pts += _arco((X_RAMI[0] - r_u, Y_SUD), r_u, 0.0, -math.pi)[1:]
    pts += _ramo_s(X_RAMI[1], Y_SUD, Y_NORD, S_SCARTO)[1:]
    pts += _arco((X_RAMI[1] - r_u, Y_NORD), r_u, 0.0, math.pi)[1:]
    pts += _ramo_s(X_RAMI[2], Y_NORD, Y_SUD, -S_SCARTO)[1:]
    pts += _arco((X_RAMI[2] - r_u, Y_SUD), r_u, 0.0, -math.pi)[1:]
    pts += _ramo_s(X_RAMI[3], Y_SUD, Y_FINE, S_SCARTO)[1:]
    return pts


# --- gli ambienti, uno dopo l'altro (metri dalla presa) ------------------------------------------------------------
# (fiume B, "viaggio sottomarino", 19 ottobre: volta a mosaico blu, oblò illuminati, coralli, ancora, forziere,
# palombaro, pesci sui piedistalli, tartaruga appesa, portello da sottomarino all'approdo; ogni ambiente cambia
# colore del mosaico, luce e cose, così ce n'è sempre uno nuovo)
AMBIENTI = [
    dict(nome='presa', titolo="la presa e la galleria del mosaico", fino=65.0,
         nota="la testa del tunnel con la porta del bacino, la presa d'acqua profonda da cui riemerge lei, il primo "
              "rettilineo col mosaico blu e la fila di oblò"),
    dict(nome='coralli', titolo="il giardino dei coralli", fino=118.0,
         nota="coralli finti sulle banchine e sui muri, luce verde-azzurra; un pezzo di banchina crollato"),
    dict(nome='relitto', titolo="il relitto", fino=165.0,
         nota="la prima curva a U col relitto: ancora gigante, forziere, rete con le stelle marine; l'ancora caduta"),
    dict(nome='palombaro', titolo="la sala del palombaro", fino=240.0,
         nota="il tunnel si allarga in una sala alta col palombaro; il primo passaggio basso nella galleria di servizio"),
    dict(nome='pesci', titolo="la parata dei pesci", fino=315.0,
         nota="la seconda curva a U coi pesci di vetroresina sui piedistalli; un cancello di servizio bloccato"),
    dict(nome='tartaruga', titolo="la volta della tartaruga", fino=390.0,
         nota="volta più alta con la tartaruga appesa in alto; un pezzo di volta crollato sulla banchina"),
    dict(nome='abisso', titolo="gli oblò dell'abisso", fino=470.0,
         nota="la terza curva a U con gli oblò grandi e la luce blu scura; il secondo passaggio basso"),
    dict(nome='approdo', titolo="l'approdo", fino=1e9,
         nota="l'ultimo rettilineo e l'approdo col portello da sottomarino (il volantino, FINE DEL CAPITOLO 1)"),
]


def campioni():
    """I campioni della linea ogni PASSO: s, posizione, direzione, ambiente."""
    pts = linea()
    out = []
    s = 0.0
    for i, (x, y) in enumerate(pts):
        if i:
            s += math.hypot(x - pts[i - 1][0], y - pts[i - 1][1])
        a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1.0
        amb = next(k for k, a_ in enumerate(AMBIENTI) if s < a_['fino'])
        out.append(dict(s=round(s, 3), x=round(x, 3), y=round(y, 3), dx=round(dx / l, 4), dy=round(dy / l, 4), ambiente=amb))
    return out


def scrivi(percorso=None):
    c = campioni()
    g = lambda x, y, z: [round(x, 3), round(z, 3), round(-y, 3)]
    dati = dict(
        nota="Strada del tunnel del viaggio sottomarino (tools/blender/sottomarino_strada.py). Coordinate di Godot "
             "(x, y in su, z); l'asse del canale ogni 0,5 m dalla presa (s = 0) all'approdo.",
        lunghezza=c[-1]['s'],
        quote=dict(piano_banchine=PIANO, acqua=ACQUA, fondo_canale=FONDO, imposta_volta=IMPOSTA, chiave_volta=VOLTA,
                   volta_minima=VOLTA_MIN),
        sezione=dict(mezza_larghezza_canale=CANALE, larghezza_banchina=BANCHINA, asse_muro=MURO, spessore_muri=SPESSORE),
        lei=dict(mezza_larghezza_coi_tentacoli=LEI_MEZZA, quota_bassa=LEI_BASSO, quota_alta=LEI_ALTO,
                 nota="lei fluttua sull'asse del canale: fra quota_bassa e quota_alta e a meno di mezza_larghezza "
                      "dall'asse non c'è niente (muri, volta, banchine, gommoni, ostacoli)"),
        porta_bacino=g(40.0, 5.0, PIANO),
        ambienti=[dict(nome=a['nome'], titolo=a['titolo'], fino_a=(a['fino'] if a['fino'] < 1e8 else c[-1]['s']), nota=a['nota'])
                  for a in AMBIENTI],
        asse=[dict(s=p['s'], pos=g(p['x'], p['y'], ACQUA), dir=[p['dx'], 0.0, -p['dy']], ambiente=p['ambiente']) for p in c],
    )
    percorso = percorso or os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'assets', 'ambiente', 'sottomarino',
                                        'sottomarino_strada.json')
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso, 'w') as f:
        json.dump(dati, f, ensure_ascii=False, separators=(',', ':'))
    return dati


if __name__ == '__main__':
    d = scrivi()
    print('lunghezza %.1f m, %d campioni' % (d['lunghezza'], len(d['asse'])))
    for a in d['ambienti']:
        print('  %-10s fino a %6.1f m' % (a['nome'], a['fino_a']))
