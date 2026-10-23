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
# asse e raggio della testa (per non dare peso alle mani alzate vicino al muso)
TESTA_ASSE = ((0.03, -0.45, 1.55), (0.15, -1.18, 1.52))
TESTA_RAGGIO = 0.42
# cerniera della mascella: dietro gli angoli della bocca, sotto l'occhio
CERNIERA = (Vector((-0.17, -0.70, 1.60)), Vector((0.45, -0.70, 1.53)))


def carica():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SORGENTE)
    ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # il glTF ha i vertici doppi sulle cuciture delle UV: si uniscono (le UV stanno sugli angoli delle
    # facce e restano), così la superficie è un pezzo solo e le distanze sulla superficie hanno senso
    bm = bmesh.new(); bm.from_mesh(ob.data)
    prima = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=8e-4)   # i doppioni del glTF arrivano a 0,5 mm
    # restano dei bordi aperti (cuciture con i due lati a 1-4 mm): si saldano solo i vertici di bordo,
    # se no sotto la deformazione si aprono in crepe nere
    bordo = list({v for e in bm.edges if e.is_boundary for v in e.verts})
    bmesh.ops.remove_doubles(bm, verts=bordo, dist=0.004)
    print('VERTICI', prima, '->', len(bm.verts), '; bordi aperti rimasti',
          sum(1 for e in bm.edges if e.is_boundary))
    # dopo l'unione qualche faccia può avere il verso opposto alle vicine: si rimettono coerenti
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    # le normali personalizzate del glTF dopo l'unione non valgono più (triangoli neri): si ricalcolano
    if ob.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    ob.data.shade_smooth()
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
    c0, c1 = np.array(TESTA_ASSE[0]), np.array(TESTA_ASSE[1])
    ax = (c1 - c0) / np.linalg.norm(c1 - c0)
    t_ax = (P - c0) @ ax
    in_testa = np.linalg.norm(P - c0 - np.outer(t_ax, ax), axis=1) < TESTA_RAGGIO
    # negli ultimi centimetri verso gli angoli la bocca non si taglia: la pelle si tende (peso sfumato)
    margine = 0.035
    dentro_x = (P[:, 0] > xs[0] + margine) & (P[:, 0] < xs[-1] - margine)
    muso = (P[:, 1] < MUSO_Y) & (P[:, 2] > MUSO_Z[0]) & (P[:, 2] < MUSO_Z[1]) & ~np.isnan(zl) & in_testa & dentro_x
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
    """Peso della mascella (0-1) di ogni vertice: 1 sotto la bocca, 0 sopra. Fuori dalla zona tagliata
    (agli angoli della bocca, sulle guance e verso la gola) una sfumatura rispetto alla linea delle labbra
    prolungata, così la pelle si tende invece di strapparsi."""
    w = np.zeros(len(P), np.float32)
    w[muso & (lab < 0)] = 1.0
    c0, c1 = np.array(TESTA_ASSE[0]), np.array(TESTA_ASSE[1])
    ax = (c1 - c0) / np.linalg.norm(c1 - c0)
    t_ax = np.clip((P - c0) @ ax, -0.3, None)
    in_testa = np.linalg.norm(P - c0 - np.outer(t_ax, ax), axis=1) < TESTA_RAGGIO
    zl_ext = np.interp(P[:, 0], xs, zs)        # la linea delle labbra, prolungata oltre gli angoli
    for i in np.where(~muso & in_testa)[0]:
        x, y, z = P[i]
        if y > -0.35 or z < 1.05:              # lontano dalla testa: niente mascella
            continue
        # sotto la linea delle labbra; dietro gli angoli la linea scende un poco verso la gola
        z_lim = zl_ext[i] - 0.01 - max(0.0, y - MUSO_Y) * 0.25
        t = np.clip((z_lim - z) / 0.07 + 0.5, 0, 1)
        dietro = np.clip((y - (-0.72)) / 0.30, 0, 1)      # sfuma dalla cerniera verso il collo
        w[i] = float(t * (1 - dietro) * (1 - 0.3 * np.clip((1.30 - z) / 0.2, 0, 1)))
    return w


ANGOLO = 0.08   # verso gli angoli della bocca, per tanto così il peso del labbro non è fisso


