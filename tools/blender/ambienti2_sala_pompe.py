"""Sala pompe del capitolo 1: costruisce la stanza, esporta il GLB per Godot e fa il render.

Uso:
  /home/user/tools/blender-venv/bin/python tools/blender/ambienti2_sala_pompe.py [--render] [--anteprima] [--blend]
Uscite:
  assets_src/ambienti_tecnici/glb/sala_pompe.glb
  docs/report/render_ambienti2/sala_pompe*.jpg   (con --render)

Pianta (metri, origine al centro del pavimento, +Y = nord):
  stanza 18 x 12, alta 5,5. Ovest: apertura del tunnel verso la camera delle onde.
  Nord: le tre pompe (da sinistra GIALLA, ROSSA, BLU). Est: porta del ponte inferiore, schema a colori,
  leva grande dietro la grata. Centro-sud: vasca di raccolta con l'acqua nera. Sud-est: scrivania col CRT.
  Ordine giusto delle pompe (schema sul muro): BLU, GIALLO, ROSSO, poi la leva.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Euler
from ambienti2_comune import *
import ambienti2_comune as C
import ambienti1_hq as HQ
HQ.LINK[0] = C._link
R_ = math.radians
# rotazione (gradi attorno a Z) che porta il fronte dei modelli Meshy dove serve: tarata guardando i modelli
ROT_POMPA = float(os.environ.get('ROT_POMPA', '90'))

ARGS = argomenti()
X0, X1, Y0, Y1, H = -9.0, 9.0, -6.0, 6.0, 5.5
SP = 0.3  # spessore muri

reset()

# ------------------------------------------------------------------ materiali
M = {}
M['piastrelle'] = mat_pbr('piastrelle_muro', 'Tiles133D', color='derivate/piastrelle_sporche_Color.jpg', rough='derivate/piastrelle_sporche_Roughness.jpg')
M['pavimento'] = mat_pbr('pavimento_bagnato', 'Tiles107', color='derivate/pavimento_sporco_Color.jpg',
                         rough='derivate/pavimento_bagnato_Roughness.jpg')
M['cemento'] = mat_pbr('cemento', 'Concrete042C')
M['ferro'] = mat_pbr('ferro_arrugginito', 'Metal021')
M['tubi'] = mat_pbr('tubo_ruggine', 'Metal041B')
M['ruggine'] = mat_pbr('ruggine', 'Rust004')
M['verde'] = mat_pbr('vernice_verde', 'PaintedMetal006')
M['pericolo'] = mat_pbr('strisce_pericolo', 'PaintedMetal016')
M['lamiera'] = mat_pbr('lamiera_forata', 'MetalWalkway014')
M['rete'] = mat_pbr('rete_grata', 'Fence008A')
for c in ('giallo', 'rosso', 'blu'):
    M[c] = mat_pbr(f'vernice_{c}', 'PaintedMetal006', color=f'derivate/vernice_{c}_Color.jpg')
M['manometro'] = mat_pbr('quadrante_manometro', color='derivate/manometro_Color.jpg', roughness=0.25)
M['vetro'] = mat_vetro()
M['schema'] = mat_pbr('schema_pompe', color='derivate/schema_pompe_Color.jpg', normal='PaintedMetal006/PaintedMetal006_NormalGL.jpg',
                      roughness=0.7)
M['rosso_luce'] = mat_emissivo('luce_emergenza', (1.0, 0.06, 0.03), 40.0)
M['neon'] = mat_emissivo('neon_azzurro', (0.25, 0.95, 1.0), 25.0)
M['neon_spento'] = mat_pbr('neon_spento', base=(0.7, 0.7, 0.68), roughness=0.3)
M['crt'] = mat_pbr('SCHERMO_CRT', color='derivate/crt_neve_Color.jpg', roughness=0.08,
                   emissione=(0.55, 0.65, 0.8), emissione_forza=0.6, base=(0.02, 0.02, 0.02))
M['acqua'] = mat_acqua_nera()
M['gomma'] = mat_pbr('gomma_nera', base=(0.02, 0.02, 0.02), roughness=0.7)
M['leva_pomello'] = mat_pbr('pomello_rosso', 'PaintedMetal006', color='derivate/vernice_rosso_Color.jpg')

# la neve del CRT e' anche la sua emissione
_crt = M['crt'].node_tree
_crt.links.new([n for n in _crt.nodes if n.type == 'TEX_IMAGE'][0].outputs['Color'],
               _crt.nodes['Principled BSDF'].inputs['Emission Color'])

statici = []      # pezzi fissi da unire per gruppo
C.SMUSSO[0] = 0.012   # spigoli smussati per tutte le scatole (pareti, travi, cordoli, telai)
def S(gruppo, ob):
    statici.append((gruppo, ob)); return ob

# ------------------------------------------------------------------ struttura
usa_collezione('struttura')
VASCA = (-3.2, 1.6, -4.6, -1.6)   # x0, x1, y0, y1 della vasca di raccolta
PROF = 1.7
ACQUA_Z = -0.15   # pelo dell'acqua nera: la vasca è piena, 15 cm sotto il pavimento
# pavimento a pezzi intorno al buco della vasca
vx0, vx1, vy0, vy1 = VASCA
for nome, (a, b, c, d) in {'p1': (X0, vx0, Y0, Y1), 'p2': (vx1, X1, Y0, Y1), 'p3': (vx0, vx1, vy1, Y1), 'p4': (vx0, vx1, Y0, vy0)}.items():
    S('struttura', box(f'pav_{nome}', ((a + b) / 2, (c + d) / 2, -0.15), (b - a, d - c, 0.3), M['pavimento'], uv=1.8))
# vasca: fondo e pareti piastrellate
S('vasca', box('vasca_fondo', ((vx0 + vx1) / 2, (vy0 + vy1) / 2, -PROF - 0.15), (vx1 - vx0, vy1 - vy0, 0.3), M['cemento']))
for nome, c, d in (('vn', ((vx0 + vx1) / 2, vy1 + 0.1, -PROF / 2), (vx1 - vx0 + 0.4, 0.2, PROF)),
                   ('vs', ((vx0 + vx1) / 2, vy0 - 0.1, -PROF / 2), (vx1 - vx0 + 0.4, 0.2, PROF)),
                   ('vo', (vx0 - 0.1, (vy0 + vy1) / 2, -PROF / 2), (0.2, vy1 - vy0, PROF)),
                   ('ve', (vx1 + 0.1, (vy0 + vy1) / 2, -PROF / 2), (0.2, vy1 - vy0, PROF))):
    S('vasca', box(f'vasca_{nome}', c, d, M['piastrelle'], uv=1.2))
# cordolo intorno alla vasca, con strisce di pericolo
for nome, c, d in (('cn', ((vx0 + vx1) / 2, vy1 + 0.12, 0.08), (vx1 - vx0 + 0.48, 0.24, 0.16)),
                   ('cs', ((vx0 + vx1) / 2, vy0 - 0.12, 0.08), (vx1 - vx0 + 0.48, 0.24, 0.16)),
                   ('co', (vx0 - 0.12, (vy0 + vy1) / 2, 0.08), (0.24, vy1 - vy0, 0.16)),
                   ('ce', (vx1 + 0.12, (vy0 + vy1) / 2, 0.08), (0.24, vy1 - vy0, 0.16))):
    S('vasca', box(f'cordolo_{nome}', c, d, M['pericolo'], uv=0.8))
acqua = box('ACQUA_vasca_raccolta', ((vx0 + vx1) / 2, (vy0 + vy1) / 2, ACQUA_Z - 0.01), (vx1 - vx0, vy1 - vy0, 0.02), M['acqua'], uv=None)
empty('PUNTO_vasca_raccolta_fondo', ((vx0 + vx1) / 2, (vy0 + vy1) / 2, -PROF))
# ringhiera su due lati e scaletta
for i, (p, q) in enumerate((((vx0 - 0.15, vy1 + 0.15), (vx1 + 0.15, vy1 + 0.15)), ((vx1 + 0.15, vy1 + 0.15), (vx1 + 0.15, vy0 - 0.15)))):
    p, q = Vector((*p, 0)), Vector((*q, 0))
    L = (q - p).length; n = max(2, int(L / 1.2) + 1)
    for k in range(n):
        t = p + (q - p) * (k / (n - 1))
        S('ringhiera', cilindro(f'palo_{i}_{k}', t + Vector((0, 0, 0.55)), 0.025, 1.1, M['verde'], seg=10))
    for z in (1.08, 0.6):
        S('ringhiera', tubo(f'corrimano_{i}_{z}', [p + Vector((0, 0, z)), q + Vector((0, 0, z))], 0.025, M['verde'], seg=10))
sx = vx0 + 0.9
for s in (-0.25, 0.25):
    S('ringhiera', tubo(f'scaletta_{s}', [(sx + s, vy0 + 0.05, -PROF), (sx + s, vy0 + 0.05, 0.0), (sx + s, vy0 - 0.25, 0.7), (sx + s, vy0 - 0.25, 0.9)],
                         0.025, M['verde'], seg=10, rc=0.2))
for k in range(6):
    S('ringhiera', cilindro(f'piolo_{k}', (sx, vy0 + 0.05, -PROF + 0.25 + k * 0.28), 0.018, 0.5, M['ferro'], asse=(1, 0, 0), seg=8))

# muri: piastrelle fino a 3 m, cemento sopra. Aperture: ovest (tunnel), est (porta).
TUN_Y, TUN_W, TUN_H = -2.2, 2.6, 2.8
PORTA_Y, PORTA_W, PORTA_H = -3.6, 1.1, 2.2
def muro(nome, x0, y0, x1, y1, aperture=()):
    """Muro lungo X o lungo Y, con aperture [(centro, larghezza, altezza)]."""
    lungo_x = abs(x1 - x0) > abs(y1 - y0)
    a0, a1 = (x0, x1) if lungo_x else (y0, y1)
    fisso = y0 if lungo_x else x0
    tagli = sorted(aperture)
    pezzi = []
    cur = a0
    for c, w, h in tagli:
        pezzi.append((cur, c - w / 2, 0, H))
        pezzi.append((c - w / 2, c + w / 2, h, H))
        cur = c + w / 2
    pezzi.append((cur, a1, 0, H))
    for i, (s0, s1, z0, z1) in enumerate(pezzi):
        if s1 - s0 < 1e-3:
            continue
        for parte, za, zb, mat, sc in (('basso', z0, min(z1, 3.0), M['piastrelle'], 2.0), ('alto', max(z0, 3.0), z1, M['cemento'], 2.5)):
            if zb - za < 1e-3:
                continue
            c = ((s0 + s1) / 2, fisso, (za + zb) / 2) if lungo_x else (fisso, (s0 + s1) / 2, (za + zb) / 2)
            d = (s1 - s0, SP, zb - za) if lungo_x else (SP, s1 - s0, zb - za)
            S('struttura', box(f'{nome}_{i}_{parte}', c, d, mat, uv=sc))
muro('muro_n', X0 - SP / 2, Y1 + SP / 2, X1 + SP / 2, Y1 + SP / 2)
muro('muro_s', X0 - SP / 2, Y0 - SP / 2, X1 + SP / 2, Y0 - SP / 2)
muro('muro_o', X0 - SP / 2, Y0, X0 - SP / 2, Y1, [(TUN_Y, TUN_W, TUN_H)])
muro('muro_e', X1 + SP / 2, Y0, X1 + SP / 2, Y1, [(PORTA_Y, PORTA_W, PORTA_H)])
# zoccolo scuro e fascia di piastrelle rotte: gia' nella texture. Soffitto e travi.
S('struttura', box('soffitto', (0, 0, H + 0.15), (X1 - X0 + 2 * SP, Y1 - Y0 + 2 * SP, 0.3), M['cemento'], uv=3.0))
for k, x in enumerate((-6, -3, 0, 3, 6)):
    S('travi', box(f'trave_{k}_anima', (x, 0, H - 0.25), (0.08, Y1 - Y0, 0.5), M['ferro'], uv=1.0))
    S('travi', box(f'trave_{k}_ala', (x, 0, H - 0.49), (0.3, Y1 - Y0, 0.04), M['ferro'], uv=1.0))
# tunnel verso la camera delle onde (tratto corto, poi buio)
for k, (c, d) in enumerate((((X0 - 2.0, TUN_Y, -0.15), (4.0, TUN_W, 0.3)), ((X0 - 2.0, TUN_Y, TUN_H + 0.15), (4.0, TUN_W, 0.3)),
                            ((X0 - 2.0, TUN_Y - TUN_W / 2 - 0.15, TUN_H / 2), (4.0, 0.3, TUN_H)), ((X0 - 2.0, TUN_Y + TUN_W / 2 + 0.15, TUN_H / 2), (4.0, 0.3, TUN_H)))):
    S('struttura', box(f'tunnel_{k}', c, d, M['cemento'] if k != 0 else M['ferro'], uv=2.0))
# niente parete in fondo: il tunnel prosegue nella camera delle onde (TECNICI: si attacca in x = X0 - 4)
# telaio dell'apertura, con strisce di pericolo
for k, (c, d) in enumerate((((X0 + 0.02, TUN_Y, TUN_H + 0.12), (0.12, TUN_W + 0.5, 0.24)),
                            ((X0 + 0.02, TUN_Y - TUN_W / 2 - 0.12, TUN_H / 2), (0.12, 0.24, TUN_H)),
                            ((X0 + 0.02, TUN_Y + TUN_W / 2 + 0.12, TUN_H / 2), (0.12, 0.24, TUN_H)))):
    S('struttura', box(f'telaio_tunnel_{k}', c, d, M['pericolo'], uv=0.8))
empty('PUNTO_tunnel_camera_onde', (X0 - 3.5, TUN_Y, 0))

# ------------------------------------------------------------------ pompe
usa_collezione('pompe')
POMPE = [(-5.5, 'giallo', 3), (-1.0, 'rosso', 1), (3.5, 'blu', 0)]   # x, colore, indice nell'ordine (0 = prima)
ORDINE = {'blu': 1, 'giallo': 2, 'rosso': 3}
PY = 2.6  # y del centro del basamento
HEADER_Z, HEADER_Y = 4.55, 5.0

def volantino(nome, centro, asse, r, mat):
    a = Vector(asse).normalized()
    obs = [toro(nome, centro, r, r * 0.09, mat, asse=a, seg=24, seg2=8)]
    Mo = orienta(a).to_3x3()
    for k in range(3):
        ang = 2 * math.pi * k / 3
        d = Mo @ Vector((math.cos(ang), math.sin(ang), 0))
        obs.append(tubo(f'{nome}_r{k}', [Vector(centro), Vector(centro) + d * r], r * 0.06, mat, seg=6))
    obs.append(cilindro(f'{nome}_mozzo', centro, r * 0.15, r * 0.3, mat, asse=a, seg=10))
    return obs

def manometro(nome, centro, normale, r=0.11):
    n = Vector(normale).normalized()
    if HQ.disponibile('manometro'):
        d = HQ.dimensioni('manometro'); k = 2.3 * r / max(d.x, d.z)
        ob = HQ.metti(nome, 'manometro', Vector(centro), (d.x * k, d.y * k, d.z * k), rot_z=math.atan2(n.x, -n.y),
                      perno=(0, 0, d.z * k * 0.62))
        return []
    obs = [cilindro(f'{nome}_cassa', Vector(centro) - n * 0.03, r, 0.06, M['ferro'], asse=n, seg=20)]
    obs.append(toro(f'{nome}_ghiera', Vector(centro) + n * 0.002, r, 0.012, M['tubi'], asse=n, seg=20, seg2=6))
    quad_ = disco(f'{nome}_quadrante', Vector(centro) + n * 0.001, r * 0.93, n, M['manometro'])
    vetro = disco(f'{nome}_vetro', Vector(centro) + n * 0.012, r * 0.95, n, M['vetro'])
    lancetta = box(f'{nome}_lancetta', Vector(centro) + n * 0.006, (0.006, 0.006, r * 0.8), M['gomma'], uv=None)
    return obs + [quad_, vetro, lancetta]

turbine = []
for i, (px, col, _) in enumerate(POMPE):
    n = i + 1
    g = f'POMPA_{n}'
    c = Vector((px, PY, 0))
    vern = M[col]
    S(g, box(f'{g}_basamento', c + Vector((0, 0.2, 0.15)), (2.2, 3.4, 0.3), M['cemento'], uv=1.5))
    # corpo della pompa (chiocciola) con asse lungo Y, faccia verso il giocatore
    CZ = 1.2
    cas = c + Vector((0, -0.45, CZ))
    pompa_hq = HQ.disponibile(f'pompa_{col}')
    if pompa_hq:
        # pompa Meshy intera (chiocciola, giunto, motore colorato) sul basamento, lunga 3,2 m lungo Y
        HQ.metti(f'{g}_modello', f'pompa_{col}', c + Vector((0, 0.25, 0.3)), (3.2, None, None), rot_z=R_(ROT_POMPA))
    if not pompa_hq:
        S(g, cilindro(f'{g}_chiocciola', cas, 0.78, 0.55, M['ferro'], asse=(0, 1, 0), seg=40, uv=1.0))
        S(g, cilindro(f'{g}_chiocciola_bordo', cas + Vector((0.12, 0, 0.1)), 0.86, 0.38, M['ferro'], asse=(0, 1, 0), seg=40, uv=1.0))
        S(g, box(f'{g}_bocca', cas + Vector((0.45, 0, 0.55)), (0.5, 0.42, 0.5), M['ferro'], uv=1.0))
        for o in flangia(f'{g}_coperchio', cas + Vector((0, -0.3, 0)), (0, 1, 0), 0.62, M['ferro'], 0.06, 12, M['ruggine']):
            S(g, o)
        S(g, box(f'{g}_piede', cas + Vector((0, 0, -0.6)), (1.0, 0.5, 0.5), M['ferro'], uv=1.0))
        # supporto con cuscinetto e albero verso la turbina
        S(g, box(f'{g}_supporto', c + Vector((0, -1.05, 0.62)), (0.36, 0.3, 0.65), M['ferro'], uv=1.0))
        S(g, cilindro(f'{g}_cuscinetto', c + Vector((0, -1.05, CZ)), 0.16, 0.3, vern, asse=(0, 1, 0), seg=20, uv=0.8))
        S(g, cilindro(f'{g}_albero', c + Vector((0, -1.1, CZ)), 0.055, 0.7, M['tubi'], asse=(0, 1, 0), seg=12))
        # motore dietro, verniciato col colore della pompa, con alette
        mot = c + Vector((0, 0.85, CZ))
        S(g, cilindro(f'{g}_giunto', c + Vector((0, 0.05, CZ)), 0.2, 0.45, M['ferro'], asse=(0, 1, 0), seg=16))
        S(g, cilindro(f'{g}_motore', mot, 0.5, 1.2, vern, asse=(0, 1, 0), seg=32, uv=1.0))
        for k in range(9):
            S(g, cilindro(f'{g}_aletta{k}', mot + Vector((0, -0.48 + k * 0.12, 0)), 0.56, 0.04, vern, asse=(0, 1, 0), seg=32, uv=1.0))
        S(g, cilindro(f'{g}_motore_retro', mot + Vector((0, 0.65, 0)), 0.44, 0.12, M['ferro'], asse=(0, 1, 0), seg=24))
        S(g, box(f'{g}_scatola_morsetti', mot + Vector((0.42, 0, 0.42)), (0.3, 0.4, 0.25), M['ferro'], uv=0.8))
        S(g, box(f'{g}_piedi_motore', mot + Vector((0, 0, -0.62)), (0.9, 1.0, 0.3), vern, uv=1.0))
    # mandata: sale dalla bocca, valvola, manometro, curva verso il collettore
    m0 = cas + Vector((0.45, 0, 0.8))
    S(g, tubo(f'{g}_mandata', [m0, Vector((m0.x, m0.y, HEADER_Z)), Vector((m0.x, HEADER_Y, HEADER_Z))], 0.21, M['tubi'], rc=0.55, seg=20, uv=1.2))
    for z in (m0.z + 0.05, 2.6, 3.6):
        for o in flangia(f'{g}_fl{z:.1f}', (m0.x, m0.y, z), (0, 0, 1), 0.3, M['ferro'], 0.07, 8, M['ruggine']):
            S(g, o)
    S(g, cilindro(f'{g}_corpo_valvola', (m0.x, m0.y, 2.9), 0.3, 0.5, M['ferro'], seg=20))
    S(g, cilindro(f'{g}_stelo_valvola', (m0.x, m0.y - 0.45, 2.9), 0.04, 0.5, M['tubi'], asse=(0, 1, 0), seg=8))
    for o in volantino(f'{g}_volantino', (m0.x, m0.y - 0.72, 2.9), (0, 1, 0), 0.32, M['rosso'] if col == 'rosso' else M['verde']):
        S(g, o)
    # fascia colorata sulla mandata (si legge da lontano)
    S(g, cilindro(f'{g}_fascia', (m0.x, m0.y, 3.25), 0.225, 0.35, vern, seg=24, uv=0.8))
    for o in manometro(f'{g}_manometro', (m0.x - 0.34, m0.y - 0.182, 2.25), (0, -1, 0)):   # (sulla presa, 3 mm dentro: a -0,2 restava 1,5 cm staccato, a -0,185 a filo)
        S(g, o)
    S(g, tubo(f'{g}_presa_man', [(m0.x - 0.18, m0.y, 2.25), (m0.x - 0.34, m0.y, 2.25), (m0.x - 0.34, m0.y - 0.17, 2.25)], 0.02, M['tubi'], seg=8, rc=0.05))
    # aspirazione: dal fianco della chiocciola giu' nel pavimento
    a0 = cas + Vector((-0.78, 0, -0.1))
    S(g, tubo(f'{g}_aspirazione', [a0, a0 + Vector((-0.55, 0, 0)), Vector((a0.x - 0.55, a0.y, -0.3))], 0.19, M['tubi'], rc=0.45, seg=20, uv=1.2))
    for o in flangia(f'{g}_fl_asp', a0 + Vector((-0.08, 0, 0)), (1, 0, 0), 0.27, M['ferro'], 0.06, 8, M['ruggine']):
        S(g, o)
    S(g, cilindro(f'{g}_piatto_pav', (a0.x - 0.55, a0.y, 0.02), 0.32, 0.04, M['ruggine'], seg=20))

    # turbina d'avviamento: girante assiale a 8 pale, davanti alla pompa, asse = Y (verso il giocatore)
    T = c + Vector((0, -1.55, CZ))
    parti = []
    parti.append(cilindro(f'TURBINA_{n}_mozzo', T, 0.17, 0.26, vern, asse=(0, 1, 0), seg=24, uv=0.6))
    parti.append(sfera(f'TURBINA_{n}_ogiva', T + Vector((0, -0.13, 0)), 0.17, vern, scala=(1, 0.8, 1), uv=0.6))
    for k in range(8):
        ang = 2 * math.pi * k / 8
        R = 0.43
        mt = (Matrix.Translation(T) @ Matrix.Rotation(ang, 4, 'Y') @ Matrix.Translation((R, 0, 0))
              @ Matrix.Rotation(math.radians(38), 4, 'X'))
        parti.append(box(f'TURBINA_{n}_pala{k}', None, (0.56, 0.035, 0.24), M['ferro'], uv=None, matrice=mt))
    parti.append(toro(f'TURBINA_{n}_anello', T, 0.72, 0.035, vern, asse=(0, 1, 0), seg=40, seg2=8, uv=0.6))
    for p in parti:
        applica_trasf(p); uv_box(p, 0.8)
    tb = unisci(f'TURBINA_{n}', parti)
    imposta_origine(tb, T)
    if HQ.disponibile('turbina_avviamento'):
        # girante Meshy: stesso nome e perno (asse lungo Y); la tinta del colore la mette Godot
        bpy.data.objects.remove(tb)
        dt = HQ.dimensioni('turbina_avviamento'); k = 1.5 / max(dt.x, dt.z)
        tb = HQ.metti(f'TURBINA_{n}', 'turbina_avviamento', T, (dt.x * k, dt.y * k, dt.z * k), perno=(0, 0, dt.z * k / 2))
    tb['colore'] = col; tb['ordine'] = ORDINE[col]; tb['asse_rotazione'] = 'Y Blender = -Z Godot'
    turbine.append(tb)
    # carter fisso dietro la turbina (anello di protezione con due bracci)
    S(g, toro(f'{g}_carter', T + Vector((0, 0.12, 0)), 0.78, 0.04, M['ferro'], asse=(0, 1, 0), seg=40, seg2=8, uv=0.8))
    for sgn in (-1, 1):
        S(g, tubo(f'{g}_braccio{sgn}', [T + Vector((sgn * 0.78, 0.12, 0)), Vector((c.x + sgn * 0.78, T.y + 0.12, 0.3))], 0.03, M['ferro'], seg=8))
    empty(f'VAPORE_pompa_{n}', (m0.x + 0.2, m0.y, 2.62))

# collettore sul soffitto e tubi di servizio
usa_collezione('tubi')
S('tubi', tubo('collettore', [(X0, HEADER_Y, HEADER_Z), (X1, HEADER_Y, HEADER_Z)], 0.36, M['tubi'], seg=36, uv=1.5))
for k, x in enumerate((-7.5, -3.2, 1.2, 5.6, 8.0)):
    for o in flangia(f'coll_fl{k}', (x, HEADER_Y, HEADER_Z), (1, 0, 0), 0.46, M['ferro'], 0.08, 12, M['ruggine']):
        S('tubi', o)
    S('tubi', box(f'coll_staffa{k}', (x + 0.4, HEADER_Y, (HEADER_Z + H) / 2 + 0.1), (0.08, 0.08, H - HEADER_Z + 0.2), M['ferro'], uv=1.0))
corse = [
    ([(X0, 5.6, 3.4), (X1, 5.6, 3.4)], 0.12, M['verde']),
    ([(X0, 5.75, 2.9), (-2.0, 5.75, 2.9), (-2.0, 5.75, 0.0)], 0.08, M['tubi']),
    ([(X1, -5.7, 4.0), (-6.0, -5.7, 4.0), (-6.0, -5.7, 5.3)], 0.15, M['tubi']),
    ([(X0, -5.6, 4.7), (X1, -5.6, 4.7)], 0.1, M['ferro']),
    ([(X1 - 0.25, -1.0, H), (X1 - 0.25, -1.0, 5.0), (X1 - 0.25, 5.2, 5.0)], 0.14, M['tubi']),
    ([(X0 + 0.25, 5.8, 3.9), (X0 + 0.25, -0.5, 3.9), (X0 + 0.25, -0.5, 0.0)], 0.12, M['tubi']),
]
for k, (pts, r, mat) in enumerate(corse):
    S('tubi', tubo(f'servizio_{k}', pts, r, mat, rc=3 * r, seg=28, uv=1.2))
    p0 = Vector(pts[0]); p1 = Vector(pts[1]); d = (p1 - p0).normalized()
    L = (p1 - p0).length
    for j in range(1, int(L / 2.5)):
        for o in flangia(f'serv{k}_fl{j}', p0 + d * (j * 2.5), d, r * 1.45, M['ferro'], 0.05, 6, M['ruggine']):
            S('tubi', o)
# tubo con una perdita (vapore) sul lato ovest
empty('VAPORE_perdita_ovest', (X0 + 0.5, 3.0, 3.9))
empty('VAPORE_collettore', (-3.2, HEADER_Y - 0.3, HEADER_Z - 0.2))

# filtri tondi grandi (angolo nord-ovest)
usa_collezione('filtri')
for i, (fx, fy) in enumerate(((-7.6, 4.4), (-7.6, 1.8))):
    g = f'FILTRO_{i + 1}'
    c = Vector((fx, fy, 0))
    if HQ.disponibile('filtro_tondo'):
        fm = HQ.metti(f'{g}_modello', 'filtro_tondo', c, (None, None, 3.45), rot_z=R_(-45 + 90 * i))
        if i == 1:      # girato così, il modello restava 1,1 cm dentro le flange: largo quanto loro
            fm.matrix_world = fm.matrix_world @ Matrix.Diagonal((1.0105, 1.0105, 1.0, 1.0))
        S(g, tubo(f'{g}_uscita', [c + Vector((0, 0, 3.4)), Vector((fx, fy, 4.0)), Vector((fx, HEADER_Y, 4.0)), Vector((fx, HEADER_Y, HEADER_Z - 0.3))], 0.16, M['tubi'], rc=0.4, uv=1.2, seg=28))
        continue
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        S(g, cilindro(f'{g}_gamba{k}', c + Vector((math.cos(a) * 0.75, math.sin(a) * 0.75, 0.3)), 0.06, 0.6, M['ferro'], seg=8))
    S(g, cilindro(f'{g}_corpo', c + Vector((0, 0, 1.8)), 1.0, 2.4, M['verde'], seg=40, uv=1.5))
    S(g, sfera(f'{g}_cupola', c + Vector((0, 0, 3.0)), 1.0, M['verde'], scala=(1, 1, 0.45), emisfero=True, seg=40, uv=1.5))
    S(g, sfera(f'{g}_fondo', c + Vector((0, 0, 0.6)), 1.0, M['verde'], scala=(1, 1, -0.3), emisfero=True, seg=40, uv=1.5))
    for z in (0.75, 2.85):
        for o in flangia(f'{g}_cerchio{z}', c + Vector((0, 0, z)), (0, 0, 1), 1.06, M['ferro'], 0.08, 20, M['ruggine']):
            S(g, o)
    # boccaporto tondo sul fianco, con bulloni
    hc = c + Vector((1.0, 0, 1.7))
    for o in flangia(f'{g}_bocca', hc, (1, 0, 0), 0.38, M['ferro'], 0.12, 10, M['ruggine']):
        S(g, o)
    S(g, cilindro(f'{g}_bocca_tappo', hc + Vector((0.06, 0, 0)), 0.3, 0.08, M['ruggine'], asse=(1, 0, 0), seg=24))
    for o in manometro(f'{g}_man', c + Vector((0.72, -0.72, 2.45)), (0.7, -0.7, 0)):
        S(g, o)
    S(g, tubo(f'{g}_uscita', [c + Vector((0, 0, 3.4)), Vector((fx, fy, 4.0)), Vector((fx, HEADER_Y, 4.0)), Vector((fx, HEADER_Y, HEADER_Z - 0.3))], 0.16, M['tubi'], rc=0.4, uv=1.2))

# ------------------------------------------------------------------ parete est: porta, schema, leva
usa_collezione('parete_est')
XE = X1
# porta stagna del ponte inferiore, cardine sul lato sud
porta = []
porta.append(box('PORTA_ponte_anta', (XE - 0.05, PORTA_Y, PORTA_H / 2), (0.08, PORTA_W - 0.04, PORTA_H - 0.04), M['verde'], uv=1.2))
porta.append(box('PORTA_ponte_oblo_bordo', (XE - 0.1, PORTA_Y, 1.6), (0.04, 0.34, 0.34), M['ferro'], uv=None))
porta.append(cilindro('PORTA_ponte_oblo', (XE - 0.11, PORTA_Y, 1.6), 0.13, 0.03, M['vetro'], asse=(1, 0, 0)))
# maniglione antipanico
porta.append(tubo('PORTA_ponte_maniglione', [(XE - 0.1, PORTA_Y - 0.4, 1.0), (XE - 0.2, PORTA_Y - 0.35, 1.0), (XE - 0.2, PORTA_Y + 0.35, 1.0), (XE - 0.1, PORTA_Y + 0.4, 1.0)], 0.025, M['tubi'], rc=0.05, seg=8))
for p in porta:
    applica_trasf(p)
pt = unisci('PORTA_ponte', porta)
imposta_origine(pt, (XE - 0.05, PORTA_Y - PORTA_W / 2, 0))
if HQ.disponibile('porta_servizio'):
    # anta Meshy (come la porta della sala pompe vista dal corridoio) e maniglione dal lato della sala
    bpy.data.objects.remove(pt)
    pt = HQ.metti('PORTA_ponte', 'porta_servizio', (XE - 0.05, PORTA_Y - PORTA_W / 2 + 0.02, 0.0),   # (poggia sulla soglia)
                  (PORTA_W - 0.04, None, PORTA_H - 0.03),
                  rot_z=R_(-90), perno=((PORTA_W - 0.04) / 2, 0, 0))
    man = tubo('PORTA_ponte_maniglione', [(XE - 0.12, PORTA_Y - 0.4, 1.0), (XE - 0.24, PORTA_Y - 0.35, 1.0), (XE - 0.24, PORTA_Y + 0.35, 1.0), (XE - 0.12, PORTA_Y + 0.4, 1.0)], 0.025, M['pericolo'], rc=0.05, seg=16)
    applica_trasf(man)
    mw = man.matrix_world.copy(); man.parent = pt; man.matrix_world = mw
pt['cardine'] = 'asse Z Blender (Y Godot), si apre verso l esterno'
for k, (c, d) in enumerate((((XE - 0.02, PORTA_Y, PORTA_H + 0.1), (0.14, PORTA_W + 0.3, 0.2)),
                            ((XE - 0.02, PORTA_Y - PORTA_W / 2 - 0.08, PORTA_H / 2), (0.14, 0.16, PORTA_H)),
                            ((XE - 0.02, PORTA_Y + PORTA_W / 2 + 0.08, PORTA_H / 2), (0.14, 0.16, PORTA_H)))):
    S('parete_est', box(f'telaio_porta_{k}', c, d, M['ferro'], uv=1.0))
# di la' dalla porta c'è il raccordo verso gli interni (tools/blender/ambienti2_raccordo.py)
empty('PUNTO_porta_ponte_inferiore', (XE - 1.0, PORTA_Y, 0))
# neon azzurro sopra la porta e lampada rossa
S('luci', box('neon_porta', (XE - 0.03, PORTA_Y, PORTA_H + 0.45), (0.05, 1.3, 0.05), M['neon'], uv=None))

# schema a colori sul muro (senza testo)
SC_Y, SC_Z = 0.4, 2.0
schema = quad('SCHEMA_pompe', (XE - 0.035, SC_Y, SC_Z), 2.6, 1.3, (-1, 0, 0), M['schema'])
schema['ordine'] = 'blu, giallo, rosso, poi la leva'
S('parete_est', box('schema_cornice', (XE - 0.01, SC_Y, SC_Z), (0.02, 2.75, 1.45), M['ferro'], uv=1.0))
for k, dz in enumerate((-1, 1)):
    S('parete_est', box(f'schema_vite{k}', (XE - 0.03, SC_Y, SC_Z + dz * 0.6), (0.02, 2.5, 0.02), M['ruggine'], uv=None))

# leva grande in alto, dietro una grata (gabbia)
LV = Vector((XE - 0.05, 2.9, 3.9))
def allinea_occhio(base, braccio):
    """Sposta il braccio della leva in modo che l'occhio del perno stia sul centro del perno della base."""
    bpy.context.view_layer.update()
    vs = [base.matrix_world @ v.co for v in base.data.vertices]
    xmin = min(v.x for v in vs)
    boss = [v for v in vs if v.x < xmin + 0.02]
    c = Vector(((min(v.x for v in boss) + max(v.x for v in boss)) / 2, (min(v.y for v in boss) + max(v.y for v in boss)) / 2,
                (min(v.z for v in boss) + max(v.z for v in boss)) / 2))
    occhio = braccio.matrix_world @ Vector((-0.84, 0.0, 0.148))   # occhio nel GLB, origine al centro della base
    d = c - occhio
    braccio.matrix_world = Matrix.Translation((0, d.y, d.z)) @ braccio.matrix_world
    return braccio


