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
import posa as Posa   # (il modulo comune: qui "posa" è già una funzione)

HQ.LINK[0] = C._link
for _c in (('tappa7_arredo',), ('sala_angoli',), ('ambienti_interni', 'meshy')):
    HQ.CARTELLE.append(os.path.join(C.RADICE, 'assets_src', *_c))
USCITA = os.path.join(C.RADICE, 'godot', 'assets', 'ambienti_tecnici', 'proposte_tappa7')
R_ = math.radians

# misure del raccordo (vedi ambienti2_raccordo.py)
XR, YD = 46.6, -1.4
X_S0, X_S1 = 50.6, 52.6
Y_R0, Y_R1 = -2.4, -0.4
Y_T0, Y_T1 = 6.5, 9.1
X_T0 = 43.44
X_F2 = X_T0 + 2.16
Z_L1, Z_T = 3.625, 7.25
XC0, XC1 = 43.6, 45.5
Y_SCALA2, N2, ALZ2, PED2 = 3.2, 10, 0.18, 0.28
Z_SALA = 9.05
YC3_0, YC3_1 = -16.0, -14.0
BUCO_Y = -4.9                       # la grata sfondata nel muro sud di C2 (ambienti2_raccordo.py: BY)
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


def _al_muro(objs, punto, n):
    """Porta il retro vero di objs (il loro vertice più indietro, contro n) a 1 mm dal muro che passa per punto con
    normale n (fuori dal muro), tutti insieme: qui il muro del raccordo non c'è, se ne conosce il piano. Prima la
    roba appesa stava col box a 5 mm dal muro e il modello vero a volte di più (controllo del 22 ottobre sera)."""
    n = Vector(n).normalized()
    retro = min(v.dot(n) for o in objs for v in Posa._punti_mondo(o))
    d = n * (Vector(punto).dot(n) + 0.001 - retro)
    for o in objs:
        o.matrix_world.translation += d
    bpy.context.view_layer.update()


def cartello(nome, pos, normale, obs, freccia_a_destra=True):
    """Cartello verde d'uscita acceso, appeso al muro con la faccia lungo 'normale'. La freccia del modello va verso
    destra guardandolo: con freccia_a_destra=False lo si specchia."""
    verde = lambda c, nrm: c[1] > 0.35 and c[1] > c[0] * 1.3 and c[1] > c[2] * 1.1
    HQ.dividi('cartello_uscita', 'cartello_uscita_luce', verde, (0.3, 1.0, 0.45), 2.5)
    n = Vector(normale).normalized()
    Rm = (-n).to_track_quat('Y', 'Z').to_matrix().to_4x4()   # il fronte del modello (-Y) verso la stanza
    S = Matrix.Diagonal((1 if freccia_a_destra else -1, 1, 1, 1))
    pezzi = []
    for parte, nm in ((None, nome), ('cartello_uscita_luce', nome + '_luce')):
        o = HQ.metti(nm, 'cartello_uscita', (0, 0, 0), (0.45, None, None), parte=parte)
        o.matrix_world = Matrix.Translation(Vector(pos)) @ Rm @ S @ o.matrix_world
        obs.append(o)
        pezzi.append(o)
    _al_muro(pezzi, Vector(pos) - n * 0.02, n)   # (il muro è 2 cm dietro pos)
    # la luce verde che fa il cartello la mettono le scene di prova (OmniLight piccole): quelle del glTF in Godot
    # escono fortissime


def corrimano_c2(obs, mat):
    """Corrimano sul muro ovest della scala di C2 (sale verso -Y), con le staffe."""
    x = XC0 + 0.07
    a = (x, Y_SCALA2 + 0.6, Z_T + 0.95)
    b = (x, Y_SCALA2 - N2 * PED2, Z_SALA + 0.95)
    c = (x, Y_SCALA2 - N2 * PED2 - 0.6, Z_SALA + 0.95)
    punti = [a, (x, Y_SCALA2, Z_T + 0.95), b, c]
    r = 0.025
    obs.append(C.tubo('c2_corrimano', punti, r, mat, rc=0.15, seg=12, uv=None))
    # le staffe dal muro fino al corrimano: finiscono 1 mm dentro la sua faccia verso il muro, all'altezza del suo asse vero
    # (raccordato alle svolte come in C.tubo). Prima arrivavano al suo asse, dentro il tubo: le due di mezzo restavano
    # 1,2 cm sotto la sua faccia (collaudo del raccordo del 22 ottobre sera)
    asse = C._arrotonda(punti, 0.15)
    lungo = x - r + 0.001 - XC0
    for k in range(4):
        y = Y_SCALA2 - k * N2 * PED2 / 3
        z = _quota_asse(asse, y)
        obs.append(C.cilindro(f'c2_corrimano_staffa{k}', (XC0 + lungo / 2, y, z), 0.012, lungo, mat, asse=(1, 0, 0), seg=8, uv=None))


def _quota_asse(asse, y):
    """La quota dell'asse di un tubo (punti di C._arrotonda) dove passa per y."""
    for p, q in zip(asse, asse[1:]):
        if min(p.y, q.y) - 1e-6 <= y <= max(p.y, q.y) + 1e-6 and abs(q.y - p.y) > 1e-9:
            return p.z + (q.z - p.z) * (y - p.y) / (q.y - p.y)
    raise ValueError('y fuori dal tubo: %.3f' % y)


def festone(nome, a, b, n, obs, pendenza=0.35, seme=1, ma=None, mb=None):
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
    # i due capi sono sulla faccia del muro (normale ma, mb verso la stanza): una piastrina col gancio
    # (prima finivano a 5-40 cm dal muro, nel vuoto)
    for k, (q, nm) in enumerate(((a, ma), (b, mb))):
        if nm is None:
            continue
        nm = Vector((nm[0], nm[1], 0)).normalized()
        obs.append(C.box(f'{nome}_gancio{k}', q + nm * 0.005, (0.01 + abs(nm.y) * 0.04, 0.01 + abs(nm.x) * 0.04, 0.04), _acciaio(), uv=None))
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
    # in fondo a R1, sul muro est del vano scala (x 52,6): si gira a sinistra (+Y). Prima era a x 50,6, dove R1 si apre
    # sul vano scala e non c'è muro: restava appeso nel vuoto
    cartello('uscita_r1', (X_S1 - 0.02, YD, 2.35), (-1, 0, 0), obs)
    cartello('uscita_l1', (X_S1 - 0.02, 7.8, Z_L1 + 2.35), (-1, 0, 0), obs)          # sul pianerottolo: su per F2
    cartello('uscita_t', (XC1 - 0.02, 4.8, Z_T + 2.2), (-1, 0, 0), obs)              # in cima: giù per il corridoio C2
    cartello('uscita_c3', (XC0 + 0.02, YC3_1 + 0.6, Z_SALA + 2.25), (1, 0, 0), obs)  # in fondo a C2: a destra in C3
    cartello('uscita_mag', (XM0 + 0.32, -13.6, Z_SALA + 2.5), (1, 0, 0), obs)        # sopra la serranda
    corrimano_c2(obs, mat_corrimano)



# ---------------------------------------------------------------------------------------------------------------
# Versione piena (16 ottobre: "in A e B resta quasi vuota"): ogni tratto di muro si riempie, sui due lati, con gruppi
# di oggetti appoggiati, cataste e roba appesa; al centro resta sempre una corsia libera di almeno un metro.

def _dim(file, k):
    d = HQ.dimensioni(file)
    return Vector((d.x * k, d.y * k, d.z * k))


def _scala_per(file, alto=None, largo=None, prof_max=None):
    d = HQ.dimensioni(file)
    k = alto / d.z if alto else largo / d.x
    if prof_max and d.y * k > prof_max:
        k = prof_max / d.y
    return k


def posa(nome, file, centro_base, k, rz, obs):
    """Oggetto con scala uniforme k, base al centro in centro_base, girato di rz (radianti)."""
    d = HQ.dimensioni(file)
    o = HQ.metti(nome, file, tuple(centro_base), (d.x * k, d.y * k, d.z * k), rot_z=rz)
    obs.append(o)
    return o


