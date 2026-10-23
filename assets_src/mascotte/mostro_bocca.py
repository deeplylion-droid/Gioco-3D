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
    nuovo_denti = 'denti' not in mats
    s_denti = slot('denti', (0.62, 0.55, 0.42), 0.4)
    if nuovo_denti:
        materiale_denti(me.materials[s_denti])
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
    # denti in più (l'utente, 23 ottobre: "più file di denti, 3D"; riscontro del coordinatore: non triangoli di
    # carta sparsi): denti di squalo veri (_dente_squalo: lama seghettata con spessore, piegata verso la gola, base
    # affondata), in file regolari lungo la curva della gengiva, fitti, ognuno un po' diverso. L'uv dice al
    # materiale (Godot: denti_squalo.gdshader) quanto è dentro la fila (x: 0 davanti, 1 in gola: più in ombra) e
    # dove si è sul dente (y: 0 la base nella gengiva, 1 la punta)
    rng = np.random.default_rng(4)

    def curva(P):
        """Una polilinea: (punto, tangente) a una frazione della lunghezza."""
        P = [Vector(p[:]) for p in P]
        l = [0.0]
        for a_, b_ in zip(P, P[1:]):
            l.append(l[-1] + (b_ - a_).length)
        def a(s_):
            x = s_ * l[-1]
            for k in range(len(P) - 1):
                if x <= l[k + 1] or k == len(P) - 2:
                    f = (x - l[k]) / max(l[k + 1] - l[k], 1e-9)
                    return P[k].lerp(P[k + 1], min(max(f, 0.0), 1.0)), (P[k + 1] - P[k]).normalized(), k + f
        return a, l[-1]

    def fila(P, pesi, alto, profondo, scala, piega, sopra_fila, largo_r=0.016):
        """Una fila lungo la polilinea P (con i pesi della mascella dei suoi punti), dagli angoli esclusi."""
        a, lung = curva(P)
        largo = 0.034 * scala                       # passo tra un dente e l'altro: fitti
        quanti = max(int(lung * 0.9 / largo), 3)
        fatti = 0
        for k in range(quanti):
            s_ = 0.05 + 0.9 * (k + 0.5) / quanti
            base, tang, ik = a(s_)
            i_ = min(int(ik), len(pesi) - 1)
            verso = Vector((sotto - sopra) if sopra_fila else (sopra - sotto)).normalized()
            dentro = (Vector(gola) - base).normalized()
            if sopra_fila:
                d = (verso * 0.85 + dentro * (0.3 + piega)).normalized()
            else:
                d = (verso * 0.7 + dentro * (0.55 + piega)).normalized()
            # ognuno un po' diverso, ma ordinati: grandezza e inclinazione di poco, verso gli angoli più piccoli
            ai_lati = 1.0 - 0.35 * abs(s_ - 0.5) * 2
            h = alto * scala * ai_lati * float(rng.uniform(0.88, 1.1))
            r = largo_r * scala * ai_lati * float(rng.uniform(0.92, 1.08))
            d = (d + tang * float(rng.uniform(-0.06, 0.06))).normalized()
            nuovi_t = _dente_squalo(bm, base, d, h, r, tang, dentro, profondo, s_denti, uv)
            for v in nuovi_t:
                v.index = len(w); w.append(float(pesi[i_])); lab.append(1 if sopra_fila else -1)
            fatti += 1
        return fatti
    def anello_tra(k0, f, metà):
        idx = list(range(M)) if metà == 'su' else list(range(M, n))
        P = [Vector(anelli_v[k0][i].co).lerp(Vector(anelli_v[k0 + 1][i].co), f) for i in idx]
        pesi = [w[anelli_v[k0][i].index] * (1 - f) + w[anelli_v[k0 + 1][i].index] * f for i in idx]
        return P, pesi
    # di sopra: tre file sulla sacca, dietro i denti del modello, sempre più piccole, piegate e in ombra
    for t_f, scala, piega, prof in ((0.07, 0.95, 0.0, 0.15), (0.2, 0.85, 0.2, 0.5), (0.34, 0.72, 0.4, 0.85)):
        kf = t_f * K
        k0 = min(int(kf), K - 1)
        P, pesi = anello_tra(k0, kf - k0, 'su')
        P = P[3:M - 3]; pesi = pesi[3:M - 3]
        print('FILA SOPRA', t_f, fila(P, pesi, 0.075, prof, scala, piega, True), 'denti')
    # di sotto: due file sulla gengiva tra il labbro (i denti del modello) e l'ingresso della sacca; i due bordi
    # si prendono alla stessa frazione della loro lunghezza (non il punto più vicino: le file venivano storte)
    a_lab, _ = curva([v.co for v in h_giu])
    a_ane, _ = curva([anelli_v[0][i].co for i in range(M, n)][::-1])
    pesi_giu = [w[anelli_v[0][i].index] for i in range(M, n)][::-1]
    for f_g, scala, prof in ((0.35, 0.8, 0.3), (0.7, 0.7, 0.65)):
        P = [a_lab(s_)[0].lerp(a_ane(s_)[0], f_g) for s_ in np.linspace(0.1, 0.9, 30)]
        pesi = [pesi_giu[min(int(s_ * len(pesi_giu)), len(pesi_giu) - 1)] for s_ in np.linspace(0.1, 0.9, 30)]
        print('FILA SOTTO', f_g, fila(P, pesi, 0.048, prof, scala, 0.1, False, largo_r=0.02), 'denti')
    return len(nuovi)