LEVA_NUOVA = HQ.disponibile('leva_base') and HQ.disponibile('leva_maniglia')
if LEVA_NUOVA:
    # leva nuova (questionario del 15 ottobre): base in ghisa con il quadrante e braccio rosso con l'impugnatura,
    # modelli Meshy. Il braccio ruota sull'asse X (perpendicolare al muro) attorno all'occhio del perno.
    MOZZO = Vector((XE, 2.75, 3.72))
    db = HQ.dimensioni('leva_base'); kb = 0.55 / max(db.x, db.z)
    # il perno del quadrante è al centro in larghezza e a 0,46 dell'altezza
    base_leva = HQ.metti('LEVA_base', 'leva_base', MOZZO + Vector((-db.y * kb / 2, 0, -0.464 * db.z * kb)), tuple(db * kb), rot_z=R_(-90))
    dm = HQ.dimensioni('leva_maniglia'); km = 0.7 / 2.26   # braccio lungo 0,7 m (occhio-impugnatura 2,26 nel GLB)
    # occhio del perno nel GLB: (-0,81; 0; -0,64) con il centro della scatola nello zero; braccio a 38 gradi,
    # raddrizzato a 63 gradi (rot Y -25) e girato verso nord (rot Z +90)
    lv = HQ.metti('LEVA', 'leva_maniglia', MOZZO + Vector((-db.y * kb - 0.045, 0, 0)), tuple(dm * km), rot=(0, R_(-25), 0),
                  rot_z=R_(90), perno=(-0.84 * km, 0, 0.148 * km))
    allinea_occhio(base_leva, lv)
    # il braccio contro il perno della base (a 4,5 cm restava staccato): lo si avvicina finché tocca
    bpy.context.view_layer.update()
    from mathutils.bvhtree import BVHTree
    mb = base_leva.matrix_world
    tb = BVHTree.FromPolygons([mb @ v.co for v in base_leva.data.vertices], [list(p.vertices) for p in base_leva.data.polygons])
    gap = min((h[3] for h in (tb.ray_cast(lv.matrix_world @ v.co, Vector((1, 0, 0)), 0.2) for v in lv.data.vertices) if h[0] is not None), default=0.0)
    lv.matrix_world = Matrix.Translation((gap - 0.002, 0, 0)) @ lv.matrix_world
    lv['alzata'] = 'braccio verso nord e in alto (63 gradi); abbassata: -70 gradi attorno a X globale'
