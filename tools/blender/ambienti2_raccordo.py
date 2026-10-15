"""Raccordo di servizio: dalla porta del ponte inferiore della sala pompe al fondo della scala che scende dal
corridoio degli interni (porta "sala pompe"). Ci si passa al ritorno al buio (tappa 7).

Uso:
  TECNICI_GODOT=1 /home/user/tools/blender-venv/bin/python tools/blender/ambienti2_raccordo.py [--anteprima]
Uscite:
  godot/assets/ambienti_tecnici/raccordo.gltf (con TECNICI_GODOT=1), altrimenti assets_src/ambienti_tecnici/glb/raccordo.glb

Coordinate: le stesse della scena godot/scenes/tecnici/tecnici.tscn (origine sotto il portello, camera delle onde
lungo +X, la sala pompe spostata di (37,3; 2,2) in Blender). Con la scena messa nel livello in (0; -9,05; 1,36)
e girata di -90 gradi su Y (vedi LEGGIMI), il fondo della scala degli interni cade in X=43,44, Y=6,7..8,9, Z=7,25.

Percorso (metri, Blender, Z in alto):
  corridoio R1   X 46,6..50,6, Y -2,4..-0,4, pavimento 0: dalla porta della sala verso est
  vano scala S   X 50,6..52,6, Y -2,4..9,1: rampa F1 che sale verso +Y fino al pianerottolo L1 (Z 3,625)
  rampa F2       X 45,6..50,6, Y 6,7..8,9: sale verso -X fino al pianerottolo T (Z 7,25)
  pianerottolo T X 43,44..45,6: davanti al primo gradino della scala degli interni
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
from ambienti2_comune import *
import ambienti2_comune as C
import ambienti1_hq as HQ
HQ.LINK[0] = C._link

ARGS = argomenti()
SP = 0.3
ALZ, PED = 0.18125, 0.2515          # alzata e pedata: 20 gradini per rampa, 36 gradi come la scala degli interni
N = 20
SALE = N * ALZ                      # 3,625 per rampa
PEND = ALZ / PED
XD = 46.3                           # faccia interna del muro est della sala (la porta)
XR = 46.6                           # faccia esterna
YD = -1.4                           # asse della porta
X_S0, X_S1 = 50.6, 52.6             # vano scala
Y_R0, Y_R1 = -2.4, -0.4             # corridoio
Y_F1 = Y_R1                         # primo gradino di F1
Y_L1 = Y_F1 + N * PED               # inizio del pianerottolo L1 (4,63)
Y_T0, Y_T1 = 6.5, 9.1               # larghezza del vano degli interni
Y_G0, Y_G1 = 6.7, 8.9               # larghezza della scala degli interni
X_T0 = 43.44                        # fondo della scala degli interni
X_F2 = X_T0 + 2.16                  # ultimo gradino di F2 (45,6)
Z_L1, Z_T = SALE, 2 * SALE          # 3,625 e 7,25
H_R1, H_S = 2.8, 7.2
H_T = Z_T + 2.6                     # soffitto sopra T (9,85)
Z_INTERNI = 9.05                    # pavimento degli interni

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
M['giallo'] = mat_pbr('vernice_giallo', 'PaintedMetal006', color='derivate/vernice_giallo_Color.jpg')
M['neon'] = mat_emissivo('neon_azzurro', (0.25, 0.95, 1.0), 25.0)
M['neon_spento'] = mat_pbr('neon_spento', base=(0.7, 0.7, 0.68), roughness=0.3)

C.SMUSSO[0] = 0.012
statici = []
def S(g, ob):
    statici.append((g, ob)); return ob

def blocco(nome, lo, hi, mat, uv=2.0, g='struttura'):
    """Scatola tra due angoli."""
    lo, hi = Vector(lo), Vector(hi)
    return S(g, box(nome, (lo + hi) / 2, hi - lo, mat, uv=uv))

def muro(nome, lo, hi):
    """Muro con lo zoccolo di cemento fino a 1 m sopra il pavimento lo.z e lamiere sopra."""
    lo, hi = Vector(lo), Vector(hi)
    zc = min(hi.z, lo.z + 1.0)
    blocco(nome + '_basso', lo, (hi.x, hi.y, zc), M['cemento'], 2.5)
    if hi.z > zc + 1e-3:
        blocco(nome + '_alto', (lo.x, lo.y, zc), hi, M['lamiere'], 2.0)

usa_collezione('struttura')
# ------------------------------------------------------------------ corridoio R1
blocco('r1_pavimento', (XD, Y_R0, -0.3), (X_S0, Y_R1, 0), M['cemento_bagnato'], 3.0)
blocco('r1_soffitto', (XR, Y_R0 - SP, H_R1), (X_S0, Y_R1 + SP, H_R1 + 0.3), M['cemento'], 2.5)
muro('r1_muro_s', (XR, Y_R0 - SP, 0), (X_S0, Y_R0, H_R1))
muro('r1_muro_n', (XR, Y_R1, 0), (X_S0 - SP, Y_R1 + SP, H_R1))
# ------------------------------------------------------------------ vano scala S con F1 e L1
blocco('s_pavimento', (X_S0, Y_R0, -0.3), (X_S1, Y_F1, 0), M['cemento_bagnato'], 3.0)
blocco('s_soffitto', (X_S0 - SP, Y_R0 - SP, H_S), (X_S1 + SP, Y_T1 + SP, H_S + 0.3), M['cemento'], 2.5)
muro('s_muro_e', (X_S1, Y_R0 - SP, 0), (X_S1 + SP, Y_T1 + SP, H_S))
muro('s_muro_s', (X_S0, Y_R0 - SP, 0), (X_S1, Y_R0, H_S))
muro('s_muro_n', (X_S0 - SP, Y_T1, Z_L1), (X_S1, Y_T1 + SP, H_S))
muro('s_muro_o', (X_S0 - SP, Y_R1, 0), (X_S0, Y_T0, H_S))
blocco('s_muro_o_sopra_r1', (X_S0 - SP, Y_R0, H_R1), (X_S0, Y_R1, H_S), M['lamiere'])
blocco('s_muro_o_sopra_f2', (X_S0 - SP, Y_T0, Z_L1 + 2.6), (X_S0, Y_T1, H_S), M['lamiere'])
# pianerottolo L1: blocco pieno
blocco('l1_blocco', (X_S0 - SP, Y_L1, 0), (X_S1, Y_T1 + SP, Z_L1), M['cemento'], 2.5)
# ------------------------------------------------------------------ rampa F2 e pianerottolo T
blocco('f2_fondo', (X_F2, Y_T0, Z_L1 - 0.5), (X_S0 - SP, Y_T1, Z_L1 - 0.3), M['cemento'], 2.5)
muro('f2_muro_s', (X_T0, Y_T0 - SP, Z_L1 - 0.5), (X_S0 - SP, Y_T0, H_T + 0.3))
muro('f2_muro_n', (X_T0, Y_T1, Z_L1 - 0.5), (X_S0 - SP, Y_T1 + SP, H_T + 0.3))
blocco('t_blocco', (X_T0, Y_T0, Z_L1 - 0.5), (X_F2, Y_T1, Z_T), M['cemento'], 2.5)
blocco('t_soffitto', (X_T0, Y_T0 - SP, H_T), (X_F2, Y_T1 + SP, H_T + 0.3), M['cemento'], 2.5)
# soffitto inclinato sopra F2 (parallelo alla rampa, 2,6 m più su)
lung = (X_S0 - X_F2) / math.cos(math.atan(PEND))
f2s = S('struttura', box('f2_soffitto', ((X_F2 + X_S0) / 2, (Y_T0 + Y_T1) / 2, (H_T + Z_L1 + 2.6) / 2 + 0.15),
                          (lung + 0.2, Y_T1 - Y_T0 + 2 * SP, 0.3), M['cemento'], uv=2.5, rot=(0, math.atan(PEND), 0)))
# sotto la scala degli interni: pavimento e fianchi fino al pavimento degli interni
X_I0 = X_T0 - 10 * 0.25
blocco('sotto_scala_pav', (X_I0, Y_T0, Z_T - 0.25), (X_T0, Y_T1, Z_T - 0.05), M['cemento'], 2.5)
blocco('sotto_scala_fianco_s', (X_I0, Y_T0 - SP, Z_T - 0.25), (X_T0, Y_T0, Z_INTERNI), M['lamiere'])
blocco('sotto_scala_fianco_n', (X_I0, Y_T1, Z_T - 0.25), (X_T0, Y_T1 + SP, Z_INTERNI), M['lamiere'])
# architrave sopra il passaggio verso la scala degli interni (sotto c'è il loro muro, da 9,05)
blocco('t_architrave', (X_T0, Y_T0 - SP, Z_INTERNI + 0.01), (X_T0 + 0.32, Y_T1 + SP, H_T + 0.01), M['lamiere'])
empty('PUNTO_raccordo_sala', (XR + 0.6, YD, 0))
empty('PUNTO_raccordo_interni', (X_T0 + 0.6, (Y_G0 + Y_G1) / 2, Z_T))

# ------------------------------------------------------------------ gradini (pieni, con il naso a strisce)
usa_collezione('scale')
def rampa(nome, origine, avanti, lato, larghezza, base_z):
    """N gradini pieni: origine = centro del filo del primo gradino a terra; avanti = direzione di salita."""
    o = Vector(origine); a = Vector(avanti); l = Vector(lato)
    for i in range(N):
        z = base_z + (i + 1) * ALZ
        p0 = o + a * i * PED - l * larghezza / 2
        p1 = o + a * (i + 1) * PED + l * larghezza / 2
        lo = Vector((min(p0.x, p1.x), min(p0.y, p1.y), base_z)); hi = Vector((max(p0.x, p1.x), max(p0.y, p1.y), z))
        S('scale', box(f'{nome}_gradino{i}', (lo + hi) / 2, hi - lo, M['cemento'], uv=1.5))
        naso = o + a * (i * PED + 0.03); naso.z = z - 0.0145
        d = Vector((abs(a.x) * 0.06 + abs(l.x) * larghezza, abs(a.y) * 0.06 + abs(l.y) * larghezza, 0.035))
        S('scale', box(f'{nome}_naso{i}', naso, d, M['pericolo'], uv=0.6))

rampa('f1', ((X_S0 + X_S1) / 2, Y_F1, 0), (0, 1, 0), (1, 0, 0), X_S1 - X_S0, 0.0)
rampa('f2', (X_S0, (Y_G0 + Y_G1) / 2, Z_L1), (-1, 0, 0), (0, 1, 0), Y_T1 - Y_T0, Z_L1)
# collisione: rampe lisce sul filo dei nasi (come la scala degli interni)
usa_collezione('collisioni')
def rampa_col(nome, inizio, fine, larghezza, asse):
    a, b = Vector(inizio), Vector(fine)
    lung = (b - a).length
    ang = math.atan2(b.z - a.z, (b - a).xy.length)
    # allungata di 0,2 solo in basso: in cima finisce a filo del pianerottolo
    c = (a + b) / 2 - (b - a).normalized() * 0.1 + Vector((0, 0, -0.1 / math.cos(ang)))
    if asse == 'Y':
        ob = box(f'{nome}-convcolonly', c, (larghezza, lung + 0.2, 0.2), None, uv=None, rot=(ang, 0, 0))
    else:
        ob = box(f'{nome}-convcolonly', c, (lung + 0.2, larghezza, 0.2), None, uv=None, rot=(0, ang, 0))
    ob['collisione'] = True; ob.hide_render = True
    return ob
# la retta dei nasi: dal pavimento un gradino prima del primo, fino al pianerottolo un gradino prima della fine
rampa_col('f1_rampa', ((X_S0 + X_S1) / 2, Y_F1 - PED, 0), ((X_S0 + X_S1) / 2, Y_F1 + (N - 1) * PED, Z_L1), X_S1 - X_S0, 'Y')
rampa_col('f2_rampa', (X_S0 + PED, (Y_T0 + Y_T1) / 2, Z_L1), (X_S0 - (N - 1) * PED, (Y_T0 + Y_T1) / 2, Z_T), Y_T1 - Y_T0, 'X')
# la rampa di collisione della scala degli interni finisce 17 cm sopra il loro ultimo gradino: un raccordo sulla
# stessa retta (36 gradi) la collega al pavimento del pianerottolo T
rampa_col('attacco_scala_interni', (X_T0 + 0.3, (Y_G0 + Y_G1) / 2, Z_T - 0.3 * PEND), (X_T0 - 0.5, (Y_G0 + Y_G1) / 2, Z_T + 0.5 * PEND), Y_G1 - Y_G0, 'X')

# ------------------------------------------------------------------ corrimano, tubi, costole
usa_collezione('dettagli')
yc = X_S1 - 0.12
S('dettagli', tubo('corrimano_f1', [(yc, Y_F1 - 0.3, 0.95), (yc, Y_F1 + (N - 1) * PED, Z_L1 + 0.95), (yc, Y_T1 - 0.3, Z_L1 + 0.95)], 0.025, M['giallo'], rc=0.15, seg=12))
for k in range(5):
    y = Y_F1 + k * (N - 1) * PED / 4
    z = (y - Y_F1 + PED) * PEND
    S('dettagli', cilindro(f'corrimano_f1_staffa{k}', (X_S1 - 0.06, y, z + 0.95), 0.012, 0.12, M['ferro'], asse=(1, 0, 0), seg=8, uv=None))
xc = Y_T1 - 0.12
S('dettagli', tubo('corrimano_f2', [(X_S0 + 0.3, xc, Z_L1 + 0.95), (X_S0 - (N - 1) * PED, xc, Z_T + 0.95), (X_T0 + 0.4, xc, Z_T + 0.95)], 0.025, M['giallo'], rc=0.15, seg=12))
# tubo grosso con flange: sotto il soffitto di R1, poi su per il vano scala
tg = [(XR, Y_R0 + 0.3, 2.45), (X_S1 - 0.35, Y_R0 + 0.3, 2.45), (X_S1 - 0.35, Y_R0 + 0.3, 6.6), (X_S1 - 0.35, Y_T1 - 0.4, 6.6)]
S('dettagli', tubo('tubo_grosso', tg, 0.16, M['tubi'], rc=0.45, seg=28, uv=1.2))
for k, (p, asse) in enumerate([((47.8, Y_R0 + 0.3, 2.45), (1, 0, 0)), ((49.6, Y_R0 + 0.3, 2.45), (1, 0, 0)),
                               ((X_S1 - 0.35, Y_R0 + 0.3, 4.2), (0, 0, 1)), ((X_S1 - 0.35, 2.0, 6.6), (0, 1, 0)),
                               ((X_S1 - 0.35, 5.5, 6.6), (0, 1, 0))]):
    for o in flangia(f'tubo_grosso_fl{k}', p, asse, 0.22, M['ferro'], 0.06, 8, M['ruggine']):
        S('dettagli', o)
for k, x in enumerate((47.2, 49.0)):
    S('dettagli', box(f'staffa_tubo{k}', (x, Y_R0 + 0.3, (2.45 + H_R1) / 2 + 0.1), (0.06, 0.06, H_R1 - 2.45), M['ferro'], uv=None))
# tubo piccolo lungo il muro nord di R1 che entra nel muro del vano
S('dettagli', tubo('tubo_piccolo', [(XR, Y_R1 - 0.18, 2.3), (X_S0 - 0.15, Y_R1 - 0.18, 2.3), (X_S0 - 0.15, Y_R1 + 0.3, 2.3)], 0.06, M['verde'], rc=0.2, seg=16))
for k, x in enumerate((47.5, 49.5)):
    for o in flangia(f'tubo_piccolo_fl{k}', (x, Y_R1 - 0.18, 2.3), (1, 0, 0), 0.09, M['ferro'], 0.03, 6, M['ruggine']):
        S('dettagli', o)
# tubo lungo il fianco di F2, parallelo alla rampa
S('dettagli', tubo('tubo_f2', [(X_S0 - 0.2, Y_T0 + 0.15, Z_L1 + 1.9), (X_F2, Y_T0 + 0.15, Z_T + 1.9), (X_T0 + 0.5, Y_T0 + 0.15, Z_T + 1.9)], 0.08, M['tubi'], rc=0.3, seg=20))
# costole d'acciaio nel corridoio
for k, x in enumerate((47.6, 49.4)):
    S('dettagli', box(f'costola{k}_s', (x, Y_R0 + 0.08, H_R1 / 2), (0.2, 0.16, H_R1), M['ferro'], uv=1.0))
    S('dettagli', box(f'costola{k}_n', (x, Y_R1 - 0.08, H_R1 / 2), (0.2, 0.16, H_R1), M['ferro'], uv=1.0))
    S('dettagli', box(f'costola{k}_t', (x, (Y_R0 + Y_R1) / 2, H_R1 - 0.08), (0.2, Y_R1 - Y_R0, 0.16), M['ferro'], uv=1.0))
# strisce di pericolo sul bordo del pianerottolo T
S('dettagli', box('t_bordo', (X_T0 + 0.05, (Y_G0 + Y_G1) / 2, Z_T + 0.005), (0.1, Y_G1 - Y_G0, 0.01), M['pericolo'], uv=0.6))

# ------------------------------------------------------------------ luci segnaposto (le finali le fa grafica)
usa_collezione('luci')
def lampada(nome, pos, normale, accesa=True):
    n = Vector(normale).normalized(); pos = Vector(pos)
    rosso = lambda c, nrm: c[0] > 0.25 and c[0] > c[1] * 2.2 and c[0] > c[2] * 2.0
    HQ.dividi('lampada_muro', 'lampada_muro_vetro', rosso, (1, 0.05, 0.02), 14.0)
    Rm = n.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    for o in (HQ.metti(f'lampada_{nome}', 'lampada_muro', (0, 0, 0), (0.34, None, None)),
              HQ.metti(f'lampada_{nome}_vetro' if accesa else f'lampada_{nome}_vetro_spento', 'lampada_muro', (0, 0, 0), (0.34, None, None), parte='lampada_muro_vetro')):
        o.matrix_world = Matrix.Translation(pos) @ Rm @ o.matrix_world
    if accesa:
        luce(f'LUCE_rossa_{nome}', 'POINT', pos + n * 0.25, 60, (1.0, 0.08, 0.04), raggio=0.08)

lampada('rc1', (48.5, Y_R0 + 0.02, 2.1), (0, 1, 0))
lampada('rc2', (X_S1 - 0.02, 7.0, Z_L1 + 2.0), (-1, 0, 0))
lampada('rc3', (44.6, Y_T1 - 0.02, Z_T + 2.0), (0, -1, 0))
giu = lambda c, nrm: nrm.z < -0.6 and (c[0] + c[1] + c[2]) > 1.6
HQ.dividi('plafoniera_neon', 'plafoniera_neon_diffusore', giu, (0.82, 1.0, 0.92), 10.0)
HQ.metti('plafoniera_rc', 'plafoniera_neon', (48.5, -0.9, H_R1 - 0.12), (1.4, 0.32, 0.1))
HQ.metti('neon_rc_tubo_sfarfalla', 'plafoniera_neon', (48.5, -0.9, H_R1 - 0.12), (1.4, 0.32, 0.1), parte='plafoniera_neon_diffusore')
luce('LUCE_neon_rc', 'AREA', (48.5, -0.9, H_R1 - 0.17), 60, (0.45, 0.9, 1.0), size=1.3)

# ------------------------------------------------------------------ collisioni dei muri e dei pianerottoli
for g, ob in statici:
    if g == 'struttura' and ob.name in bpy.data.objects:
        collisione_struttura(ob)

# ------------------------------------------------------------------ unione ed export
gruppi = {}
for g, ob in statici:
    if ob.name in bpy.data.objects:
        gruppi.setdefault(g, []).append(ob)
for g, obs in gruppi.items():
    for o in obs:
        applica_trasf(o)
    unisci('RACCORDO_' + g, obs)

esporta_glb(os.path.join(SRC, 'glb', 'raccordo.glb'))

if '--anteprima' in ARGS:
    mondo()
    imposta_render(campioni=16, w=800, h=450, esposizione=1.0)
    viste = {
        'raccordo_corridoio': ((47.0, -1.4, 1.65), (52.0, 2.0, 2.4)),
        'raccordo_scala': ((51.6, -1.8, 1.65), (51.6, 6.0, 4.5)),
        'raccordo_f2': ((51.4, 7.8, Z_L1 + 1.65), (44.0, 7.8, Z_T + 1.4)),
    }
    for nome, (loc, mira) in viste.items():
        camera(loc, mira, lente=18)
        renderizza(nome + '_anteprima.jpg')
