"""Le misure degli stendardi dell'inseguimento, in un posto solo: le leggono stendardi.py (la geometria) e teli.py (le
texture). Per cambiare la grandezza basta cambiare qui (largo, alto) e rilanciare i due script.

Un lenzuolo matrimoniale è largo 2,4 m e lungo 2,8 m (PEZZA): uno stendardo più grande è fatto di più lenzuoli
cuciti insieme, e con cuciture=True si vedono le cuciture (un lenzuolo per pezzo, ognuno della sua tinta sbiadita)."""

# il lenzuolo da cui sono fatti (largo, alto), in metri
PEZZA = (2.4, 2.8)

# Gli stendardi: nome (la texture), trave (x), y del centro, quota della cima del lenzuolo, largo, alto, girato (gradi
# attorno alla verticale: 0 = il lenzuolo guarda verso -x, cioè verso ovest), cuciture (più lenzuoli cuciti insieme).
# Ognuno accanto a una lampada appesa della sala (inseguimento_luci.json, "appese"), che lo illumina, e dove la vista
# dalla vasca è libera (non dietro le paratie, che lo coprivano).
STENDARDI = [
    # vasca 1: a nord-ovest, oltre la lampada calda (45; 22,5; -19), rivolto a sud verso la vasca (travi 44 e 48); 5 m
    # più a nord della prima prova, che dalla vasca 1 copriva la lampada appesa fredda (43,8; 28,5): ora le sta dietro,
    # a 0,55-0,78 m dal suo cavo (misure di enigmi, docs/collaudo/ricontrollo_stendardi/varianti_fattibilita.txt)
    dict(nome='stendardo_1', x=46.0, y=29.6, cima=-13.3, largo=6.0, alto=9.0, giro=90.0, cuciture=True),
    # vasca 2: a est, accanto alla lampada calda (70,5; 24; -18,5), rivolto a ovest; più a sud del posto dove sale lei
    dict(nome='stendardo_2', x=72.0, y=21.8, cima=-13.8, largo=6.0, alto=9.0, giro=0.0, cuciture=True),
    # vasca 3: a nord-ovest, accanto alla lampada calda bassa (61; 9,9; -23,5), rivolto a est verso la vasca; il fondo
    # resta più di 2 m sopra l'acqua dello scolo 0
    dict(nome='stendardo_3', x=64.0, y=7.2, cima=-13.65, largo=6.0, alto=9.0, giro=180.0, cuciture=True),
    # vasca 3: a nord, rivolto a sud verso la vasca (travi 68 e 72), lontano dalla vasca 1
    dict(nome='stendardo_4', x=70.0, y=12.0, cima=-13.15, largo=6.0, alto=9.0, giro=90.0, cuciture=True),
]

# la texture: pixel per metro (1024 per 3 m), col lato lungo al più LATO_MAX
PPM = 341
LATO_MAX = 2048


def misura(nome):
    for s in STENDARDI:
        if s['nome'] == nome:
            return s
    raise KeyError(nome)


def pixel(s):
    """La texture di uno stendardo (larga, alta) in pixel, in proporzione alla stoffa."""
    w, h = s['largo'] * PPM, s['alto'] * PPM
    k = min(1.0, LATO_MAX / max(w, h))
    return int(round(w * k / 8) * 8), int(round(h * k / 8) * 8)


def pezzi(s):
    """Quanti lenzuoli lo fanno (colonne, righe): 1 x 1 senza cuciture."""
    if not s.get('cuciture'):
        return 1, 1
    import math
    return max(1, math.ceil(s['largo'] / PEZZA[0] - 0.05)), max(1, math.ceil(s['alto'] / PEZZA[1] - 0.05))