else:
    MOZZO = LV + Vector((0, -0.4, -0.2))   # il mozzo della leva Meshy: piastra e perno a muro dietro di lui
    S('parete_est', box('leva_piastra', MOZZO + Vector((-0.02, 0, 0)), (0.04, 0.42, 0.42), M['ferro'], uv=1.0))
    S('parete_est', cilindro('leva_perno_base', MOZZO + Vector((-0.08, 0, 0)), 0.07, 0.1, M['ruggine'], asse=(1, 0, 0), seg=16))
    leva = [tubo('LEVA_braccio', [LV + Vector((-0.12, 0, 0)), LV + Vector((-0.55, 0, 0.55))], 0.045, M['pericolo'], seg=10),
            cilindro('LEVA_pomello', LV + Vector((-0.6, 0, 0.62)), 0.07, 0.3, M['leva_pomello'], asse=(1, 0, 1.0), seg=16)]
    for p in leva:
        applica_trasf(p)
    lv = unisci('LEVA', leva)
    imposta_origine(lv, LV + Vector((-0.12, 0, 0)))
    if HQ.disponibile('leva_braccio'):
        # braccio Meshy: perno sull'estremità col mozzo, braccio inclinato verso la stanza e in alto
        bpy.data.objects.remove(lv)
        dl = HQ.dimensioni('leva_braccio')
        # nel GLB il braccio è già inclinato di 30 gradi, mozzo (asse Y) in basso sul lato -X. Girato di 90 gradi
        # il mozzo guarda la stanza e il braccio corre lungo il muro, verso nord e in alto: si legge da lontano
        kl = 1.0 / max(dl)
        lv = HQ.metti('LEVA', 'leva_braccio', MOZZO + Vector((-0.14, 0, 0)), tuple(dl * kl), rot_z=math.pi / 2,
                      perno=(-0.41 * dl.x * kl, 0, 0.17 * dl.z * kl))
