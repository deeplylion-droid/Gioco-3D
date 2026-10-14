"""Camera delle onde: il tunnel sotto la piscina a onde, tra il portello sul fondo della piscina e la sala pompe.

Uso:
  /home/user/tools/blender-venv/bin/python tools/blender/ambienti2_camera_onde.py [--render] [--anteprima]
Uscite:
  assets_src/ambienti_tecnici/glb/camera_onde.glb
  docs/report/render_ambienti2/camera_onde*.jpg

Pianta (metri; il tunnel corre lungo +X, origine al centro del pavimento sotto il portello):
  tunnel largo 4,4 e alto 4,2, da X=-2 a X=24. In X=0 il pozzo col portello che sale al fondo della piscina.
  Lato nord (+Y): tre nicchie con le grandi pale delle onde (PALA_1..3), immerse nell'acqua, mosse da un
  albero a gomiti sul soffitto (ALBERO_pale). In fondo alle nicchie le bocche grigliate verso la piscina.
  Lato sud (-Y): le bocchette tonde dell'aria (ARIA_bocchetta_*).
  In X=17,5 e X=21 le due paratie (PARATIA_1, PARATIA_2) che scendono. In X=24 si prosegue verso la sala pompe.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
from ambienti2_comune import *

ARGS = argomenti()
XA, XB = -2.0, 24.0
W, H = 4.4, 4.2
YN, YS = W / 2, -W / 2
SP = 0.3

reset()
M = {}
M['lamiere'] = mat_pbr('lamiere_rivettate', 'MetalPlates013')
M['cemento'] = mat_pbr('cemento', 'Concrete042C')
M['cemento_bagnato'] = mat_pbr('cemento_bagnato', 'Concrete042C', rough='derivate/pavimento_bagnato_Roughness.jpg')
M['ferro'] = mat_pbr('ferro_arrugginito', 'Metal021')
M['tubi'] = mat_pbr('tubo_ruggine', 'Metal041B')
M['ruggine'] = mat_pbr('ruggine', 'Rust004')
M['verde'] = mat_pbr('vernice_verde', 'PaintedMetal006')
M['pericolo'] = mat_pbr('strisce_pericolo', 'PaintedMetal016')
M['rete'] = mat_pbr('rete_grata', 'Fence008A')
M['lamiera'] = mat_pbr('lamiera_forata', 'MetalWalkway014')
M['piastrelle'] = mat_pbr('piastrelle_muro', 'Tiles133D', color='derivate/piastrelle_sporche_Color.jpg',
                          rough='derivate/piastrelle_sporche_Roughness.jpg')
M['giallo'] = mat_pbr('vernice_giallo', 'PaintedMetal006', color='derivate/vernice_giallo_Color.jpg')
M['rosso_luce'] = mat_emissivo('luce_emergenza', (1.0, 0.06, 0.03), 40.0)
M['neon'] = mat_emissivo('neon_azzurro', (0.25, 0.95, 1.0), 25.0)
M['neon_spento'] = mat_pbr('neon_spento', base=(0.7, 0.7, 0.68), roughness=0.3)
M['acqua'] = mat_acqua_nera()
M['gonfiabile'] = mat_pbr('gonfiabile_rosa', base=(0.85, 0.25, 0.45), roughness=0.35)

statici = []
def S(g, ob):
    statici.append((g, ob)); return ob

usa_collezione('struttura')
# ------------------------------------------------------------------ guscio del tunnel
NICCHIE = [6.0, 10.0, 14.0]   # centri X delle nicchie delle pale
NW = 3.0                      # larghezza nicchia
ND = 2.6                      # profondita' nicchia (oltre il muro nord)
POZZO = (0.0, 0.0)            # centro del pozzo del portello
PZ = 1.3                      # lato del pozzo

S('struttura', box('pavimento', ((XA + XB) / 2, 0, -0.15), (XB - XA, W, 0.3), M['cemento_bagnato'], uv=3.0))
# canaletta al centro con un filo d'acqua
S('struttura', box('canaletta', ((XA + XB) / 2, -0.9, 0.005), (XB - XA, 0.4, 0.01), M['lamiera'], uv=1.0))
# muro sud continuo (lamiere sopra 1 m, cemento sotto)
S('struttura', box('muro_s_basso', ((XA + XB) / 2, YS - SP / 2, 0.5), (XB - XA, SP, 1.0), M['cemento'], uv=2.5))
S('struttura', box('muro_s_alto', ((XA + XB) / 2, YS - SP / 2, (1.0 + H) / 2), (XB - XA, SP, H - 1.0), M['lamiere'], uv=2.0))
# muro nord con le aperture delle nicchie
cur = XA
for k, xc in enumerate(NICCHIE + [None]):
    x1 = (xc - NW / 2) if xc is not None else XB
    S('struttura', box(f'muro_n_{k}', ((cur + x1) / 2, YN + SP / 2, H / 2), (x1 - cur, SP, H), M['lamiere'], uv=2.0))
    if xc is not None:
        S('struttura', box(f'architrave_{k}', (xc, YN + SP / 2, H - 0.15), (NW, SP, 0.3), M['lamiere'], uv=2.0))
        cur = xc + NW / 2
# soffitto con il buco del pozzo
px, py = POZZO
for nome, (a, b, c, d) in {'s1': (XA, px - PZ / 2, YS, YN), 's2': (px + PZ / 2, XB, YS, YN),
                           's3': (px - PZ / 2, px + PZ / 2, py + PZ / 2, YN), 's4': (px - PZ / 2, px + PZ / 2, YS, py - PZ / 2)}.items():
    S('struttura', box(f'soffitto_{nome}', ((a + b) / 2, (c + d) / 2, H + 0.15), (b - a, d - c, 0.3), M['cemento'], uv=2.5))
# testate: inizio chiuso, fine aperta verso la sala pompe (tratto buio)
S('struttura', box('testata_ovest', (XA - SP / 2, 0, H / 2), (SP, W, H), M['lamiere'], uv=2.0))
empty('PUNTO_verso_sala_pompe', (XB, 0, 0))

# costole d'acciaio ogni 2 m (profilo a U intorno alla sezione)
for k, x in enumerate([x for x in range(-1, 24, 2)]):
    if any(abs(x - xc) < NW / 2 + 0.1 for xc in NICCHIE):
        # sopra le nicchie solo la parte alta
        S('costole', box(f'costola{k}_s', (x, YS + 0.1, H / 2), (0.25, 0.2, H), M['ferro'], uv=1.0))
        S('costole', box(f'costola{k}_t', (x, 0, H - 0.1), (0.25, W, 0.2), M['ferro'], uv=1.0))
        continue
    S('costole', box(f'costola{k}_s', (x, YS + 0.1, H / 2), (0.25, 0.2, H), M['ferro'], uv=1.0))
    S('costole', box(f'costola{k}_n', (x, YN - 0.1, H / 2), (0.25, 0.2, H), M['ferro'], uv=1.0))
    S('costole', box(f'costola{k}_t', (x, 0, H - 0.1), (0.25, W, 0.2), M['ferro'], uv=1.0))

# ------------------------------------------------------------------ pozzo e portello
usa_collezione('pozzo')
PH = 2.6  # altezza del pozzo sopra il soffitto
for k, (c, d) in enumerate((((px - PZ / 2 - 0.1, py, H + PH / 2), (0.2, PZ + 0.4, PH)), ((px + PZ / 2 + 0.1, py, H + PH / 2), (0.2, PZ + 0.4, PH)),
                            ((px, py - PZ / 2 - 0.1, H + PH / 2), (PZ, 0.2, PH)), ((px, py + PZ / 2 + 0.1, H + PH / 2), (PZ, 0.2, PH)))):
    S('pozzo', box(f'pozzo_{k}', c, d, M['piastrelle'], uv=2.0))
# piastra in cima con il foro tondo del portello (anello) e la piscina sopra (buio azzurrino)
R_P = 0.5
S('pozzo', toro('portello_ghiera', (px, py, H + PH), R_P + 0.05, 0.06, M['ferro'], seg=32, seg2=8))
for k, (c, d) in enumerate((((px - (PZ / 2 + R_P) / 2, py, H + PH + 0.05), (PZ / 2 - R_P, PZ, 0.1)), ((px + (PZ / 2 + R_P) / 2, py, H + PH + 0.05), (PZ / 2 - R_P, PZ, 0.1)),
                            ((px, py - (PZ / 2 + R_P) / 2, H + PH + 0.05), (2 * R_P, PZ / 2 - R_P, 0.1)), ((px, py + (PZ / 2 + R_P) / 2, H + PH + 0.05), (2 * R_P, PZ / 2 - R_P, 0.1)))):
    S('pozzo', box(f'piastra_portello_{k}', c, d, M['ferro'], uv=1.0))
# portello aperto (cardine sul lato +X, ruotato di 110 gradi)
port = [cilindro('PORTELLO_disco', (px, py, H + PH + 0.12), R_P + 0.04, 0.08, M['ferro'], seg=32, uv=1.0)]
port += [o for o in [toro('PORTELLO_volantino', (px, py, H + PH + 0.22), 0.22, 0.02, M['giallo'], seg=24, seg2=6)]]
port.append(cilindro('PORTELLO_perno', (px, py, H + PH + 0.18), 0.04, 0.1, M['ferro'], seg=8))
for p in port:
    applica_trasf(p)
portello = unisci('PORTELLO', port)
cardine = Vector((px + R_P + 0.08, py, H + PH + 0.12))
imposta_origine(portello, cardine)
portello.rotation_euler = (0, math.radians(-110), 0)
portello['cardine'] = 'asse Y Blender (-Z Godot); chiuso = 0, aperto = -110 gradi'
# luce fredda che scende dal portello (la piscina sotto la cupola)
luce('LUCE_portello', 'SPOT', (px, py, H + PH + 1.5), 300, (0.55, 0.7, 0.9), spot=60, mira=(px, py, 0), raggio=0.3)
# scala alla marinara dal pozzo al pavimento (contro la parete -X del pozzo)
LX = px - PZ / 2 + 0.18
for s in (-0.22, 0.22):
    S('pozzo', tubo(f'scala_montante{s}', [(LX, py + s, 0.0), (LX, py + s, H + PH)], 0.025, M['verde'], seg=8))
for k in range(int((H + PH) / 0.3)):
    S('pozzo', cilindro(f'scala_piolo{k}', (LX, py, 0.3 + k * 0.3), 0.018, 0.44, M['ferro'], asse=(0, 1, 0), seg=8, uv=None))
empty('PUNTO_portello', (px, py, H + PH))
empty('PUNTO_arrivo_scala', (px + 0.6, py, 0))

# ------------------------------------------------------------------ nicchie con le pale
usa_collezione('pale')
ACQ_Z = -0.35   # pelo dell'acqua nelle nicchie
FONDO = -1.6
for i, xc in enumerate(NICCHIE):
    n = i + 1
    g = f'NICCHIA_{n}'
    y0, y1 = YN + SP, YN + SP + ND
    S(g, box(f'{g}_fondo', (xc, (y0 + y1) / 2 - SP / 2, FONDO - 0.15), (NW, ND + SP, 0.3), M['cemento'], uv=2.0))
    for s in (-1, 1):
        S(g, box(f'{g}_lato{s}', (xc + s * (NW / 2 + 0.15), (y0 + y1) / 2 - SP / 2, (FONDO + H) / 2), (0.3, ND + SP, H - FONDO), M['lamiere'], uv=2.0))
    S(g, box(f'{g}_tetto', (xc, (y0 + y1) / 2, H + 0.15), (NW + 0.6, ND, 0.3), M['cemento'], uv=2.0))
    # gradino del pavimento: bordo della nicchia, con strisce
    S(g, box(f'{g}_bordo', (xc, YN + SP / 2, -0.5), (NW, SP, 1.0), M['cemento'], uv=2.0))
    S(g, box(f'{g}_bordo_strisce', (xc, YN + 0.1, 0.03), (NW, 0.2, 0.06), M['pericolo'], uv=0.8))
    # parete di fondo con la bocca grigliata verso la piscina
    BW, BH = 2.4, 1.6
    S(g, box(f'{g}_fondo_basso', (xc, y1 + SP / 2, (FONDO + ACQ_Z - 0.6) / 2), (NW + 0.6, SP, ACQ_Z - 0.6 - FONDO), M['lamiere'], uv=2.0))
    S(g, box(f'{g}_fondo_alto', (xc, y1 + SP / 2, (ACQ_Z - 0.6 + BH + H) / 2), (NW + 0.6, SP, H - (ACQ_Z - 0.6 + BH)), M['lamiere'], uv=2.0))
    for s in (-1, 1):
        S(g, box(f'{g}_fondo_lato{s}', (xc + s * (BW / 2 + (NW + 0.6 - BW) / 4), y1 + SP / 2, ACQ_Z - 0.6 + BH / 2), ((NW + 0.6 - BW) / 2, SP, BH), M['lamiere'], uv=2.0))
    zb = ACQ_Z - 0.6 + BH / 2
    for k in range(9):
        S(g, box(f'{g}_sbarra{k}', (xc - BW / 2 + 0.15 + k * (BW - 0.3) / 8, y1, zb), (0.06, 0.08, BH), M['ruggine'], uv=0.5))
    S(g, box(f'{g}_oltre', (xc, y1 + 1.2, zb), (BW, 0.1, BH), M['cemento'], uv=2.0))
    acq = box(f'ACQUA_nicchia_{n}', (xc, (y0 + y1) / 2 - SP / 2, ACQ_Z), (NW, ND + SP, 0.02), M['acqua'], uv=None)
    # pala: piastra con nervature, cerniera sul fondo (asse X)
    HY, HZ = y0 + 1.2, FONDO + 0.3
    PH_ = 2.9
    parti = [box(f'PALA_{n}_piastra', (xc, HY, HZ + PH_ / 2), (NW - 0.4, 0.08, PH_), M['ferro'], uv=1.5)]
    for k in range(3):
        parti.append(box(f'PALA_{n}_nerv_h{k}', (xc, HY - 0.07, HZ + 0.6 + k * 1.0), (NW - 0.4, 0.1, 0.12), M['giallo'], uv=1.0))
    for k in (-1, 0, 1):
        parti.append(box(f'PALA_{n}_nerv_v{k}', (xc + k * 0.85, HY - 0.07, HZ + PH_ / 2), (0.12, 0.1, PH_), M['giallo'], uv=1.0))
    parti.append(box(f'PALA_{n}_bordo', (xc, HY - 0.06, HZ + PH_ - 0.12), (NW - 0.4, 0.1, 0.24), M['pericolo'], uv=0.6))
    parti.append(cilindro(f'PALA_{n}_cerniera', (xc, HY, HZ), 0.12, NW - 0.3, M['ruggine'], asse=(1, 0, 0), seg=16))
    parti.append(box(f'PALA_{n}_attacco', (xc, HY - 0.15, HZ + PH_ - 0.1), (0.3, 0.25, 0.25), M['giallo'], uv=0.6))
    for p in parti:
        applica_trasf(p)
    pala = unisci(f'PALA_{n}', parti)
    imposta_origine(pala, (xc, HY, HZ))
    pala.rotation_euler = (math.radians(-14 + 12 * i), 0, 0)
    pala['asse_rotazione'] = 'X; oscilla tra -12 e +12 gradi'
    empty(f'ARIA_nicchia_{n}', (xc, y1 - 0.3, ACQ_Z + 0.3))
    if True:
        luce(f'LUCE_nicchia_{n}', 'POINT', (xc + 1.0, y1 - 0.5, H - 0.6), 30, (1.0, 0.1, 0.05), raggio=0.08)
        S(g, sfera(f'{g}_lampada', (xc + 1.0, y1 - 0.15, H - 0.6), 0.09, M['rosso_luce'], seg=12, uv=None))

# albero a gomiti sul soffitto, lungo tutte le nicchie (ruota attorno a X)
AY, AZ = YN + SP + 0.45, H - 0.75
alb = [cilindro('ALBERO_pale_asse', (10.0, AY, AZ), 0.14, 12.5, M['tubi'], asse=(1, 0, 0), seg=20, uv=1.0)]
for i, xc in enumerate(NICCHIE):
    ang = i * 2 * math.pi / 3
    for s in (-0.35, 0.35):
        alb.append(box(f'ALBERO_gomito{i}{s}', (xc + s, AY + 0.25 * math.cos(ang), AZ + 0.25 * math.sin(ang)), (0.1, 0.25, 0.7), M['ferro'], uv=0.6,
                       rot=(ang + math.pi / 2, 0, 0)))
    alb.append(cilindro(f'ALBERO_perno{i}', (xc, AY + 0.45 * math.cos(ang), AZ + 0.45 * math.sin(ang)), 0.07, 0.8, M['ruggine'], asse=(1, 0, 0), seg=10))
for k, xs in enumerate((4.1, 8.0, 12.0, 15.9)):
    alb.append(cilindro(f'ALBERO_volano{k}', (xs, AY, AZ), 0.5, 0.15, M['giallo'], asse=(1, 0, 0), seg=32, uv=1.0))
for p in alb:
    applica_trasf(p)
albero = unisci('ALBERO_pale', alb)
imposta_origine(albero, (10.0, AY, AZ))
albero['asse_rotazione'] = 'X'
for k, xs in enumerate((4.1, 8.0, 12.0, 15.9)):
    S('pale_supporti', box(f'supporto_albero{k}', (xs + 0.3, AY, (AZ + H) / 2), (0.25, 0.4, H - AZ + 0.1), M['ferro'], uv=1.0))
# bielle: dal perno dell'albero all'attacco della pala (oggetti separati, li muove lo script in Godot)
for i, xc in enumerate(NICCHIE):
    ang = i * 2 * math.pi / 3
    pa = Vector((xc, AY + 0.45 * math.cos(ang), AZ + 0.45 * math.sin(ang)))
    pala = bpy.data.objects[f'PALA_{i + 1}']
    pb = pala.matrix_basis @ Vector((0, -0.15, 2.8))
    b = tubo(f'BIELLA_{i + 1}', [pa, pb], 0.06, M['tubi'], seg=10)
    imposta_origine(b, pa)

# ringhiere davanti alle nicchie
for i, xc in enumerate(NICCHIE):
    p, q = Vector((xc - NW / 2, YN - 0.15, 0)), Vector((xc + NW / 2, YN - 0.15, 0))
    for t in (0, 0.5, 1):
        S('ringhiere', cilindro(f'r{i}_palo{t}', p + (q - p) * t + Vector((0, 0, 0.55)), 0.025, 1.1, M['verde'], seg=8))
    for z in (0.6, 1.08):
        S('ringhiere', tubo(f'r{i}_corr{z}', [p + Vector((0, 0, z)), q + Vector((0, 0, z))], 0.025, M['verde'], seg=8))

# ------------------------------------------------------------------ bocchette dell'aria (muro sud)
usa_collezione('bocchette')
for i, xc in enumerate(NICCHIE):
    c = Vector((xc, YS + 0.02, 2.2))
    S('bocchette', cilindro(f'bocchetta{i}_cono', c + Vector((0, 0.18, 0)), 0.55, 0.36, M['ferro'], asse=(0, 1, 0), seg=32, r2=0.45, tappi=False))
    S('bocchette', toro(f'bocchetta{i}_bordo', c + Vector((0, 0.36, 0)), 0.46, 0.05, M['ferro'], asse=(0, 1, 0), seg=32, seg2=8))
    S('bocchette', cilindro(f'bocchetta{i}_buio', c + Vector((0, 0.02, 0)), 0.5, 0.02, mat_pbr('buio', base=(0.0, 0.0, 0.0), roughness=1.0), asse=(0, 1, 0), seg=32, uv=None))
    for k in range(-3, 4):
        S('bocchette', box(f'bocchetta{i}_al{k}', c + Vector((0, 0.3, k * 0.12)), (0.86 * math.cos(math.asin(min(abs(k * 0.12) / 0.45, 0.99))), 0.03, 0.05), M['ruggine'], uv=None, rot=(math.radians(30), 0, 0)))
    for o in flangia(f'bocchetta{i}_fl', c + Vector((0, 0.03, 0)), (0, 1, 0), 0.62, M['ferro'], 0.05, 12, M['ruggine']):
        S('bocchette', o)
    empty(f'ARIA_bocchetta_{i + 1}', c + Vector((0, 0.5, 0)), rot=(math.radians(-90), 0, 0))
# condotta dell'aria lungo il muro sud, che alimenta le bocchette
S('bocchette', tubo('condotta_aria', [(XA, YS + 0.4, 3.6), (XB, YS + 0.4, 3.6)], 0.3, M['tubi'], seg=20, uv=1.5))
for i, xc in enumerate(NICCHIE):
    S('bocchette', tubo(f'raccordo{i}', [(xc, YS + 0.4, 3.35), (xc, YS + 0.4, 2.85)], 0.18, M['tubi'], seg=16))
    S('bocchette', box(f'scatola{i}', (xc, YS + 0.32, 2.8), (0.8, 0.6, 0.3), M['ferro'], uv=1.0))
for k in range(0, 26, 3):
    for o in flangia(f'condotta_fl{k}', (XA + k, YS + 0.4, 3.6), (1, 0, 0), 0.38, M['ferro'], 0.05, 8, M['ruggine']):
        S('bocchette', o)

# ------------------------------------------------------------------ paratie
usa_collezione('paratie')
for i, xg in enumerate((17.5, 21.0)):
    n = i + 1
    g = f'PORTALE_{n}'
    # guide laterali e cassone in alto
    for s in (-1, 1):
        S(g, box(f'{g}_guida{s}', (xg, s * (W / 2 - 0.15), H / 2), (0.5, 0.3, H), M['ferro'], uv=1.0))
        S(g, box(f'{g}_guida_strisce{s}', (xg - 0.26, s * (W / 2 - 0.15), 1.0), (0.02, 0.3, 2.0), M['pericolo'], uv=0.6))
    S(g, box(f'{g}_cassone', (xg, 0, H - 0.4), (0.9, W, 0.8), M['ferro'], uv=1.0))
    for s in (-1, 1):
        S(g, cilindro(f'{g}_pistone{s}', (xg, s * 1.2, H - 0.85), 0.12, 0.6, M['tubi'], seg=16))
    # la paratia: lastra con nervature e bordo inferiore a strisce. Origine sul bordo inferiore, scende lungo -Z.
    alza = 2.65 if n == 1 else 2.2
    pw = W - 0.3
    parti = [box(f'PARATIA_{n}_lastra', (xg, 0, alza + H / 2), (0.16, pw, H), M['verde'], uv=1.5)]
    for k in range(4):
        parti.append(box(f'PARATIA_{n}_nerv{k}', (xg - 0.12, 0, alza + 0.4 + k * 1.1), (0.1, pw, 0.12), M['ferro'], uv=1.0))
    parti.append(box(f'PARATIA_{n}_strisce', (xg - 0.09, 0, alza + 0.15), (0.02, pw, 0.3), M['pericolo'], uv=0.6))
    parti.append(box(f'PARATIA_{n}_gomma', (xg, 0, alza + 0.03), (0.2, pw, 0.06), mat_pbr('gomma_nera', base=(0.02, 0.02, 0.02), roughness=0.7), uv=None))
    for p in parti:
        applica_trasf(p)
    par = unisci(f'PARATIA_{n}', parti)
    imposta_origine(par, (xg, 0, alza))
    par['movimento'] = f'scende lungo Z da {alza} a 0'
    S(g, cilindro(f'{g}_luce_base', (xg - 0.3, W / 2 - 0.2, H - 0.3), 0.08, 0.1, M['ferro'], asse=(1, 0, 0), seg=12))
    S(g, sfera(f'{g}_luce', (xg - 0.36, W / 2 - 0.2, H - 0.3), 0.07, M['rosso_luce'], seg=12, uv=None))
    luce(f'LUCE_paratia_{n}', 'POINT', (xg - 0.5, W / 2 - 0.3, H - 0.4), 35, (1.0, 0.1, 0.04), raggio=0.06)

# ------------------------------------------------------------------ luci e oggetti
usa_collezione('luci')
def lampada(nome, pos, normale, accesa=True):
    n = Vector(normale).normalized(); pos = Vector(pos)
    S('lampade', cilindro(f'{nome}_base', pos, 0.12, 0.06, M['ferro'], asse=n, seg=16))
    S('lampade', sfera(f'{nome}_vetro', pos + n * 0.03, 0.1, M['rosso_luce'] if accesa else M['neon_spento'], seg=16, uv=None))
    t1 = n.orthogonal().normalized(); t2 = n.cross(t1)
    for k, a in enumerate((t1, t2)):
        S('lampade', toro(f'{nome}_g{k}', pos + n * 0.03, 0.105, 0.008, M['ferro'], asse=a, seg=16, seg2=4, uv=None))
    if accesa:
        luce(f'LUCE_rossa_{nome}', 'POINT', pos + n * 0.25, 45, (1.0, 0.08, 0.04), raggio=0.08)

lampada('l1', (3.0, YS + 0.02, 3.0), (0, 1, 0))
lampada('l2', (8.0, YS + 0.02, 3.0), (0, 1, 0), accesa=False)
lampada('l3', (12.0, YS + 0.02, 3.0), (0, 1, 0))
lampada('l4', (16.0, YN - 0.02, 3.0), (0, -1, 0))
lampada('l5', (23.0, YS + 0.02, 3.0), (0, 1, 0))
for k, (x, acceso) in enumerate(((4.0, False), (10.0, True), (19.3, False))):
    S('lampade', box(f'plafoniera_{k}', (x, -0.6, H - 0.06), (1.5, 0.22, 0.08), M['ferro'], uv=None))
    S('lampade', cilindro(f'neon_{k}', (x, -0.6, H - 0.13), 0.025, 1.35, M['neon'] if acceso else M['neon_spento'], asse=(1, 0, 0), seg=10, uv=None))
    if acceso:
        luce(f'LUCE_neon_{k}', 'AREA', (x, -0.6, H - 0.17), 60, (0.45, 0.9, 1.0), size=1.3)
# un gonfiabile e un salvagente portati dall'acqua, una pozza
S('oggetti', toro('salvagente', (7.2, -1.4, 0.09), 0.3, 0.09, M['gonfiabile'], seg=24, seg2=12))
S('oggetti', toro('salvagente2', (13.1, YN + 1.4, ACQ_Z + 0.03), 0.35, 0.1, mat_pbr('gonfiabile_giallo', base=(0.9, 0.7, 0.1), roughness=0.35), seg=24, seg2=12))
empty('VAPORE_tunnel', (11.0, 0.4, 0.5))

# ------------------------------------------------------------------ unione ed export
gruppi = {}
for g, ob in statici:
    if ob.name in bpy.data.objects:
        gruppi.setdefault(g, []).append(ob)
for g, obs in gruppi.items():
    for o in obs:
        applica_trasf(o)
    unisci(g if g.isupper() else 'CAMERA_' + g, obs)

esporta_glb(os.path.join(SRC, 'glb', 'camera_onde.glb'))

if '--render' in ARGS or '--anteprima' in ARGS:
    mondo()
    volume('nebbia', ((XA + XB) / 2, 0, H / 2 + 0.5), (XB - XA, W + 6, H + 3), 0.03, (0.85, 0.9, 0.92), 0.4)
    volume('vapore_nicchie', (10, YN + 1.6, 0.4), (12, 2.6, 1.2), 0.25, (0.9, 0.92, 0.95), 0.2, rumore=1.2)
    ant = '--anteprima' in ARGS
    imposta_render(campioni=16 if ant else 160, w=800 if ant else 1600, h=450 if ant else 900, esposizione=1.0)
    viste = {
        'camera_onde': ((1.1, -0.9, 1.65), (12.0, 1.2, 1.6)),
        'camera_onde_pale': ((8.2, -1.6, 1.65), (10.4, 3.4, 2.0)),
    }
    for nome, (loc, mira) in viste.items():
        camera(loc, mira, lente=20)
        renderizza(nome + ('_anteprima' if ant else '') + '.jpg')
