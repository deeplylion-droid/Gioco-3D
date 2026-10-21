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
LUCE_INTERNI = 0.5                  # apertura nel muro degli interni sopra la loro scala (fino a 0,5 sul loro pavimento)
# tappa 7 (16 ottobre, l'utente ha scelto il magazzino dei gonfiabili): da T non si sale più agli interni (grata
# chiusa) ma si va a ovest (corridoio C2, con una scala di 10 gradini fino al livello della sala grande), poi a
# nord (corridoio C3) fino al magazzino, che si apre con una serranda nell'angolo sud-ovest della sala grande.
# Qui Y = x globale, X = z globale - 1,36, Z = y globale + 9,05 (con la scena nel livello girata di -90 gradi).
XC0, XC1 = 43.6, 45.5               # larghezza del corridoio C2 (lungo X)
Y_SCALA2 = 3.2                      # primo gradino della scala di C2 (sale verso -Y)
N2, ALZ2, PED2 = 10, 0.18, 0.28     # 10 gradini da 18 cm: da 7,25 a 9,05
Y_SCALA2_FINE = Y_SCALA2 - N2 * PED2
YC3_0, YC3_1 = -16.0, -14.0         # larghezza del corridoio C3 (lungo Y), centrato sulla serranda (x globale -15)
XM0, XM1 = 18.84, 28.84             # magazzino: z globale da 20,2 (dietro il muro sud della sala) a 30,2
YM0, YM1 = -18.0, -12.0
HM = 3.4
Z_SALA = Z_INTERNI                  # pavimento della sala grande (y globale 0)
H_C = Z_SALA + 2.8                  # soffitto dei corridoi al livello della sala
SERR_Y0, SERR_Y1, SERR_H = -15.9, -14.1, 2.5   # varco della serranda nel muro sud della sala (x -15,9..-14,1)
SERR_BASSO = 1.95                   # la serranda è alzata fino a 1,95 m: si passa in piedi

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
muro('f2_muro_s', (XC1 + SP, Y_T0 - SP, Z_L1 - 0.5), (X_S0 - SP, Y_T0, H_T + 0.3))
blocco('f2_muro_s_sotto_c2', (X_T0, Y_T0 - SP, Z_L1 - 0.5), (XC1 + SP, Y_T0, Z_T - 0.3), M['cemento'])   # sotto il pavimento di C2
blocco('t_pilastro_c2', (X_T0, Y_T0 - SP, Z_T - 0.3), (XC0 - SP, Y_T0, H_T + 0.3), M['lamiere'])
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
# architrave sopra il passaggio verso la scala degli interni (sotto c'è l'apertura nel loro muro)
blocco('t_architrave', (X_T0, Y_T0 - SP, Z_INTERNI + LUCE_INTERNI + 0.01), (X_T0 + 0.32, Y_T1 + SP, H_T + 0.01), M['lamiere'])
empty('PUNTO_raccordo_sala', (XR + 0.6, YD, 0))
empty('PUNTO_raccordo_interni', (X_T0 + 0.6, (Y_G0 + Y_G1) / 2, Z_T))