lv['asse_rotazione'] = 'X (Blender e Godot), perpendicolare al muro; abbassata = -70 gradi'
# gabbia con rete metallica (la grata davanti si puo' aprire: oggetto separato)
# (profonda fino al muro: a 0,9 restava 5 cm staccata, collaudo del 22 sera)
GC = LV + Vector((-0.425, 0, 0.1)); GW, GH, GD = 1.1, 1.3, 0.95
for k, (c, d) in enumerate(((GC + Vector((0, -GW / 2, 0)), (GD, 0.02, GH)), (GC + Vector((0, GW / 2, 0)), (GD, 0.02, GH)),
                            (GC + Vector((0, 0, GH / 2)), (GD, GW, 0.02)), (GC + Vector((0, 0, -GH / 2)), (GD, GW, 0.02)))):
    S('gabbia', box(f'gabbia_{k}', c, d, M['rete'], uv=0.6))
for sy in (-1, 1):
    for sz in (-1, 1):
        S('gabbia', box(f'gabbia_spigolo{sy}{sz}', GC + Vector((0, sy * GW / 2, sz * GH / 2)), (GD, 0.04, 0.04), M['ferro'], uv=None))
gr = box('GRATA_leva', GC + Vector((-GD / 2, 0, 0)), (0.02, GW, GH), M['rete'], uv=0.6)
gr_tel = [box(f'GRATA_leva_tel{k}', GC + Vector((-GD / 2, 0, 0)) + o, d, M['ferro'], uv=None) for k, (o, d) in enumerate(
    ((Vector((0, 0, GH / 2)), (0.04, GW, 0.04)), (Vector((0, 0, -GH / 2)), (0.04, GW, 0.04)),
     (Vector((0, GW / 2, 0)), (0.04, 0.04, GH)), (Vector((0, -GW / 2, 0)), (0.04, 0.04, GH))))]