# Le pile contro il muro non superano 1,3 m: più alte e strette non starebbero in piedi. I pezzi di troppo si
# mettono lo stesso e si tolgono alla fine (TROPPO_ALTI): così i numeri a caso, e il resto della strada, non cambiano.
PILA_MAX = 1.3
TROPPO_ALTI = []


def riempi_muro(nome, a, b, n, z, tavolozza, obs, prof_max, rnd, vuoti=(), passo=(0.05, 0.35), zfun=None):
    """Lungo il muro da a a b (faccia del muro, in pianta), con la stanza dalla parte di n: gruppi di oggetti in fila.
    tavolozza: lista di (file, alto, impilabile). vuoti: tratti (u0, u1) in metri da a dove non si mette niente
    (porte, aperture). zfun(p) dà la quota del pavimento (scale); altrimenti z."""
    a, b, n = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0)), Vector((n[0], n[1], 0)).normalized()
    L = (b - a).length; d = (b - a).normalized()
    rz_base = math.atan2(n.x, -n.y)   # il fronte del modello (-Y) verso la stanza
    u = rnd.uniform(0.05, 0.3); k_obj = 0
    ultimi = []
    while u < L - 0.2:
        if any(v0 - 0.1 <= u <= v1 for v0, v1 in vuoti):
            u = max(v1 for v0, v1 in vuoti if v0 - 0.1 <= u <= v1) + 0.1
            continue
        # niente ripetizioni vicine: non lo stesso oggetto di uno degli ultimi due
        file, alto, pila = rnd.choice([t for t in tavolozza if t[0] not in ultimi] or tavolozza)
        ultimi = (ultimi + [file])[-2:]
        alto *= rnd.uniform(0.85, 1.15)
        k = _scala_per(file, alto=alto, prof_max=prof_max)
        dm = _dim(file, k)
        if u + dm.x > L - 0.05:
            u += 0.2
            continue
        if any(u < v1 and u + dm.x > v0 for v0, v1 in vuoti):
            u += 0.2
            continue
        c = a + d * (u + dm.x / 2) + n * (dm.y / 2 + 0.03)
        # sulle scale: alla quota del gradino più alto sotto l'oggetto (meglio un filo sospeso che dentro il gradino)
        zz = max(zfun(c - d * dm.x / 2), zfun(c + d * dm.x / 2), zfun(c)) if zfun else z
        rz = rz_base + rnd.uniform(-0.12, 0.12)
        posa(f'{nome}_{k_obj}', file, (c.x, c.y, zz), k, rz, obs)
        k_obj += 1
        if pila:   # 1-3 piani, ognuno un po' girato e più piccolo di quello sotto
            h = dm.z
            sotto, tolto = file, False
            for piano in range(rnd.choice((0, 1, 1, 2))):
                f2, a2, _ = rnd.choice([t for t in tavolozza if t[2]])
                k2 = _scala_per(f2, alto=a2 * rnd.uniform(0.75, 0.95), prof_max=prof_max * 0.9)
                d2 = _dim(f2, k2)
                if d2.x > dm.x * 1.05:
                    k2 *= dm.x / d2.x; d2 = _dim(f2, k2)
                o2 = posa(f'{nome}_{k_obj}', f2, (c.x, c.y, zz + h + 0.004), k2, rz + rnd.uniform(-0.2, 0.2), obs)
                _appoggia(o2, obs[-2])
                # il pesante sotto: sul cartone solo altro cartone; sopra un pezzo tolto non resta niente
                tolto = tolto or h + d2.z > PILA_MAX or (sotto.startswith('scatolone') and not f2.startswith('scatolone'))
                if tolto:
                    TROPPO_ALTI.append(o2.name)
                sotto = f2
                k_obj += 1
                h += d2.z
        u += dm.x + rnd.uniform(*passo)


def _appoggia(o, sotto):
    """Abbassa (o alza) o finché tocca l'oggetto sotto: raggi verso il basso dai vertici più bassi di o contro le
    facce di sotto (prima i pezzi impilati stavano 4 mm sopra la scatola di quello sotto, cioè sopra il suo punto più
    alto, e spesso non lo toccavano)."""
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    def facce(ob):
        e = ob.evaluated_get(dg)
        m = e.to_mesh()
        vs = [ob.matrix_world @ v.co for v in m.vertices]
        ps = [tuple(p.vertices) for p in m.polygons]
        e.to_mesh_clear()
        return vs, ps
    vs_s, ps_s = facce(sotto)
    albero = BVHTree.FromPolygons(vs_s, ps_s)
    vs_o, _ = facce(o)
    zmin = min(v.z for v in vs_o)
    meglio = None
    for v in vs_o:
        if v.z > zmin + 0.06:
            continue
        hit = albero.ray_cast(v + Vector((0, 0, 0.3)), Vector((0, 0, -1)), 1.0)
        if hit[0] is not None:
            d = v.z - hit[0].z
            meglio = d if meglio is None else min(meglio, d)
    if meglio is not None:
        o.location.z -= meglio
        bpy.context.view_layer.update()


def _scatola(o):
    """Ingombro (min, max) di un oggetto nella scena."""
    vs = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)])


def _tocca(o, altri, margine=0.02):
    lo, hi = _scatola(o)
    for x in altri:
        a, b = _scatola(x)
        if all(lo[i] < b[i] - margine and hi[i] > a[i] + margine for i in range(3)):
            return True
    return False


def appendi_muro(nome, a, b, n, z0, tavolozza, obs, rnd, passo=(0.9, 1.8), vuoti=(), zfun=None):
    """Roba appesa al muro (salvagenti, bacheche, cartelli, rulli col tubo) col centro a quota z0 dal pavimento
    (o dal gradino sotto). A filo del muro, senza rotazioni a caso; i salvagenti su un piolo d'acciaio.
    Dove toccherebbe la roba già messa a terra si salta il posto."""
    a, b, n = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0)), Vector((n[0], n[1], 0)).normalized()
    L = (b - a).length; d = (b - a).normalized()
    rz = math.atan2(n.x, -n.y)
    u = rnd.uniform(0.3, 0.9); k_obj = 0
    ultimo = None
    gia = list(obs)
    while u < L - 0.3:
        if any(v0 <= u <= v1 for v0, v1 in vuoti):
            u += 0.3
            continue
        file, alto = rnd.choice([t for t in tavolozza if t[0] != ultimo] or tavolozza)
        k = _scala_per(file, alto=alto)
        dm = _dim(file, k)
        if u + dm.x / 2 > L - 0.05:
            break
        u = max(u, dm.x / 2 + 0.05)   # niente che sporga oltre l'inizio del muro (le aperture dei corridoi)
        c = a + d * u + n * (dm.y / 2 + 0.005)
        # all'altezza della testa (da 1,2 m) a muro si sporge al massimo 25 cm (regola del coordinatore, 23 ottobre): i
        # rulli col tubo (44 cm) e gli estintori con la staffa (25,1 cm) vanno sotto, con la cima a 1,15 m al più
        z0k = z0 if dm.y <= 0.24 else min(z0, 1.09 - dm.z / 2)
        zz = (zfun(c) if zfun else 0) + z0k - dm.z / 2 + rnd.uniform(-0.06, 0.06)
        o = HQ.metti(f'{nome}_{k_obj}', file, (c.x, c.y, zz), (dm.x, dm.y, dm.z), rot_z=rz)
        if _tocca(o, gia):
            bpy.data.objects.remove(o)
            u += 0.25
            continue
        obs.append(o)
        ultimo = file
        _al_muro([o], c - n * (dm.y / 2 + 0.005), n)
        if file == 'salvagente_anulare':   # piolo nel muro, dentro l'anello in alto
            muro = c - n * (dm.y / 2 + 0.005)
            obs.append(C.box(f'{nome}_{k_obj}_piolo', muro + n * (dm.y * 0.5) + Vector((0, 0, zz + dm.z * 0.8)),
                             (0.025 + abs(n.x) * dm.y * 0.9, 0.025 + abs(n.y) * dm.y * 0.9, 0.025), _acciaio(), uv=None))
            obs.append(C.box(f'{nome}_{k_obj}_piastra', muro + n * 0.006 + Vector((0, 0, zz + dm.z * 0.8)),
                             (0.012 + abs(n.y) * 0.08, 0.012 + abs(n.x) * 0.08, 0.08), _acciaio(), uv=None))
        k_obj += 1
        u += dm.x + rnd.uniform(*passo)