# ------------------------------------------------------------------ tappa 7: corridoio C2 verso ovest
blocco('c2_pav_basso', (XC0, Y_SCALA2, Z_T - 0.3), (XC1, Y_T0, Z_T), M['cemento_bagnato'], 3.0)
blocco('c2_pav_alto', (XC0, YC3_0 - SP, Z_SALA - 0.3), (XC1, Y_SCALA2_FINE, Z_SALA), M['cemento_bagnato'], 3.0)
blocco('c2_sotto_alto', (XC0, YC3_0 - SP, Z_T - 0.3), (XC1, Y_SCALA2_FINE, Z_SALA - 0.3), M['cemento'], 3.0)
muro('c2_muro_n', (XC0 - SP, YC3_1, Z_T - 0.3), (XC0, Y_T0 - SP, H_C))          # lato verso gli interni
# muro sud di C2 con il buco dell'agnellino (v0.3.6): una grata di ventilazione sfondata alla base, larga BW e
# alta BH, troppo bassa per il giocatore (accucciato è alto 1,05 m); dietro una cavità buia profonda BP.
BY = -4.9                            # centro del buco (z = 4,9 nella scena dei tecnici; lì l'arredo lascia il varco)
BW, BH, BP = 0.85, 0.9, 2.2
BY0, BY1 = BY - BW / 2, BY + BW / 2
ZC2 = Z_T - 0.3 + 1.0                # dove finisce lo zoccolo di cemento (sotto il pavimento alto di C2)
blocco('c2_muro_s_basso', (XC1, YC3_0 - SP, Z_T - 0.3), (XC1 + SP, Y_T0 - SP, ZC2), M['cemento'], 2.5)
blocco('c2_muro_s_alto', (XC1, YC3_0 - SP, ZC2), (XC1 + SP, BY0, H_C), M['lamiere'], 2.0)
blocco('c2_muro_s_alto_b', (XC1, BY1, ZC2), (XC1 + SP, Y_T0 - SP, H_C), M['lamiere'], 2.0)
blocco('c2_muro_s_sotto_buco', (XC1, BY0, ZC2), (XC1 + SP, BY1, Z_SALA), M['lamiere'], 2.0)
blocco('c2_muro_s_sopra_buco', (XC1, BY0, Z_SALA + BH), (XC1 + SP, BY1, H_C), M['lamiere'], 2.0)
M['buio'] = mat_pbr('buio_condotto', base=(0.012, 0.011, 0.01), roughness=0.9)
XB0, XB1 = XC1 + SP, XC1 + SP + BP
blocco('buco_pav', (XB0, BY0 - 0.1, Z_SALA - 0.3), (XB1 + 0.1, BY1 + 0.1, Z_SALA), M['buio'], 2.0)
blocco('buco_cielo', (XB0, BY0 - 0.1, Z_SALA + BH), (XB1 + 0.1, BY1 + 0.1, Z_SALA + BH + 0.2), M['buio'], 2.0)
blocco('buco_lato_a', (XB0, BY0 - 0.1, Z_SALA), (XB1, BY0, Z_SALA + BH), M['buio'], 2.0)
blocco('buco_lato_b', (XB0, BY1, Z_SALA), (XB1, BY1 + 0.1, Z_SALA + BH), M['buio'], 2.0)
blocco('buco_fondo', (XB1, BY0 - 0.1, Z_SALA), (XB1 + 0.1, BY1 + 0.1, Z_SALA + BH), M['buio'], 2.0)
# dentro lo spessore del muro: le facce del taglio scure di sporco (la lamiera tagliata si vede solo sul bordo)
for k, (y0, y1) in enumerate(((BY0, BY0 + 0.02), (BY1 - 0.02, BY1))):
    S('dettagli', box(f'buco_spalla{k}', (XC1 + SP / 2 + 0.01, (y0 + y1) / 2, Z_SALA + BH / 2), (SP - 0.02, y1 - y0, BH), M['ruggine'], uv=1.0))
# il telaio della grata, rimasto avvitato al muro, con il traverso alto piegato verso fuori
for nome, c, d in (('buco_telaio_s', (XC1 - 0.012, BY0 - 0.025, Z_SALA + BH / 2), (0.025, 0.05, BH)),
                   ('buco_telaio_d', (XC1 - 0.012, BY1 + 0.025, Z_SALA + BH / 2), (0.025, 0.05, BH)),
                   ('buco_telaio_basso', (XC1 - 0.012, BY, Z_SALA + 0.025), (0.025, BW + 0.1, 0.05))):
    S('dettagli', box(nome, c, d, M['ferro'], uv=1.0))
S('dettagli', box('buco_telaio_alto', (XC1 - 0.05, BY + 0.06, Z_SALA + BH + 0.01), (0.025, BW - 0.05, 0.05), M['ferro'], uv=1.0,
                  rot=(math.radians(14), math.radians(-35), 0)))
# la grata sfondata: presa a calci, è caduta dentro e sta storta sul fondo della cavità
gm = (Matrix.Translation((XB1 - 0.5, BY + 0.03, Z_SALA + 0.055)) @ Matrix.Rotation(math.radians(7), 4, 'Z')
      @ Matrix.Rotation(math.radians(-84), 4, 'Y'))