for p in [gr] + gr_tel:
    applica_trasf(p)
grata = unisci('GRATA_leva', [gr] + gr_tel)
imposta_origine(grata, GC + Vector((-GD / 2, -GW / 2, 0)))
# la leva tira il chiavistello della porta con un cavo d'acciaio; le tre turbine comandano la chiusura stagna
# della stessa porta con tre tubi dei loro colori (questionario del 15 ottobre: deve essere chiaro a cosa servono)
if LEVA_NUOVA:
    usa_collezione('meccanismi')
    M['cavo'] = mat_pbr('cavo_acciaio', base=(0.62, 0.63, 0.64), roughness=0.35)
    # chiavistello sul muro accanto alla porta, dal lato del maniglione (nord); il catenaccio entra nello stipite
    CH = Vector((XE - 0.055, PORTA_Y + PORTA_W / 2 + 0.27, 1.0))
    dc = HQ.dimensioni('chiavistello'); kc = 0.5 / dc.x
    chiav = HQ.metti('CHIAVISTELLO', 'chiavistello', CH, tuple(dc * kc), rot_z=R_(-90))
    chiav['uso'] = 'il cavo della leva lo tira: catenaccio lungo Y, si apre spostandolo di +0,12 lungo Y'
    puleggia_ch = Vector((XE - 0.06, CH.y - 0.18 * kc, CH.z + 0.23 * kc))
    empty('PUNTO_chiavistello', puleggia_ch)
    ZC = 3.25   # quota del cavo lungo il muro
    cavo = [Vector((XE - 0.17, MOZZO.y, MOZZO.z - 0.12)), Vector((XE - 0.06, MOZZO.y, ZC)), Vector((XE - 0.06, puleggia_ch.y, ZC)), puleggia_ch]
    S('meccanismi', tubo('CAVO_leva', cavo, 0.008, M['cavo'], rc=0.06, seg=8, uv=None))
    for k, pz in enumerate((cavo[1], cavo[2])):
        S('meccanismi', cilindro(f'cavo_puleggia{k}', pz + Vector((0.01, 0, 0)), 0.05, 0.03, M['ferro'], asse=(1, 0, 0), seg=20, uv=None))
        S('meccanismi', box(f'cavo_staffa{k}', pz + Vector((0.035, 0, 0)), (0.03, 0.04, 0.14), M['ruggine'], uv=None))
    for k in range(1, 6):   # ganci a muro lungo il tratto orizzontale
        y = cavo[1].y + (cavo[2].y - cavo[1].y) * k / 6
        S('meccanismi', box(f'cavo_gancio{k}', (XE - 0.03, y, ZC), (0.06, 0.02, 0.03), M['ferro'], uv=None))
    # chiusura stagna: cilindro idraulico dal lato del cardine (sud) che spinge sullo stipite
    # lungo 53 cm: sporge dal muro 24,9 cm, staffa compresa (regola del coordinatore per le cose a muro: al più 25 cm),
    # con il fianco 3 mm dentro la staffa
    da = HQ.dimensioni('attuatore_stagno'); ka0 = 0.6 / da.x; ka = 0.53 / da.x
    AT = Vector((XE - 0.04 - da.y * ka / 2 + 0.003, PORTA_Y - PORTA_W / 2 - 0.7, 1.2))
    att = HQ.metti('ATTUATORE_stagno', 'attuatore_stagno', AT, tuple(da * ka), rot_z=R_(-90))
    att['uso'] = 'chiusura stagna della porta: le tre turbine la mettono in pressione con i tubi TUBO_stagno_1..3'
    # il tirante dalla testa dell'attuatore (1 cm dentro) fino allo stipite, dove arrivava prima (AT.y + 0,55)
    t0 = da.x * ka / 2 - 0.01
    S('meccanismi', box('attuatore_tirante', (AT.x, AT.y + (t0 + 0.55) / 2, AT.z + 0.12 * ka / ka0), (0.04, 0.55 - t0, 0.04), M['ferro'], uv=None))
    S('meccanismi', box('attuatore_staffa', (XE - 0.02, AT.y, AT.z + 0.18), (0.04, 0.5, 0.3), M['ferro'], uv=1.0))
    empty('PUNTO_chiusura_stagna', AT + Vector((0, 0, 0.18 * ka / ka0)))
    attacchi = [AT + Vector((0, -rx * ka, 0.31 * ka / ka0)) for rx in (-0.25, 0.13, 0.32)]
    for i, (px, col, _) in enumerate(POMPE):
        n = i + 1
        T = Vector((px, PY - 1.55, 1.2))
        yk = T.y + 0.12 + 0.1 * i
        zk = 3.5 + 0.13 * i
        # parte dalla cima del carter della sua turbina, sale, corre verso il muro est e scende sulla chiusura stagna
        punti = [Vector((px, T.y + 0.12, 1.96)), Vector((px, yk, 2.3)), Vector((px, yk, zk)), Vector((AT.x, yk, zk)),
                 Vector((AT.x, attacchi[i].y, zk)), attacchi[i]]
        S('meccanismi', tubo(f'TUBO_stagno_{n}', punti, 0.03, M[col], rc=0.12, seg=12, uv=1.0))
        for k in range(2, 5):
            q, r = punti[k], punti[k + 1]
            d = (r - q).normalized()
            for o in flangia(f'tubo_stagno_{n}_fl{k}', q + d * 0.18, d, 0.045, M['ferro'], 0.02, 6, M['ruggine']):
                S('meccanismi', o)
        for k in range(1, 4):   # tiranti al soffitto lungo il tratto lungo
            x = px + (AT.x - px) * k / 4
            S('meccanismi', box(f'tubo_stagno_{n}_tirante{k}', (x, yk, (zk + H) / 2), (0.02, 0.02, H - zk), M['ferro'], uv=None))

