"""Mostro-squalo A: la bocca che si spalanca (GDD, "L'inizio con il mostro-squalo").

Il modello di Meshy ha la bocca chiusa: un sorriso scolpito, con i denti di sopra e di sotto
attaccati alle gengive e l'interno rosso appena incavato. Qui:
1. si trova la linea delle labbra, il fondo del solco tra i denti di sopra e quelli di sotto, fetta per
   fetta (guardando il muso di fronte), come il punto più arretrato delle facce rivolte in avanti;
2. ogni vertice del muso va alla mascella di sopra (testa) o a quella di sotto: vicino alla linea per
   distanza sulla superficie da chi è sicuramente sopra o sotto (così ogni dente resta con la sua
   gengiva), più in là con una sfumatura che fa tendere le guance dietro gli angoli della bocca;
3. si tagliano le facce a cavallo della linea: resta un buco a forma di bocca, e dal suo bordo si
   costruisce l'interno (gola, palato, lingua) e una seconda fila di denti.
Restituisce, per lo scheletro (mostro_rig.py), il peso della mascella di ogni vertice e la cerniera.
Si usa da mostro_rig.py; da solo fa i render di controllo:
  flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
      assets_src/mascotte/mostro_bocca.py <cartella render>
"""
import heapq, math, os, sys
import numpy as np
import bpy, bmesh
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
SORGENTE = os.path.join(QUI, 'gioco', 'mostro_squalo_A.glb')

# Muso (coordinate di Blender del modello: x di lato, -y avanti, z in alto). Dai render ortografici.
MUSO_Y = -0.70           # davanti a questo piano c'è il muso
MUSO_Z = (1.30, 1.80)
LINEA_X = (-0.10, 0.39)  # da un angolo della bocca all'altro, visto di fronte
FASCIA = 0.045           # metà dell'altezza della fascia dove si decide per distanza sulla superficie
# cerniera della mascella: dietro gli angoli della bocca, sotto l'occhio
CERNIERA = (Vector((-0.17, -0.70, 1.60)), Vector((0.45, -0.70, 1.53)))


def carica():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SORGENTE)
    ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def linea_labbra(P, N):
    """Per fette in x: lo z del fondo del solco (punto più arretrato tra le facce che guardano avanti)."""
    xs, zs = [], []
    for x in np.arange(LINEA_X[0] + 0.01, LINEA_X[1] - 0.005, 0.015):
        s = (np.abs(P[:, 0] - x) < 0.01) & (P[:, 1] < MUSO_Y - 0.05) & (P[:, 2] > MUSO_Z[0] + 0.05) & \
            (P[:, 2] < MUSO_Z[1] - 0.05) & (N[:, 1] < -0.2)
        if s.sum() < 10:
            continue
        idx = np.where(s)[0]
        # il guscio esterno del muso in questa fetta: per ogni z, la y più avanti; il solco è dove la
        # y più avanti è più arretrata rispetto alla curva liscia del muso
        zz = P[idx, 2]
        bins = np.arange(MUSO_Z[0] + 0.05, MUSO_Z[1] - 0.05, 0.008)
        fronte = []
        for b in bins:
            k = idx[np.abs(zz - b) < 0.004]
            fronte.append(P[k, 1].min() if len(k) else np.nan)
        fronte = np.array(fronte)
        ok = ~np.isnan(fronte)
        if ok.sum() < 8:
            continue
        # curva liscia (polinomio di 2° grado) e scarto: il solco è il massimo dello scarto
        c = np.polyfit(bins[ok], fronte[ok], 2)
        scarto = fronte - np.polyval(c, bins)
        scarto[~ok] = -1
        xs.append(x); zs.append(bins[int(np.argmax(scarto))])
    xs, zs = np.array(xs), np.array(zs)
    # lisciatura (mediana mobile poi media)
    from scipy.ndimage import median_filter, uniform_filter1d
    zs = uniform_filter1d(median_filter(zs, 5, mode='nearest'), 3, mode='nearest')
    return xs, zs


