"""Passo 1: importa il GLB di Meshy, salda il guscio e separa le parti.

Il GLB di Meshy e' un unico guscio (diviso in 1142 pezzi solo dalle cuciture UV): qui lo si salda e
si classificano le facce con posizione, connettivita', spessore e colore della texture:
  0 pelle (corpo vinile)  1 capelli  2 campana  3 moncherini  4 occhio_dipinto
Ogni parte ha il suo materiale, ma tutti usano le stesse texture.

Scrive:
  assets_src/medusa/tex/medusa_mr.jpg (metallic/roughness, copiata cosi' com'e')
  assets_src/medusa/build/originali/medusa_basecolor_originale.jpg, medusa_normal_originale.png
      (le texture originali restano anche dentro meshy_base.glb; il passo 2 ne fa le versioni pulite)
  assets_src/medusa/dati/occhio.json         (centro e raggi dell'occhio dipinto)
  assets_src/medusa/dati/attacchi_tentacoli.json (radici dei moncherini sotto la campana)
  assets_src/medusa/build/medusa_01_parti.blend
  assets_src/medusa/build/viso_piatto.png    (colore della texture visto di fronte, per l'occhio)

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_01_parti.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
from mathutils.bvhtree import BVHTree  # noqa: E402
from scipy.sparse import coo_matrix, csr_matrix  # noqa: E402
from scipy.sparse.csgraph import connected_components, maximum_flow, breadth_first_order  # noqa: E402

PARTI = ['pelle', 'capelli', 'campana', 'moncherini', 'occhio_dipinto']
PELLE, CAPELLI, CAMPANA, MONCHERINI, OCCHIO = range(5)

Z_VITA = -0.155          # taglio orizzontale tra busto (vinile) e campana: meta' del passaggio di colore
R_CAMPANA = 0.5          # raggio massimo della campana (le braccia sotto la vita sono oltre 0.55)
Z_SOTTO = -0.53          # sotto questa quota ci sono solo bordo, sottombrella e moncherini
SPESSORE_MONCHERINO = 0.075
MARGINE_ORBITA = 0.006   # l'orbita e' un po' piu' larga delle punte dei raggi dell'occhio

ORIGINALI = os.path.join(BUILD, 'originali')
os.makedirs(ORIGINALI, exist_ok=True)
BASE_ORIG = os.path.join(ORIGINALI, 'medusa_basecolor_originale.jpg')
NORMAL_ORIG = os.path.join(ORIGINALI, 'medusa_normal_originale.png')
MR = os.path.join(TEX, 'medusa_mr.jpg')
FILE_ORIGINALI = {'Image_0': BASE_ORIG, 'Image_1': MR, 'normal': NORMAL_ORIG}

# vista frontale piatta del viso (per misurare l'occhio dipinto)
VISO_ZC, VISO_SCALA, VISO_PX = 0.66, 0.36, 1400


# ---------------------------------------------------------------- utilita'

def taglio_grafo(costo0, costo1, ei, ej, w, scala=1000):
    """Min-cut binario (scipy maximum_flow). True = etichetta 1."""
    n = len(costo0)
    S, T = n, n + 1
    c0 = np.round(np.asarray(costo0) * scala).astype(np.int64)
    c1 = np.round(np.asarray(costo1) * scala).astype(np.int64)
    mn = np.minimum(c0, c1); c0 -= mn; c1 -= mn
    wi = np.maximum(np.round(np.asarray(w) * scala).astype(np.int64), 0)
    rows = np.concatenate([np.full(n, S), np.arange(n), ei, ej])
    cols = np.concatenate([np.arange(n), np.full(n, T), ej, ei])
    caps = np.concatenate([c1, c0, wi, wi])
    k = caps > 0
    G = csr_matrix((caps[k].astype(np.int32), (rows[k], cols[k])), shape=(n + 2, n + 2))
    G.sum_duplicates()
    flusso = maximum_flow(G, S, T).flow
    R = G - flusso
    R.data[R.data < 0] = 0
    R.eliminate_zeros()
    raggiunti = breadth_first_order(R, S, directed=True, return_predecessors=False)
    lab1 = np.ones(n + 2, bool)
    lab1[raggiunti] = False
    return lab1[:n]


def componenti(mask, adj):
    F = len(mask)
    e = adj[mask[adj[:, 0]] & mask[adj[:, 1]]]
    idx = np.nonzero(mask)[0]
    loc = -np.ones(F, int); loc[idx] = np.arange(len(idx))
    A = coo_matrix((np.ones(len(e)), (loc[e[:, 0]], loc[e[:, 1]])), shape=(len(idx), len(idx)))
    n, lab = connected_components(A, directed=False)
    full = -np.ones(F, int); full[idx] = lab
    return n, full


def pulisci_isole(lab, adj, min_facce=40, giri=3):
    """Le isole piccole di un'etichetta prendono l'etichetta piu' comune tra le facce vicine."""
    F = len(lab)
    for _ in range(giri):
        cambiato = 0
        for k in np.unique(lab):
            n, comp = componenti(lab == k, adj)
            sz = np.bincount(comp[comp >= 0], minlength=n)
            for c in np.nonzero(sz < min_facce)[0]:
                m = comp == c
                vic = np.concatenate([adj[m[adj[:, 0]], 1], adj[m[adj[:, 1]], 0]])
                vic = vic[lab[vic] != k]
                if len(vic):
                    lab[m] = np.bincount(lab[vic]).argmax()
                    cambiato += 1
        if not cambiato:
            break
    return lab