# strisce di pericolo sotto la leva
S('parete_est', quad('pericolo_leva', (XE - 0.02, 2.9, 3.05), 1.3, 0.2, (-1, 0, 0), M['pericolo']))

# quadro elettrico e pannello con gli strumenti sul muro sud
for nome, file, x, z, w in (('QUADRO_elettrico', 'quadro_elettrico', -6.2, 0.9, 1.1), ('QUADRO_strumenti', 'quadro_strumenti', -1.6, 1.3, 1.2)):
    if HQ.disponibile(file):
        d = HQ.dimensioni(file); k = w / d.x
        HQ.metti(nome, file, (x, Y0 + d.y * k / 2 - 0.002, z),   # (col retro sul muro: a 1 cm restava staccato)
                 (w, d.y * k, d.z * k), rot_z=R_(180))

# ------------------------------------------------------------------ scrivania, CRT, sedia (Meshy)
usa_collezione('arredo')

def importa_meshy(nome, lato_max, pos, rot_z, asse_lato=None):
    path = os.path.join(SRC, 'meshy', nome + '.glb')
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    mesh = [o for o in nuovi if o.type == 'MESH']
    for o in mesh:
        o.data.transform(o.matrix_world); o.parent = None; o.matrix_basis = Matrix.Identity(4)
    for o in nuovi:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    ob = unisci(nome.upper(), mesh)
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    _coll = bpy.data.collections['arredo']; _coll.objects.link(ob)
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    dim = hi - lo
    s = lato_max / (dim[asse_lato] if asse_lato is not None else max(dim))
    ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    ob.data.transform(Matrix.Scale(s, 4))
    ob.location = pos; ob.rotation_euler = (0, 0, math.radians(rot_z))
    # texture di Meshy ridotte a 1024 per stare leggeri
    for m in ob.data.materials:
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image and n.image.size[0] > 1024:
                n.image.scale(1024, 1024)
    print(nome, 'dimensioni', tuple(round(v * s, 2) for v in dim))
    return ob, dim * s