_ACC = []


def _acciaio():
    if not _ACC or _ACC[0].name not in bpy.data.materials:
        _ACC[:] = [C.mat_pbr('piolo_acciaio', base=(0.45, 0.46, 0.47), roughness=0.4, metallic=0.9)]
    return _ACC[0]


def tubi_muro(nome, a, b, n, z, mat, obs, quanti=3, r=0.045, nel_muro_b=False, nel_muro_a=False, vuoti=()):
    """Fascio di tubi lungo il muro, sotto il soffitto, con le staffe. Con nel_muro_b in fondo ogni tubo piega e
    rientra nel muro (dove il muro finisce in un'apertura, o prima di una lampada): prima quello vicino al muro, poi
    gli altri, 15 cm più avanti l'uno dall'altro, così non si incrociano; con nel_muro_a escono dal muro all'inizio,
    allo stesso modo. Tutti i tubi poggiano sulle staffe (prima i due più vicini al muro restavano 3 e 6 cm sopra)."""
    a, b, n = Vector(a), Vector(b), Vector((n[0], n[1], 0)).normalized()
    d = (b - a).normalized()
    L = (b - a).length
    # le staffe ogni 1,6 m, dove ci sono tutti i tubi (non nei tratti dove piegano verso il muro) e dove c'è il muro
    # (vuoti: tratti (u0, u1) da a senza muro dietro, come il vano di una porta)
    staffe = []
    for j in range(int(L / 1.6) + 1):
        u = min(max(j * 1.6 + 0.3, (quanti - 1) * 0.15 + 0.1 if nel_muro_a else 0.0), L - 0.1 - ((quanti - 1) * 0.15 if nel_muro_b else 0.0))
        for v0, v1 in vuoti:
            if v0 - 0.05 <= u <= v1 + 0.05:
                u = v0 - 0.1 if u - v0 < v1 - u else v1 + 0.1
        if not staffe or u - staffe[-1] > 0.3:
            staffe.append(u)
    for k in range(quanti):
        rk = r * (1 - 0.2 * k)
        o = n * (0.09 + k * 0.13)
        h = Vector((0, 0, z - r + rk))
        inizio = a + d * (quanti - 1 - k) * 0.15 if nel_muro_a else a
        fine = b - d * (quanti - 1 - k) * 0.15 if nel_muro_b else b
        # anche un punto sopra ogni staffa, così il tubo ha i vertici dove poggia
        sopra = [a + d * u + o + h for u in staffe if (inizio - a).length < u < (fine - a).length]
        # dove entra nel muro il tubo ha un anello proprio sulla faccia del muro (dritto, perpendicolare): il capo è
        # attaccato lì, poi prosegue 10 cm dentro (prima l'anello più vicino era 10 cm dentro il muro e la curva
        # nell'aria, e il controllo dei capi lo dava nel vuoto)
        pts = ([inizio - n * 0.1 + h, inizio + h] if nel_muro_a else []) + [inizio + o + h] + sopra + [fine + o + h] + \
            ([fine + h, fine - n * 0.1 + h] if nel_muro_b else [])
        obs.append(C.tubo(f'{nome}_{k}', pts, rk, mat, rc=0.12, seg=12, uv=None))
        # dove il tubo passa in una costola del muro (sporge 16 cm): un collare di passaggio su ciascuna faccia della
        # costola, così si legge come il foro di un'ordinata di nave (scelta del coordinatore, 23 ottobre). Spesso 12 mm,
        # 1 mm dentro la costola
        if (0.09 + k * 0.13) - rk < 0.16:
            u_da, u_a = (inizio - a).length, (fine - a).length
            for j, (clo, chi, _ax) in enumerate(costole()):
                centro = (clo + chi) / 2
                if abs((centro - a).dot(n) - 0.08) > 0.02 or not clo.z <= a.z + z <= chi.z:
                    continue   # non è una costola di questo muro
                u0, u1 = sorted((min((Vector((clo.x, clo.y, 0)) - a).dot(d), (Vector((chi.x, chi.y, 0)) - a).dot(d)),
                                 max((Vector((clo.x, clo.y, 0)) - a).dot(d), (Vector((chi.x, chi.y, 0)) - a).dot(d))))
                if u1 < u_da or u0 > u_a:
                    continue
                for faccia, verso in ((u0, -1.0), (u1, 1.0)):
                    c = a + d * (faccia + verso * 0.005) + o + h
                    obs.append(C.cilindro(f'{nome}_{k}_collare{j}{"a" if verso < 0 else "b"}', tuple(c), rk * 1.45, 0.012, mat,
                                          asse=tuple(d), seg=16, uv=None))
    # le staffe reggono i tubi da sotto e vanno dal muro all'ultimo tubo (prima sporgevano oltre, nel vuoto)
    lung = 0.09 + (quanti - 1) * 0.13 + r * (1 - 0.2 * (quanti - 1))
    zs = z - r - 0.015
    for j, u in enumerate(staffe):
        p = a + d * u
        obs.append(C.box(f'{nome}_staffa{j}', p + n * lung / 2 + Vector((0, 0, zs)), (0.04 + abs(n.x) * (lung - 0.04), 0.04 + abs(n.y) * (lung - 0.04), 0.03), mat, uv=None))


def z_f1(p):
    k = int((p.y - Y_R1) / 0.2515)
    return 0.0 if k < 0 else min(k + 1, 20) * 0.18125


def z_f2(p):
    k = int((X_S0 - p.x) / 0.2515)
    return Z_L1 if k < 0 else Z_L1 + min(k + 1, 20) * 0.18125


def z_c2(p):
    if p.y > Y_SCALA2:
        return Z_T
    k = int((Y_SCALA2 - p.y) / PED2)
    return min(Z_T + (k + 1) * ALZ2, Z_SALA)


