"""Vetrina del kit di dettagli: un tratto di parete della sala (piastrelle e pavimento del kit della sala)
con i dettagli messi come andrebbero in gioco. Render Cycles.

Uso: /home/user/tools/blender-venv/bin/python tools/blender/dettagli_vetrina.py [--anteprima]
Legge i GLB di assets_src/ambiente_dettagli/glb/. Render in docs/report/render_ambienti2/dettagli_vetrina*.jpg
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Euler
from ambienti2_comune import *

ARGS = argomenti()
DET = os.path.join(RADICE, 'assets_src', 'ambiente_dettagli')
KT = os.path.join(RADICE, 'assets_src', 'ambiente', 'textures')
reset()

# ------------------------------------------------------------------ importa i nodi
for f in sorted(os.listdir(os.path.join(DET, 'glb'))):
    bpy.ops.import_scene.gltf(filepath=os.path.join(DET, 'glb', f))
KIT = {o.name: o for o in bpy.data.objects if o.name.startswith('det_')}
for o in KIT.values():
    o.hide_render = True
usati = {}


def metti(nome, loc, rz=0.0, rx=0.0, ry=0.0, s=1.0):
    """Copia del dettaglio `nome` in loc (Blender), ruotata (gradi)."""
    src = KIT[nome]
    o = src.copy(); o.data = src.data
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = False
    o.matrix_basis = Matrix.Translation(loc) @ Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix().to_4x4() @ Matrix.Scale(s, 4)
    usati[nome] = usati.get(nome, 0) + 1
    return o


# ------------------------------------------------------------------ set: parete lunga 14 m, pavimento, soffitto della galleria
def kitmat(nome, col, cc):
    return mat_pbr(nome, color=os.path.join(KT, 'derivate', 'sala_a', col), normal=os.path.join(KT, 'cc0', cc, f'{cc}_nrm.jpg'),
                   orm=os.path.join(KT, 'cc0', cc, f'{cc}_orm.jpg'))


parete = kitmat('M_amb_parete', 'parete_col.jpg', 'piastrelle_bianche')
pav = mat_pbr('M_amb_pavimento', color=os.path.join(KT, 'derivate', 'sala_a', 'pavimento_col.jpg'),
              normal=os.path.join(KT, 'cc0', 'antiscivolo', 'antiscivolo_nrm.jpg'), orm=os.path.join(KT, 'derivate', 'sala_a', 'pavimento_orm.jpg'))
intonaco = kitmat('M_amb_intonaco', 'intonaco_col.jpg', 'intonaco_scrostato')
zoccolo = kitmat('M_amb_zoccolo', 'zoccolo_col.jpg', 'piastrelle_bianche')
box('pavimento', (4, -4, -0.1), (12, 9, 0.2), pav, uv=1.5)
box('parete_bassa', (4, 0.15, 1.0), (12, 0.3, 2.0), parete, uv=1.5)
box('parete_zoccolo', (4, 0.0, 0.125), (12, 0.04, 0.25), zoccolo, uv=1.5)
box('parete_alta', (4, 0.15, 3.0), (12, 0.3, 2.0), intonaco, uv=2.0)
box('galleria', (4, -1.5, 4.15), (12, 3.3, 0.3), intonaco, uv=2.0)
met = kitmat('M_amb_metallo', 'metallo_col.jpg', 'metallo_verniciato')
box('galleria_bordo', (4, -3.15, 4.05), (12, 0.12, 0.5), met, uv=1.0)
for x in (-0.6, 8.6):
    box(f'colonna{x}', (x, -2.9, 2.0), (0.4, 0.4, 4.0), met, uv=1.0)
box('parete_fianco', (-2.0, -3, 2.5), (0.3, 8, 5), intonaco, uv=2.0)

# ------------------------------------------------------------------ a parete (y = 0, fronte verso -Y)
W = 0.0
metti('det_condotta_aria_4m', (-1.8, W, 3.65))
metti('det_condotta_aria_curva', (2.2, W, 3.65))
metti('det_tubi_paralleli_2m', (3.0, W, 3.0))
metti('det_tubo_muro_16cm_2m', (5.0, W, 3.45))
metti('det_tubo_muro_7cm_2m', (5.0, W, 3.05))
metti('det_tubo_verticale_3m', (7.1, W, 0.0))
metti('det_tubo_valvola_T', (5.6, W, 1.25))
metti('det_macchia_ruggine_colata_muro', (6.2, W, 1.12))
metti('det_macchia_ruggine_colata_muro', (3.6, W, 2.82))
metti('det_quadro_elettrico', (0.9, W, 1.45))
metti('det_cassetta_aperta', (2.45, W, 1.65))
metti('det_cassetta_piccola', (3.3, W, 2.15))
metti('det_interruttore_stagno', (4.0, W, 1.25))
metti('det_bocchetta_rettangolare', (4.6, W, 2.45))
metti('det_bocchetta_rettangolare_rotta', (2.9, W, 0.45))
metti('det_cartello_non_correre', (4.7, W, 1.75))
metti('det_cartello_pavimento_bagnato_penzolante', (3.4, W, 1.6))
metti('det_cartello_uscita', (7.7, W, 1.85))
metti('det_applique_emergenza', (6.4, W, 2.6))
metti('det_applique_emergenza_rotta', (-0.6, W, 2.7))
metti('det_faro', (7.6, W, 3.4))
metti('det_macchia_calcare_muro', (1.9, W, 0.45))
metti('det_macchia_muffa_muro', (6.6, W, 0.6))
metti('det_incrostazione_spigolo_1', (0.0, W, 0.02))
metti('det_incrostazione_spigolo_2', (5.2, W, 0.02))

# ------------------------------------------------------------------ dal soffitto della galleria (z = 4)
C = 4.0
metti('det_neon_soffitto', (1.2, -1.3, C))
metti('det_neon_penzolante', (5.0, -1.6, C))
metti('det_neon_senza_diffusore', (7.6, -1.0, C), rz=90)
metti('det_cavo_pendente_1', (2.6, -0.7, C))
metti('det_cavo_pendente_3', (3.6, -2.1, C))
metti('det_cavo_pendente_4', (6.5, -1.9, C))
metti('det_fascio_cavi_4m', (0.3, -0.35, C))
metti('det_cavo_festone_2', (4.2, -2.7, C))
metti('det_catena_pendente_2m', (0.2, -2.4, C))
metti('det_gancio', (0.2, -2.38, C - 1.95))
metti('det_corda_pendente_2', (-1.2, -1.6, C))
metti('det_corda_galleggianti_4m', (-0.6, -3.05, 3.3))

# ------------------------------------------------------------------ per terra
metti('det_mucchio_piastrelle_1', (1.6, -0.45, 0), rz=20)
metti('det_mucchio_piastrelle_3', (6.5, -0.5, 0), rz=-40)
metti('det_piastrella_rotta_4', (2.4, -1.3, 0), rz=33)
metti('det_piastrella_rotta_1', (3.0, -1.7, 0), rz=-12)
metti('det_vetri_rotti_1', (7.4, -1.1, 0))
metti('det_vetri_rotti_2', (-0.4, -0.7, 0), rz=90)
metti('det_foglio_1', (3.5, -1.8, 0), rz=25)
metti('det_foglio_2', (3.8, -1.45, 0), rz=-60)
metti('det_foglio_3', (5.6, -2.6, 0), rz=10)
metti('det_carta_accartocciata_1', (4.4, -0.9, 0))
metti('det_carta_accartocciata_2', (1.2, -2.0, 0))
metti('det_asciugamano_1', (4.3, -2.5, 0), rz=15)
metti('det_asciugamano_3', (7.0, -2.6, 0), rz=-30)
metti('det_ciabatta', (5.2, -1.5, 0), rz=40)
metti('det_ciabatta', (5.5, -1.2, 0), rz=-110)
metti('det_paperella', (2.7, -2.7, 0), rz=-30)
metti('det_secchiello', (6.0, -1.9, 0), rz=10)
metti('det_paletta', (6.3, -1.6, 0), rz=60)
metti('det_barchetta', (0.8, -3.0, 0), rz=-20)
metti('det_pistola_acqua', (2.0, -3.3, 0), rz=120)
metti('det_pesce_gomma', (6.6, -3.2, 0), rz=200)
metti('det_maschera_sub', (7.8, -1.9, 0), rz=-70)
metti('det_alghe_secche_mucchio_1', (7.6, -0.6, 0))
metti('det_alghe_secche_mucchio_2', (0.3, -1.0, 0), rz=60)
metti('det_macchia_alghe_verdi_pavimento', (7.2, -0.9, 0), rz=30)
metti('det_macchia_calcare_pavimento', (2.0, -0.7, 0))
metti('det_catena_a_terra', (5.0, -0.55, 0))
metti('det_corda_rotolo', (-0.9, -1.6, 0))

# ------------------------------------------------------------------ luci: come in gioco (buio, rosso, neon, faro)
mondo((0.002, 0.0025, 0.004))
luce('l_neon', 'AREA', (1.2, -1.3, C - 0.13), 60, (0.8, 1.0, 0.93), size=1.2)
luce('l_rossa1', 'POINT', (6.4, -0.3, 2.6), 25, (1.0, 0.05, 0.02), raggio=0.08)
luce('l_faro', 'SPOT', (7.6, -0.45, 3.35), 300, (1.0, 0.78, 0.5), spot=75, mira=(6.0, -2.5, 0), raggio=0.1)
luce('l_ambiente', 'AREA', (4, -8, 3.0), 8, (0.45, 0.55, 0.85), size=6, mira=(4, 0, 1.5))
luce('l_rossa2', 'POINT', (-1.5, -3.5, 3.0), 50, (1.0, 0.06, 0.03), raggio=0.1)
volume('nebbia', (4, -4, 2), (14, 10, 4.4), 0.015, (0.85, 0.88, 0.92), 0.4)

ant = '--anteprima' in ARGS
imposta_render(campioni=16 if ant else 192, w=800 if ant else 1600, h=450 if ant else 900, esposizione=-0.3)
camera((3.4, -6.4, 1.7), (3.4, 0, 1.95), lente=18, nome='cam_vetrina')
renderizza('dettagli_vetrina' + ('_anteprima' if ant else '') + '.jpg')
camera((3.0, -3.6, 0.85), (4.6, -0.8, 0.2), lente=22, nome='cam_pavimento')
renderizza('dettagli_vetrina_pavimento' + ('_anteprima' if ant else '') + '.jpg')
camera((3.0, -3.4, 1.55), (2.2, 0, 2.2), lente=22, nome='cam_muro')
renderizza('dettagli_vetrina_muro' + ('_anteprima' if ant else '') + '.jpg')
mancanti = [n for n in KIT if n not in usati]
print('usati', len(usati), 'non messi in vetrina:', mancanti)