DESK = Vector((4.6, Y0 + 0.55, 0))
if HQ.disponibile('scrivania') and HQ.disponibile('monitor_crt'):
    sdim = Vector((1.5, 0.7, 0.78))
    scr = HQ.metti('SCRIVANIA', 'scrivania', DESK, tuple(sdim), rot_z=R_(180))
    dm = HQ.dimensioni('monitor_crt'); km = 0.5 / dm.x; mdim = dm * km
    mon = HQ.metti('MONITOR_CRT', 'monitor_crt', DESK + Vector((-0.25, 0.08, sdim.z)), tuple(mdim), rot_z=R_(200))
else:
    scr, sdim = importa_meshy('scrivania', 1.5, DESK, 180, asse_lato=0)
    mon, mdim = importa_meshy('monitor_crt', 0.5, DESK + Vector((-0.25, 0.08, sdim.z)), 200, asse_lato=0)
sed, _ = importa_meshy('sedia', 0.95, DESK + Vector((0.1, 1.1, 0)), 160, asse_lato=2)
# schermo: quadrato davanti al vetro del CRT (in Godot MonitorCrt lo sostituisce con una griglia sul vetro)
ang = math.radians(200)
fronte = Matrix.Rotation(ang, 3, 'Z') @ Vector((0, -1, 0))
sc_c = mon.location + fronte * (mdim.y / 2 + 0.003) + Vector((0, 0, mdim.z * 0.6))
schermo = quad('SCHERMO_CRT', sc_c, mdim.x * 0.6, mdim.z * 0.52, fronte, M['crt'])
luce('LUCE_crt', 'AREA', sc_c + fronte * 0.05, 3.0, (0.6, 0.7, 0.9), size=0.25, mira=sc_c + fronte * 2)
empty('PUNTO_monitor', sc_c)

# oggetti sulla scrivania e per terra
top = DESK.z + sdim.z
for k, (dx, dy, rz) in enumerate(((0.3, 0.05, 12), (0.38, -0.05, -20), (0.45, 0.1, 40))):
    S('arredo', box(f'foglio_{k}', DESK + Vector((dx, dy, sdim.z + 0.002 + k * 0.001)), (0.21, 0.297, 0.001),
                    mat_pbr('carta_sporca', base=(0.62, 0.58, 0.48), roughness=0.85), uv=None, rot=(0, 0, math.radians(rz))))
S('arredo', cilindro('tazza', DESK + Vector((0.55, -0.2, sdim.z + 0.05)), 0.04, 0.1, mat_pbr('ceramica', base=(0.55, 0.12, 0.1), roughness=0.3), seg=16, uv=None))
S('arredo', cilindro('torcia', DESK + Vector((0.2, -0.25, sdim.z + 0.025)), 0.025, 0.25, M['gomma'], asse=(1, 0.3, 0), seg=12, uv=None))
# manichetta abbandonata sul pavimento, secchio, carte
pts = [(-3.6, 1.0, 0.04), (-2.8, 0.2, 0.04), (-3.4, -0.6, 0.04), (-4.6, -0.4, 0.04), (-5.2, 0.6, 0.04), (-5.4, 1.6, 0.6), (-5.42, 1.62, 1.1)]
S('arredo', tubo('manichetta', pts, 0.035, mat_pbr('manichetta_tela', base=(0.45, 0.1, 0.06), roughness=0.8), rc=0.5, seg=10, uv=0.5))
S('arredo', cilindro('secchio', (-2.4, -0.9, 0.18), 0.17, 0.36, M['ruggine'], seg=20, r2=0.2, tappi=True))
S('arredo', box('cassetta_attrezzi', (6.4, -5.5, 0.12), (0.55, 0.25, 0.24), M['rosso'], uv=0.6))
for k, (x, y, rz) in enumerate(((-1.5, -0.4, 30), (1.1, 0.4, -10), (-4.2, -3.6, 65))):
    S('arredo', box(f'carta_terra_{k}', (x, y, 0.003), (0.3, 0.42, 0.002), mat_pbr('carta_sporca'), uv=None, rot=(0, 0, math.radians(rz))))

# ------------------------------------------------------------------ luci (rosse d'emergenza, neon)
usa_collezione('luci')

def lampada_rossa(nome, pos, normale, accesa=True):
    n = Vector(normale).normalized(); pos = Vector(pos)
    if HQ.disponibile('lampada_muro'):
        rosso = lambda c, nrm: c[0] > 0.25 and c[0] > c[1] * 2.2 and c[0] > c[2] * 2.0
        HQ.dividi('lampada_muro', 'lampada_muro_vetro', rosso, (1, 0.05, 0.02), 14.0)
        Rm = n.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        for o in (HQ.metti(f'lampada_{nome}', 'lampada_muro', (0, 0, 0), (0.34, None, None)),
                  HQ.metti(f'lampada_{nome}_vetro' if accesa else f'lampada_{nome}_vetro_spento', 'lampada_muro', (0, 0, 0), (0.34, None, None), parte='lampada_muro_vetro')):
            o.matrix_world = Matrix.Translation(pos) @ Rm @ o.matrix_world
        if accesa:
            luce(f'LUCE_rossa_{nome}', 'POINT', pos + n * 0.25, 60, (1.0, 0.08, 0.04), raggio=0.08)
        return
    obs = [cilindro(f'{nome}_base', pos, 0.12, 0.06, M['ferro'], asse=n, seg=16)]
    obs.append(sfera(f'{nome}_vetro', pos + n * 0.03, 0.1, M['rosso_luce'] if accesa else M['neon_spento'], scala=(1, 1, 1), seg=16, uv=None))
    t1 = n.orthogonal().normalized(); t2 = n.cross(t1)
    for k, a in enumerate((t1, t2)):
        obs.append(toro(f'{nome}_gabbia{k}', pos + n * 0.03, 0.105, 0.008, M['ferro'], asse=a, seg=16, seg2=4, uv=None))
    for o in obs:
        S('lampade', o)
    if accesa:
        luce(f'LUCE_rossa_{nome}', 'POINT', pos + n * 0.25, 60, (1.0, 0.08, 0.04), raggio=0.08)