def percorso_pieno(nome, tav_terra, tav_muro, tav_piccoli, obs, rnd, tubi=None):
    """Riempie tutta la strada con le tre tavolozze: oggetti a terra, roba appesa e roba piccola sui gradini."""
    # R1: muro sud (porta del ponte a ovest: si lascia libero il primo metro) e muro nord
    riempi_muro(f'{nome}_r1s', (XR + 1.0, Y_R0), (X_S0, Y_R0), (0, 1), 0, tav_terra, obs, 0.5, rnd)
    riempi_muro(f'{nome}_r1n', (XR + 1.0, Y_R1), (X_S0 - 0.1, Y_R1), (0, -1), 0, tav_terra, obs, 0.45, rnd)
    appendi_muro(f'{nome}_r1s_m', (XR + 0.5, Y_R0), (X_S0, Y_R0), (0, 1), 1.55, tav_muro, obs, rnd)
    appendi_muro(f'{nome}_r1n_m', (XR + 0.5, Y_R1), (X_S0, Y_R1), (0, -1), 1.55, tav_muro, obs, rnd)
    # scala F1: roba piccola sui gradini contro il muro ovest, roba appesa ai due muri
    riempi_muro(f'{nome}_f1', (X_S0, Y_R1 + 0.3), (X_S0, 4.4), (1, 0), 0, tav_piccoli, obs, 0.4, rnd, passo=(0.3, 0.7), zfun=z_f1)
    appendi_muro(f'{nome}_f1o_m', (X_S0, Y_R1), (X_S0, 4.5), (1, 0), 1.55, tav_muro, obs, rnd, zfun=z_f1)
    appendi_muro(f'{nome}_f1e_m', (X_S1, -2.2), (X_S1, 4.5), (-1, 0), 1.55, tav_muro, obs, rnd, zfun=z_f1)
    # niente roba appesa ai primi due metri del muro est: a un passo dall'ingresso della scala, di scorcio, sembrava storta
    for o in [o for o in obs if o.name.startswith(f'{nome}_f1e_m') and o.location.y < 0.6]:
        obs.remove(o); bpy.data.objects.remove(o)
    # pianerottolo L1: muro est pieno e muro nord (la strada passa in x 50,6..52,0)
    riempi_muro(f'{nome}_l1e', (X_S1, 4.9), (X_S1, Y_T1), (-1, 0), Z_L1, tav_terra, obs, 0.6 if nome != 'G' else 0.45, rnd)
    riempi_muro(f'{nome}_l1n', (X_S1 - 0.6, Y_T1), (X_S0 + 0.2, Y_T1), (0, -1), Z_L1, tav_terra, obs, 0.4, rnd)
    appendi_muro(f'{nome}_l1_m', (X_S1, 4.7), (X_S1, Y_T1), (-1, 0), Z_L1 + 1.55, tav_muro, obs, rnd)
    # rampa F2: roba piccola sui gradini contro il muro nord, appesa ai due muri
    riempi_muro(f'{nome}_f2', (X_S0 - 0.3, Y_T1), (X_F2 + 0.3, Y_T1), (0, -1), 0, tav_piccoli, obs, 0.35, rnd, passo=(0.3, 0.8), zfun=z_f2)
    appendi_muro(f'{nome}_f2s_m', (X_S0, Y_T0), (X_F2, Y_T0), (0, 1), 1.55, tav_muro, obs, rnd, zfun=z_f2)
    appendi_muro(f'{nome}_f2n_m', (X_S0, Y_T1), (X_F2, Y_T1), (0, -1), 1.55, tav_muro, obs, rnd, zfun=z_f2)
    # pianerottolo T: davanti alla grata (muro ovest) e nell'angolo nord
    riempi_muro(f'{nome}_t', (X_T0 + 0.1, Y_T1), (X_T0 + 1.2, Y_T1), (0, -1), Z_T, tav_terra, obs, 0.7, rnd)
    # corridoio C2: tutti e due i lati, sopra e sotto la scala (sulla scala solo roba piccola)
    for lato, x, nn in (('o', XC0, (1, 0)), ('e', XC1, (-1, 0))):
        riempi_muro(f'{nome}_c2{lato}a', (x, Y_T0 - 0.2), (x, Y_SCALA2 + 0.3), nn, Z_T, tav_terra, obs, 0.42, rnd)
        riempi_muro(f'{nome}_c2{lato}s', (x, Y_SCALA2), (x, Y_SCALA2 - N2 * PED2), nn, 0, tav_piccoli, obs, 0.3, rnd, passo=(0.3, 0.6), zfun=z_c2)
        riempi_muro(f'{nome}_c2{lato}b', (x, -0.2), (x, YC3_1 - 0.1), nn, Z_SALA, tav_terra, obs, 0.42, rnd,
                    vuoti=((8.8, 10.4),) if lato == 'o' and nome == 'A' else ())   # lì la testa della mascotte (A)
        appendi_muro(f'{nome}_c2{lato}_m', (x, Y_T0), (x, YC3_1), nn, 1.55, tav_muro, obs, rnd, zfun=z_c2, vuoti=((20.4, 22.6),) if lato == 'o' else ())
    # corridoio C3: tutti e due i lati
    for lato, y, nn in (('s', YC3_0, (0, 1)), ('n', YC3_1, (0, -1))):
        # davanti al mucchio di gonfiabili del raccordo (x 36,5) non si mette niente: col mucchio la corsia si chiudeva
        riempi_muro(f'{nome}_c3{lato}', (XC0 - 0.1, y), (XM1 + 0.4, y), nn, Z_SALA, tav_terra, obs, 0.4, rnd,
                    vuoti=((XC0 - 0.1 - 38.2, XC0 - 0.1 - 34.8),))
        # nel muro sud la porta della scala di servizio (x 36,59..37,59): niente appeso nel vano (i vuoti sono per il
        # centro dell'oggetto, larghi mezzo oggetto in più, fino a 45 cm, e 5 cm)
        appendi_muro(f'{nome}_c3{lato}_m', (XC0, y), (XM1 + 0.3, y), nn, 1.55, tav_muro, obs, rnd, zfun=lambda p: Z_SALA,
                     vuoti=((XC0 - 37.59 - 0.5, XC0 - 36.59 + 0.5),) if lato == 's' else ())
    if tubi:
        mat, quanti = tubi
        # R1: sotto il tubo grosso (2,45), fino al muro est del vano scala (prima finivano nel vuoto all'entrata)
        # (la lampada rc1 del raccordo è sullo stesso muro, a x 48,5 e 2,1 m: i tubi le passavano dentro; il fascio
        # rientra nel muro prima e ne esce dopo)
        # (le staffe non sulle costole del muro: vuoti dove passano, vedi COSTOLE)
        tubi_muro(f'{nome}_tubi_r1', (XR, Y_R0, 0), (48.5 - 0.4, Y_R0, 0), (0, 1), 2.15, mat, obs, quanti, nel_muro_b=True,
                  vuoti=_vuoti_costole(XR, 1))
        tubi_muro(f'{nome}_tubi_r1b', (48.5 + 0.4, Y_R0, 0), (X_S1, Y_R0, 0), (0, 1), 2.15, mat, obs, quanti, nel_muro_a=True,
                  vuoti=_vuoti_costole(48.5 + 0.4, 1))
        # in C2 no: sullo stesso muro c'è già il tubo grosso del raccordo (t7_tubo_c2) e non c'è posto sopra i 2 m
        # C3: dal muro est di C2 (dove il corridoio gira) fin quasi al magazzino, dove rientrano nel muro sud
        # (e così attorno alla lampada t7_c3b, a x 33,5)
        # (a 2,35 m: a 2,2 passavano davanti all'architrave della porta della scala di servizio, x 36,59..37,59, e una
        # staffa restava nel vano, senza muro dietro)
        tubi_muro(f'{nome}_tubi_c3', (XC1, YC3_0, Z_SALA), (33.5 + 0.4, YC3_0, Z_SALA), (0, 1), 2.35, mat, obs, quanti, nel_muro_b=True,
                  vuoti=((XC1 - 37.59, XC1 - 36.59),) + _vuoti_costole(XC1, -1))
        tubi_muro(f'{nome}_tubi_c3b', (33.5 - 0.4, YC3_0, Z_SALA), (XM1 + 0.8, YC3_0, Z_SALA), (0, 1), 2.35, mat, obs, quanti, nel_muro_a=True, nel_muro_b=True,
                  vuoti=_vuoti_costole(33.5 - 0.4, -1))


def magazzino_pieno(nome, tav_cumuli, obs, rnd, liberi=()):
    """Il magazzino stracolmo: cumuli a terra in tutte e due le metà, davanti agli scaffali e tra uno e l'altro,
    lasciando la corsia y -15,75..-14,25 dal passaggio di C3 alla serranda."""
    k_obj = 0
    # i mucchi di gonfiabili che ci sono già nel raccordo (ambienti2_raccordo.py): lì non si mette niente
    gia = [(XM1 - 2.4, YM0 + 1.3), (XM0 + 4.2, YM1 - 1.2), (XM0 + 2.0, YM0 + 1.4), (XM1 - 4.6, YM1 - 1.1)] + list(liberi)
    for y0, y1 in ((YM0 + 0.7, -15.85), (-14.15, YM1 - 0.7)):
        x = XM1 - 0.4
        while x > XM0 + 0.8:
            file, alto, pila = rnd.choice(tav_cumuli)
            k = _scala_per(file, alto=alto * rnd.uniform(0.85, 1.2))
            dm = _dim(file, k)
            if max(dm.x, dm.y) > (y1 - y0) * 1.1:
                k *= (y1 - y0) / max(dm.x, dm.y); dm = _dim(file, k)
            yc = rnd.uniform(y0 + dm.y / 2, max(y0 + dm.y / 2, y1 - dm.y / 2))
            if any(math.hypot(x - dm.x / 2 - gx, yc - gy) < 0.6 + max(dm.x, dm.y) / 2 for gx, gy in gia):
                x -= 0.3
                continue
            posa(f'{nome}_mag_{k_obj}', file, (x - dm.x / 2, yc, Z_SALA), k, rnd.uniform(-0.3, 0.3) + (math.pi if y0 > -15 else 0), obs)
            k_obj += 1
            if pila:
                h = dm.z
                for _ in range(rnd.choice((1, 2, 2, 3))):
                    f2, a2, _p = rnd.choice([t for t in tav_cumuli if t[2]])
                    k2 = _scala_per(f2, alto=a2 * rnd.uniform(0.7, 0.95))
                    d2 = _dim(f2, k2)
                    if d2.x > dm.x:
                        k2 *= dm.x / d2.x; d2 = _dim(f2, k2)
                    posa(f'{nome}_mag_{k_obj}', f2, (x - dm.x / 2, yc, Z_SALA + h + 0.004), k2, rnd.uniform(-0.4, 0.4), obs)
                    _appoggia(obs[-1], obs[-2])
                    k_obj += 1
                    h += d2.z
            x -= dm.x + rnd.uniform(0.02, 0.15)