def liscia_pesi(bm, P, w, muso, lab, xs):
    """Il peso della mascella fuori dalla zona tagliata (angoli della bocca, guance, gola) diventa una
    funzione armonica: ogni vertice è la media dei vicini, con fissi i vertici del muso (0 o 1) e quelli
    lontani dalla testa (0). Così la pelle agli angoli si tende tutta insieme, senza linguette né righe
    di texture stirate dove prima il peso cambiava di colpo. Anche le labbra negli ultimi ANGOLO metri
    verso gli angoli sono libere, e i lati tagliati (tra sopra e sotto) non contano: così il taglio si
    apre piano piano verso gli angoli, come una bocca vera, invece di avere agli angoli un vertice a 0
    accanto a uno a 1 (le linguette tirate tra le due labbra)."""
    from scipy.sparse import coo_matrix, diags
    n = len(P)
    c0, c1 = np.array(TESTA_ASSE[0]), np.array(TESTA_ASSE[1])
    ax = (c1 - c0) / np.linalg.norm(c1 - c0)
    t_ax = np.clip((P - c0) @ ax, -0.3, None)
    in_testa = (np.linalg.norm(P - c0 - np.outer(t_ax, ax), axis=1) < TESTA_RAGGIO + 0.08) & (P[:, 1] < -0.15) & (P[:, 2] > 0.95)
    fisso = muso & (P[:, 0] > xs[0] + ANGOLO) & (P[:, 0] < xs[-1] - ANGOLO)
    libero = in_testa & ~fisso
    w = np.where(in_testa | muso, w, 0.0).astype(np.float64)
    e = np.array([(ed.verts[0].index, ed.verts[1].index) for ed in bm.edges])
    e = e[lab[e[:, 0]].astype(int) * lab[e[:, 1]] >= 0]       # niente lati attraverso il taglio
    A = coo_matrix((np.ones(len(e) * 2), (np.r_[e[:, 0], e[:, 1]], np.r_[e[:, 1], e[:, 0]])), shape=(n, n)).tocsr()
    # soluzione esatta dell'equazione di Laplace (le iterazioni non arrivavano in fondo: restava una piega
    # netta sotto il mento)
    from scipy.sparse.linalg import spsolve
    L = (diags(np.asarray(A.sum(1)).ravel()) - A).tocsr()
    f = np.where(libero)[0]
    c = np.where(~libero)[0]
    w[f] = spsolve(L[f][:, f].tocsc(), -(L[f][:, c] @ w[c]))
    w = np.clip(w, 0.0, 1.0)
    print('PESI LISCI: liberi', int(libero.sum()))
    return w.astype(np.float32)


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
    w = liscia_pesi(bm, P, w, muso, lab, xs)
    # indice originale in un livello del bmesh: dopo le cancellazioni l'ordine dei vertici cambia
    orig = bm.verts.layers.int.new('orig')
    for v in bm.verts:
        v[orig] = v.index
    # facce a cavallo: dentro il muso, con vertici di etichette diverse
    via = [f for f in bm.faces if muso[[v.index for v in f.verts]].all() and len({lab[v.index] for v in f.verts}) > 1]
    print('FACCE TAGLIATE', len(via))
    orlo = bm.verts.layers.int.new('orlo')      # i vertici delle facce tagliate: il bordo della bocca
    for f in via:
        for v in f.verts:
            v[orlo] = 1
    bmesh.ops.delete(bm, geom=via, context='FACES_ONLY')
    sole = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=sole, context='VERTS')
    bm.verts.index_update(); bm.verts.ensure_lookup_table()
    tenuti = np.array([v[orig] for v in bm.verts])
    w = list(w[tenuti]); lab = list(lab[tenuti]); muso_t = muso[tenuti]
    nuovi = interno(bm, w, lab, muso_t, me, orlo)
    # i vertici nuovi possono finire nei posti lasciati liberi da quelli cancellati: i pesi viaggiano
    # in due livelli del bmesh e si rileggono dalla mesh nell'ordine giusto
    lp = bm.verts.layers.float.new('peso_mascella'); ll = bm.verts.layers.int.new('lato_bocca')
    for v in bm.verts:
        v[lp] = w[v.index]; v[ll] = lab[v.index]
    bm.to_mesh(me); bm.free()
    nv = len(me.vertices)
    pw = np.zeros(nv, np.float32); me.attributes['peso_mascella'].data.foreach_get('value', pw)
    pl = np.zeros(nv, np.int32); me.attributes['lato_bocca'].data.foreach_get('value', pl)
    return dict(peso=pw, lab=pl, linea=(xs, zs), interno=nuovi)