# le lampade col retro a filo del muro (a 2 cm restavano staccate)
lampada_rossa('l1', (X0 - 0.002, 1.0, 3.3), (1, 0, 0))
lampada_rossa('l2', (XE + 0.002, PORTA_Y, PORTA_H + 0.9), (-1, 0, 0))
lampada_rossa('l3', (-3.2, Y1 + 0.002, 2.4), (0, -1, 0))
lampada_rossa('l4', (1.2, Y0 - 0.002, 3.2), (0, 1, 0))
lampada_rossa('l5', (5.8, Y1 + 0.002, 2.4), (0, -1, 0))
lampada_rossa('l6', (X0 - 0.002, -4.8, 3.0), (1, 0, 0), accesa=False)
lampada_rossa('l7', (XE + 0.002, 4.0, 4.7), (-1, 0, 0))   # sopra la leva
# neon sul soffitto: uno solo funziona (azzurro freddo), gli altri spenti
for k, (x, y, acceso) in enumerate(((-4.5, -1.0, False), (0.5, -1.0, True), (5.0, -1.0, False), (0.5, 3.5, False))):
    if HQ.disponibile('plafoniera_neon'):
        giu = lambda c, nrm: nrm.z < -0.6 and (c[0] + c[1] + c[2]) > 1.6
        HQ.dividi('plafoniera_neon', 'plafoniera_neon_diffusore', giu, (0.82, 1.0, 0.92), 10.0)
        HQ.metti(f'plafoniera_{k}', 'plafoniera_neon', (x, y, H - 0.72), (1.4, 0.32, 0.1))
        HQ.metti(f'neon_{k}_tubo_sfarfalla' if acceso else f'neon_{k}_tubi', 'plafoniera_neon', (x, y, H - 0.72), (1.4, 0.32, 0.1), parte='plafoniera_neon_diffusore')
        # catenelle che la reggono: oggetti a parte (non nel gruppo delle lampade, 10 m), dal soffitto (3 mm dentro)
        # fino a 3 mm dentro il coperchio della plafoniera, così il controllo di posizionamento le vede appese
        for i, dx in enumerate((-0.6, 0.6)):
            cilindro(f'plafoniera_{k}_catena_{i}', (x + dx, y, (H - 0.623 + H + 0.003) / 2), 0.008, 0.626, M['ferro'], seg=6, uv=None)
    else:
        S('lampade', box(f'plafoniera_{k}', (x, y, H - 0.62), (1.5, 0.22, 0.08), M['ferro'], uv=None))
        S('lampade', cilindro(f'neon_{k}', (x, y, H - 0.69), 0.025, 1.35, M['neon'] if acceso else M['neon_spento'], asse=(1, 0, 0), seg=10, uv=None))
    if acceso:
        luce(f'LUCE_neon_{k}', 'AREA', (x, y, H - 0.73), 90, (0.45, 0.9, 1.0), size=1.3, rot=(0, 0, 0))
luce('LUCE_neon_porta', 'AREA', (XE - 0.15, PORTA_Y, PORTA_H + 0.45), 25, (0.3, 0.95, 1.0), size=1.2, rot=(0, math.radians(-90), 0))

# ------------------------------------------------------------------ collisioni per Godot
usa_collezione('collisioni')
for g, ob in statici:
    if g in ('struttura', 'vasca') and ob.name in bpy.data.objects:
        collisione_struttura(ob)
for i, (px, col, _) in enumerate(POMPE):
    c = Vector((px, PY, 0))
    collisione_box(f'POMPA_{i + 1}_corpo', c + Vector((-1.1, -1.25, 0)), c + Vector((1.1, 1.9, 2.1)))
    mx, my = px + 0.45, PY - 0.45
    collisione_box(f'POMPA_{i + 1}_mandata', (mx - 0.32, my - 0.35, 2.1), (mx + 0.32, my + 0.35, HEADER_Z))
    collisione_box(f'POMPA_{i + 1}_aspirazione', (px - 1.62, my - 0.25, 0), (px - 1.1, my + 0.25, 1.4))
    tb = bpy.data.objects[f'TURBINA_{i + 1}']
    collisione_box(f'TURBINA_{i + 1}_disco', tb.location + Vector((-0.76, -0.2, -0.76)), tb.location + Vector((0.76, 0.15, 0.76)), padre=tb)
for i, (fx, fy) in enumerate(((-7.6, 4.4), (-7.6, 1.8))):
    collisione_box(f'FILTRO_{i + 1}', (fx - 1.08, fy - 1.08, 0), (fx + 1.08, fy + 1.08, 3.45))
for o in (scr, sed):
    collisione_da_bbox(o)
vx0, vx1, vy0, vy1 = VASCA
collisione_box('ringhiera_nord', (vx0 - 0.2, vy1 + 0.1, 0), (vx1 + 0.2, vy1 + 0.2, 1.1))
collisione_box('ringhiera_est', (vx1 + 0.1, vy0 - 0.2, 0), (vx1 + 0.2, vy1 + 0.2, 1.1))
collisione_box('gabbia_leva', GC - Vector((GD / 2 - 0.05, GW / 2, GH / 2)), GC + Vector((GD / 2, GW / 2, GH / 2)))
if LEVA_NUOVA:
    collisione_box('LEVA_braccio', (XE - 0.27, MOZZO.y - 0.08, MOZZO.z - 0.08), (XE - 0.15, MOZZO.y + 0.4, MOZZO.z + 0.66), padre=lv)
else:
    collisione_box('LEVA_braccio', LV + Vector((-0.3, -0.55, -0.35)), LV + Vector((-0.06, 0.55, 0.4)), padre=lv)
collisione_box('GRATA_leva_anta', GC + Vector((-GD / 2 - 0.03, -GW / 2, -GH / 2)), GC + Vector((-GD / 2 + 0.03, GW / 2, GH / 2)), padre=grata)
collisione_box('PORTA_ponte_anta', (XE - 0.1, PORTA_Y - PORTA_W / 2, 0), (XE, PORTA_Y + PORTA_W / 2, PORTA_H), padre=pt)

# ------------------------------------------------------------------ unione dei pezzi fissi per gruppo
gruppi = {}
for g, ob in statici:
    if ob.name in bpy.data.objects:
        gruppi.setdefault(g, []).append(ob)
for g, obs in gruppi.items():
    for o in obs:
        applica_trasf(o)
    nome = g if g.isupper() else 'SALA_' + g
    unisci(nome, obs)

# ------------------------------------------------------------------ export
GLB = os.path.join(SRC, 'glb', 'sala_pompe.glb')
esporta_glb(GLB)
if '--blend' in ARGS:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, 'blend', 'sala_pompe.blend'))

# ------------------------------------------------------------------ render dal punto di vista del giocatore
if '--render' in ARGS or '--anteprima' in ARGS:
    mondo()
    volume('nebbia', (0, 0, H / 2), (X1 - X0, Y1 - Y0, H), 0.018, (0.85, 0.9, 0.92), 0.4)
    for e in [o for o in bpy.data.objects if o.name.startswith('VAPORE_')]:
        volume(e.name + '_vol', e.location + Vector((0, 0, 0.5)), (0.7, 0.7, 1.1), 6.0, (0.9, 0.92, 0.95), 0.2, rumore=2.5, forma='sfera')
    ant = '--anteprima' in ARGS
    imposta_render(campioni=16 if ant else 160, w=800 if ant else 1600, h=450 if ant else 900, esposizione=0.9)
    viste = {
        'sala_pompe': ((X0 + 2.2, -4.3, 1.65), (3.0, 3.0, 1.7)),
        'sala_pompe_scrivania': ((2.9, -2.9, 1.65), (4.6, -5.4, 0.95)),
        'sala_pompe_leva': ((3.6, -2.6, 1.65), (XE, 1.9, 3.1)),
        'sala_pompe_porta': ((4.2, 0.6, 1.65), (XE, -3.4, 2.0)),
    }
    for nome, (loc, mira) in viste.items():
        camera(loc, mira, lente=20)
        renderizza(nome + ('_anteprima' if ant else '') + '.jpg')