def proposta_A_piena():
    reset()
    obs = []
    rnd = random.Random(11)
    terra = [('lettini_impilati', 0.9, False), ('materassini_arrotolati', 1.1, False), ('cassa_tubi', 0.85, False),
             ('scatolone_blu', 0.45, True), ('scatolone_rosso', 0.45, True),
             ('scatolone_giallo', 0.42, True), ('pallone_gonfio_a', 0.5, False), ('pallone_gonfio_b', 0.5, False),
             ('carrello_asciugamani', 1.0, False), ('ombrelloni_chiusi', 2.0, False), ('pallone_sgonfio', 0.12, False)]
    muro = [('salvagente_anulare', 0.75), ('bacheca', 0.7), ('salvagente_anulare', 0.75), ('cartello_pericolo', 0.45)]
    piccoli = [('pallone_gonfio_a', 0.35, False), ('pallone_gonfio_b', 0.35, False), ('braccioli', 0.18, False), ('secchio_mocio', 0.5, False),
               ('salvagente_giocattolo', 0.25, False), ('paperella', 0.12, False), ('ciabatta', 0.08, False), ('scatolone_giallo', 0.25, True)]
    percorso_pieno('A', terra, muro, piccoli, obs, rnd)
    magazzino_pieno('A', [('gonfiabili_mucchio', 0.6, False), ('lettini_impilati', 1.0, True), ('materassini_arrotolati', 1.2, False),
                          ('scatolone_blu', 0.5, True), ('scatolone_rosso', 0.5, True), ('scatolone_giallo', 0.45, True),
                          ('pallone_gonfio_a', 0.55, False), ('pallone_gonfio_b', 0.55, False), ('pallone_mezzo', 0.4, False),
                          ('sedie_impilate', 1.6, False), ('cassa_tubi', 0.9, True)], obs, rnd)
    # i pezzi che raccontano la festa finita: la testa della mascotte, il coccodrillo, i festoni
    metti('A_testa_mascotte', 'testa_mascotte', (44.0, -9.6, Z_SALA), alto=0.85, rz=-90, obs=obs)
    metti('A_coccodrillo_l1', 'coccodrillo_sgonfio', (51.4, 6.2, Z_L1), largo=1.2, rz=170, obs=obs)
    festone('A_festone_s1', (X_S0 + 0.1, 0.3, 3.3), (X_S1 - 0.1, 4.2, 5.0), 16, obs, seme=1)
    festone('A_festone_s2', (X_S1 - 0.1, 6.8, 6.6), (X_S0 - 3.0, 8.8, 9.2), 16, obs, seme=2)
    festone('A_festone_c2', (XC0 + 0.05, 1.5, Z_SALA + 2.6), (XC1 - 0.05, -2.0, Z_SALA + 2.6), 10, obs, seme=3)
    festone('A_festone_c2b', (XC0 + 0.05, -6.0, Z_SALA + 2.5), (XC1 - 0.05, -9.5, Z_SALA + 2.5), 10, obs, seme=5)
    festone('A_festone_c3', (40.0, YC3_0 + 0.05, Z_SALA + 2.5), (33.0, YC3_1 - 0.05, Z_SALA + 2.5), 16, obs, seme=6)
    festone('A_festone_mag', (XM1 - 0.5, YM0 + 0.4, Z_SALA + 3.1), (XM0 + 1.0, YM1 - 0.4, Z_SALA + 3.1), 22, obs, pendenza=0.6, seme=4)
    festone('A_festone_mag2', (XM1 - 0.5, YM1 - 0.4, Z_SALA + 3.0), (XM0 + 1.0, YM0 + 0.4, Z_SALA + 3.0), 22, obs, pendenza=0.5, seme=7)
    comuni(obs, C.mat_pbr('corrimano_A', base=(0.85, 0.65, 0.12), roughness=0.5, metallic=0.5))
    return obs


def proposta_B_piena():
    reset()
    obs = []
    rnd = random.Random(23)
    giallo = C.mat_pbr('vernice_frecce', base=(0.85, 0.65, 0.05), roughness=0.7)
    terra = [('fusti_cloro', 0.75, False), ('casse_plastica', 0.8, True), ('scatolone_marrone', 0.45, True),
             ('carrello_attrezzi', 1.2, False), ('sacchi_sale', 0.75, False), ('secchio_mocio', 0.55, False),
             ('scatolone_marrone', 0.4, True), ('cassa_tubi', 0.8, False)]
    muro = [('rullo_tubo', 0.6), ('quadro_elettrico', 0.7), ('cartello_pericolo', 0.45), ('estintore_staffa', 0.6), ('bacheca', 0.6)]
    piccoli = [('secchio_mocio', 0.5, False), ('scatolone_marrone', 0.25, True), ('casse_plastica', 0.3, True), ('cestino', 0.4, False)]
    tubi = C.mat_pbr('tubi_B', base=(0.35, 0.38, 0.36), roughness=0.5, metallic=0.7)
    percorso_pieno('B', terra, muro, piccoli, obs, rnd, tubi=(tubi, 3))
    magazzino_pieno('B', [('fusti_cloro', 0.85, False), ('sacchi_sale', 0.8, True), ('casse_plastica', 0.85, True),
                          ('scatolone_marrone', 0.55, True), ('transpallet', 1.2, False), ('carrello_attrezzi', 1.2, False)], obs, rnd)
    for k, (p, d) in enumerate((((48.0, YD, 0), (1, 0, 0)), ((51.6, -1.2, 0), (0, 1, 0)), ((51.6, 7.8, Z_L1), (-1, 0, 0)),
                                ((44.55, 6.0, Z_T), (0, -1, 0)), ((44.55, -3.0, Z_SALA), (0, -1, 0)), ((44.55, -13.0, Z_SALA), (0, -1, 0)),
                                ((42.0, -15.0, Z_SALA), (-1, 0, 0)), ((33.0, -15.0, Z_SALA), (-1, 0, 0)), ((24.0, -15.0, Z_SALA), (-1, 0, 0)))):
        freccia_terra(f'B_freccia_{k}', p, d, obs, giallo)
    nastro = C.mat_pbr('nastro_bianco_rosso', base=(0.8, 0.12, 0.08), roughness=0.6)
    obs.append(C.tubo('B_nastro_f1', [(X_S1 - 0.12, -0.6, 1.0), (X_S1 - 0.12, 4.4, 4.55)], 0.03, nastro, seg=8, uv=None))
    comuni(obs, C.mat_pbr('corrimano_B', base=(0.85, 0.65, 0.12), roughness=0.5, metallic=0.5))
    return obs

# ---------------------------------------------------------------------------------------------------------------
# Versione del gioco (scelta dell'utente del 17 ottobre: "un misto di A e B. Tieni i modelli di cui sei più sicuro").
# Dal provino dei modelli restano fuori quelli dubbi: il secchio col mocio (lo straccio si stacca), il pallone sgonfio
# (forma confusa), lo scatolone blu a onde e gli ombrelloni chiusi (troppo sottili); il cartello di pericolo, che è un
# cavalletto, sta a terra e non appeso. Con le collisioni (scatole) per tutto quello che è più alto di 25 cm.

