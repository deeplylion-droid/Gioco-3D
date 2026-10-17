"""Proposte di arredamento della strada di risalita (tappa 7 B, punto 12 della prova v0.3.1): solo proposte.
Esporta soltanto gli oggetti aggiunti, in glTF a parte, nelle stesse coordinate del raccordo (raccordo.gltf non cambia):
  A "deposito della festa": la roba della piscina messa via (lettini, ombrelloni, la testa della mascotte, tubi
    galleggianti, asciugamani, un coccodrillo sgonfio) e festoni di bandierine sbiadite nella tromba delle scale;
  B "manutenzione": prodotti e attrezzi dell'acquapark (fusti di cloro, sacchi di sale, transpallet, carrello degli
    attrezzi), frecce gialle dipinte a terra e nastro bianco e rosso sul corrimano.
In tutte e due: cartelli verdi d'uscita accesi alle svolte e un corrimano sulla scala del corridoio C2, così resta
chiaro dove andare. Modelli Meshy in assets_src/tappa7_arredo/ (genera_arredo.py).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/tappa7_arredo.py [A|B ...]
Uscita: godot/assets/ambienti_tecnici/proposte_tappa7/arredo_<A|B>.gltf"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import ambienti2_comune as C
import ambienti1_hq as HQ

HQ.LINK[0] = C._link
HQ.CARTELLE.append(os.path.join(C.RADICE, 'assets_src', 'tappa7_arredo'))
USCITA = os.path.join(C.RADICE, 'godot', 'assets', 'ambienti_tecnici', 'proposte_tappa7')
R_ = math.radians

# misure del raccordo (vedi ambienti2_raccordo.py)
XR, YD = 46.6, -1.4
X_S0, X_S1 = 50.6, 52.6
Y_R0, Y_R1 = -2.4, -0.4
Y_T0, Y_T1 = 6.5, 9.1
X_T0 = 43.44
Z_L1, Z_T = 3.625, 7.25
XC0, XC1 = 43.6, 45.5
Y_SCALA2, N2, ALZ2, PED2 = 3.2, 10, 0.18, 0.28
Z_SALA = 9.05
YC3_0, YC3_1 = -16.0, -14.0
XM0, XM1 = 18.84, 28.84
YM0, YM1 = -18.0, -12.0


def reset():
    C.reset()
    HQ._base.clear(); HQ._dim.clear()


def metti(nome, file, pos, alto=None, largo=None, rz=0.0, obs=None):
    """Un oggetto Meshy alto 'alto' (o largo 'largo') con la base in pos, girato di rz gradi."""
    d = HQ.dimensioni(file)
    dim = (largo, None, None) if largo else (None, None, alto)
    o = HQ.metti(nome, file, pos, dim, rot_z=R_(rz))
    if obs is not None:
        obs.append(o)
    return o


def cartello(nome, pos, normale, obs, freccia_a_destra=True):
    """Cartello verde d'uscita acceso, appeso al muro con la faccia lungo 'normale'. La freccia del modello va verso
    destra guardandolo: con freccia_a_destra=False lo si specchia."""
    verde = lambda c, nrm: c[1] > 0.35 and c[1] > c[0] * 1.3 and c[1] > c[2] * 1.1
    HQ.dividi('cartello_uscita', 'cartello_uscita_luce', verde, (0.3, 1.0, 0.45), 2.5)
    n = Vector(normale).normalized()
    Rm = (-n).to_track_quat('Y', 'Z').to_matrix().to_4x4()   # il fronte del modello (-Y) verso la stanza
    S = Matrix.Diagonal((1 if freccia_a_destra else -1, 1, 1, 1))
    for parte, nm in ((None, nome), ('cartello_uscita_luce', nome + '_luce')):
        o = HQ.metti(nm, 'cartello_uscita', (0, 0, 0), (0.45, None, None), parte=parte)
        o.matrix_world = Matrix.Translation(Vector(pos)) @ Rm @ S @ o.matrix_world
        obs.append(o)
    # la luce verde che fa il cartello la mettono le scene di prova (OmniLight piccole): quelle del glTF in Godot
    # escono fortissime


def corrimano_c2(obs, mat):
    """Corrimano sul muro ovest della scala di C2 (sale verso -Y), con le staffe."""
    x = XC0 + 0.07
    a = (x, Y_SCALA2 + 0.6, Z_T + 0.95)
    b = (x, Y_SCALA2 - N2 * PED2, Z_SALA + 0.95)
    c = (x, Y_SCALA2 - N2 * PED2 - 0.6, Z_SALA + 0.95)
    obs.append(C.tubo('c2_corrimano', [a, (x, Y_SCALA2, Z_T + 0.95), b, c], 0.025, mat, rc=0.15, seg=12, uv=None))
    for k in range(4):
        y = Y_SCALA2 - k * N2 * PED2 / 3
        z = Z_T + 0.95 + (Y_SCALA2 - y) / PED2 * ALZ2
        obs.append(C.cilindro(f'c2_corrimano_staffa{k}', (XC0 + 0.035, y, z), 0.012, 0.07, mat, asse=(1, 0, 0), seg=8, uv=None))


def festone(nome, a, b, n, obs, pendenza=0.35, seme=1):
    """Fila di bandierine triangolari sbiadite su un filo che pende tra a e b (festa finita da anni)."""
    rnd = random.Random(seme)
    colori = [(0.75, 0.2, 0.15), (0.95, 0.75, 0.15), (0.1, 0.55, 0.6), (0.9, 0.45, 0.6), (0.25, 0.6, 0.25)]
    mats = [C.mat_pbr(f'bandierina_{k}', base=tuple(0.55 * v + 0.2 for v in c), roughness=0.9) for k, c in enumerate(colori)]
    a, b = Vector(a), Vector(b)
    pts = []
    for k in range(n + 1):
        u = k / n
        p = a.lerp(b, u); p.z -= pendenza * 4 * u * (1 - u)
        pts.append(p)
    obs.append(C.tubo(nome + '_filo', pts, 0.004, mats[0], rc=0.01, seg=6, uv=None))
    for k in range(n):
        if rnd.random() < 0.12:
            continue   # qualcuna è caduta
        p0, p1 = pts[k], pts[k + 1]
        m = (p0 + p1) / 2
        punta = m + Vector((0, 0, -0.22)) + Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), 0))
        import bmesh
        bm = bmesh.new()
        vs = [bm.verts.new(p0.lerp(m, 0.15)), bm.verts.new(p1.lerp(m, 0.15)), bm.verts.new(punta)]
        bm.faces.new(vs)
        ob = C._ob_da_bm(f'{nome}_{k}', bm, mats[k % len(mats)])
        ob.modifiers.new('spessore', 'SOLIDIFY').thickness = 0.004
        obs.append(ob)


def freccia_terra(nome, pos, direzione, obs, mat):
    """Freccia gialla dipinta sul pavimento, nella direzione di marcia."""
    import bmesh
    d = Vector(direzione).normalized(); l = Vector((-d.y, d.x, 0))
    p = Vector(pos) + Vector((0, 0, 0.004))
    forma = [(-0.35, 0.08), (0.05, 0.08), (0.05, 0.22), (0.35, 0.0), (0.05, -0.22), (0.05, -0.08), (-0.35, -0.08)]
    bm = bmesh.new()
    vs = [bm.verts.new(p + d * u + l * v) for u, v in forma]
    bm.faces.new(vs)
    obs.append(C._ob_da_bm(nome, bm, mat))


def proposta_A():
    reset()
    obs = []
    # corridoio R1, appena fuori dalla porta col maniglione: il carrello degli asciugamani contro il muro sud
    metti('A_carrello_asciugamani', 'carrello_asciugamani', (49.2, Y_R0 + 0.45, 0), alto=1.0, rz=0, obs=obs)
    metti('A_cassa_tubi_r1', 'cassa_tubi', (50.05, Y_R1 - 0.42, 0), alto=0.95, rz=-12, obs=obs)
    # pianerottolo L1 (tra le due rampe): lettini impilati contro il muro est, un coccodrillo sgonfio nell'angolo
    # (fuori dalla strada: si arriva da F1 in x 51,6 e si gira verso F2 in y 7,8)
    metti('A_lettini', 'lettini_impilati', (52.1, 5.75, Z_L1), largo=0.95, rz=90, obs=obs)
    metti('A_coccodrillo_l1', 'coccodrillo_sgonfio', (52.0, 8.55, Z_L1), largo=1.3, rz=170, obs=obs)
    # pianerottolo T, davanti alla grata chiusa: gli ombrelloni chiusi
    metti('A_ombrelloni', 'ombrelloni_chiusi', (43.95, 8.65, Z_T), alto=2.1, rz=20, obs=obs)
    # corridoio C2: la testa della mascotte delfino contro il muro, che guarda chi passa; tubi galleggianti
    metti('A_testa_mascotte', 'testa_mascotte', (43.98, -6.5, Z_SALA), alto=0.85, rz=-90, obs=obs)
    metti('A_cassa_tubi_c2', 'cassa_tubi', (45.1, -10.8, Z_SALA), alto=0.95, rz=8, obs=obs)
    # corridoio C3 e magazzino
    metti('A_coccodrillo_c3', 'coccodrillo_sgonfio', (39.0, -15.2, Z_SALA), largo=1.6, rz=-15, obs=obs)
    metti('A_lettini_mag', 'lettini_impilati', (23.7, -13.15, Z_SALA), largo=1.0, rz=0, obs=obs)
    metti('A_carrello_mag', 'carrello_asciugamani', (21.4, -16.0, Z_SALA), alto=1.0, rz=160, obs=obs)
    # festoni di bandierine sbiadite nella tromba delle scale e nel magazzino
    festone('A_festone_s1', (X_S0 + 0.1, 0.3, 3.3), (X_S1 - 0.1, 4.2, 5.0), 16, obs, seme=1)
    festone('A_festone_s2', (X_S1 - 0.1, 6.8, 6.6), (X_S0 - 3.0, 8.8, 9.2), 16, obs, seme=2)
    festone('A_festone_c2', (XC0 + 0.05, 1.5, Z_SALA + 2.6), (XC1 - 0.05, -2.0, Z_SALA + 2.6), 10, obs, seme=3)
    festone('A_festone_mag', (XM1 - 0.5, YM0 + 0.4, Z_SALA + 3.1), (XM0 + 1.0, YM1 - 0.4, Z_SALA + 3.1), 22, obs, pendenza=0.6, seme=4)
    comuni(obs, C.mat_pbr('corrimano_A', base=(0.85, 0.65, 0.12), roughness=0.5, metallic=0.5))
    return obs


def proposta_B():
    reset()
    obs = []
    giallo = C.mat_pbr('vernice_frecce', base=(0.85, 0.65, 0.05), roughness=0.7)
    # corridoio R1: fusti di cloro e il carrello degli attrezzi
    metti('B_fusti_r1', 'fusti_cloro', (49.6, Y_R0 + 0.5, 0), alto=0.9, rz=10, obs=obs)
    metti('B_carrello_attrezzi', 'carrello_attrezzi', (47.5, Y_R1 - 0.4, 0), alto=1.3, rz=180, obs=obs)
    # pianerottolo L1: bancale di sacchi di sale nell'angolo
    metti('B_sacchi_l1', 'sacchi_sale', (52.05, 5.75, Z_L1), largo=1.0, rz=90, obs=obs)
    # pianerottolo T: il transpallet lasciato davanti alla grata
    metti('B_transpallet', 'transpallet', (44.1, 8.55, Z_T), largo=1.5, rz=-70, obs=obs)
    # corridoio C2: altri fusti e il carrello lungo i muri
    metti('B_fusti_c2', 'fusti_cloro', (45.05, -6.8, Z_SALA), alto=0.9, rz=-30, obs=obs)
    metti('B_carrello_c2', 'carrello_attrezzi', (44.0, -11.5, Z_SALA), alto=1.3, rz=90, obs=obs)
    # magazzino: sacchi e fusti tra gli scaffali
    metti('B_sacchi_mag', 'sacchi_sale', (23.7, -13.2, Z_SALA), largo=1.1, rz=5, obs=obs)
    metti('B_fusti_mag', 'fusti_cloro', (21.2, -16.2, Z_SALA), alto=0.9, rz=40, obs=obs)
    # frecce gialle dipinte a terra lungo la strada
    for k, (p, d) in enumerate((((48.0, YD, 0), (1, 0, 0)), ((51.6, -1.2, 0), (0, 1, 0)), ((51.6, 7.8, Z_L1), (-1, 0, 0)),
                                ((44.55, 6.0, Z_T), (0, -1, 0)), ((44.55, -3.0, Z_SALA), (0, -1, 0)), ((44.55, -13.0, Z_SALA), (0, -1, 0)),
                                ((42.0, -15.0, Z_SALA), (-1, 0, 0)), ((33.0, -15.0, Z_SALA), (-1, 0, 0)), ((24.0, -15.0, Z_SALA), (-1, 0, 0)))):
        freccia_terra(f'B_freccia_{k}', p, d, obs, giallo)
    # nastro bianco e rosso sul corrimano della rampa F1
    nastro = C.mat_pbr('nastro_bianco_rosso', base=(0.8, 0.12, 0.08), roughness=0.6)
    obs.append(C.tubo('B_nastro_f1', [(X_S1 - 0.12, -0.6, 1.0), (X_S1 - 0.12, 4.4, 4.55)], 0.03, nastro, seg=8, uv=None))
    comuni(obs, C.mat_pbr('corrimano_B', base=(0.85, 0.65, 0.12), roughness=0.5, metallic=0.5))
    return obs


def comuni(obs, mat_corrimano):
    """Dove andare, in tutte e due: cartelli d'uscita accesi alle svolte e il corrimano sulla scala di C2."""
    cartello('uscita_r1', (X_S0 - 0.02, YD, 2.35), (-1, 0, 0), obs)                 # in fondo a R1: si gira a sinistra (+Y)
    cartello('uscita_l1', (X_S1 - 0.02, 7.8, Z_L1 + 2.35), (-1, 0, 0), obs)          # sul pianerottolo: su per F2
    cartello('uscita_t', (XC1 - 0.02, 4.8, Z_T + 2.2), (-1, 0, 0), obs)              # in cima: giù per il corridoio C2
    cartello('uscita_c3', (XC0 + 0.02, YC3_1 + 0.6, Z_SALA + 2.25), (1, 0, 0), obs)  # in fondo a C2: a destra in C3
    cartello('uscita_mag', (XM0 + 0.32, -13.6, Z_SALA + 2.5), (1, 0, 0), obs)        # sopra la serranda
    corrimano_c2(obs, mat_corrimano)


def esporta(nome, obs):
    os.makedirs(USCITA, exist_ok=True)
    for im in bpy.data.images:
        lim = 2048 if im.colorspace_settings.name != 'Non-Color' else 1024
        if im.size[0] > lim:
            im.scale(lim, lim)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    p = os.path.join(USCITA, f'arredo_{nome}.gltf')
    bpy.ops.export_scene.gltf(filepath=p, export_format='GLTF_SEPARATE', export_texture_dir='texture', use_selection=True,
                              export_apply=True, export_lights=False, export_cameras=False, export_yup=True,
                              export_image_format='JPEG', export_jpeg_quality=88)
    print('esportato', p, len(obs), 'oggetti', flush=True)


if __name__ == '__main__':
    scelte = [a for a in C.argomenti() if a in ('A', 'B')] or ['A', 'B']
    for s in scelte:
        esporta(s, proposta_A() if s == 'A' else proposta_B())
