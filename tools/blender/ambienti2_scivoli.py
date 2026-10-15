"""Scivoli del capitolo 1: kit di moduli di tubo (interno percorribile) e vasca d'arrivo.

Uso:
  /home/user/tools/blender-venv/bin/python tools/blender/ambienti2_scivoli.py [--render] [--anteprima] [--solo vasca|tubo|bivio|spaccato]
Uscite:
  assets_src/ambienti_tecnici/glb/scivolo_<modulo>.glb   (un GLB per modulo)
  assets_src/ambienti_tecnici/glb/vasca_arrivo.glb
  docs/report/render_ambienti2/scivolo_*.jpg, vasca_arrivo.jpg

Convenzione dei moduli: l'ingresso e' nell'origine, l'asse del tubo parte lungo +X, l'asse e' a Z=0
(il fondo del tubo e' a Z=-0,8). Ogni modulo ha un Empty USCITA (o USCITA_sx / USCITA_dx) con posizione e
rotazione dell'uscita: in Godot il modulo dopo si aggancia li'. Diametro interno 1,6 m, parete 6 cm.
L'acqua che scorre e' una striscia separata (ACQUA_scorre_*) con la U lungo il tubo, in metri / 5.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler, Quaternion
from ambienti2_comune import *

ARGS = argomenti()
R_IN = 0.8
SPESS = 0.06
U_TILE = 5.0          # metri di tubo per una ripetizione della texture
GLB_DIR = os.path.join(SRC, 'glb')

reset()
M = {}
for c in ('rosso', 'verde', 'blu', 'giallo', 'arancio'):
    M[c] = mat_pbr(f'SCIVOLO_{c}', 'Plastic006', color=f'derivate/scivolo_{c}_Color.jpg',
                   rough='derivate/scivolo_Roughness.jpg', normal_forza=0.6)
M['trasparente'] = mat_pbr('SCIVOLO_trasparente', base=(0.75, 0.85, 0.85), roughness=0.18, alpha=0.22, ior=1.5,
                           normal='Plastic006/Plastic006_NormalGL.jpg', normal_forza=0.3)
M['ferro'] = mat_pbr('ferro_arrugginito', 'Metal021')
M['tubi'] = mat_pbr('tubo_ruggine', 'Metal041B')
M['ruggine'] = mat_pbr('ruggine', 'Rust004')
M['lamiere'] = mat_pbr('lamiere_rivettate', 'MetalPlates013')
M['pericolo'] = mat_pbr('strisce_pericolo', 'PaintedMetal016')
M['verde'] = mat_pbr('vernice_verde', 'PaintedMetal006')
M['giallo_v'] = mat_pbr('vernice_giallo', 'PaintedMetal006', color='derivate/vernice_giallo_Color.jpg')
M['rosso_v'] = mat_pbr('vernice_rosso', 'PaintedMetal006', color='derivate/vernice_rosso_Color.jpg')
M['rete'] = mat_pbr('rete_grata', 'Fence008A')
M['rosso_luce'] = mat_emissivo('luce_emergenza', (1.0, 0.06, 0.03), 40.0)
M['ambra_luce'] = mat_emissivo('luce_servizio_ambra', (1.0, 0.45, 0.12), 25.0)
M['acqua'] = mat_acqua_corrente('ACQUA_scorre')
M['gomma'] = mat_pbr('gomma_nera', base=(0.02, 0.02, 0.02), roughness=0.7)


# ------------------------------------------------------------------ percorso a tartaruga
def percorso(passi, ds=0.1):
    """passi: ('dritto', L) | ('gira', R, gradi) (+ = sinistra) | ('pendenza', R, gradi) (- = in discesa).
    Restituisce [(p, t, s)] e la matrice dell'uscita."""
    p = Vector((0, 0, 0)); yaw = 0.0; pitch = 0.0; s = 0.0
    def tang():
        return Vector((math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch)))
    out = [(p.copy(), tang(), s)]
    for passo in passi:
        if passo[0] == 'dritto':
            n = max(1, int(round(passo[1] / ds)))
            for _ in range(n):
                p += tang() * (passo[1] / n); s += passo[1] / n
                out.append((p.copy(), tang(), s))
        else:
            R, ang = passo[1], math.radians(passo[2])
            L = abs(ang) * R
            n = max(2, int(round(L / ds)))
            for _ in range(n):
                # punto medio per restare sull'arco
                if passo[0] == 'gira':
                    yaw += ang / n / 2; p += tang() * (L / n); yaw += ang / n / 2
                else:
                    pitch += ang / n / 2; p += tang() * (L / n); pitch += ang / n / 2
                s += L / n
                out.append((p.copy(), tang(), s))
    t = tang()
    rot = Euler((0, -pitch, yaw), 'XYZ')
    uscita = Matrix.Translation(p) @ rot.to_matrix().to_4x4()
    return out, uscita


def cornice(t):
    """n punta verso il basso (perpendicolare a t), b = t x n."""
    d = Vector((0, 0, -1))
    n = (d - t * d.dot(t))
    n = n.normalized() if n.length > 1e-4 else Vector((1, 0, 0))
    return n, t.cross(n)


def _campiona(pts, s):
    """Punto e tangente del percorso alla lunghezza s (interpolazione lineare)."""
    if s <= pts[0][2]:
        return pts[0][0], pts[0][1]
    for (p0, t0, s0), (p1, t1, s1) in zip(pts, pts[1:]):
        if s <= s1:
            k = (s - s0) / max(s1 - s0, 1e-9)
            return p0.lerp(p1, k), t0.lerp(t1, k).normalized()
    return pts[-1][0], pts[-1][1]