# ---------------------------------------------------------------- passi

def importa_e_salda():
    reset()
    bpy.ops.import_scene.gltf(filepath=BASE_GLB)
    ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
    ob.name = ob.data.name = 'Medusa'
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    nv = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    log('saldatura:', nv, '->', len(bm.verts), 'vertici')
    # taglio pulito della vita (solo busto/campana, non le braccia)
    geom = [f for f in bm.faces if abs(f.calc_center_median().z - Z_VITA) < 0.06
            and math.hypot(*f.calc_center_median().xy) < 0.45]
    sel_e = list({e for f in geom for e in f.edges})
    sel_v = list({v for f in geom for v in f.verts})
    res = bmesh.ops.bisect_plane(bm, geom=sel_v + sel_e + geom, plane_co=(0, 0, Z_VITA), plane_no=(0, 0, 1))
    tagliate = [f for f in bm.faces if len(f.verts) > 3]
    bmesh.ops.triangulate(bm, faces=tagliate)
    bm.to_mesh(me); bm.free()
    for nome in ('custom_normal', 'sharp_face', 'sharp_edge'):
        a = me.attributes.get(nome)
        if a:
            me.attributes.remove(a)
    me.shade_smooth()
    log('mesh:', len(me.vertices), 'vertici', len(me.polygons), 'facce')
    return ob


def estrai_texture(ob):
    """Copia le texture del GLB in tex/ (byte identici) e collega il materiale ai file esterni."""
    mat = ob.data.materials[0]
    for img in list(bpy.data.images):
        if img.name in FILE_ORIGINALI and img.packed_file:
            p = FILE_ORIGINALI[img.name]
            if not os.path.exists(p):
                with open(p, 'wb') as f:
                    f.write(img.packed_file.data)
                log('estratta', os.path.relpath(p, REPO))
    return mat


def viso_piatto(ob):
    """Render ortografico del colore della texture (emissione) davanti al viso."""
    path = os.path.join(BUILD, 'viso_piatto.png')
    mat = bpy.data.materials.new('piatto')
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    out = nodo(nt, 'ShaderNodeOutputMaterial')
    em = nodo(nt, 'ShaderNodeEmission')
    t = nodo(nt, 'ShaderNodeTexImage'); t.image = immagine(BASE_ORIG)
    nt.links.new(t.outputs['Color'], em.inputs['Color'])
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    vecchi = list(ob.data.materials)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    imposta_render(samples=4, res=(VISO_PX, VISO_PX), denoise=False, vista='Standard')
    mondo((0, 0, 0), 0)
    cam = camera((0, -5, VISO_ZC), (0, 0, VISO_ZC), ortho=VISO_SCALA, nome='cam_viso')
    render(path)
    bpy.data.objects.remove(cam)
    ob.data.materials.clear()
    for m in vecchi:
        ob.data.materials.append(m)
    return path


