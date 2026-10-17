"""Proposte per la tappa 7 senza backtracking (solo render, non vanno nel gioco): due stanze nuove fra la sala
pompe e la sala grande, al buio del blackout (solo luci rosse d'emergenza e la torcia del giocatore).
  A. locale caldaie: due caldaie, tubi, passerella, scala che sale verso la porta di servizio della sala grande;
  B. magazzino dei gonfiabili: scaffali, mucchi di gonfiabili sgonfi, una serranda mezza alzata.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/proposte_tappa7.py [a] [b] [--prova]
Uscita: docs/proposte/tappa7/<nome>.jpg"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
from ambienti2_comune import *
import ambienti2_comune as C
import ambienti1_hq as HQ
HQ.LINK[0] = C._link

ARGS = argomenti()
PROVA = '--prova' in ARGS
C.RENDER = os.path.join(C.RADICE, 'docs', 'proposte', 'tappa7')
R_ = math.radians


def materiali():
    HQ._base.clear(); HQ._dim.clear(); C._img_cache.clear()   # scena nuova: modelli e immagini si ricaricano
    M = {}
    M['lamiere'] = mat_pbr('lamiere_rivettate', 'MetalPlates013')
    M['cemento'] = mat_pbr('cemento', 'Concrete042C')
    M['bagnato'] = mat_pbr('cemento_bagnato', 'Concrete042C', rough='derivate/pavimento_bagnato_Roughness.jpg')
    M['ferro'] = mat_pbr('ferro_arrugginito', 'Metal021')
    M['tubi'] = mat_pbr('tubo_ruggine', 'Metal041B')
    M['ruggine'] = mat_pbr('ruggine', 'Rust004')
    M['verde'] = mat_pbr('vernice_verde', 'PaintedMetal006')
    M['pericolo'] = mat_pbr('strisce_pericolo', 'PaintedMetal016')
    M['grata'] = mat_pbr('lamiera_forata', 'MetalWalkway014')
    M['giallo'] = mat_pbr('vernice_giallo', 'PaintedMetal006', color='derivate/vernice_giallo_Color.jpg')
    M['piastrelle'] = mat_pbr('piastrelle_muro', 'Tiles133D', color='derivate/piastrelle_sporche_Color.jpg',
                              rough='derivate/piastrelle_sporche_Roughness.jpg')
    return M


def stanza(M, x0, x1, y0, y1, h, basso='cemento', alto='lamiere', pav='bagnato', aperture=()):
    """Pavimento, soffitto e quattro muri; aperture = [(lato, da, a, z0, z1)] con lato in 'nsoe'."""
    box('pav', ((x0 + x1) / 2, (y0 + y1) / 2, -0.15), (x1 - x0 + 0.6, y1 - y0 + 0.6, 0.3), M[pav], uv=3.0)
    box('soff', ((x0 + x1) / 2, (y0 + y1) / 2, h + 0.15), (x1 - x0 + 0.6, y1 - y0 + 0.6, 0.3), M['cemento'], uv=3.0)
    lati = {'s': ('x', y0 - 0.15, x0, x1), 'n': ('x', y1 + 0.15, x0, x1), 'o': ('y', x0 - 0.15, y0, y1), 'e': ('y', x1 + 0.15, y0, y1)}
    for lato, (asse, fisso, a0, a1) in lati.items():
        buchi = sorted([(d, a, z0, z1) for (l, d, a, z0, z1) in aperture if l == lato])
        pezzi, cur = [], a0
        for d, a, z0, z1 in buchi:
            pezzi.append((cur, d, 0, h)); pezzi.append((d, a, z1, h))
            if z0 > 0:
                pezzi.append((d, a, 0, z0))
            cur = a
        pezzi.append((cur, a1, 0, h))
        for s0, s1, z0, z1 in pezzi:
            if s1 - s0 < 1e-3 or z1 - z0 < 1e-3:
                continue
            for za, zb, mat in ((z0, min(z1, 1.1), M[basso]), (max(z0, 1.1), z1, M[alto])):
                if zb - za < 1e-3:
                    continue
                c = ((s0 + s1) / 2, fisso, (za + zb) / 2) if asse == 'x' else (fisso, (s0 + s1) / 2, (za + zb) / 2)
                d = (s1 - s0, 0.3, zb - za) if asse == 'x' else (0.3, s1 - s0, zb - za)
                box(f'muro_{lato}', c, d, mat, uv=2.0)


def tubo_flange(nome, punti, r, M, mat='tubi', passo=1.6):
    tubo(nome, punti, r, M[mat], rc=3 * r, seg=24, uv=1.2)
    for a, b in zip(punti, punti[1:]):
        a, b = Vector(a), Vector(b)
        d = (b - a); L = d.length; d.normalize()
        k = 1
        while k * passo < L - 0.3:
            flangia(f'{nome}_fl', a + d * k * passo, d, r * 1.45, M['ferro'], 0.05, 8, M['ruggine'])
            k += 1


def lampada_rossa(nome, pos, normale):
    n = Vector(normale).normalized(); pos = Vector(pos)
    rosso = lambda c, nrm: c[0] > 0.25 and c[0] > c[1] * 2.2 and c[0] > c[2] * 2.0
    HQ.dividi('lampada_muro', 'lampada_muro_vetro', rosso, (1, 0.05, 0.02), 14.0)
    Rm = n.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    for o in (HQ.metti(f'lampada_{nome}', 'lampada_muro', (0, 0, 0), (0.34, None, None)),
              HQ.metti(f'lampada_{nome}_vetro', 'lampada_muro', (0, 0, 0), (0.34, None, None), parte='lampada_muro_vetro')):
        o.matrix_world = Matrix.Translation(pos) @ Rm @ o.matrix_world
    luce(f'LUCE_rossa_{nome}', 'POINT', pos + n * 0.25, 70, (1.0, 0.08, 0.04), raggio=0.08)


def torcia(cam_loc, mira):
    """La torcia del giocatore: faro caldo dalla mano destra."""
    loc = Vector(cam_loc) + Vector((0, 0, -0.25))
    luce('torcia', 'SPOT', loc, 160, (1.0, 0.9, 0.75), spot=52, mira=mira, raggio=0.03)


def scatta(nome, cam, mira, lente=20):
    camera(cam, mira, lente=lente)
    torcia(cam, mira)
    mondo((0.002, 0.002, 0.003), 1.0)
    imposta_render(campioni=24 if PROVA else 220, w=800 if PROVA else 1600, h=450 if PROVA else 900, esposizione=0.6)
    renderizza(nome + ('_prova' if PROVA else '') + '.jpg')


# ------------------------------------------------------------------ A. locale caldaie
def caldaie():
    reset(); M = materiali()
    C.SMUSSO[0] = 0.012
    X0, X1, Y0, Y1, H = 0.0, 11.0, 0.0, 7.0, 4.6
    # entra da ovest (dal corridoio di servizio della sala pompe); esce in alto a est (porta verso la sala grande)
    stanza(M, X0, X1, Y0, Y1, H, aperture=[('o', 2.6, 3.8, 0, 2.2), ('e', 4.6, 5.8, 2.6, 4.8)])
    for k, x in enumerate((2.6, 6.4)):
        if HQ.disponibile('caldaia'):
            dc = HQ.dimensioni('caldaia'); kc = 3.4 / dc.x
            HQ.metti(f'caldaia_{k}', 'caldaia', (x + 0.9, 5.3, 0.0), tuple(dc * kc), rot_z=R_(180))
        tubo_flange(f'fumi_{k}', [(x + 0.9, 5.3, 2.6), (x + 0.9, 5.3, 4.0), (x + 0.9, 6.7, 4.0), (x + 0.9, 6.7, H)], 0.22, M)
        tubo_flange(f'mandata_{k}', [(x + 0.2, 4.6, 2.2), (x + 0.2, 4.0, 3.7), (X1 - 0.3, 4.0, 3.7)], 0.09, M, 'verde')
    tubo_flange('collettore_caldaie', [(X0, 0.5, 3.9), (X1, 0.5, 3.9)], 0.16, M)
    tubo_flange('ritorno', [(X0, 0.9, 3.5), (8.0, 0.9, 3.5), (8.0, 0.9, 0.3), (X1, 0.9, 0.3)], 0.07, M)
    # passerella in grata lungo il muro est e scala che sale alla porta alta (2,6 m)
    box('passerella', (9.9, 5.2, 2.55), (2.2, 1.8, 0.08), M['grata'], uv=1.0)
    for k in range(13):
        z = 0.2 * (k + 1)
        box(f'gradino{k}', (5.2 + 0.26 * k + 0.13, 5.2, z - 0.03), (0.28, 1.2, 0.05), M['grata'], uv=1.0)
        box(f'naso{k}', (5.2 + 0.26 * k + 0.26, 5.2, z - 0.005), (0.04, 1.2, 0.015), M['pericolo'], uv=0.5)
    for s in (-1, 1):
        tubo(f'corrimano{s}', [(5.2, 5.2 + s * 0.62, 1.0), (8.6, 5.2 + s * 0.62, 3.6), (X1 - 0.2, 5.2 + s * 0.62, 3.6)], 0.025, M['giallo'], rc=0.1, seg=10)
    box('porta_alta', (X1 + 0.12, 5.2, 3.7), (0.08, 1.15, 2.15), M['verde'], uv=1.0)
    # pozze, un secchio, cartello
    lampada_rossa('a1', (X0 + 0.02, 1.6, 2.6), (1, 0, 0))
    lampada_rossa('a2', (X1 - 0.02, 2.2, 3.0), (-1, 0, 0))
    lampada_rossa('a3', (5.0, Y1 - 0.02, 3.6), (0, -1, 0))
    volume('vapore', (5.5, 4.5, 1.2), (9, 4, 2.4), 0.06, (0.9, 0.9, 0.92), 0.3, rumore=1.0)
    volume('nebbia', (5.5, 3.5, 2.3), (11, 7, 4.6), 0.02, (0.85, 0.85, 0.88), 0.3)
    scatta('a_caldaie_entrata', (0.7, 1.0, 1.62), (9.0, 4.6, 2.0), 18)


# ------------------------------------------------------------------ B. magazzino dei gonfiabili
def magazzino():
    reset(); M = materiali()
    C.SMUSSO[0] = 0.012
    X0, X1, Y0, Y1, H = 0.0, 10.0, 0.0, 6.0, 3.4
    stanza(M, X0, X1, Y0, Y1, H, basso='piastrelle', alto='lamiere', aperture=[('o', 2.4, 3.6, 0, 2.2), ('e', 1.8, 4.2, 0, 2.6)])
    for k, x in enumerate((1.2, 3.4, 5.6, 7.8)):
        for y, rz in ((0.55, 0), (Y1 - 0.55, 180)):
            if HQ.disponibile('scaffale_magazzino'):
                ds = HQ.dimensioni('scaffale_magazzino'); ks = 2.4 / ds.z
                HQ.metti(f'scaffale_{k}_{y:.0f}', 'scaffale_magazzino', (x + 0.9, y, 0), tuple(ds * ks), rot_z=R_(rz))
    for k, (x, y, rz, s) in enumerate(((2.2, 2.0, 20, 1.6), (5.0, 3.9, -40, 1.9), (7.6, 2.4, 70, 1.4), (4.0, 1.6, 120, 1.2))):
        if HQ.disponibile('gonfiabili_mucchio'):
            dg = HQ.dimensioni('gonfiabili_mucchio'); kg = s / max(dg.x, dg.y)
            HQ.metti(f'mucchio_{k}', 'gonfiabili_mucchio', (x, y, 0), tuple(dg * kg), rot_z=R_(rz))
    # serranda mezza alzata sul lato est: sotto filtra la luce rossa della sala grande
    for k in range(22):
        z = 1.05 + k * 0.07
        box(f'serranda_{k}', (X1 + 0.05, 3.0, z), (0.04, 2.5, 0.06), M['ferro'], uv=0.6)
    box('serranda_cassone', (X1 + 0.05, 3.0, 2.75), (0.3, 2.7, 0.3), M['ferro'], uv=1.0)
    luce('LUCE_rossa_oltre', 'AREA', (X1 + 1.2, 3.0, 0.5), 400, (1.0, 0.1, 0.05), size=2.0, mira=(X1 - 3, 3.0, 0.0))
    tubo_flange('tubo_soffitto', [(X0, 3.0, 3.1), (X1, 3.0, 3.1)], 0.1, M)
    lampada_rossa('b1', (X0 + 0.02, 1.4, 2.4), (1, 0, 0))
    lampada_rossa('b2', (6.6, Y1 - 0.02, 2.6), (0, -1, 0))
    volume('nebbia', (5, 3, 1.7), (10, 6, 3.4), 0.025, (0.85, 0.85, 0.88), 0.3)
    scatta('b_magazzino_entrata', (0.7, 3.0, 1.62), (9.0, 2.8, 1.1), 18)


cosa = [a for a in ARGS if a in ('a', 'b')] or ['a', 'b']
if 'a' in cosa:
    caldaie()
if 'b' in cosa:
    magazzino()