TESTA_MAG = (XM1 - 1.6, YM1 - 0.8)


def proposta_gioco():
    reset()
    obs = []
    rnd = random.Random(17)
    terra = [('lettini_impilati', 0.9, False), ('materassini_arrotolati', 1.1, False), ('cassa_tubi', 0.85, False),
             ('scatolone_rosso', 0.45, True), ('scatolone_giallo', 0.42, True), ('scatolone_marrone', 0.45, True),
             ('pallone_gonfio_a', 0.5, False), ('pallone_gonfio_b', 0.5, False), ('carrello_asciugamani', 1.0, False),
             ('fusti_cloro', 0.75, False), ('casse_plastica', 0.8, True), ('carrello_attrezzi', 1.2, False),
             ('sacchi_sale', 0.75, False), ('cartello_pericolo', 0.5, False)]
    muro = [('salvagente_anulare', 0.75), ('bacheca', 0.65), ('rullo_tubo', 0.6), ('quadro_elettrico', 0.7), ('estintore_staffa', 0.6)]
    piccoli = [('pallone_gonfio_a', 0.35, False), ('pallone_gonfio_b', 0.35, False), ('braccioli', 0.18, False),
               ('salvagente_giocattolo', 0.25, False), ('paperella', 0.12, False), ('ciabatta', 0.08, False),
               ('scatolone_giallo', 0.25, True), ('cestino', 0.4, False), ('casse_plastica', 0.3, True)]
    tubi = C.mat_pbr('tubi_B', base=(0.35, 0.38, 0.36), roughness=0.5, metallic=0.7)
    percorso_pieno('G', terra, muro, piccoli, obs, rnd, tubi=(tubi, 3))
    # davanti alla grata sfondata del muro sud di C2 (il buco dell'agnellino, v0.3.6: centro in y = BUCO_Y, vedi
    # ambienti2_raccordo.py) non resta niente a terra: è dove si infila, e dal lato da cui arriva il giocatore (+Y)
    # niente nasconde il buco. Si tolgono dopo, così il resto non cambia.
    # le scale restano libere (regola del posizionamento, 21 ottobre): niente roba piccola sui gradini di F1, F2 e C2
    for o in [o for o in obs if o.name.startswith(('G_f1_', 'G_f2_', 'G_c2os_', 'G_c2es_'))]:
        obs.remove(o); bpy.data.objects.remove(o)
    for o in [o for o in obs if o.name.startswith('G_c2eb_')]:
        lo, hi = _scatola(o)
        if lo.y < BUCO_Y + 1.45 and hi.y > BUCO_Y - 0.6:
            obs.remove(o); bpy.data.objects.remove(o)
    # in C3, di fronte alla porta della scala di servizio, il rullo col tubo (44 cm di sporgenza) stava all'altezza
    # della testa: si toglie (regola del posizionamento, 21 ottobre)
    for o in [o for o in obs if o.name == 'G_c3n_m_3']:
        obs.remove(o); bpy.data.objects.remove(o)
    # la porta di servizio verso il fiume nel tratto basso di C2 (y 4,6..5,6, muro est) e la grata dopo il buco
    # dell'agnellino (y = BUCO_Y - 1,025): lì non resta niente (scelta β, 21 ottobre)
    for o in [o for o in obs if o.name.startswith(('G_c2e', 'G_c2o'))]:
        lo, hi = _scatola(o)
        porta = o.name.startswith('G_c2e') and lo.y < 5.9 and hi.y > 4.3 and lo.z < Z_T + 2.4
        grata = lo.y < BUCO_Y - 1.025 + 0.35 and hi.y > BUCO_Y - 1.025 - 0.35
        if porta or grata:
            obs.remove(o); bpy.data.objects.remove(o)
    magazzino_pieno('G', [('gonfiabili_mucchio', 0.6, False), ('lettini_impilati', 1.0, True), ('materassini_arrotolati', 1.2, False),
                          ('scatolone_rosso', 0.5, True), ('scatolone_giallo', 0.45, True), ('scatolone_marrone', 0.55, True),
                          ('pallone_gonfio_a', 0.55, False), ('pallone_gonfio_b', 0.55, False), ('pallone_mezzo', 0.4, False),
                          ('sedie_impilate', 1.6, False), ('cassa_tubi', 0.9, True), ('fusti_cloro', 0.85, False),
                          ('sacchi_sale', 0.8, True), ('casse_plastica', 0.85, True), ('transpallet', 1.2, False)], obs, rnd,
                    liberi=[(TESTA_MAG[0] + 0.4, TESTA_MAG[1]), (TESTA_MAG[0] - 0.4, TESTA_MAG[1])])
    # ai due lati della serranda (il cancello finale della risalita) resta solo il pezzo a terra: i lettini e gli
    # scatoloni impilati sopra sembravano messi a caso (riscontro dell'utente del 21 ottobre)
    for o in [o for o in obs if o.name.startswith('G_mag_') and o.location.x < XM0 + 3.0 and o.location.z > Z_SALA + 0.01]:
        obs.remove(o); bpy.data.objects.remove(o)
    # la testa della mascotte (1,8 m di muso) nel corridoio C2 lo chiudeva: sta nel magazzino, contro il muro nord
    # accanto all'entrata, girata verso la corsia (lì intorno il magazzino resta libero)
    d = HQ.dimensioni('testa_mascotte')
    metti('G_testa_mascotte', 'testa_mascotte', (TESTA_MAG[0], YM1 - 0.05 - d.y * 0.7 / d.z / 2, Z_SALA), alto=0.7, rz=0, obs=obs)
    metti('G_coccodrillo_l1', 'coccodrillo_sgonfio', (51.4, 6.2, Z_L1), largo=1.2, rz=170, obs=obs)
    # (i capi sulla faccia dei muri, col gancio: controllo di posizionamento severo del 22 ottobre)
    festone('G_festone_s1', (X_S0, 0.3, 3.6), (X_S1, 4.2, 6.3), 16, obs, seme=1, ma=(1, 0), mb=(-1, 0))   # sopra i 2 m dai gradini di F1
    festone('G_festone_s2', (X_S1, 6.8, 6.6), (X_S0 - 3.0, Y_T1, 9.2), 16, obs, seme=2, ma=(-1, 0), mb=(0, -1))
    festone('G_festone_c2', (XC0, 1.5, Z_SALA + 2.6), (XC1, -2.0, Z_SALA + 2.6), 10, obs, seme=3, ma=(1, 0), mb=(-1, 0))
    festone('G_festone_mag', (XM1 - 0.5, YM0, Z_SALA + 3.1), (XM0 + 1.0, YM1, Z_SALA + 3.1), 22, obs, pendenza=0.6, seme=4, ma=(0, 1), mb=(0, -1))
    giallo = C.mat_pbr('vernice_frecce', base=(0.85, 0.65, 0.05), roughness=0.7)
    for k, (p, d) in enumerate((((48.0, YD, 0), (1, 0, 0)), ((51.6, -1.2, 0), (0, 1, 0)), ((51.6, 7.8, Z_L1), (-1, 0, 0)),
                                ((44.55, 6.0, Z_T), (0, -1, 0)), ((44.55, -3.0, Z_SALA), (0, -1, 0)), ((44.55, -13.0, Z_SALA), (0, -1, 0)),
                                ((42.0, -15.0, Z_SALA), (-1, 0, 0)), ((33.0, -15.0, Z_SALA), (-1, 0, 0)), ((24.0, -15.0, Z_SALA), (-1, 0, 0)))):
        # in C2 (3, 4, 5) no: puntavano al magazzino, che ora la grata chiude (scelta dell'utente, 22 ottobre)
        if k not in (3, 4, 5):
            freccia_terra(f'G_freccia_{k}', p, d, obs, giallo)
    comuni(obs, C.mat_pbr('corrimano_A', base=(0.85, 0.65, 0.12), roughness=0.5, metallic=0.5))
    for o in [o for o in obs if o.name in TROPPO_ALTI]:
        obs.remove(o); bpy.data.objects.remove(o)
    lontano_dai_corrimano(obs)
    lontano_dalle_costole(obs)
    # collisioni: una scatola (allineata agli assi) per ogni modello più alto di 25 cm
    sorgenti = {o.data for o in HQ._base.values()}
    for o in list(obs):
        if o.type == 'MESH' and o.data in sorgenti and o.dimensions.z > 0.25:
            lo, hi = _scatola(o)
            obs.append(C.collisione_box(o.name + '_col', lo, hi))
    return obs