def misura_occhio(path):
    """Trova l'anello scuro dell'occhio dipinto e ne ricava centro e raggi (in metri)."""
    import cv2
    img = cv2.imread(path)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(float)
    H, S, V = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    anello = (((H > 290) | (H < 10)) & (S > 0.45) & (V < 0.62)).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(anello)
    big = np.argmax(stats[1:, cv2.CC_STAT_AREA]) + 1
    ys, xs = np.nonzero(lab == big)
    A = np.stack([xs, ys, np.ones_like(xs)], 1).astype(float)
    c = np.linalg.lstsq(A, (xs ** 2 + ys ** 2).astype(float), rcond=None)[0]
    cx, cy = c[0] / 2, c[1] / 2
    d = np.hypot(xs - cx, ys - cy)
    h, e = np.histogram(d, bins=np.arange(0, 500, 2.5))
    forte = np.nonzero(h > 0.25 * h.max())[0]
    r_in, r_out = e[forte[0]], e[forte[-1] + 1]
    deboli = np.nonzero(h > 0.004 * h.max())[0]
    r_punte = e[deboli[-1] + 1]
    # pupilla: dischetto magenta scuro vicino al centro
    pup = (((H > 290) | (H < 10)) & (S > 0.5) & (V < 0.6)).astype(np.uint8)
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    dd = np.hypot(xx - cx, yy - cy)
    hp, ep = np.histogram(dd[pup > 0], bins=np.arange(0, r_in, 2.5))
    area = np.histogram(dd, bins=ep)[0]
    frac = hp / np.maximum(area, 1)
    r_pup = ep[np.nonzero(frac > 0.5)[0][-1] + 1] if (frac > 0.5).any() else 0.4 * r_in
    k = VISO_SCALA / VISO_PX
    f = lambda v: round(float(v), 5)  # noqa: E731
    occhio = {
        'centro_x': f((cx - VISO_PX / 2) * k),
        'centro_z': f(VISO_ZC - (cy - VISO_PX / 2) * k),
        'raggio_anello_interno': f(r_in * k),
        'raggio_anello_esterno': f(r_out * k),
        'raggio_punte': f(r_punte * k),
        'raggio_pupilla': f(r_pup * k),
        'raggio_orbita': f(r_punte * k + MARGINE_ORBITA),
        'pixel': {'cx': f(cx), 'cy': f(cy), 'scala_m_per_px': k, 'immagine': 'build/viso_piatto.png',
                  'zc': VISO_ZC, 'lato_px': VISO_PX,
                  'r_anello_in': f(r_in), 'r_anello_out': f(r_out), 'r_punte': f(r_punte), 'r_pupilla': f(r_pup)},
    }
    log('occhio dipinto:', {kk: round(v, 4) for kk, v in occhio.items() if isinstance(v, float)})
    return occhio


def dati_facce(ob):
    me = ob.data
    co = coords(me)
    cen, nor = facce(me)
    tri = loop_vert(me).reshape(-1, 3)
    uv = loop_uv(me).reshape(-1, 3, 2)
    img = carica_immagine_np(BASE_ORIG)
    c = uv.mean(1)
    col = np.mean([campiona_uv(img, s) for s in [c] + [0.6 * c + 0.4 * uv[:, k] for k in range(3)]], axis=0)
    adj = adiacenza_facce(me)
    return co, tri, cen, nor, col, adj


def sfera_adattata(P):
    A = np.c_[2 * P, np.ones(len(P))]
    s = np.linalg.lstsq(A, (P ** 2).sum(1), rcond=None)[0]
    c = s[:3]
    return c, float(np.sqrt(s[3] + c @ c))


def spessore(co, tri, cen, nor, sel):
    """Diametro locale (shape diameter): raggi verso l'interno, mediana di 5 raggi in un cono."""
    bvh = BVHTree.FromPolygons([Vector(v) for v in co], tri.tolist(), all_triangles=True)
    out = np.full(len(cen), np.nan)
    for f in np.nonzero(sel)[0]:
        n = Vector(nor[f]); p = Vector(cen[f]) - n * 1e-4
        t1 = n.orthogonal().normalized(); t2 = n.cross(t1)
        ds = []
        for a, b in ((0, 0), (0.35, 0), (-0.35, 0), (0, 0.35), (0, -0.35)):
            hit = bvh.ray_cast(p, (-n + t1 * a + t2 * b).normalized(), 1.0)
            if hit[0] is not None:
                ds.append(hit[3])
        out[f] = np.median(ds) if ds else 1.0
    return out