S('dettagli', box('grata_cornice_a', None, (0.025, 0.05, 0.8), M['ferro'], uv=1.0, matrice=gm @ Matrix.Translation((0, -0.37, 0))))
S('dettagli', box('grata_cornice_b', None, (0.025, 0.05, 0.8), M['ferro'], uv=1.0, matrice=gm @ Matrix.Translation((0, 0.37, 0))))
S('dettagli', box('grata_cornice_c', None, (0.025, 0.79, 0.05), M['ferro'], uv=1.0, matrice=gm @ Matrix.Translation((0, 0, -0.38))))
S('dettagli', box('grata_cornice_d', None, (0.025, 0.79, 0.05), M['ferro'], uv=1.0, matrice=gm @ Matrix.Translation((0, 0, 0.38))))
for k in range(6):
    z = -0.3 + k * 0.12
    piega = Matrix.Rotation(math.radians((0, 0, 14, 22, 0, -8)[k]), 4, 'Z')
    lung = 0.72 if k != 3 else 0.45
    S('dettagli', box(f'grata_lamella{k}', None, (0.035, lung, 0.012), M['ruggine'] if k % 3 == 0 else M['ferro'], uv=1.0,
                      matrice=gm @ Matrix.Translation((0, -0.36 + lung / 2 + (0.0 if k != 3 else 0.25), z)) @ piega @ Matrix.Rotation(math.radians(30), 4, 'Y')))
blocco('c2_soffitto_basso', (XC0 - SP, 3.6, H_T), (XC1 + SP, Y_T0 - SP, H_T + 0.3), M['cemento'], 2.5)
blocco('c2_architrave', (XC0, 3.6, H_T), (XC1, 3.9, H_C), M['lamiere'])
blocco('c2_soffitto', (XC0 - SP, YC3_0 - SP, H_C), (XC1 + SP, 3.6, H_C + 0.3), M['cemento'], 2.5)
# ------------------------------------------------------------------ tappa 7: corridoio C3 verso nord
blocco('c3_pav', (XM1 + SP, YC3_0 - SP, Z_SALA - 0.3), (XC0, YC3_1 + SP, Z_SALA), M['cemento_bagnato'], 3.0)
# la porta della scala di servizio che sale dall'infermeria (strada nuova della risalita, 21 ottobre):
# nel muro ovest di C3, z globale da 37,95 a 38,95, tra i gonfiabili e gli oggetti appesi
X_PS0, X_PS1, H_PS = 37.95 - 1.36, 38.95 - 1.36, 2.2
muro('c3_muro_o', (XM1 + SP, YC3_0 - SP, Z_SALA), (X_PS0, YC3_0, H_C))
muro('c3_muro_o_nord', (X_PS1, YC3_0 - SP, Z_SALA), (XC1 + SP, YC3_0, H_C))
blocco('c3_muro_o_sopra_porta', (X_PS0, YC3_0 - SP, Z_SALA + H_PS), (X_PS1, YC3_0, H_C), M['lamiere'], 2.0)
# il telaio d'acciaio della porta, dalla parte di C3
for k, x in enumerate((X_PS0 + 0.03, X_PS1 - 0.03)):
    S('dettagli', box(f'c3_porta_stipite{k}', (x, YC3_0 + 0.03, Z_SALA + H_PS / 2), (0.06, 0.06, H_PS), M['verde'], uv=1.0))
S('dettagli', box('c3_porta_architrave', ((X_PS0 + X_PS1) / 2, YC3_0 + 0.03, Z_SALA + H_PS + 0.03), (X_PS1 - X_PS0, 0.06, 0.06), M['verde'], uv=1.0))
muro('c3_muro_e', (XM1 + SP, YC3_1, Z_SALA), (XC0 - SP, YC3_1 + SP, H_C))
blocco('c3_soffitto', (XM1 + SP, YC3_0 - SP, H_C), (XC0 - SP, YC3_1 + SP, H_C + 0.3), M['cemento'], 2.5)
# ------------------------------------------------------------------ tappa 7: magazzino dei gonfiabili
M['piastrelle'] = mat_pbr('piastrelle_muro', 'Tiles133D', color='derivate/piastrelle_sporche_Color.jpg',
                          rough='derivate/piastrelle_sporche_Roughness.jpg')
blocco('mag_pav', (XM0 - 0.35, YM0 - SP, Z_SALA - 0.3), (XM1 + SP, YM1 + SP, Z_SALA), M['cemento_bagnato'], 3.0)
blocco('mag_soffitto', (XM0, YM0 - SP, Z_SALA + HM), (XM1 + SP, YM1 + SP, Z_SALA + HM + 0.3), M['cemento'], 2.5)
def muro_piastrelle(nome, lo, hi):
    lo, hi = Vector(lo), Vector(hi)
    zc = min(hi.z, lo.z + 1.1)
    blocco(nome + '_basso', lo, (hi.x, hi.y, zc), M['piastrelle'], 2.0)
    if hi.z > zc + 1e-3:
        blocco(nome + '_alto', (lo.x, lo.y, zc), hi, M['lamiere'], 2.0)