def _dente_squalo(bm, base, d, h, r, lato, dentro, profondo, s_denti, uv):
    """Un dente di squalo: lama triangolare seghettata con spessore, larga alla base (affondata per un quarto nella
    gengiva), piegata verso la gola. uv: x = [param profondo] (0 davanti, 1 in gola), y = 0 la base, 1 la punta."""
    lato = (lato - d * lato.dot(d)).normalized()
    sp = d.cross(lato).normalized()
    piega = dentro - d * dentro.dot(d)
    piega = piega.normalized() if piega.length > 1e-6 else sp
    inizio = base - d * h * 0.25
    LIV = 9
    livelli = []
    for k in range(LIV):
        u = k / LIV
        c = inizio + d * h * u + piega * h * 0.22 * u * u
        # i bordi seghettati: un dentino ogni livello (largo, un poco più stretto, largo...)
        w_ = r * (1.0 - u) ** 0.85 * (1.0 if k % 2 == 0 else 0.86)
        t_ = r * 0.38 * (1.0 - u) ** 0.9
        livelli.append(([bm.verts.new(c - lato * w_), bm.verts.new(c + sp * t_), bm.verts.new(c + lato * w_),
                         bm.verts.new(c - sp * t_)], u))
    punta = bm.verts.new(inizio + d * h + piega * h * 0.22)
    tutti = [punta]
    for (vs, u), (vs2, u2) in zip(livelli, livelli[1:]):
        for i in range(4):
            f = bm.faces.new((vs[i], vs[(i + 1) % 4], vs2[(i + 1) % 4], vs2[i]))
            f.material_index = s_denti
            for l_, uu in zip(f.loops, (u, u, u2, u2)):
                l_[uv].uv = (profondo, uu)
    vs, u = livelli[-1]
    for i in range(4):
        f = bm.faces.new((vs[i], vs[(i + 1) % 4], punta))
        f.material_index = s_denti
        for l_, uu in zip(f.loops, (u, u, 1.0)):
            l_[uv].uv = (profondo, uu)
    for vs, _ in livelli:
        tutti += vs
    # le normali verso fuori dal dente
    asse_d = d
    for f in {f for v in tutti for f in v.link_faces}:
        c = f.calc_center_median()
        centro = inizio + asse_d * asse_d.dot(c - inizio)
        if f.normal.dot(c - centro) < 0:
            f.normal_flip()
        f.smooth = True
    return tutti


def materiale_denti(m):
    """Il materiale dei denti in più per i render di Blender, come denti_squalo.gdshader di Godot: avorio sporco,
    la punta più chiara, la base scura e rosata nella gengiva, le file più dentro in ombra (uv x)."""
    nt = m.node_tree
    bs = nt.nodes['Principled BSDF']
    uvn = nt.nodes.new('ShaderNodeUVMap')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(uvn.outputs['UV'], sep.inputs[0])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    e = ramp.color_ramp.elements
    e[0].position = 0.0; e[0].color = (0.30, 0.10, 0.09, 1)
    e[1].position = 0.38; e[1].color = (0.44, 0.37, 0.29, 1)
    e.new(1.0).color = (0.62, 0.56, 0.46, 1)
    nt.links.new(sep.outputs['Y'], ramp.inputs[0])
    ombra = nt.nodes.new('ShaderNodeMapRange')
    ombra.inputs['To Min'].default_value = 1.0; ombra.inputs["To Max"].default_value = 0.42
    nt.links.new(sep.outputs['X'], ombra.inputs['Value'])
    mul = nt.nodes.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    nt.links.new(ramp.outputs['Color'], mul.inputs[6])
    nt.links.new(ombra.outputs['Result'], mul.inputs[7])
    nt.links.new(mul.outputs[2], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = 0.38


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