def classifica(co, tri, cen, nor, col, adj, occhio):
    F = len(cen)
    x, y, z = cen.T
    r = np.hypot(x, y)
    lab = np.full(F, PELLE)

    # campana: sotto il taglio della vita
    campana = (z < Z_VITA) & (r < R_CAMPANA)
    lab[campana] = CAMPANA

    # moncherini: tubi sottili sotto la sottombrella
    sotto = campana & (z < Z_SOTTO)
    sp = spessore(co, tri, cen, nor, sotto)
    cand = sotto & (sp < SPESSORE_MONCHERINO)
    n, comp = componenti(cand, adj)
    monc = np.zeros(F, bool)
    for k in range(n):
        m = comp == k
        if m.sum() >= 40 and z[m].min() < -0.70:     # i moncherini scendono sotto il labbro del bordo
            monc |= m
    # riempi i buchi (nodi piu' spessi dentro un moncherino)
    n2, comp2 = componenti(sotto & ~monc, adj)
    sz2 = np.bincount(comp2[comp2 >= 0], minlength=n2)
    for k in np.nonzero(sz2 < 1500)[0]:
        monc |= comp2 == k
    lab[monc] = MONCHERINI

    # capelli contro pelle nella testa: taglio di grafo sul colore (B-R) e sulle pieghe della superficie
    br = col[:, 2] - col[:, 0]
    regione = (z > 0.22) & (np.abs(x) < 0.45)
    idx = np.nonzero(regione)[0]
    loc = -np.ones(F, int); loc[idx] = np.arange(len(idx))
    p = np.clip(1 / (1 + np.exp(-(br - 0.09) / 0.02)), 0.02, 0.98)
    c_pelle, c_capelli = -np.log(p), -np.log(1 - p)
    ex, ez = occhio['centro_x'], occhio['centro_z']
    d_occhio = np.hypot(x - ex, z - ez)
    # dentro l'anello dell'occhio non c'e' frangia davanti: e' sicuramente viso. Con una sfera adattata a
    # quel pezzo di viso si riconosce anche il resto dell'occhio dipinto (la frangia sta piu' avanti)
    viso = (d_occhio < occhio['raggio_anello_interno']) & (y < -0.18) & (nor[:, 1] < -0.5)
    sc, sr = sfera_adattata(cen[viso])
    occhio['sfera_viso'] = {'centro': [round(float(v), 5) for v in sc], 'raggio': round(float(sr), 5)}
    sul_viso = (d_occhio < occhio['raggio_orbita'] + 0.01) & (np.abs(np.linalg.norm(cen - sc, axis=1) - sr) < 0.006)
    viso |= sul_viso
    c_capelli = np.where(((z < 0.30) & (np.abs(x) < 0.25) & (y > -0.2)) | viso, 50.0, c_capelli)
    c_pelle = np.where(viso, 0.0, c_pelle)
    e = adj[regione[adj[:, 0]] & regione[adj[:, 1]]]
    cosang = np.clip((nor[e[:, 0]] * nor[e[:, 1]]).sum(1), 0, 1)
    L = np.linalg.norm(cen[e[:, 0]] - cen[e[:, 1]], axis=1)
    w = 6.0 * L / np.median(L) * (0.05 + 0.95 * cosang ** 8)
    capelli = taglio_grafo(c_pelle[idx], c_capelli[idx], loc[e[:, 0]], loc[e[:, 1]], w)
    lab[idx[capelli]] = CAPELLI

    # occhio dipinto: pelle del viso dentro l'orbita (la frangia davanti resta capelli)
    occ = (lab == PELLE) & (d_occhio < occhio['raggio_orbita']) & (y < -0.12) & (nor[:, 1] < -0.2) & (z > 0.45)
    lab[occ] = OCCHIO

    lab = pulisci_isole(lab, adj)
    for i, nome in enumerate(PARTI):
        log(f'  {nome:15s} {int((lab == i).sum()):6d} facce')
    return lab, sp