# ---------------------------------------------------------------------------------------------------------------
# I corrimano del raccordo (ambienti2_raccordo.py: F1 sul muro est del vano scala, F2 sul muro nord) e quello di C2
# (corrimano_c2): asse e raggio. Riscontro dell'utente sulla v0.3.11: "1 scatola e 1 estintore e 1 pompa antincendio
# arrotolata compenetrati con il corrimano". Con la regola dei 25 cm (23 ottobre) la roba appesa più sporgente scende
# con la cima a 1,15 m, cioè all'altezza del corrimano (95 cm sui gradini), e le pile a muro arrivano a 1,3 m.

N_F, PED_F = 20, 0.2515


def corrimano_assi():
    yc = X_S1 - 0.12
    f1 = [(yc, Y_R1 - 0.3, 0.95), (yc, Y_R1 + (N_F - 1) * PED_F, Z_L1 + 0.95), (yc, Y_T1 - 0.3, Z_L1 + 0.95)]
    xc = Y_T1 - 0.12
    f2 = [(X_S0 + 0.3, xc, Z_L1 + 0.95), (X_S0 - (N_F - 1) * PED_F, xc, Z_T + 0.95), (X_T0 + 0.4, xc, Z_T + 0.95)]
    x = XC0 + 0.07
    c2 = [(x, Y_SCALA2 + 0.6, Z_T + 0.95), (x, Y_SCALA2, Z_T + 0.95), (x, Y_SCALA2 - N2 * PED2, Z_SALA + 0.95),
          (x, Y_SCALA2 - N2 * PED2 - 0.6, Z_SALA + 0.95)]
    return {'f1': C._arrotonda(f1, 0.15), 'f2': C._arrotonda(f2, 0.15), 'c2': C._arrotonda(c2, 0.15)}


def _punti_asse(asse, passo=0.02):
    out = []
    for a, b in zip(asse, asse[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / passo))
        out += [a.lerp(b, i / n) for i in range(n + 1)]
    return out


def distanza_corrimano(o):
    """La distanza più piccola fra la mesh vera di o e l'asse dei corrimano (None se lontano), e quale corrimano."""
    from mathutils.bvhtree import BVHTree
    lo, hi = _scatola(o)
    vicini = {k: [p for p in _punti_asse(a) if all(lo[i] - 0.1 < p[i] < hi[i] + 0.1 for i in range(3))]
              for k, a in corrimano_assi().items()}
    vicini = {k: v for k, v in vicini.items() if v}
    if not vicini:
        return None, None
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    vs = [o.matrix_world @ v.co for v in m.vertices]
    ps = [tuple(p.vertices) for p in m.polygons]
    e.to_mesh_clear()
    if not ps:
        return None, None
    t = BVHTree.FromPolygons(vs, ps)
    meglio = (None, None)
    for k, pts in vicini.items():
        d = min(t.find_nearest(p)[3] for p in pts)
        if meglio[0] is None or d < meglio[0]:
            meglio = (d, k)
    return meglio


R_CORR, STACCO = 0.025, 0.02

# Le costole d'acciaio dei corridoi (ambienti2_raccordo.py): larghe 20 cm, sporgono 16 cm dal muro, dal pavimento al
# soffitto. La roba a muro (a 3 cm) ci entrava di 6-13 cm: il controllo di posizionamento non le vedeva, perché i
# dettagli del raccordo sono una mesh sola di 44 m (trovato col controllo corretto, 23 ottobre).
H_R1 = 2.8
H_C = Z_SALA + 2.8


def costole():
    """Le scatole (lo, hi) delle costole, e per ognuna l'asse lungo il muro (0 = x, 1 = y)."""
    out = []
    for x in (47.6, 49.4):
        out.append(((x - 0.1, Y_R0, 0.0), (x + 0.1, Y_R0 + 0.16, H_R1), 0))
        out.append(((x - 0.1, Y_R1 - 0.16, 0.0), (x + 0.1, Y_R1, H_R1), 0))
    for y in (-1.0, -4.0, -7.0, -10.0, -13.0):
        out.append(((XC0, y - 0.1, Z_SALA), (XC0 + 0.16, y + 0.1, H_C), 1))
        out.append(((XC1 - 0.16, y - 0.1, Z_SALA), (XC1, y + 0.1, H_C), 1))
    for x in (42.0, 39.0, 36.0, 33.0, 30.0):
        out.append(((x - 0.1, YC3_0, Z_SALA), (x + 0.1, YC3_0 + 0.16, H_C), 0))
        out.append(((x - 0.1, YC3_1 - 0.16, Z_SALA), (x + 0.1, YC3_1, H_C), 0))
    return [(Vector(lo), Vector(hi), ax) for lo, hi, ax in out]


def _vuoti_costole(x_da, verso):
    """I tratti (u0, u1) lungo un muro di R1 o di C3 che parte da x_da e va verso x crescente (verso 1) o
    decrescente (-1) dove ci sono le costole."""
    out = []
    for lo, hi, ax in costole():
        if ax == 0:
            u0, u1 = sorted(((lo.x - x_da) * verso, (hi.x - x_da) * verso))
            if u1 > 0:
                out.append((u0, u1))
    return tuple(sorted(set(out)))


# dove la roba spostata lungo il muro non può andare: la porta della scala di servizio in C3, la porta verso il fiume
# e il buco dell'agnellino con la grata in C2 (vedi proposta_gioco)
VIETATI = [((36.39, YC3_0, Z_SALA), (37.79, YC3_0 + 0.8, H_C)), ((XC1 - 0.8, 4.3, Z_T), (XC1, 5.9, Z_T + 2.4)),
           ((XC1 - 0.8, BUCO_Y - 1.4, Z_SALA), (XC1, BUCO_Y + 1.45, H_C))]


def _bvh(o):
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    vs = [o.matrix_world @ v.co for v in m.vertices]
    ps = [tuple(p.vertices) for p in m.polygons]
    e.to_mesh_clear()
    return BVHTree.FromPolygons(vs, ps) if ps else None


def _bvh_scatola(lo, hi):
    from mathutils.bvhtree import BVHTree
    vs = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    facce = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return BVHTree.FromPolygons(vs, facce)


def nella_costola(o):
    """La costola che la mesh vera di o attraversa (le facce si incrociano), o None."""
    lo, hi = _scatola(o)
    for c in costole():
        clo, chi, ax = c
        if not all(lo[i] < chi[i] + 0.005 and hi[i] > clo[i] - 0.005 for i in range(3)):
            continue
        t = _bvh(o)
        if t and t.overlap(_bvh_scatola(clo - Vector((0.005,) * 3), chi + Vector((0.005,) * 3))):
            return c
    return None


def _pila(o, obs):
    """o e i pezzi impilati con lui (sopra o sotto, con l'impronta che si sovrappone), dal basso."""
    lo, hi = _scatola(o)
    gruppo = []
    for x in obs:
        if x.type != 'MESH':
            continue
        a, b = _scatola(x)
        ox = min(hi.x, b.x) - max(lo.x, a.x)
        oy = min(hi.y, b.y) - max(lo.y, a.y)
        if ox > 0.05 and oy > 0.05 and not x.name.startswith(('G_tubi', 'G_festone', 'G_freccia', 'uscita_')) \
                and 'corrimano' not in x.name and '_m_' not in x.name:
            gruppo.append(x)
    return sorted(gruppo, key=lambda x: _scatola(x)[0].z)