muro_piastrelle('mag_muro_o', (XM0, YM0 - SP, Z_SALA), (XM1 + SP, YM0, Z_SALA + HM))
muro_piastrelle('mag_muro_e', (XM0, YM1, Z_SALA), (XM1 + SP, YM1 + SP, Z_SALA + HM))
# muro sud (verso C3) con il passaggio, muro nord (contro il muro della sala) con il varco della serranda
muro_piastrelle('mag_muro_s_o', (XM1, YM0, Z_SALA), (XM1 + SP, YC3_0, Z_SALA + HM))
muro_piastrelle('mag_muro_s_e', (XM1, YC3_1, Z_SALA), (XM1 + SP, YM1, Z_SALA + HM))
blocco('mag_muro_s_sopra', (XM1, YC3_0, H_C), (XM1 + SP, YC3_1, Z_SALA + HM), M['lamiere'])
muro_piastrelle('mag_muro_n_o', (XM0, YM0, Z_SALA), (XM0 + SP, SERR_Y0, Z_SALA + HM))
muro_piastrelle('mag_muro_n_e', (XM0, SERR_Y1, Z_SALA), (XM0 + SP, YM1, Z_SALA + HM))
blocco('mag_muro_n_sopra', (XM0, SERR_Y0, Z_SALA + SERR_H), (XM0 + SP, SERR_Y1, Z_SALA + HM), M['lamiere'])
# soglia nel varco del muro della sala (spesso 0,2): il pavimento continua
blocco('soglia_serranda', (XM0 - 0.35, SERR_Y0, Z_SALA - 0.3), (XM0, SERR_Y1, Z_SALA - 0.002), M['ferro'], 1.0)
empty('PUNTO_t7_inizio', (XR + 0.9, YD, 0))
empty('PUNTO_t7_cima_scala', ((XC0 + XC1) / 2, Y_SCALA2_FINE - 0.8, Z_SALA))
empty('PUNTO_t7_magazzino', (XM1 - 1.2, (YC3_0 + YC3_1) / 2, Z_SALA))
empty('PUNTO_t7_serranda', (XM0 - 0.9, (SERR_Y0 + SERR_Y1) / 2, Z_SALA))   # appena fuori, nella sala grande
empty('PUNTO_t7_inizio_scia', (XM0 - 1.6, (SERR_Y0 + SERR_Y1) / 2, Z_SALA))

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

# ------------------------------------------------------------------ tappa 7: scala di C2 (10 gradini da 18 cm)
usa_collezione('scale')
for k in range(N2):
    z = Z_T + (k + 1) * ALZ2
    y1, y0 = Y_SCALA2 - k * PED2, Y_SCALA2 - (k + 1) * PED2
    S('scale', box(f'c2_gradino{k}', ((XC0 + XC1) / 2, (y0 + y1) / 2, (Z_T + z) / 2), (XC1 - XC0, PED2, z - Z_T), M['cemento'], uv=1.5))
    S('scale', box(f'c2_naso{k}', ((XC0 + XC1) / 2, y1 - 0.03, z - 0.0145), (XC1 - XC0, 0.06, 0.035), M['pericolo'], uv=0.6))
usa_collezione('collisioni')
# rampa liscia sul filo dei nasi (sale verso -Y): il giocatore non deve scavalcare gradini
a = Vector(((XC0 + XC1) / 2, Y_SCALA2 + PED2, Z_T)); b = Vector(((XC0 + XC1) / 2, Y_SCALA2 - (N2 - 1) * PED2, Z_SALA))
ang = math.atan2(b.z - a.z, (a - b).y); lung = (b - a).length
c = (a + b) / 2 - (b - a).normalized() * 0.1 + Vector((0, 0, -0.1 / math.cos(ang)))
ob = box('c2_rampa-convcolonly', c, (XC1 - XC0, lung + 0.2, 0.2), None, uv=None, rot=(-ang, 0, 0))
ob['collisione'] = True; ob.hide_render = True

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

# ------------------------------------------------------------------ tappa 7: dettagli, luci e oggetti
R_ = math.radians
usa_collezione('dettagli')
# grata chiusa con catena davanti alla scala degli interni: di lì non si torna indietro
XG = X_T0 + 0.06
for k in range(18):
    y = Y_T0 + 0.1 + k * (Y_T1 - Y_T0 - 0.2) / 17
    S('dettagli', cilindro(f'grata_interni_sbarra{k}', (XG, y, (Z_T + Z_INTERNI + LUCE_INTERNI) / 2), 0.012, Z_INTERNI + LUCE_INTERNI - Z_T,
                         M['ferro'], seg=8, uv=None))