def superficie_tubo(nome, pts, r, mat, seg=48, maschera=None, spessore=SPESS, u0=0.0, limiti=None, anelli_n=40):
    """Con `limiti(a) -> (s0, s1)` il tubo per ogni angolo va da s0 a s1: bordi rotti frastagliati ma lisci."""
    if limiti is not None:
        bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
        grid = []
        for j in range(seg + 1):
            a = -math.pi + 2 * math.pi * j / seg
            s0, s1 = limiti(a)
            col = []
            for i in range(anelli_n + 1):
                ss = s0 + (s1 - s0) * i / anelli_n
                p, t = _campiona(pts, ss)
                n, b = cornice(t)
                col.append((bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r), ss, a))
            grid.append(col)
        for j in range(seg):
            for i in range(anelli_n):
                vs = (grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
                f = bm.faces.new([v[0] for v in vs])
                for l, v in zip(f.loops, vs):
                    l[uvl].uv = ((v[1] + u0) / U_TILE, 0.5 + v[2] / (2 * math.pi))
        ob = _nuovo(nome, bm, mat)
        _normali_verso_asse(ob, pts)
        if spessore:
            mod = ob.modifiers.new('spessore', 'SOLIDIFY')
            mod.thickness = spessore; mod.offset = -1.0; mod.use_rim = True; mod.use_even_offset = True
            applica_modificatori(ob)
        return liscio(ob, 40)
    return _superficie_tubo(nome, pts, r, mat, seg, maschera, spessore, u0)


def _normali_verso_asse(ob, pts):
    me = ob.data
    if len(me.polygons):
        pl = me.polygons[len(me.polygons) // 2]
        c = pl.center
        p0, t0 = _campiona(pts, pts[0][2])
        # punto dell'asse piu' vicino al centro della faccia
        best = min(pts, key=lambda q: (q[0] - c).length)
        verso = best[0] - c
        verso -= best[1] * verso.dot(best[1])
        if pl.normal.dot(verso) < 0:
            for pl in me.polygons:
                pl.flip()


def _superficie_tubo(nome, pts, r, mat, seg=48, maschera=None, spessore=SPESS, u0=0.0):
    """Superficie interna del tubo (normali verso l'asse) + Solidify verso l'esterno.
    V = 0,5 sul fondo del tubo (dove la texture e' piu' sporca). maschera(s, a) -> False toglie la faccia."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    anelli = []
    for p, t, s in pts:
        n, b = cornice(t)
        ring = []
        for j in range(seg + 1):
            a = -math.pi + 2 * math.pi * j / seg   # a = 0 sul fondo
            ring.append((bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r), s, a))
        anelli.append(ring)
    for i in range(len(anelli) - 1):
        A, B = anelli[i], anelli[i + 1]
        for j in range(seg):
            sm = (A[j][1] + B[j][1]) / 2; am = (A[j][2] + A[j + 1][2]) / 2
            if maschera and not maschera(sm, am):
                continue
            # ordine scelto per avere le normali verso l'asse
            vs = (A[j], B[j], B[j + 1], A[j + 1])
            f = bm.faces.new([v[0] for v in vs])
            for l, v in zip(f.loops, vs):
                l[uvl].uv = ((v[1] + u0) / U_TILE, 0.5 + v[2] / (2 * math.pi))
    ob = _nuovo(nome, bm, mat)
    # normali verso l'asse: controllo sul primo poligono
    me = ob.data
    if len(me.polygons):
        pl = me.polygons[0]
        p0, t0, _ = pts[0]
        c = pl.center
        if pl.normal.dot(p0 - c + t0 * t0.dot(c - p0)) < 0:
            for pl in me.polygons:
                pl.flip()
    if spessore:
        mod = ob.modifiers.new('spessore', 'SOLIDIFY')
        mod.thickness = spessore; mod.offset = -1.0; mod.use_rim = True; mod.use_even_offset = True
        applica_modificatori(ob)
    return liscio(ob, 40)


def _nuovo(nome, bm, mat):
    me = bpy.data.meshes.new(nome); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me)
    (_coll[0] or bpy.context.scene.collection).objects.link(ob)
    if mat:
        assegna(ob, mat)
    return ob


_coll = [None]
def coll(nome):
    c = collezione(nome); _coll[0] = c
    usa_collezione(nome)
    return c


def applica_modificatori(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    vecchio = ob.data; ob.data = me
    bpy.data.meshes.remove(vecchio)
    return ob


def giunti(nome, pts, ogni=2.0, mat_anello=None, bulloni=12, salta_inizio=True, maschera=None):
    """Giunture ogni `ogni` metri: anello interno appena rilevato con bulloni, flangia esterna."""
    obs = []
    L = pts[-1][2]
    k = 1 if salta_inizio else 0
    while k * ogni < L - 0.05:
        s = k * ogni
        i = min(range(len(pts)), key=lambda j: abs(pts[j][2] - s))
        p, t, _ = pts[i]
        n, b = cornice(t)
        def ok(a):
            return maschera is None or maschera(s, a)
        if ok(0) and ok(math.pi / 2) and ok(math.pi):
            obs.append(toro(f'{nome}_anello{k}', p, R_IN - 0.005, 0.018, mat_anello or M['ferro'], asse=t, seg=48, seg2=6, uv=0.5))
            obs.append(toro(f'{nome}_flangia{k}', p, R_IN + SPESS + 0.02, 0.045, mat_anello or M['ferro'], asse=t, seg=48, seg2=6, uv=0.5))
            for j in range(bulloni):
                a = 2 * math.pi * (j + 0.5) / bulloni
                d = n * math.cos(a) + b * math.sin(a)
                obs.append(sfera(f'{nome}_b{k}_{j}', p + d * (R_IN - 0.01) + t * 0.05, 0.022, M['ruggine'], seg=8, uv=None))
                obs.append(sfera(f'{nome}_b{k}_{j}x', p + d * (R_IN - 0.01) - t * 0.05, 0.022, M['ruggine'], seg=8, uv=None))
        k += 1
    return obs


def acqua_scorre(nome, pts, h=0.1, maschera=None):
    w = math.sqrt(R_IN ** 2 - (R_IN - h) ** 2) + 0.02
    bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
    prev = None
    for p, t, s in pts:
        n, b = cornice(t)
        c = p + n * (R_IN - h)
        cur = (bm.verts.new(c - b * w), bm.verts.new(c + b * w), s)
        if prev and (maschera is None or maschera(s, 0)):
            f = bm.faces.new((prev[0], prev[1], cur[1], cur[0]))
            for l, (u, v) in zip(f.loops, ((prev[2], 0), (prev[2], 1), (cur[2], 1), (cur[2], 0))):
                l[uvl].uv = (u / U_TILE, v)
        prev = cur
    ob = _nuovo(nome, bm, M['acqua'])
    ob['velocita_m_s'] = 6.0
    return ob


def uscita(nome, mat):
    e = empty(nome, (0, 0, 0), 'ARROWS', 0.6)
    e.matrix_basis = mat
    return e


def luce_servizio(nome, p, t, col=(1.0, 0.45, 0.12), energia=5):
    """Lampada di servizio stagna sul cielo del tubo (luce rossa)."""
    n, b = cornice(t)
    su = -n
    obs = [box(f'{nome}_cassa', p + su * (R_IN - 0.04), (0.3, 0.16, 0.08), M['ferro'], uv=None,
               matrice=Matrix.Translation(p + su * (R_IN - 0.04)) @ Matrix((t, b, su)).transposed().to_4x4())]
    obs.append(box(f'{nome}_vetro', None, (0.22, 0.1, 0.04), M['ambra_luce'], uv=None,
                   matrice=Matrix.Translation(p + su * (R_IN - 0.09)) @ Matrix((t, b, su)).transposed().to_4x4()))
    l = luce(f'LUCE_{nome}', 'POINT', p + su * (R_IN - 0.2), energia, col, raggio=0.05)
    return obs, l


def collisione_tubo(nome, pts, maschera=None, limiti=None):
    """Interno del tubo a bassa risoluzione (16 lati, anelli ogni 0,5 m) come trimesh -colonly.
    Le normali guardano l'asse: il giocatore scivola sulla faccia giusta."""
    sub = [q for k, q in enumerate(pts) if k % 5 == 0]
    if sub[-1] is not pts[-1]:
        sub.append(pts[-1])
    if limiti is not None:
        ob = superficie_tubo(f'{nome}-colonly', pts, R_IN, None, seg=16, spessore=0, limiti=limiti, anelli_n=8)
    else:
        ob = _superficie_tubo(f'{nome}-colonly', sub, R_IN, None, seg=16, maschera=maschera, spessore=0)
    ob['collisione'] = True; ob.hide_render = True
    return ob


# ------------------------------------------------------------------ moduli
MODULI = {}   # nome -> (oggetti, [uscite])

def modulo_tubo(nome, passi, colore='rosso', luci=(), maschera=None, mat=None, giunti_ogni=2.0, acqua=True, limiti=None):
    coll(nome)
    pts, usc = percorso(passi)
    obs = [superficie_tubo(f'{nome}_tubo', pts, R_IN, mat or M[colore], maschera=maschera, limiti=limiti),
           collisione_tubo(f'{nome}_col', pts, maschera, limiti)]
    gi = giunti(nome, pts, giunti_ogni, maschera=maschera)
    if gi:
        for o in gi:
            applica_trasf(o)
        obs.append(unisci(f'{nome}_giunti', gi))
    if acqua:
        obs.append(acqua_scorre(f'ACQUA_scorre_{nome}', pts, maschera=maschera))
    lamp = []
    for s in luci:
        i = min(range(len(pts)), key=lambda j: abs(pts[j][2] - s))
        o, l = luce_servizio(f'{nome}_luce{len(lamp)}', pts[i][0], pts[i][1])
        lamp += o; obs.append(l)
    if lamp:
        for o in lamp:
            applica_trasf(o)
        obs.append(unisci(f'{nome}_lampade', lamp))
    e = uscita(f'{nome}_USCITA', usc)
    obs.append(e)
    MODULI[nome] = (obs, [e])
    return pts, usc


def rumore1(x, seed):
    return sum(math.sin(x * f + seed * 1.7 * f) / f for f in (1, 2.3, 4.1, 7.7)) * 0.5


ARGS_SOLO = ARGS[ARGS.index('--solo') + 1] if '--solo' in ARGS else None
fare = lambda k: ARGS_SOLO in (None, k)

if fare('tubo') or fare('spaccato') or fare('bivio'):
    modulo_tubo('scivolo_dritto_4m', [('dritto', 4.0)])
    modulo_tubo('scivolo_curva_sx_90', [('gira', 4.0, 90)])
    modulo_tubo('scivolo_curva_dx_90', [('gira', 4.0, -90)], luci=(3.1,))
    modulo_tubo('scivolo_curva_sx_45', [('gira', 4.0, 45)])
    modulo_tubo('scivolo_curva_dx_45', [('gira', 4.0, -45)], luci=(2.4,))
    modulo_tubo('scivolo_discesa_inizio', [('pendenza', 5.0, -20)])
    modulo_tubo('scivolo_discesa_4m', [('dritto', 4.0)], giunti_ogni=2.0)
    modulo_tubo('scivolo_discesa_fine', [('pendenza', 5.0, 20)])
    modulo_tubo('scivolo_spirale_dx', [('gira', 3.5, -180)], luci=(5.5,))   # da inclinare in discesa in Godot
    # tratto trasparente: anelli colorati ogni 0,8 m, si vede fuori
    coll('scivolo_trasparente_4m')
    pts, usc = percorso([('dritto', 4.0)])
    obs = [superficie_tubo('scivolo_trasparente_4m_tubo', pts, R_IN, M['trasparente'], spessore=0.03),
           collisione_tubo('scivolo_trasparente_4m_col', pts)]
    an = []
    for k in range(6):
        s = k * 0.8
        an.append(toro(f'tr_anello{k}', (s, 0, 0), R_IN + 0.04, 0.07, M['rosso'], asse=(1, 0, 0), seg=48, seg2=8, uv=0.5))
    for o in an:
        applica_trasf(o)
    obs.append(unisci('scivolo_trasparente_4m_anelli', an))
    obs.append(acqua_scorre('ACQUA_scorre_trasparente', pts))
    obs.append(uscita('scivolo_trasparente_4m_USCITA', usc))
    MODULI['scivolo_trasparente_4m'] = (obs, [obs[-1]])
    # grata cieca: la strada sbagliata del bivio finisce contro una grata
    pts, usc = modulo_tubo('scivolo_grata_cieca', [('dritto', 3.0)], colore='blu')
    g = []
    for k in range(-6, 7):
        y = k * 0.12
        h = math.sqrt(max(R_IN ** 2 - y * y, 0))
        g.append(cilindro(f'cieca_sbarra{k}', (2.8, y, 0), 0.018, 2 * h, M['ferro'], seg=8, uv=None))
    for z in (-0.4, 0.0, 0.4):
        h = math.sqrt(R_IN ** 2 - z * z)
        g.append(box(f'cieca_traversa{z}', (2.8, 0, z), (0.04, 2 * h, 0.05), M['ferro'], uv=None))
    g.append(toro('cieca_telaio', (2.8, 0, 0), R_IN - 0.03, 0.04, M['ferro'], asse=(1, 0, 0), seg=48, seg2=6, uv=None))
    for o in g:
        applica_trasf(o)
    gr = unisci('scivolo_grata_cieca_grata', g)
    MODULI['scivolo_grata_cieca'][0].append(gr)
    cg = box('scivolo_grata_cieca_grata_col-convcolonly', (2.8, 0, 0), (0.1, 1.6, 1.6), None, uv=None)
    cg['collisione'] = True; cg.hide_render = True
    MODULI['scivolo_grata_cieca'][0].append(cg)

if fare('spaccato') or fare('tubo'):
    # tubo spaccato: il cielo del tubo si rompe prima, il fondo prosegue come un trampolino
    def rottura(a, seme):
        dente = 0.18 * math.sin(a * 11 + seme) * math.sin(a * 5.3 + 2 * seme)   # denti della plastica spaccata
        return 1.7 + 1.7 * max(0.0, math.cos(a)) ** 1.6 + 0.35 * rumore1(a * 3.0, seme) + dente
    m1 = lambda s, a: s < rottura(a, 1)
    modulo_tubo('scivolo_spaccato_partenza', [('dritto', 4.0)], maschera=m1, colore='giallo',
                limiti=lambda a: (0.0, rottura(a, 1)))
    m2 = lambda s, a: s > 4.0 - rottura(a, 2) + 0.4
    modulo_tubo('scivolo_spaccato_arrivo', [('dritto', 4.0)], maschera=m2, colore='giallo',
                limiti=lambda a: (4.0 - rottura(a, 2) + 0.4, 4.0))

if fare('bivio') or fare('tubo'):
    # bivio: il tubo entra in una camera di smistamento d'acciaio con due uscite e due paratie a ribalta
    coll('scivolo_bivio')
    obs = []
    pts, _ = percorso([('dritto', 1.5)])
    obs.append(superficie_tubo('bivio_entrata', pts, R_IN, M['rosso']))
    obs.append(collisione_tubo('bivio_entrata_col', pts))
    obs.append(acqua_scorre('ACQUA_scorre_bivio_entrata', pts))
    CX0, CX1 = 1.5, 4.5          # camera: pareti interne
    CY = 2.1
    CZ0, CZ1 = -R_IN, 1.3
    T = 0.1
    est = box('bivio_camera_est', ((CX0 + CX1) / 2, 0, (CZ0 + CZ1) / 2), (CX1 - CX0 + 2 * T, 2 * CY + 2 * T, CZ1 - CZ0 + 2 * T), M['lamiere'], uv=None)
    inn = box('bivio_camera_int', ((CX0 + CX1) / 2, 0, (CZ0 + CZ1) / 2), (CX1 - CX0, 2 * CY, CZ1 - CZ0), M['lamiere'], uv=None)
    USC = [(-1.05, 'dx'), (1.05, 'sx')]
    fori = [cilindro('bivio_foro_in', (CX0, 0, 0), R_IN + SPESS / 2, 0.6, None, asse=(1, 0, 0), seg=48, uv=None)]
    for y, _ in USC:
        fori.append(cilindro(f'bivio_foro_{y}', (CX1, y, 0), R_IN + SPESS / 2, 0.6, None, asse=(1, 0, 0), seg=48, uv=None))
    for o in [inn] + fori:
        md = est.modifiers.new('b', 'BOOLEAN'); md.object = o; md.operation = 'DIFFERENCE'; md.solver = 'EXACT'
        bpy.context.view_layer.update()
        applica_modificatori(est)
    print('bivio camera: facce', len(est.data.polygons))
    for o in [inn] + fori:
        bpy.data.objects.remove(o)
    uv_box(est, 2.0)
    est.name = 'bivio_camera'
    obs.append(est)
    obs.append(collisione_copia(est, convessa=False, nome='bivio_camera_col'))
    # fondo della camera bagnato e acqua
    obs.append(box('ACQUA_scorre_bivio_camera', ((CX0 + CX1) / 2, 0, CZ0 + 0.05), (CX1 - CX0, 2 * CY, 0.01), M['acqua'], uv=None))
    # costole interne e lampada
    cos = []
    for x in (CX0 + 0.75, CX1 - 0.75):
        cos.append(box(f'bivio_costola_t{x}', (x, 0, CZ1 - 0.06), (0.12, 2 * CY, 0.12), M['ferro'], uv=1.0))
        for s in (-1, 1):
            cos.append(box(f'bivio_costola_l{x}{s}', (x, s * (CY - 0.06), (CZ0 + CZ1) / 2), (0.12, 0.12, CZ1 - CZ0), M['ferro'], uv=1.0))
    for o in cos:
        applica_trasf(o)
    obs.append(unisci('bivio_costole', cos))
    lp = [box('bivio_lampada', ((CX0 + CX1) / 2, 0, CZ1 - 0.05), (0.3, 0.14, 0.1), M['ferro'], uv=None),
          box('bivio_lampada_vetro', ((CX0 + CX1) / 2, 0, CZ1 - 0.11), (0.22, 0.1, 0.03), M['rosso_luce'], uv=None)]
    for o in lp:
        applica_trasf(o)
    obs.append(unisci('bivio_lampade', lp))
    obs.append(luce('LUCE_bivio', 'POINT', ((CX0 + CX1) / 2, 0, CZ1 - 0.4), 70, (1.0, 0.18, 0.08), raggio=0.05))
    # uscite: tubi che partono dritti e poi si aprono a +-30 gradi
    uscite = []
    for y, lato in USC:
        sgn = 1 if lato == 'sx' else -1
        p_s, u = percorso([('dritto', 1.0), ('gira', 5.0, sgn * 30), ('dritto', 1.0)])
        p_s = [(p + Vector((CX1, y, 0)), t, s) for p, t, s in p_s]
        obs.append(superficie_tubo(f'bivio_ramo_{lato}', p_s, R_IN, M['verde'] if lato == 'sx' else M['blu']))
        obs.append(collisione_tubo(f'bivio_ramo_{lato}_col', p_s))
        obs.append(acqua_scorre(f'ACQUA_scorre_bivio_{lato}', p_s))
        uscite.append(uscita(f'scivolo_bivio_USCITA_{lato}', Matrix.Translation((CX1, y, 0)) @ u))
        # paratia a ribalta: disco d'acciaio, cerniera in alto (asse Y). Origine sulla cerniera.
        par = [cilindro(f'PARATIA_bivio_{lato}_disco', (CX1 - 0.06, y, 0), R_IN + 0.02, 0.05, M['verde'], asse=(1, 0, 0), seg=48, uv=1.0),
               toro(f'PARATIA_bivio_{lato}_bordo', (CX1 - 0.09, y, 0), R_IN - 0.06, 0.035, M['pericolo'], asse=(1, 0, 0), seg=48, seg2=6, uv=0.4),
               cilindro(f'PARATIA_bivio_{lato}_bersaglio', (CX1 - 0.1, y, 0), 0.22, 0.03, M['giallo_v'] if lato == 'sx' else M['rosso_v'], asse=(1, 0, 0), seg=32, uv=0.5),
               cilindro(f'PARATIA_bivio_{lato}_cerniera', (CX1 - 0.06, y, R_IN + 0.05), 0.05, 0.5, M['ruggine'], asse=(0, 1, 0), seg=12)]
        for o in par:
            applica_trasf(o)
        pp = unisci(f'PARATIA_bivio_{lato}', par)
        imposta_origine(pp, (CX1 - 0.06, y, R_IN + 0.05))
        cpp = box(f'PARATIA_bivio_{lato}_disco-convcolonly', (0, 0, -(R_IN + 0.05)), (0.08, 2 * R_IN, 2 * R_IN), None, uv=None)
        cpp.parent = pp; cpp.matrix_parent_inverse = Matrix.Identity(4); cpp['collisione'] = True; cpp.hide_render = True
        pp['asse_rotazione'] = 'Y Blender (-Z Godot): chiusa = 0, aperta = +80 gradi (si alza verso la camera di smistamento)'
        if lato == 'dx':
            pp.rotation_euler = (0, math.radians(88), 0)
        obs.append(pp)
    # flange tra camera e tubi
    def anello_flangia(nome, c):
        out = [toro(nome, c, R_IN + SPESS + 0.06, 0.07, M['ferro'], asse=(1, 0, 0), seg=48, seg2=8, uv=0.5)]
        for j in range(12):
            a = 2 * math.pi * j / 12
            out.append(cilindro(f'{nome}_b{j}', Vector(c) + Vector((0, math.cos(a), math.sin(a))) * (R_IN + SPESS + 0.06), 0.03, 0.2, M['ruggine'], asse=(1, 0, 0), seg=6, uv=None))
        return out
    fl = anello_flangia('bivio_fl_in', (CX0 - T - 0.05, 0, 0))
    for y, _ in USC:
        fl += anello_flangia(f'bivio_fl_{y}', (CX1 + T + 0.05, y, 0))
    for o in fl:
        applica_trasf(o)
    obs.append(unisci('bivio_flange', fl))
    MODULI['scivolo_bivio'] = (obs, uscite)


# ------------------------------------------------------------------ export dei moduli
def esporta_kit():
    """Un solo GLB con tutti i moduli (le texture non si ripetono). Ogni modulo sta sotto un Empty
    MOD_<nome> che e' il suo ingresso; nel file i moduli sono messi in fila ogni 12 m lungo Y."""
    tutti = []
    for k, (nome, (obs, usc)) in enumerate(MODULI.items()):
        e = empty('MOD_' + nome, (0, 12.0 * k, 0), 'ARROWS', 1.0)
        tutti.append(e)
        for o in {o.name: o for o in obs + usc}.values():
            if o.name in bpy.data.objects and o.parent is None:
                o.parent = e; o.matrix_parent_inverse = Matrix.Identity(4)
                tutti.append(o)
    figli = [c for o in tutti for c in o.children_recursive if c not in tutti]
    esporta_glb(os.path.join(GLB_DIR, 'scivoli_kit.glb'), tutti + figli)
    for o in tutti:
        if o.parent is not None and o.parent.name.startswith('MOD_'):
            o.parent = None
    for o in [o for o in tutti if o.name.startswith('MOD_')]:
        bpy.data.objects.remove(o)

if MODULI and ARGS_SOLO in (None, 'tubo'):
    esporta_kit()


def piazza(nome, matrice):
    """Copia il modulo nella scena del render con la matrice data (per montare un percorso)."""
    obs, usc = MODULI[nome]
    for o in {o.name: o for o in obs + usc}.values():
        if o.name in bpy.data.objects:
            o.matrix_basis = matrice @ o.matrix_basis
    return [u.matrix_basis.copy() for u in usc]


# ------------------------------------------------------------------ vasca d'arrivo
def vasca_arrivo():
    coll('vasca_arrivo')
    P = {}
    # stesse texture della sala principale (kit di lavoro/ambiente, palette sala_a), piastrelle da 12,5 cm
    P['piastrelle'] = mat_pbr('M_amb_parete', color='da_ambiente/parete_col.jpg', normal='da_ambiente/piastrelle_bianche_nrm.jpg',
                              orm='da_ambiente/piastrelle_bianche_orm.jpg')
    P['pavimento'] = mat_pbr('M_amb_pavimento', color='da_ambiente/pavimento_col.jpg', normal='da_ambiente/antiscivolo_nrm.jpg',
                             orm='da_ambiente/pavimento_orm.jpg')
    P['vasca'] = mat_pbr('M_amb_vasca', color='da_ambiente/vasca_col.jpg', normal='da_ambiente/piastrelle_bianche_nrm.jpg',
                         orm='da_ambiente/piastrelle_bianche_orm.jpg')
    P['acqua'] = mat_acqua_nera('ACQUA_vasca_arrivo')
    P['cemento'] = mat_pbr('cemento', 'Concrete042C')
    P['neon_rosa'] = mat_emissivo('neon_rosa', (1.0, 0.25, 0.6), 30.0)
    P['neon'] = mat_emissivo('neon_azzurro', (0.25, 0.95, 1.0), 25.0)
    st = []
    VX0, VX1, VY0, VY1 = 0.0, 7.0, -5.0, 5.0     # 7 x 10 m come la vasca d'arrivo della sala
    FZ, AZ_ = -1.1, -0.22
    # pavimento intorno
    for nm, (a, b, c, d) in {'o': (-5, VX0, -7, 7), 'e': (VX1, 13, -7, 7), 'n': (VX0, VX1, VY1, 7), 's': (VX0, VX1, -7, VY0)}.items():
        st.append(box(f'deck_{nm}', ((a + b) / 2, (c + d) / 2, -0.15), (b - a, d - c, 0.3), P['pavimento'], uv=1.5))
    st.append(box('vasca_fondo', ((VX0 + VX1) / 2, 0, FZ - 0.15), (VX1 - VX0, VY1 - VY0, 0.3), P['vasca'], uv=1.5))
    for nm, c, d in (('n', ((VX0 + VX1) / 2, VY1 + 0.15, FZ / 2), (VX1 - VX0 + 0.6, 0.3, -FZ)),
                     ('s', ((VX0 + VX1) / 2, VY0 - 0.15, FZ / 2), (VX1 - VX0 + 0.6, 0.3, -FZ)),
                     ('o', (VX0 - 0.15, 0, FZ / 2), (0.3, VY1 - VY0, -FZ)), ('e', (VX1 + 0.15, 0, FZ / 2), (0.3, VY1 - VY0, -FZ))):
        st.append(box(f'vasca_parete_{nm}', c, d, P['vasca'], uv=1.5))
    # bordo arrotondato e griglia di scolo sul lato sud e ovest
    for nm, c, d in (('n', ((VX0 + VX1) / 2, VY1 + 0.2, 0.04), (VX1 - VX0 + 0.8, 0.4, 0.08)), ('s', ((VX0 + VX1) / 2, VY0 - 0.2, 0.04), (VX1 - VX0 + 0.8, 0.4, 0.08)),
                     ('o', (VX0 - 0.2, 0, 0.04), (0.4, VY1 - VY0, 0.08))):
        st.append(box(f'bordo_{nm}', c, d, P['piastrelle'], uv=1.5))
    st.append(box('scolo_s', ((VX0 + VX1) / 2, VY0 - 0.6, 0.002), (VX1 - VX0 + 0.8, 0.25, 0.004), M['rete'], uv=0.5))
    st.append(box('scolo_o', (VX0 - 0.6, 0, 0.002), (0.25, VY1 - VY0 + 1.2, 0.004), M['rete'], uv=0.5))
    acq = box('ACQUA_vasca_arrivo', ((VX0 + VX1) / 2, 0, AZ_), (VX1 - VX0, VY1 - VY0, 0.02), P['acqua'], uv=None)
    # pareti dell'alcova (sud e ovest), con piastrelle e cemento sopra
    for nm, c, d in (('s', (4, -7.15, 2.5), (18, 0.3, 5)), ('o', (-5.15, 0, 2.5), (0.3, 14, 5)), ('n', (4, 7.15, 2.5), (18, 0.3, 5))):
        st.append(box(f'muro_{nm}', c, d, P['piastrelle'], uv=1.5))
    st.append(box('soffitto', (4, 0, 5.15), (18.6, 14.6, 0.3), P['cemento'], uv=3.0))
    # muro est con il varco da cui arriva il tubo (dietro: buio)
    for nm, c, d in (('e1', (13.15, -4.35, 2.5), (0.3, 5.3, 5)), ('e2', (13.15, 4.35, 2.5), (0.3, 5.3, 5)),
                     ('e3', (13.15, 0, 4.15), (0.3, 3.4, 1.7))):
        st.append(box(f'muro_{nm}', c, d, P['cemento'], uv=2.5))
    st.append(box('fondale_buio', (17.0, 0, 2.5), (0.2, 6, 5), mat_pbr('buio', base=(0.0, 0.0, 0.0), roughness=1.0), uv=None))
    # scaletta (corrimano a U come nelle piscine)
    for sy in (-0.3, 0.3):
        st.append(tubo(f'scaletta{sy}', [(0.45, VY0 + 1.6 + sy, FZ + 0.3), (0.12, VY0 + 1.6 + sy, -0.1), (0.05, VY0 + 1.6 + sy, 0.6),
                                         (-0.35, VY0 + 1.6 + sy, 0.9), (-0.55, VY0 + 1.6 + sy, 0.0)], 0.025, M['tubi'], rc=0.2, seg=10))
    for k in range(3):
        st.append(box(f'gradino{k}', (0.12 + 0.05 * k, VY0 + 1.6, -0.35 - k * 0.3), (0.12, 0.5, 0.03), M['tubi'], uv=None))
    # bocca dello scivolo: il tubo arriva da est, in leggera discesa, e sputa nella vasca
    MZ = AZ_ + 0.12 + R_IN       # asse del tubo alla bocca
    MX = VX1 - 0.6               # bocca
    # il tubo parte dalla bocca verso est e sale verso la torre (l'acqua scende verso la vasca)
    pts, _ = percorso([('dritto', 4.0), ('pendenza', 6.0, 14), ('dritto', 3.0)])
    pts = [(p + Vector((MX, 0, MZ)), t, s) for p, t, s in pts]
    st_t = [superficie_tubo('vasca_scivolo_tubo', pts, R_IN, M['rosso'])]
    gi = giunti('vasca_scivolo', pts, 2.0)
    for o in gi:
        applica_trasf(o)
    st_t.append(unisci('vasca_scivolo_giunti', gi))
    st_t.append(acqua_scorre('ACQUA_scorre_vasca', pts))
    # bordo a campana sulla bocca
    st_t.append(toro('vasca_bocca_campana', (MX - 0.02, 0, MZ), R_IN + 0.12, 0.13, M['rosso'], asse=(1, 0, 0), seg=48, seg2=12, uv=0.6))
    # (niente lingua: la bocca finisce col bordo a campana)
    # pilastri sotto il tubo
    for k, x in enumerate((MX + 3.5, MX + 7.5)):
        i = min(range(len(pts)), key=lambda j: abs(pts[j][0].x - x))
        z = pts[i][0].z - R_IN - SPESS
        st_t.append(box(f'pilastro{k}', (x, 0, z / 2), (0.35, 0.35, z), M['ferro'], uv=1.0))
        st_t.append(toro(f'collare{k}', pts[i][0], R_IN + SPESS + 0.04, 0.05, M['ferro'], asse=(1, 0, 0), seg=40, seg2=6, uv=None))
    # portale della grata di sicurezza: guide ai lati della bocca, cassone in alto
    GX = MX - 0.35
    GW, GH = 2.3, 2.1
    for s in (-1, 1):
        st.append(box(f'guida{s}', (GX, s * (GW / 2 + 0.1), (FZ + 4.3) / 2), (0.25, 0.2, 4.3 - FZ), M['giallo_v'], uv=1.0))
        st.append(box(f'guida_strisce{s}', (GX - 0.13, s * (GW / 2 + 0.1), 0.6), (0.02, 0.2, 1.2), M['pericolo'], uv=0.6))
    st.append(box('cassone', (GX, 0, 3.9), (0.5, GW + 0.6, 0.8), M['giallo_v'], uv=1.0))
    st.append(box('cassone_strisce', (GX - 0.26, 0, 3.6), (0.02, GW + 0.6, 0.2), M['pericolo'], uv=0.6))
    # la grata: sbarre verticali + traverse, origine sul bordo inferiore, scende lungo -Z
    g = []
    gz = 1.05     # quota del bordo inferiore nel render (sta calando)
    for k in range(19):
        y = -GW / 2 + 0.06 + k * (GW - 0.12) / 18
        g.append(cilindro(f'GRATA_sb{k}', (GX, y, gz + GH / 2), 0.02, GH, M['ferro'], seg=8, uv=None))
    for k in range(5):
        g.append(box(f'GRATA_tr{k}', (GX, 0, gz + 0.06 + k * (GH - 0.12) / 4), (0.05, GW, 0.06), M['ferro'], uv=0.6))
    for k in range(4):
        # diagonali a forbice
        y0 = -GW / 2 + k * GW / 4
        for sgn in (-1, 1):
            a = math.atan2(GH, GW / 4) * sgn
            g.append(box(f'GRATA_d{k}{sgn}', (GX - 0.03, y0 + GW / 8, gz + GH / 2), (0.02, math.hypot(GW / 4, GH), 0.03), M['ferro'], uv=None, rot=(a, 0, 0)))
    for o in g:
        applica_trasf(o)
    grata = unisci('GRATA_sicurezza', g)
    imposta_origine(grata, (GX, 0, gz))
    grata['movimento'] = 'scende lungo Z fino a Z = %.2f (bordo dell acqua); alzata: Z = 2.2' % (AZ_ - 0.05)
    # pulsante della grata, su un palo giallo vicino alla scaletta
    BP = Vector((-1.0, VY0 - 1.2, 0))
    st.append(cilindro('pulsante_palo', BP + Vector((0, 0, 0.55)), 0.06, 1.1, M['giallo_v'], seg=16))
    st.append(box('pulsante_cassetta', BP + Vector((0, 0, 1.18)), (0.25, 0.25, 0.22), M['giallo_v'], uv=0.5))
    st.append(cilindro('pulsante_ghiera', BP + Vector((0, 0, 1.3)), 0.1, 0.03, M['ferro'], seg=24))
    pul = [cilindro('PULSANTE_grata_fungo', BP + Vector((0, 0, 1.36)), 0.085, 0.07, M['rosso_v'], seg=24, uv=None),
           cilindro('PULSANTE_grata_stelo', BP + Vector((0, 0, 1.32)), 0.04, 0.05, M['rosso_v'], seg=16, uv=None)]
    for o in pul:
        applica_trasf(o)
    pu = unisci('PULSANTE_grata', pul)
    imposta_origine(pu, BP + Vector((0, 0, 1.3)))
    # luci: rosse d'emergenza, neon rosa e azzurro sul muro
    def lamp(nome, pos, nrm):
        n = Vector(nrm); pos = Vector(pos)
        st.append(cilindro(f'{nome}_b', pos, 0.12, 0.06, M['ferro'], asse=n, seg=16, uv=None))
        st.append(sfera(f'{nome}_v', pos + n * 0.03, 0.1, M['rosso_luce'], seg=16, uv=None))
        luce(f'LUCE_rossa_{nome}', 'POINT', pos + n * 0.25, 60, (1.0, 0.08, 0.04), raggio=0.08)
    lamp('la1', (-5.0, -3.0, 3.0), (1, 0, 0))
    lamp('la2', (3.0, -7.0, 3.2), (0, 1, 0))
    lamp('la3', (10.5, 7.0, 3.0), (0, -1, 0))
    for k, (z, m_, c) in enumerate(((3.7, P['neon_rosa'], (1.0, 0.25, 0.6)), (3.95, P['neon'], (0.3, 0.95, 1.0)))):
        st.append(box(f'neon_muro{k}', (9.5, 7.0 - 0.05, z), (3.0, 0.05, 0.05), m_, uv=None))
        luce(f'LUCE_neon_muro{k}', 'AREA', (9.5, 6.85, z), 40, c, size=3.0, rot=(math.radians(90), 0, 0))
    luce('LUCE_bocca', 'SPOT', (MX - 3.0, 2.0, 3.8), 350, (1.0, 0.2, 0.1), spot=50, mira=(MX, 0, MZ), raggio=0.1)
    luce('LUCE_bocca_fredda', 'SPOT', (MX - 2.5, -3.5, 3.5), 200, (0.4, 0.8, 1.0), spot=40, mira=(MX, 0, MZ + 0.4), raggio=0.2)
    # gonfiabili e giocattoli in acqua
    st.append(toro('ciambella1', (3.0, 1.2, AZ_ + 0.05), 0.42, 0.13, mat_pbr('gonfiabile_verde', base=(0.2, 0.7, 0.25), roughness=0.35), seg=24, seg2=12))
    st.append(toro('ciambella2', (1.6, -1.6, AZ_ + 0.04), 0.35, 0.11, mat_pbr('gonfiabile_rosa', base=(0.85, 0.25, 0.45), roughness=0.35), seg=24, seg2=12))
    st.append(sfera('pallone', (4.6, -2.1, AZ_ + 0.12), 0.18, mat_pbr('pallone_giallo', base=(0.95, 0.75, 0.1), roughness=0.4), seg=20))
    for o in st + st_t:
        if o.name in bpy.data.objects:
            applica_trasf(o)
    # collisioni: copie delle scatole, trimesh del tubo, figlie per grata e pulsante
    for o in st:
        if o.name in bpy.data.objects and o.type == 'MESH' and len(o.data.vertices) == 8 and not o.name.startswith(('scolo', 'neon', 'gradino', 'fondale')):
            collisione_copia(o)
    collisione_tubo('vasca_scivolo_tubo_col', pts)
    for k, x in enumerate((MX + 3.5, MX + 7.5)):
        collisione_box(f'pilastro{k}_col', (x - 0.2, -0.2, 0), (x + 0.2, 0.2, 2.0))
    cg = box('GRATA_sicurezza_col-convcolonly', (0, 0, GH / 2), (0.1, GW, GH), None, uv=None)
    cg.parent = grata; cg.matrix_parent_inverse = Matrix.Identity(4); cg['collisione'] = True; cg.hide_render = True
    cp = box('PULSANTE_grata_col-convcolonly', (0, 0, 0.05), (0.2, 0.2, 0.12), None, uv=None)
    cp.parent = pu; cp.matrix_parent_inverse = Matrix.Identity(4); cp['collisione'] = True; cp.hide_render = True
    collisione_box('pulsante_palo_col', BP + Vector((-0.15, -0.15, 0)), BP + Vector((0.15, 0.15, 1.3)))
    unisci('VASCA_struttura', [o for o in st if o.name in bpy.data.objects and o.type == 'MESH' and not o.get('collisione')])
    unisci('VASCA_scivolo', [o for o in st_t if o.name in bpy.data.objects and o.type == 'MESH' and not o.name.startswith('ACQUA')])
    empty('PUNTO_uscita_vasca', (0.3, VY0 + 1.6, 0))
    empty('VAPORE_vasca', (3.5, 0, AZ_ + 0.2))
    esporta_glb(os.path.join(GLB_DIR, 'vasca_arrivo.glb'), [o for o in collezione('vasca_arrivo').objects if not o.get('solo_render')])
    return MX, MZ


# ------------------------------------------------------------------ render
if '--render' in ARGS or '--anteprima' in ARGS:
    ant = '--anteprima' in ARGS
    imposta_render(campioni=16 if ant else 192, w=800 if ant else 1600, h=450 if ant else 900, esposizione=1.0)
    mondo((0.01, 0.016, 0.024))
    suff = '_anteprima' if ant else ''
    nascondi = lambda nomi: [setattr(o, 'hide_render', True) for c in nomi for o in collezione(c).objects]
    if fare('tubo'):
        # percorso di prova: dritto, curva a destra, discesa e bivio in fondo
        tutti = list(MODULI)
        usati = ['scivolo_dritto_4m', 'scivolo_curva_dx_45', 'scivolo_trasparente_4m', 'scivolo_discesa_inizio', 'scivolo_discesa_4m', 'scivolo_discesa_fine', 'scivolo_bivio']
        nascondi([n for n in tutti if n not in usati])
        Mx = Matrix.Identity(4); catena = {}
        for n in usati:
            catena[n] = Mx
            Mx = piazza(n, Mx)[0]
        volume('nebbia_tubo', (8, -4, -1), (30, 30, 12), 0.006, (0.9, 0.9, 0.92), 0.5)
        # la luce rosa di lei, che insegue alle spalle del giocatore (solo nel render)
        luce('render_luce_inseguitrice', 'POINT', (0.2, 0.25, 0.1), 10, (1.0, 0.35, 0.75), raggio=0.3)
        camera((1.0, 0.2, -0.22), (6.5, -1.0, -0.25), lente=17, nome='cam_tubo')
        renderizza('scivolo_interno' + suff + '.jpg')
        # vista sul bivio: dalla fine della discesa
        Mb = catena['scivolo_bivio']
        luce('render_luce_inseguitrice_2', 'POINT', Mb @ Vector((-0.6, 0.2, 0.1)), 12, (1.0, 0.35, 0.75), raggio=0.3)
        camera(Mb @ Vector((1.0, 0.0, -0.15)), Mb @ Vector((4.5, 0, -0.2)), lente=15, nome='cam_bivio')
        renderizza('scivolo_bivio' + suff + '.jpg')
        if '--debug' in ARGS:
            print('DEBUG Mb', Mb.translation, [ (o.name, tuple(round(x,1) for x in o.matrix_basis.translation), o.hide_render) for o in MODULI['scivolo_bivio'][0][:4]])
            camera(Mb @ Vector((3.0, -12, 10)), Mb @ Vector((3.0, 0, 0)), lente=30, nome='cam_dbg')
            renderizza('dbg_anteprima.jpg')
        for c in [c for c in bpy.data.collections]:
            for o in c.objects:
                o.hide_render = True
    if fare('spaccato') and '--spaccato' in ARGS:
        for n in MODULI:
            for o in collezione(n).objects:
                o.hide_render = n not in ('scivolo_spaccato_partenza', 'scivolo_spaccato_arrivo')
        piazza('scivolo_spaccato_arrivo', Matrix.Translation((7.0, 0.6, -1.4)) @ Matrix.Rotation(math.radians(8), 4, 'Z'))
        # sala buia fuori: pavimento lontano e qualche luce
        coll('fuori')
        box('fuori_pavimento', (10, 0, -9), (60, 60, 0.2), mat_pbr('pavimento_lontano', 'Tiles107', color='derivate/pavimento_sporco_Color.jpg'), uv=2.0)
        for k, (x, y) in enumerate(((14, 8), (20, -6), (6, -12), (26, 3))):
            sfera(f'fuori_luce{k}', (x, y, -4), 0.15, M['rosso_luce'], uv=None)
            luce(f'fuori_l{k}', 'POINT', (x, y, -4), 600, (1.0, 0.1, 0.05), raggio=0.2)
        volume('nebbia_fuori', (10, 0, -3), (60, 60, 14), 0.02, (0.85, 0.88, 0.92), 0.5)
        # luce fredda della tempesta dalla cupola, e la luce rosa di lei alle spalle
        sole = luce('render_luna', 'SUN', (0, 0, 20), 0.35, (0.55, 0.7, 1.0), rot=(math.radians(35), math.radians(-20), 0))
        sole.data.angle = math.radians(3)
        luce('render_luce_inseguitrice_3', 'POINT', (-0.3, 0.2, 0.1), 10, (1.0, 0.35, 0.75), raggio=0.3)
        camera((0.4, 0, -0.15), (6.0, 0.4, -0.7), lente=18, nome='cam_spaccato')
        renderizza('scivolo_spaccato' + suff + '.jpg')
        for c in bpy.data.collections:
            for o in c.objects:
                o.hide_render = True

if fare('vasca'):
    MX, MZ = vasca_arrivo()
    if '--render' in ARGS or '--anteprima' in ARGS:
        for c in bpy.data.collections:
            if c.name != 'vasca_arrivo':
                for o in c.objects:
                    o.hide_render = True
        coll('vasca_arrivo')
        volume('nebbia_vasca', (4, 0, 2), (18, 14, 6), 0.01, (0.85, 0.88, 0.92), 0.4)
        volume('vapore_acqua', (3.5, 0, -0.05), (7, 6, 0.5), 0.2, (0.9, 0.92, 0.95), 0.2, rumore=1.0)
        mondo((0.001, 0.001, 0.0015))
        luce('render_luce_lei', 'POINT', (MX + 3.0, 0, MZ + 0.1), 25, (1.0, 0.35, 0.75), raggio=0.4)
        camera((0.4, -1.9, 1.65), (MX, 0.1, 0.85), lente=22, nome='cam_vasca')
        renderizza('vasca_arrivo' + ('_anteprima' if '--anteprima' in ARGS else '') + '.jpg')