def _dentro_vietati(gruppo):
    for x in gruppo:
        lo, hi = _scatola(x)
        for vlo, vhi in VIETATI:
            if all(lo[i] < vhi[i] and hi[i] > vlo[i] for i in range(3)):
                return True
    return False


def lontano_dalle_costole(obs):
    """La roba che entra in una costola si sposta lungo il muro quanto basta (2 cm di stacco), dalla parte più vicina;
    le pile si spostano tutte insieme. Se dall'una e dall'altra parte tocca altra roba o finisce davanti a una porta,
    si toglie. I tubi lungo i muri passano nelle costole come nelle ordinate di una nave (le staffe no: vuoti in
    tubi_muro). Alla fine si ricontrolla tutto e, se resta qualcosa, l'esportazione si ferma."""
    fatti = set()
    tolti = set()
    for o in list(obs):
        if id(o) in tolti:
            continue
        if o.name in fatti or o.type != 'MESH':
            continue
        if o.name.startswith(('G_tubi', 'G_festone', 'G_freccia', 'c2_corrimano', 'uscita_')) or o.name.endswith(('_piolo', '_piastra')):
            continue
        c = nella_costola(o)
        if c is None:
            continue
        clo, chi, ax = c
        gruppo = [o] if '_m_' in o.name else _pila(o, obs)
        lo = Vector([min(_scatola(x)[0][i] for x in gruppo) for i in range(3)])
        hi = Vector([max(_scatola(x)[1][i] for x in gruppo) for i in range(3)])
        prove = sorted([chi[ax] + STACCO - lo[ax], clo[ax] - STACCO - hi[ax]], key=abs)
        altri = [x for x in obs if x not in gruppo and x.type == 'MESH' and not x.name.startswith(('G_festone', 'G_freccia'))]
        messo = False
        for d in prove:
            v = Vector((0, 0, 0))
            v[ax] = d
            for x in gruppo:
                x.location += v
            bpy.context.view_layer.update()
            if not any(_tocca(x, altri) for x in gruppo) and not _dentro_vietati(gruppo) and not any(nella_costola(x) for x in gruppo):
                messo = True
                break
            for x in gruppo:
                x.location -= v
            bpy.context.view_layer.update()
        nomi = ', '.join(x.name for x in gruppo)
        if messo:
            print('costole: %s spostato di %.2f m lungo il muro' % (nomi, d), flush=True)
        else:
            print('costole: %s tolto (non c\'è posto accanto alla costola)' % nomi, flush=True)
            for x in gruppo:
                tolti.add(id(x))
                obs.remove(x); bpy.data.objects.remove(x)
        fatti.update(x for x in nomi.split(', '))
    resta = [o.name for o in obs if o.type == 'MESH' and not o.name.startswith(('G_tubi', 'G_festone', 'G_freccia', 'c2_corrimano', 'uscita_'))
             and not o.name.endswith(('_piolo', '_piastra')) and nella_costola(o)]
    if resta:
        raise SystemExit('ancora nelle costole: ' + ', '.join(resta))


def lontano_dai_corrimano(obs):
    """Niente a meno di 2 cm dalla faccia dei corrimano (si sistemano dopo, così il resto della strada non cambia):
    la roba appesa sul muro del corrimano va sul muro di fronte della stessa scala, alla stessa quota (lì il corrimano
    non c'è); dalle pile si toglie il pezzo che ci arriva (il pesante sotto resta); i pezzi a terra si scostano dal
    muro quanto serve. Alla fine si ricontrolla tutto e, se resta qualcosa, l'esportazione si ferma."""
    # per ogni corrimano: la faccia del muro dove sta, quella del muro di fronte, e l'asse (x o y) fra i due
    muri = {'f1': (X_S1, X_S0, 0), 'f2': (Y_T1, Y_T0, 1), 'c2': (XC0, XC1, 0)}
    for o in list(obs):
        if o.type != 'MESH' or o.name.endswith(('_piolo', '_piastra')) or 'corrimano' in o.name:
            continue
        d, k = distanza_corrimano(o)
        if d is None or d >= R_CORR + STACCO:
            continue
        da, di_fronte, ax = muri[k]
        lo, hi = _scatola(o)
        c0 = (lo + hi) / 2
        if '_m_' in o.name:
            # appesa: sul muro di fronte, girata di 180 gradi, col retro a 1 mm dal muro
            o.rotation_euler.z += math.pi
            bpy.context.view_layer.update()
            lo2, hi2 = _scatola(o)
            sposta = c0 - (lo2 + hi2) / 2
            sposta[ax] += da + di_fronte - 2 * c0[ax]
            sposta.z = 0.0
            o.location += sposta
            bpy.context.view_layer.update()
            n = Vector((0, 0, 0))
            n[ax] = 1.0 if da > di_fronte else -1.0     # dal muro di fronte verso la stanza
            p = c0.copy()
            p[ax] = di_fronte
            _al_muro([o], p, n)
            altri = [x for x in obs if x is not o and x.type == 'MESH']
            if _tocca(o, altri):
                print('corrimano: %s non ci sta sul muro di fronte, tolto' % o.name, flush=True)
                obs.remove(o); bpy.data.objects.remove(o)
            else:
                print('corrimano: %s spostato sul muro di fronte' % o.name, flush=True)
            continue
        # sopra un altro pezzo (una pila): si toglie
        sotto = [x for x in obs if x is not o and x.type == 'MESH' and not x.name.endswith('_col-convcolonly')
                 and abs(_scatola(x)[1].z - lo.z) < 0.03 and _scatola(x)[0].x < hi.x and _scatola(x)[1].x > lo.x
                 and _scatola(x)[0].y < hi.y and _scatola(x)[1].y > lo.y]
        if sotto:
            print('corrimano: %s (in cima alla pila, sopra %s) tolto' % (o.name, sotto[0].name), flush=True)
            obs.remove(o); bpy.data.objects.remove(o)
            continue
        # a terra: si scosta dal muro del corrimano quanto serve
        n = Vector((0, 0, 0))
        n[ax] = 1.0 if di_fronte > da else -1.0
        partito = o.location.copy()
        for _ in range(40):
            o.location += n * 0.01
            bpy.context.view_layer.update()
            d, _k = distanza_corrimano(o)
            if d is None or d >= R_CORR + STACCO:
                break
        print('corrimano: %s scostato dal muro di %.2f m' % (o.name, (o.location - partito).length), flush=True)
    resta = []
    for o in obs:
        if o.type == 'MESH' and not o.name.endswith(('_piolo', '_piastra')) and 'corrimano' not in o.name:
            d, k = distanza_corrimano(o)
            if d is not None and d < R_CORR + STACCO:
                resta.append('%s (%s, %.3f)' % (o.name, k, d))
    if resta:
        raise SystemExit('ancora vicino ai corrimano: ' + ', '.join(resta))


def esporta(nome, obs, percorso=None):
    os.makedirs(os.path.dirname(percorso) if percorso else USCITA, exist_ok=True)
    for im in bpy.data.images:
        lim = 2048 if im.colorspace_settings.name != 'Non-Color' else 1024
        if im.size[0] > lim:
            im.scale(lim, lim)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    p = percorso or os.path.join(USCITA, f'arredo_{nome}.gltf')
    bpy.ops.export_scene.gltf(filepath=p, export_format='GLTF_SEPARATE', export_texture_dir='texture', use_selection=True,
                              export_apply=True, export_lights=False, export_cameras=False, export_yup=True,
                              export_image_format='JPEG', export_jpeg_quality=88)
    print('esportato', p, len(obs), 'oggetti', flush=True)


if __name__ == '__main__':
    if 'gioco' in C.argomenti():
        esporta('gioco', proposta_gioco(), os.path.join(C.RADICE, 'godot', 'assets', 'ambienti_tecnici', 'arredo_risalita', 'arredo_risalita.gltf'))
        sys.exit()
    scelte = [a for a in C.argomenti() if a in ('A', 'B')] or ['A', 'B']
    for s in scelte:
        esporta(s, proposta_A_piena() if s == 'A' else proposta_B_piena())