for z in (Z_T + 0.1, Z_T + 1.1, Z_INTERNI + LUCE_INTERNI - 0.08):
    S('dettagli', box(f'grata_interni_traverso{z:.1f}', (XG, (Y_T0 + Y_T1) / 2, z), (0.05, Y_T1 - Y_T0, 0.05), M['verde'], uv=None))
for k in range(5):   # catena e lucchetto
    S('dettagli', toro(f'grata_catena{k}', (XG - 0.05, (Y_T0 + Y_T1) / 2 - 0.2 + k * 0.08, Z_T + 1.1), 0.035, 0.008, M['ferro'],
                      asse=(0, 1, 0) if k % 2 else (0, 0, 1), seg=12, seg2=6, uv=None))
S('dettagli', box('grata_lucchetto', (XG - 0.08, (Y_T0 + Y_T1) / 2 + 0.22, Z_T + 1.0), (0.04, 0.07, 0.09), M['giallo'], uv=None))
# tubi lungo i corridoi, con flange
S('dettagli', tubo('t7_tubo_c2', [(XC1 - 0.25, Y_T0 - 0.4, H_C - 0.3), (XC1 - 0.25, YC3_0 + 0.25, H_C - 0.3), (XM1 + 0.4, YC3_0 + 0.25, H_C - 0.3)],
                   0.1, M['tubi'], rc=0.3, seg=24, uv=1.2))
for y in (-2.0, -6.0, -10.0):
    for o in flangia(f't7_tubo_c2_fl{y:.0f}', (XC1 - 0.25, y, H_C - 0.3), (0, 1, 0), 0.14, M['ferro'], 0.04, 8, M['ruggine']):
        S('dettagli', o)
for x in (41.0, 37.0, 33.0):
    for o in flangia(f't7_tubo_c3_fl{x:.0f}', (x, YC3_0 + 0.25, H_C - 0.3), (1, 0, 0), 0.14, M['ferro'], 0.04, 8, M['ruggine']):
        S('dettagli', o)
S('dettagli', tubo('t7_tubo_piccolo', [(XC0 + 0.15, Y_T0 - 0.4, H_C - 0.55), (XC0 + 0.15, YC3_1 - 0.15, H_C - 0.55)], 0.04, M['verde'], seg=12, uv=1.0))
# costole d'acciaio ogni 3 m
for k, y in enumerate((-1.0, -4.0, -7.0, -10.0, -13.0)):
    S('dettagli', box(f'c2_costola{k}_a', (XC0 + 0.08, y, (Z_SALA + H_C) / 2), (0.16, 0.2, H_C - Z_SALA), M['ferro'], uv=1.0))
    S('dettagli', box(f'c2_costola{k}_b', (XC1 - 0.08, y, (Z_SALA + H_C) / 2), (0.16, 0.2, H_C - Z_SALA), M['ferro'], uv=1.0))
for k, x in enumerate((42.0, 39.0, 36.0, 33.0, 30.0)):
    S('dettagli', box(f'c3_costola{k}_a', (x, YC3_0 + 0.08, (Z_SALA + H_C) / 2), (0.2, 0.16, H_C - Z_SALA), M['ferro'], uv=1.0))
    S('dettagli', box(f'c3_costola{k}_b', (x, YC3_1 - 0.08, (Z_SALA + H_C) / 2), (0.2, 0.16, H_C - Z_SALA), M['ferro'], uv=1.0))
# serranda alzata fino a 1,95 m, con le guide laterali e il cassone (dalla parte del magazzino)
XS = XM0 + SP / 2
for k in range(int((SERR_H - SERR_BASSO) / 0.07)):
    z = Z_SALA + SERR_BASSO + 0.035 + k * 0.07
    S('dettagli', box(f'serranda_{k}', (XS, (SERR_Y0 + SERR_Y1) / 2, z), (0.04, SERR_Y1 - SERR_Y0 + 0.08, 0.065), M['ferro'], uv=0.6))
S('dettagli', box('serranda_bordo', (XS, (SERR_Y0 + SERR_Y1) / 2, Z_SALA + SERR_BASSO + 0.02), (0.06, SERR_Y1 - SERR_Y0 + 0.08, 0.04), M['pericolo'], uv=0.6))
for yy in (SERR_Y0 - 0.03, SERR_Y1 + 0.03):
    S('dettagli', box(f'serranda_guida{yy:.1f}', (XS, yy, Z_SALA + SERR_H / 2), (0.08, 0.06, SERR_H), M['ferro'], uv=None))