def etichette(bm, P, xs, zs):
    """+1 testa, -1 mascella, 0 fuori dal muso (lo decide la sfumatura). Nella fascia vicino alla linea
    decide la distanza sulla superficie dai vertici sicuri (Dijkstra a più sorgenti)."""
    n = len(P)
    zl = np.interp(P[:, 0], xs, zs, left=np.nan, right=np.nan)
    muso = (P[:, 1] < MUSO_Y) & (P[:, 2] > MUSO_Z[0]) & (P[:, 2] < MUSO_Z[1]) & ~np.isnan(zl)
    d = np.where(muso, P[:, 2] - np.nan_to_num(zl), 0)
    lab = np.zeros(n, np.int8)
    lab[muso & (d > FASCIA)] = 1
    lab[muso & (d < -FASCIA)] = -1
    fascia = muso & (np.abs(d) <= FASCIA)
    adj = [[] for _ in range(n)]
    for e in bm.edges:
        a, b = e.verts[0].index, e.verts[1].index
        if fascia[a] or fascia[b]:
            w = (P[a] - P[b]).__abs__().sum()
            w = float(np.linalg.norm(P[a] - P[b]))
            adj[a].append((b, w)); adj[b].append((a, w))
    dist = np.full(n, np.inf)
    h = []
    for i in np.where((lab != 0) & muso)[0]:
        if any(fascia[j] for j, _ in adj[i]):
            dist[i] = 0; heapq.heappush(h, (0.0, int(i), int(lab[i])))
    while h:
        dd, i, l = heapq.heappop(h)
        if dd > dist[i]:
            continue
        if fascia[i] and lab[i] == 0:
            lab[i] = l
        for j, w in adj[i]:
            if fascia[j] and dd + w < dist[j]:
                dist[j] = dd + w
                lab[j] = 0
                heapq.heappush(h, (dd + w, j, l))
    # i vertici della fascia mai raggiunti: per lato
    resto = fascia & (lab == 0)
    lab[resto] = np.where(d[resto] >= 0, 1, -1)
    return lab, muso


def peso_mascella(P, lab, muso, xs, zs):
    """Peso della mascella (0-1) di ogni vertice: 1 sotto la bocca, 0 sopra; dietro gli angoli della bocca
    e verso la gola una sfumatura, così le guance e il collo si tendono invece di strapparsi."""
    a, b = CERNIERA
    asse = (b - a).normalized()
    w = np.zeros(len(P), np.float32)
    w[muso & (lab < 0)] = 1.0
    # fuori dal muso: angolo attorno alla cerniera rispetto al piano cerniera-angoli della bocca
    ang_lab = []
    for xx, zz in ((xs[0], zs[0]), (xs[-1], zs[-1])):
        ang_lab.append((xx, zz))
    z_bocca = float(np.median(zs))
    centro = (a + b) / 2
    for i in np.where(~muso)[0]:
        p = Vector(P[i])
        if p.y > -0.35 or p.z < 1.05:     # lontano dalla testa: niente mascella
            continue
        q = p - centro
        q = q - asse * q.dot(asse)        # nel piano perpendicolare alla cerniera
        # sotto la linea della bocca prolungata indietro (leggermente in discesa verso la gola)
        z_lim = z_bocca - 0.02 + (p.y - MUSO_Y) * 0.25
        t = np.clip((z_lim - p.z) / 0.10 + 0.5, 0, 1)
        # sfuma indietro, dalla cerniera verso il collo
        dietro = np.clip((p.y - (-0.72)) / 0.30, 0, 1)
        w[i] = float(t * (1 - dietro) * (1 - 0.3 * np.clip((1.30 - p.z) / 0.2, 0, 1)))
    return w


def costruisci(ob, cartella=None):
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    bm.normal_update()
    P = np.array([v.co[:] for v in bm.verts]); N = np.array([v.normal[:] for v in bm.verts])
    xs, zs = linea_labbra(P, N)
    print('LINEA LABBRA', len(xs), 'punti; z', np.round(zs, 3).tolist())
    lab, muso = etichette(bm, P, xs, zs)
    w = peso_mascella(P, lab, muso, xs, zs)
    # facce a cavallo: dentro il muso, con vertici di etichette diverse
    via = [f for f in bm.faces if muso[[v.index for v in f.verts]].all() and len({lab[v.index] for v in f.verts}) > 1]
    print('FACCE TAGLIATE', len(via))
    bmesh.ops.delete(bm, geom=via, context='FACES')
    # vertici rimasti soli
    sole = [v for v in bm.verts if not v.link_faces]
    tenuti = [v.index for v in bm.verts if v.link_faces]
    bmesh.ops.delete(bm, geom=sole, context='VERTS')
    w = w[tenuti]; lab = lab[tenuti]
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    bm.to_mesh(me); bm.free()
    return dict(peso=w, lab=lab, linea=(xs, zs))


if __name__ == '__main__':
    ob = carica()
    r = costruisci(ob)
    print('mascella: vertici con peso > 0.5:', int((r['peso'] > 0.5).sum()))