def attacchi_moncherini(cen, nor, lab, adj, co, tri):
    """Per ogni moncherino: radice (anello dove si attacca alla sottombrella), direzione, raggio."""
    monc = lab == MONCHERINI
    n, comp = componenti(monc, adj)
    out = []
    for k in range(n):
        m = comp == k
        if m.sum() < 30:
            continue
        # facce del moncherino che toccano la campana
        a, b = adj[:, 0], adj[:, 1]
        bordo = np.concatenate([a[m[a] & ~m[b] & (lab[b] == CAMPANA)], b[m[b] & ~m[a] & (lab[a] == CAMPANA)]])
        bordo = np.unique(bordo)
        if len(bordo) < 3:
            continue
        # piu' moncherini fusi tra loro hanno piu' anelli di radice: si separano per vicinanza
        from scipy.spatial import cKDTree
        coppie = np.array(list(cKDTree(cen[bordo]).query_pairs(0.02)))
        if len(coppie) == 0:
            continue
        A = coo_matrix((np.ones(len(coppie)), (coppie[:, 0], coppie[:, 1])), shape=(len(bordo), len(bordo)))
        nr, labr = connected_components(A, directed=False)
        mf = np.nonzero(m)[0]
        for j in range(nr):
            anello = bordo[labr == j]
            if len(anello) < 6:
                continue
            rad = cen[anello].mean(0)
            # facce del moncherino piu' vicine a questa radice che a quelle degli altri anelli
            altri = [cen[bordo[labr == q]].mean(0) for q in range(nr) if q != j and (labr == q).sum() >= 6]
            dist = np.linalg.norm(cen[mf] - rad, axis=1)
            mio = np.ones(len(mf), bool)
            for a2 in altri:
                mio &= dist <= np.linalg.norm(cen[mf] - a2, axis=1)
            pezzo = cen[mf[mio]]
            punta = pezzo[np.argmin(pezzo[:, 2])]
            dirz = pezzo.mean(0) - rad
            dirz /= np.linalg.norm(dirz)
            raggio = float(np.median(np.linalg.norm(cen[anello] - rad, axis=1)))
            out.append({'radice': [round(float(v), 4) for v in rad],
                        'direzione': [round(float(v), 4) for v in dirz],
                        'punta': [round(float(v), 4) for v in punta],
                        'raggio_radice': round(raggio, 4),
                        'lunghezza': round(float(rad[2] - punta[2]), 4),
                        'facce': int(mio.sum())})
    out.sort(key=lambda d: math.atan2(d['radice'][1], d['radice'][0]))
    for i, d in enumerate(out):
        d['id'] = i
        r = math.hypot(d['radice'][0], d['radice'][1])
        d['raggio_dal_centro'] = round(r, 4)
        d['angolo_gradi'] = round(math.degrees(math.atan2(d['radice'][1], d['radice'][0])), 1)
    return out


def materiali(ob, lab):
    me = ob.data
    me.materials.clear()
    for nome in PARTI:
        me.materials.append(materiale_pbr('M_' + nome, base=BASE_ORIG, mr=MR, normal=NORMAL_ORIG))
    me.polygons.foreach_set('material_index', lab.astype(np.int32))
    att = me.attributes.get('parte') or me.attributes.new('parte', 'INT', 'FACE')
    att.data.foreach_set('value', lab.astype(np.int32))
    me.update()
    # pulizia: materiale e immagini del GLB non piu' usati
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)


def empties_attacchi(attacchi):
    coll = bpy.data.collections.new('Attacchi_tentacoli')
    bpy.context.scene.collection.children.link(coll)
    for d in attacchi:
        e = bpy.data.objects.new(f'attacco_{d["id"]:02d}', None)
        e.empty_display_type = 'SINGLE_ARROW'
        e.empty_display_size = 0.08
        e.location = d['radice']
        e.rotation_euler = Vector(d['direzione']).to_track_quat('Z', 'Y').to_euler()
        coll.objects.link(e)


def main():
    t0 = time.time()
    ob = importa_e_salda()
    estrai_texture(ob)
    occhio = misura_occhio(viso_piatto(ob))
    co, tri, cen, nor, col, adj = dati_facce(ob)
    lab, _ = classifica(co, tri, cen, nor, col, adj, occhio)
    attacchi = attacchi_moncherini(cen, nor, lab, adj, co, tri)
    log('moncherini trovati:', len(attacchi))
    materiali(ob, lab)
    empties_attacchi(attacchi)
    scrivi_json('occhio.json', occhio)
    scrivi_json('attacchi_tentacoli.json', {
        'nota': 'Radici dei moncherini di Meshy sotto la campana (metri, Z in alto, la medusa guarda -Y).',
        'z_vita': Z_VITA, 'moncherini': attacchi})
    np.save(os.path.join(BUILD, 'parti_facce.npy'), lab)
    salva(os.path.join(BUILD, 'medusa_01_parti.blend'))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