def _anelli_bordo(bm, muso_t):
    """I bordi del buco nel muso, come anelli ordinati di vertici."""
    bordo = [e for e in bm.edges if e.is_boundary and muso_t[e.verts[0].index] and muso_t[e.verts[1].index]]
    vicini = {}
    for e in bordo:
        a, b = e.verts
        vicini.setdefault(a, []).append(b); vicini.setdefault(b, []).append(a)
    fatti, anelli = set(), []
    for v0 in vicini:
        if v0 in fatti:
            continue
        anello, prec, v = [v0], None, v0
        fatti.add(v0)
        while True:
            succ = [x for x in vicini[v] if x is not prec and x not in fatti]
            if not succ:
                break
            prec, v = v, succ[0]
            anello.append(v); fatti.add(v)
        anelli.append(anello)
    anelli.sort(key=len, reverse=True)
    return anelli


def interno(bm, w, lab, muso_t, me, orlo):
    """L'interno della bocca dal bordo del buco: una sacca di carne (palato, gola, pavimento della bocca)
    che si allarga un poco dietro le labbra e si stringe verso la gola, più tre file di denti in più
    dietro quelli del modello (una di sopra, poi due di sopra e di sotto). I pesi della mascella dei vertici nuovi vanno da quelli del bordo verso
    0,3 in fondo: la sacca si tende quando la bocca si apre."""
    # il bordo del buco: i vertici di bordo nel muso, di sopra (testa) e di sotto (mascella), ordinati
    # lungo la cerniera e ricampionati: l'anello d'ingresso della sacca (sopra da sinistra a destra, sotto
    # da destra a sinistra), un poco dietro le labbra e un poco più largo del buco, così non si vede
    # lo stacco tra le labbra e la sacca
    bordo = [v for v in bm.verts if v[orlo] and v.link_faces]
    a0, a1 = CERNIERA
    asse = np.array((a1 - a0).normalized())
    Psu = np.array([v.co[:] for v in bordo if lab[v.index] > 0])
    Pgiu = np.array([v.co[:] for v in bordo if lab[v.index] < 0])
    Wsu = np.array([w[v.index] for v in bordo if lab[v.index] > 0])
    Wgiu = np.array([w[v.index] for v in bordo if lab[v.index] < 0])
    print('BORDO', len(Psu), 'sopra', len(Pgiu), 'sotto')
    tutti = np.concatenate([Psu, Pgiu])
    s_min, s_max = (tutti @ asse).min(), (tutti @ asse).max()
    M = 36
    def ricampiona(Q, W):
        sq = Q @ asse
        out, pesi = [], []
        for k in range(M):
            c = s_min + (s_max - s_min) * (k + 0.5) / M
            sel = np.abs(sq - c) < (s_max - s_min) / M
            if not sel.any():
                sel = np.argmin(np.abs(sq - c))
            out.append(np.atleast_2d(Q[sel]).mean(0)); pesi.append(float(np.mean(W[sel])))
        return np.array(out), np.array(pesi)
    su, wsu = ricampiona(Psu, Wsu)
    giu, wgiu = ricampiona(Pgiu, Wgiu)
    cen = np.concatenate([su, giu]).mean(0)
    B = np.concatenate([su, giu[::-1]])
    LB = np.array([1] * M + [-1] * M)
    WB = np.concatenate([wsu, wgiu[::-1]])     # il peso delle labbra lì accanto (verso gli angoli sfuma)
    rad = B - cen
    lat = np.outer(rad @ asse, asse)            # la parte lungo la cerniera (verso gli angoli)
    B = B + (rad - lat) * 0.30 + lat * 0.04 + np.array([0.0, 0.06, 0.0])   # più alta, non più larga
    n = len(B)
    sopra, sotto = su.mean(0), giu.mean(0)
    gola = cen + np.array([0.0, 0.30, -0.02])          # la gola: indietro, dentro la testa
    # slot dei materiali
    mats = {m.name: i for i, m in enumerate(me.materials)}
    def slot(nome, colore, rug):
        if nome not in mats:
            m = bpy.data.materials.new(nome); m.use_nodes = True
            bs = m.node_tree.nodes['Principled BSDF']
            bs.inputs['Base Color'].default_value = (*colore, 1); bs.inputs['Roughness'].default_value = rug
            me.materials.append(m); mats[nome] = len(me.materials) - 1
        return mats[nome]
    s_carne = slot('bocca_interno', (0.35, 0.06, 0.07), 0.3)
    s_denti = slot('denti', (0.62, 0.55, 0.42), 0.4)
    uv = bm.loops.layers.uv.active
    K = 6
    anelli_v = []
    nuovi = []
    for k in range(0, K + 1):
        t = k / K
        gonfio = 0.35 * math.sin(math.pi * min(t * 1.4, 1.0))     # la sacca si allarga dietro le labbra
        anello = []
        for i in range(n):
            b = B[i]
            radiale = b - cen
            fine = gola + radiale * 0.18
            p = b + (fine - b) * t + radiale * gonfio * (1 - t) * 0.6
            v = bm.verts.new(p)
            v.index = len(w)   # indice provvisorio nelle liste w e lab
            w.append(float(WB[i] * (1 - t) + 0.3 * t * (0.6 + 0.4 * WB[i])))
            lab.append(int(LB[i]))
            anello.append(v); nuovi.append(v)
        anelli_v.append(anello)
    asse_c = (cen + gola) / 2
    facce = []
    for k in range(K):
        for i in range(n):
            j = (i + 1) % n
            q = (anelli_v[k][i], anelli_v[k][j], anelli_v[k + 1][j], anelli_v[k + 1][i])
            try:
                f = bm.faces.new(q)
            except ValueError:
                continue
            f.material_index = s_carne
            for l, (ui, vi) in zip(f.loops, ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))):
                l[uv].uv = (ui / n, vi / K)
            facce.append(f)
    # la gengiva: dal bordo vero del buco all'anello d'ingresso della sacca. I due anelli si cuciono a
    # cerniera (lampo): il bordo si divide nei due angoli (gli estremi lungo la cerniera) in labbro di
    # sopra e di sotto, e ogni metà si cuce con la sua metà dell'anello, avanzando su quello dei due che
    # è più indietro in lunghezza. Così non resta nessuna fessura tra le labbra e la sacca (prima, a
    # ventaglio verso il vertice più vicino, agli angoli restavano lati scoperti e si vedeva il
    # corridoio attraverso la bocca)
    s_gengiva = slot('gengiva', (0.45, 0.12, 0.12), 0.35)
    lati_b = [e for e in bm.edges if e.is_boundary and e.verts[0][orlo] and e.verts[1][orlo]]
    vic = {}
    for e in lati_b:
        x_, y_ = e.verts
        vic.setdefault(x_, []).append(y_); vic.setdefault(y_, []).append(x_)
    # l'anello più lungo: il bordo del buco
    fatti, anelli_h = set(), []
    for v0 in vic:
        if v0 in fatti:
            continue
        an, prec, v = [v0], None, v0
        fatti.add(v0)
        while True:
            succ = [x for x in vic[v] if x is not prec and x not in fatti]
            if not succ:
                break
            prec, v = v, succ[0]
            an.append(v); fatti.add(v)
        anelli_h.append(an)
    H = max(anelli_h, key=len)
    print('BUCO', len(H), 'vertici; altri anelli', sorted(len(x) for x in anelli_h)[:-1])
    sH = np.array([np.array(v.co[:]) @ asse for v in H])
    i_min, i_max = int(np.argmin(sH)), int(np.argmax(sH))
    def tratto_h(i, j):
        out = [H[i]]
        while i != j:
            i = (i + 1) % len(H); out.append(H[i])
        return out
    c1, c2 = tratto_h(i_min, i_max), tratto_h(i_max, i_min)
    z1 = np.mean([v.co.z for v in c1]); z2 = np.mean([v.co.z for v in c2])
    h_su, h_giu = (c1, c2[::-1]) if z1 > z2 else (c2, c1[::-1])   # tutte e due da sinistra a destra
    def param(vs):
        P_ = np.array([v.co[:] for v in vs])
        l = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(P_, axis=0), axis=1))]
        return l / max(l[-1], 1e-9)
    gengive = 0
    def tri(t_):
        nonlocal gengive
        if len(set(t_)) < 3:
            return
        try:
            f = bm.faces.new(t_)
        except ValueError:
            return
        f.material_index = s_gengiva
        for l in f.loops:
            l[uv].uv = (0.5, 0.0)
        facce.append(f); gengive += 1
    def cerniera(A_, B_):
        ta, tb = param(A_), param(B_)
        i = j = 0
        while i < len(A_) - 1 or j < len(B_) - 1:
            if j == len(B_) - 1 or (i < len(A_) - 1 and ta[i + 1] <= tb[j + 1]):
                tri((A_[i], A_[i + 1], B_[j])); i += 1
            else:
                tri((A_[i], B_[j + 1], B_[j])); j += 1
    r_su = anelli_v[0][:M]                 # da sinistra a destra
    r_giu = anelli_v[0][M:][::-1]          # anche questa da sinistra a destra
    cerniera(h_su, r_su)
    cerniera(h_giu, r_giu)
    # gli angoli: il vertice d'angolo del buco con i due capi dell'anello
    tri((h_su[0], r_su[0], r_giu[0]))
    tri((h_su[-1], r_su[-1], r_giu[-1]))
    print('GENGIVA', gengive, 'triangoli')
    try:
        fondo = bm.faces.new(anelli_v[-1]); fondo.material_index = s_carne; facce.append(fondo)
        for l in fondo.loops:
            l[uv].uv = (0.5, 1.0)
    except ValueError:
        pass
    bm.normal_update()
    for f in facce:   # le normali guardano dentro la bocca (verso l'asse della sacca); carne liscia
        c = f.calc_center_median()
        if f.normal.dot(Vector(asse_c) - c) < 0:
            f.normal_flip()
        f.smooth = True
    # il fondo scuro: un ellissoide nero dentro la testa, dietro la bocca. Qualunque fessura rimasta tra
    # le labbra, i denti e la sacca mostra il buio della testa, non la luce del corridoio dietro di lui
    s_buio = slot('gola_buio', (0.01, 0.0, 0.0), 1.0)
    centro_b = Vector(gola) + Vector((0.0, -0.08, 0.02))
    r_b = Vector((0.22, 0.14, 0.13))
    nb_u, nb_v = 16, 10
    anelli_b = []
    for j in range(1, nb_v):
        th = math.pi * j / nb_v
        anello = []
        for i in range(nb_u):
            ph = 2 * math.pi * i / nb_u
            p = centro_b + Vector((r_b.x * math.sin(th) * math.cos(ph), r_b.y * math.sin(th) * math.sin(ph), r_b.z * math.cos(th)))
            v = bm.verts.new(p); v.index = len(w); w.append(0.15); lab.append(1)
            anello.append(v)
        anelli_b.append(anello)
    polo_su = bm.verts.new(centro_b + Vector((0, 0, r_b.z))); polo_su.index = len(w); w.append(0.15); lab.append(1)
    polo_giu = bm.verts.new(centro_b - Vector((0, 0, r_b.z))); polo_giu.index = len(w); w.append(0.15); lab.append(1)
    for j in range(len(anelli_b) - 1):
        for i in range(nb_u):
            f = bm.faces.new((anelli_b[j][i], anelli_b[j][(i + 1) % nb_u], anelli_b[j + 1][(i + 1) % nb_u], anelli_b[j + 1][i]))
            f.material_index = s_buio
    for i in range(nb_u):
        bm.faces.new((polo_su, anelli_b[0][(i + 1) % nb_u], anelli_b[0][i])).material_index = s_buio
        bm.faces.new((polo_giu, anelli_b[-1][i], anelli_b[-1][(i + 1) % nb_u])).material_index = s_buio
    # denti: una fila dietro il bordo, ogni 3 cm circa (con due, da sotto si vedevano lastre bianche)
    rng = np.random.default_rng(4)
    passo = 0.03
    def fila_denti(t_f, scala, sotto_anche, piega, rng, passo, solo_sotto=False):
        """Una fila di denti sulla sacca a t_f della sua profondità (0 il bordo, 1 la gola): le basi affondate
        nella carne, le punte verso l'asse della bocca, piegate verso la gola di [param piega]."""
        lung = 0.0
        quanti = 0
        kf = t_f * K
        k0 = min(int(kf), K - 1)
        for i in range(n):
            j = (i + 1) % n
            lung += float(np.linalg.norm(B[j] - B[i]))
            if lung < passo or (LB[i] <= 0 and not sotto_anche) or (LB[i] > 0 and solo_sotto):
                continue
            lung = 0.0
            if i % M < 3 or i % M > M - 4:     # niente denti negli angoli della bocca
                continue
            base = Vector(anelli_v[k0][i].co).lerp(Vector(anelli_v[k0 + 1][i].co), kf - k0)
            verso = Vector((sotto - sopra) if LB[i] > 0 else (sopra - sotto)).normalized()
            dentro = (Vector(gola) - base).normalized()
            # di sopra pendono giù, di sotto sono più corti e piegati verso la gola
            if LB[i] > 0:
                d = (verso * 0.85 + dentro * (0.3 + piega)).normalized()
            elif not sotto_anche:
                d = (verso * 0.55 + dentro * 0.7).normalized()
            else:
                # le file in più di sotto stanno dritte dietro i denti del modello (stese verso la gola, dal davanti
                # sembravano schegge sul fondo della bocca)
                d = (verso * 0.85 + dentro * (0.25 + piega * 0.5)).normalized()
            h = float(rng.uniform(0.05, 0.085)) * scala * (1.0 if LB[i] > 0 else (0.85 if sotto_anche else 0.6))
            r = float(rng.uniform(0.014, 0.022)) * scala
            # la base affonda nella gengiva (un terzo del raggio sotto la carne): non resta sospesa
            base = base - d * r * 0.35
            nuovi_t = _dente(bm, base, d, h, r, Vector(B[j]) - Vector(B[i]), s_denti, uv)
            for v in nuovi_t:
                v.index = len(w); w.append(float(w[anelli_v[k0][i].index])); lab.append(int(LB[i]))
            quanti += 1
        return quanti
    fila_denti(0.07, 0.85, False, 0.0, rng, passo)
    # le file in più dietro la prima, come uno squalo (l'utente, 23 ottobre: "più file di denti, 3D"): di
    # sopra e di sotto, più piccole e più piegate verso la gola man mano che vanno dentro
    rng2 = np.random.default_rng(5)
    for t_f, scala, piega in ((0.2, 0.78, 0.25), (0.34, 0.66, 0.45)):
        print('FILA', t_f, fila_denti(t_f, scala, False, piega, rng2, passo * 1.1), 'denti')
    # di sotto, sulla gengiva tra il labbro (i denti del modello) e l'ingresso della sacca: due file dritte, una
    # subito dietro i denti del modello e una più dentro (sulla sacca stavano troppo in alto, staccate dal labbro)
    P_lab = np.array([v.co[:] for v in h_giu])
    for f_g, scala in ((0.3, 0.62), (0.65, 0.52)):
        lung, quanti = 0.0, 0
        for i in range(M, n):
            j = (i + 1) % n
            lung += float(np.linalg.norm(B[j] - B[i]))
            if lung < passo * 1.1:
                continue
            lung = 0.0
            if i % M < 4 or i % M > M - 5:
                continue
            anello = Vector(anelli_v[0][i].co)
            lab_p = Vector(P_lab[int(np.argmin(np.linalg.norm(P_lab - np.array(anello[:]), axis=1)))])
            base = lab_p.lerp(anello, f_g)
            verso = Vector(sopra - sotto).normalized()
            dentro = (Vector(gola) - base).normalized()
            # piegati verso la gola: a bocca aperta la mascella gira in avanti e così restano dritti
            d = (verso * 0.7 + dentro * 0.65).normalized()
            h = float(rng2.uniform(0.04, 0.065)) * scala
            r = float(rng2.uniform(0.013, 0.02)) * scala
            base = base - d * r * 0.35
            # piatti lungo la cerniera (la direzione del bordo dell'anello qui li girava a caso)
            nuovi_t = _dente(bm, base, d, h, r, Vector(asse[:]), s_denti, uv)
            peso = float(WB[i])
            for v in nuovi_t:
                v.index = len(w); w.append(peso); lab.append(-1)
            quanti += 1
        print('FILA SOTTO', f_g, quanti, 'denti')
    return len(nuovi)


