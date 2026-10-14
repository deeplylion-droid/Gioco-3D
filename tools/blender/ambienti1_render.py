"""Render Cycles degli ambienti interni dal punto di vista del giocatore (occhi a 1,62 m).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/ambienti1_render.py [inquadratura ...] [--prova]
--prova: 25% della risoluzione e pochi campioni, per controllare le inquadrature.
Uscita: docs/report/render_ambienti1/<inquadratura>.jpg"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import ambienti1_lib as L

OCCHI = 1.62
INQ = {
    # nome: (posizione camera, punto guardato, lente mm)
    'corridoio_risveglio': ((21.2, 1.35, OCCHI), (9.0, 1.05, 1.25), 18),
    'corridoio_cartellone': ((16.9, 2.15, OCCHI), (14.4, 0.0, 1.35), 20),
    'corridoio_porta_pompe': ((20.2, 1.7, OCCHI), (15.8, 0.0, 1.15), 20),
    'spogliatoi': ((6.8, 3.25, OCCHI), (6.3, 12.0, 1.15), 18),
    'spogliatoi_docce': ((5.6, 10.4, OCCHI), (5.6, 14.6, 1.45), 18),
    'spogliatoi_armadietto': ((9.3, 4.2, OCCHI), (11.0, 5.2, 1.0), 22),
    'lavapiedi_tornello': ((9.7, 11.4, OCCHI), (9.8, 18.0, 1.2), 18),
    'tornello_vetro': ((9.6, 14.8, OCCHI), (11.4, 16.0, 1.45), 22),
    'stanzino': ((11.35, 8.55, OCCHI), (15.2, 8.2, 1.15), 18),
    'stanzino_rastrelliera': ((12.6, 8.9, OCCHI), (15.2, 8.3, 1.15), 24),
    'corridoio_cartellone_vicino': ((14.6, 2.3, 1.55), (14.6, 0.0, 1.4), 26),
    'stanzino_bacheca': ((13.0, 8.4, OCCHI), (12.6, 6.2, 1.35), 22),
}

def prepara():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(L.AI, 'ambienti1.blend'))
    L.usa_collezione('solo_render')
    # nebbia leggera ovunque, piu' densa in basso; vapore nelle docce
    L.nebbia('nebbia_corridoio', (0, 0, 0), (22, 2.6, 2.7), 0.035, (0.85, 0.8, 0.8), bassa=True)
    L.nebbia('nebbia_spogliatoi', (3, 3, 0), (11, 11, 2.9), 0.03, (0.85, 0.82, 0.8), bassa=True)
    L.nebbia('vapore_docce', (3, 11.2, 0), (8.2, 14.6, 2.9), 0.035, (0.9, 0.88, 0.86))
    L.nebbia('nebbia_lavapiedi', (8.6, 11.2, -0.2), (10.8, 20.5, 2.7), 0.04, (0.85, 0.82, 0.8), bassa=True)
    # riempimento freddo debole (in Godot lo fa l'ambiente): ombre verde-petrolio come nei concept
    for nome, c, sx, sy in [('fill_corridoio', (11, 1.3, 2.6), 21, 2.2), ('fill_spogliatoi', (7, 7, 2.8), 7.5, 7.5),
                            ('fill_docce', (5.6, 12.9, 2.8), 5, 3), ('fill_lavapiedi', (9.7, 15.8, 2.6), 2, 9), ('fill_stanzino', (13.2, 8.4, 2.5), 3.6, 4)]:
        L.luce_area(nome, c, (0.35, 0.62, 0.75), 3.0 * sx * sy, sx, sy)
    L.nebbia('nebbia_stanzino', (11.2, 6.2, 0), (15.2, 10.6, 2.6), 0.03, (0.85, 0.82, 0.8), bassa=True)

if __name__ == '__main__':
    prova = '--prova' in sys.argv
    nomi = [a for a in sys.argv[1:] if not a.startswith('--')] or list(INQ)
    prepara()
    L.imposta_render(campioni=16 if prova else 112)
    if prova:
        bpy.context.scene.render.resolution_percentage = 40
    out = os.path.join(L.ROOT, 'docs/report/render_ambienti1' + ('/prove' if prova else ''))
    os.makedirs(out, exist_ok=True)
    for n in nomi:
        loc, guarda, lente = INQ[n]
        cam = L.camera('cam_' + n, loc, guarda, lente)
        L.render(cam, os.path.join(out, n + '.jpg'))
        print('render', n, flush=True)