S('dettagli', box('serranda_cassone', (XM0 + SP + 0.15, (SERR_Y0 + SERR_Y1) / 2, Z_SALA + SERR_H + 0.15), (0.3, SERR_Y1 - SERR_Y0 + 0.3, 0.3), M['ferro'], uv=1.0))
usa_collezione('collisioni')
collisione_box('serranda', (XM0, SERR_Y0, Z_SALA + SERR_BASSO), (XM0 + SP, SERR_Y1, Z_SALA + SERR_H))
collisione_box('grata_interni', (XG - 0.04, Y_T0, Z_T), (XG + 0.04, Y_T1, Z_INTERNI + LUCE_INTERNI))
# scaffali lungo i due muri lunghi del magazzino e mucchi di gonfiabili sgonfi a terra (come nel render approvato)
usa_collezione('oggetti')
if HQ.disponibile('scaffale_magazzino'):
    ds = HQ.dimensioni('scaffale_magazzino'); ks = 2.4 / ds.z
    for k, x in enumerate((XM1 - 1.4, XM1 - 3.6, XM0 + 3.3, XM0 + 1.1)):
        # contro i muri lunghi, con il davanti verso il centro del magazzino
        for y, rz, lato in ((YM0 + ds.y * ks / 2 + 0.05, 180, 0), (YM1 - ds.y * ks / 2 - 0.05, 0, 1)):
            HQ.metti(f'scaffale_{k}_{lato}', 'scaffale_magazzino', (x, y, Z_SALA), tuple(ds * ks), rot_z=R_(rz))
            w, d = ds.x * ks, ds.y * ks
            collisione_box(f'scaffale_{k}_{lato}', (x - w / 2, y - d / 2, Z_SALA), (x + w / 2, y + d / 2, Z_SALA + 2.4))
if HQ.disponibile('gonfiabili_mucchio'):
    dg = HQ.dimensioni('gonfiabili_mucchio')
    for k, (x, y, rz, sz) in enumerate(((XM1 - 2.4, YM0 + 1.3, 20, 1.5), (XM0 + 4.2, YM1 - 1.2, -40, 1.7), (XM0 + 2.0, YM0 + 1.4, 70, 1.3),
                                        (XM1 - 4.6, YM1 - 1.1, 120, 1.1), (36.5, YC3_1 - 0.55, 10, 0.9))):
        kg = sz / max(dg.x, dg.y)
        HQ.metti(f'mucchio_gonfiabili_{k}', 'gonfiabili_mucchio', (x, y, Z_SALA), tuple(dg * kg), rot_z=R_(rz))
        r = sz * 0.35
        collisione_box(f'mucchio_gonfiabili_{k}', (x - r, y - r, Z_SALA), (x + r, y + r, Z_SALA + 0.35))
# luci: solo quelle d'emergenza (dopo il risveglio è blackout) e quella rossa oltre la serranda, che guida
usa_collezione('luci')
lampada('t7_c2a', (XC0 + 0.02, 5.0, Z_T + 2.0), (1, 0, 0))
lampada('t7_c2b', (XC1 - 0.02, -3.5, Z_SALA + 2.2), (-1, 0, 0))
lampada('t7_c2c', (XC0 + 0.02, -11.0, Z_SALA + 2.2), (1, 0, 0))
lampada('t7_c3a', (40.0, YC3_1 - 0.02, Z_SALA + 2.2), (0, -1, 0))
lampada('t7_c3b', (33.5, YC3_0 + 0.02, Z_SALA + 2.2), (0, 1, 0))
lampada('t7_mag_a', (XM1 - 0.02, YM0 + 1.0, Z_SALA + 2.4), (-1, 0, 0))
lampada('t7_mag_b', (XM0 + 4.0, YM1 - 0.02, Z_SALA + 2.6), (0, -1, 0))
lampada('t7_serranda', (XM0 + SP + 0.02, SERR_Y1 + 0.6, Z_SALA + 2.2), (1, 0, 0))
luce('LUCE_guida_serranda', 'AREA', (XM0 - 1.0, (SERR_Y0 + SERR_Y1) / 2, Z_SALA + 0.5), 250, (1.0, 0.12, 0.06), size=1.8,
     mira=(XM0 + 3.0, (SERR_Y0 + SERR_Y1) / 2, Z_SALA))

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