def _dente(bm, base, d, h, r, lato, s_denti, uv):
    """Dente di squalo: una lama triangolare spessa, appiattita lungo il bordo della bocca."""
    lato = (lato - d * lato.dot(d)).normalized()
    sp = d.cross(lato).normalized()
    pts = [base + lato * r, base + sp * r * 0.45, base - lato * r, base - sp * r * 0.45]
    punta = base + d * h
    vs = [bm.verts.new(p) for p in pts]
    vp = bm.verts.new(punta)
    for i in range(4):
        f = bm.faces.new((vs[i], vs[(i + 1) % 4], vp))
        f.material_index = s_denti
        if f.calc_center_median().__sub__(base).dot(f.normal) < 0:
            f.normal_flip()
        for l in f.loops:
            l[uv].uv = (0.5, 0.5)
    return vs + [vp]


def anteprima_aperta(ob, peso, gradi):
    """Ruota i vertici attorno alla cerniera secondo il peso (solo per i render di controllo)."""
    a, b = CERNIERA
    R = Matrix.Rotation(math.radians(gradi), 4, (b - a).normalized())
    for v, w in zip(ob.data.vertices, peso):
        if w > 0:
            p = Vector(v.co) - a
            v.co = a + p.lerp(R @ p, float(w))


def colora_pesi(ob, peso):
    me = ob.data
    ca = me.color_attributes.new('Peso', 'FLOAT_COLOR', 'POINT')
    for i, w in enumerate(peso):
        ca.data[i].color = (float(w), 0.15, 1 - float(w), 1)
    m = bpy.data.materials.new('pesi'); m.use_nodes = True
    a = m.node_tree.nodes.new('ShaderNodeAttribute'); a.attribute_name = 'Peso'
    m.node_tree.links.new(a.outputs['Color'], m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    vecchi = list(me.materials)
    me.materials.clear(); me.materials.append(m)
    return vecchi


def render(cartella, nome, viste):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 24; sc.cycles.use_denoising = True
    sc.render.resolution_x = 900; sc.render.resolution_y = 700
    if sc.world is None:
        sc.world = bpy.data.worlds.new('w')
    sc.world.use_nodes = True; sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.6
    cam = bpy.data.objects.get('cam') or bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    sc.camera = cam
    for k, (pos, tgt) in viste.items():
        cam.location = pos
        cam.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(cartella, f'{nome}_{k}.png')
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    cartella = sys.argv[-1]
    ob = carica()
    r = costruisci(ob)
    print('mascella: vertici con peso > 0.5:', int((r['peso'] > 0.5).sum()))
    print('CONTROLLO', len(r['peso']), len(ob.data.vertices), r['interno'])
    co = np.array([v.co[:] for v in ob.data.vertices])
    print('NUOVI bounds', co[-r['interno']:].min(0), co[-r['interno']:].max(0))
    if 'pesi' in sys.argv:
        vecchi = colora_pesi(ob, r['peso'])
        render(cartella, 'pesi', {'fronte': ((0.15, -2.2, 1.45), (0.12, -0.8, 1.4)),
                                  'lato': ((1.4, -1.6, 1.5), (0.1, -0.85, 1.35)),
                                  'sotto': ((0.2, -1.5, 0.75), (0.12, -0.85, 1.35))})
        ob.data.materials.clear()
        for m in vecchi:
            ob.data.materials.append(m)
    anteprima_aperta(ob, r['peso'], 50)
    # luce dall'alto davanti, come una lampada del corridoio
    l = bpy.data.objects.new('luce', bpy.data.lights.new('luce', 'AREA'))
    l.data.energy = 60; l.data.size = 0.6; l.location = (0.6, -2.0, 2.4)
    l.rotation_euler = (Vector((0.12, -0.9, 1.45)) - l.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(l)
    render(cartella, 'aperta', {'fronte': ((0.15, -2.2, 1.45), (0.12, -0.8, 1.4)),
                                'lato': ((1.4, -1.6, 1.5), (0.1, -0.85, 1.35))})
