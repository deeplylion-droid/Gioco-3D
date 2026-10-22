"""Sala principale dell'acquapark (capitolo 1, vertical slice): costruzione, luci, render, export.

Layout da docs/livello/capitolo1.md (mappa del percorso A): una sola grande sala sotto la cupola di
vetro. Coordinate in metri, Z in alto; +Y = prua (nord), +X = dritta (est).
  - sala: x -20..20, y -20..24; soffitto a 11,5 m. Il soppalco (galleria a 4,0 m tutto intorno) è stato
    tolto il 16 ottobre (scelta dell'utente C1): plafoniere, fari, cartelloni e altoparlanti sono sulle pareti
  - cupola: centro (0, 5), raggio 13 m, chiave a 18 m
  - piscina a onde VUOTA: x -7..7, y -5..13; parte profonda (2 m) a sud, spiaggia a nord;
    pozza torbida sul fondo intorno allo scarico (0, -2)
  - monumento della statua: piedistallo a gradoni sul piazzale sud, sull'asse dell'ingresso, 10 m
    davanti alla porta: entrando la si vede intera con la cupola sopra (vedi PIEDISTALLO)
  - ingresso dagli spogliatoi: vano 1,2 x 2,2 m con porta stagna aperta nella parete sud (x = 0)
  - area bimbi a nord-ovest, disposizione 1 (16 ottobre): struttura di gioco con il secchio gigante
    nell'angolo, vasca piccola sotto lo scivolo, vasca a scacchi con la fossa della tappa 8, due funghi
  - vasca d'arrivo a ovest (x -16..-9, y -7..3)
  - sala della torre a est (versione 2, 16 ottobre): varco nella parete est (y 12..18) chiuso dal
    portone scorrevole dipinto; dietro solo il guscio. La torre e gli scivoli di prima non sono più
    nella sala (si rifanno dopo, con una proposta a parte): le funzioni restano qui sotto, non usate

Uso (dalla radice del repository):
  PY=/home/user/tools/blender-venv/bin/python
  nice -n 10 $PY tools/blender/ambiente_sala.py --render S04_statua,S06_pozza --uscita <cartella>
  opzioni: --larghezza 1600 --altezza 900 --campioni 64 --fili 3 --rapida --senza-oggetti
           --glb <cartella>   (esporta sala_architettura.glb e sala_oggetti.glb)
           --blend file.blend (salva la scena)
"""
import math, os, sys, tempfile
import bpy, bmesh
from mathutils import Vector, Euler, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import ambiente_kit as K  # noqa: E402
import ambiente_dettagli as D  # noqa: E402

RADICE = K.RADICE
OGGETTI = os.path.join(RADICE, 'assets_src', 'ambiente', 'oggetti')
# oggetti di scena in qualità alta (Meshy meshy-7.1, come il pezzo campione): se c'è il GLB HQ si usa quello
OGGETTI_HQ = os.path.join(RADICE, 'assets_src', 'ambiente', 'oggetti_hq')
PANCA_HQ = os.path.join(RADICE, 'assets_src', 'ambienti_interni', 'meshy_hq', 'panca.glb')   # la panca degli spogliatoi
# misure degli oggetti nuovi (gli altri sono in assets_src/ambiente/oggetti/meshy_oggetti.py)
PICCOLI_1K = {'tubi_galleggianti'}   # lunghi ma sottili: bastano le texture da 1K come paperella, pallone, ciambella
MISURE_HQ = {'colonnina_ottone': ('z', 1.0), 'cestino_pesce': ('z', 1.0), 'cartello_pavimento_bagnato': ('z', 0.62),
             'panca': ('lungo', 2.0), 'lampione_braccio': ('z', 4.8), 'secchio_gigante': ('z', 1.6)}
PALETTE_SALA = 'sala_a'

# ----------------------------------------------------------------------------- misure della sala
X0, X1, Y0, Y1 = -20.0, 20.0, -20.0, 24.0   # la parete sud è a -20: piazzale del monumento
Z_GAL, SP_GAL, PROF_GAL = 4.0, 0.3, 3.0
Z_SOFF = 11.5
CUPOLA = dict(cx=0.0, cy=5.0, r=13.0, tamburo=1.0, freccia=5.5)
PISCINA = dict(x0=-7.0, x1=7.0, y0=-5.0, y1=13.0, prof=2.0, y_pendenza=1.0, scarico=(0.0, -2.0))
# buco nel fondo della piscina sotto il portello, verso il pozzo della camera delle onde (x0, y0, x1, y1):
# in Godot x +-0,64 e z da 1,36 a 2,64; il pozzo di ambienti-1 sta sotto, centrato in (0; -2,25; 2,0) Godot
BUCO_POZZO = (-0.64, -2.64, 0.64, -1.36)
VASCA_ARRIVO = dict(x0=-16.0, x1=-9.0, y0=-7.0, y1=3.0, prof=1.1, acqua=-0.22)
# piedistallo della statua (vuoto: la medusa la mette il gruppo "medusa")
# monumento: gradoni (z1, z2), tamburo col fregio fino a z3, cornice e piano a h; cordone a r_cordone
# piano: raggio 1,85 (la medusa appoggia i tentacoli fino a 1,55 m, vedi assets_src/medusa/godot/LEGGIMI.md)
PIEDISTALLO = dict(cx=0.0, cy=-10.0, r_base=2.6, r_gradino=2.2, r_tamburo=1.75, r_piano=1.88,
                   z1=0.28, z2=0.56, z3=1.03, h=1.15, z_pulsante=0.8, r_cordone=3.0)
RINGHIERA_H_SALA = 1.05
# VASCA SOLLEVATA al centro (deciso dall'utente il 15 ottobre: sostituisce il monumento, che resta per
# dopo con --monumento). Pianta esterna 6 x 4,5 m con angoli r 0,5; bordo (coping) largo 0,30 con il
# toro esterno, cima a 1,0 m; acqua a 0,88; fondo a 0. La medusa si affaccia sul lato verso l'ingresso.
VASCA_CENTRALE = dict(cx=0.0, cy=-10.0, lx=6.0, ly=4.5, r=0.5, h=1.0, coping=0.30, acqua=0.88,
                      cordone=1.3, z_pulsante=0.62)
CENTRO = {'modo': 'vasca'}   # 'vasca' (di serie) oppure 'monumento' (la statua, per più avanti)
# area bimbi, disposizione 1 (scelta dall'utente il 16 ottobre): la struttura nell'angolo nord-ovest
# (dove c'era il soppalco) con la scala verso chi arriva; lo scivolo scende nella vasca piccola
STRUTTURA = dict(cx=-14.6, cy=19.6)
# fossa dello scarico di compensazione rotto attaccata al lato sud della VascaBimbi1 (tappa 8, "lei sbuca
# dal bordo"): pianta x0..x1, y0..y1 (Blender; in Godot x -14,8..-12,3 e z -8,0..-6,0) con l'angolo sud-ovest
# tagliato a 45 gradi ('taglio'): lì il bordo piastrellato regge la medusa affacciata, rivolta a sud-ovest.
# Fondo a -3,0; piastrelle fino a -0,6, poi cemento grezzo; in fondo il condotto verso est.
FOSSA_BIMBI = dict(x0=-14.8, x1=-12.3, y0=6.0, y1=8.0, taglio=1.0, fondo=-3.0, piastrelle=-0.6, bordo=0.3,
                   h_bordo=0.45, acqua_piena=0.42, condotto=dict(y=7.0, z=-2.3, r=0.6, x_fine=-8.8))
# vasche basse dell'area bimbi: (x0, y0, x1, y1) del bordo esterno
VASCHE_BASSE = [(-15.1, 7.7, -10.1, 11.5), (-11.3, 16.5, -7.9, 19.9)]
VASCA_BIMBI_2 = dict(cx=-9.6, cy=18.2, lato=2.8, acqua=0.22)   # sotto la fine dello scivolo
# dove stavano struttura e vasca piccola fino al 15 ottobre: servono solo a tenere le pozzanghere dov'erano
# (stessi numeri casuali); quelle che finiscono sotto i pezzi nuovi si tolgono dopo
STRUTTURA_15_OTTOBRE = dict(cx=-13.0, cy=16.0)
VASCHE_BASSE_15_OTTOBRE = [(-15.1, 7.7, -10.1, 11.5), (-17.0, 10.7, -13.6, 14.1)]
# oggetti di scena tolti con la disposizione 1 dell'area bimbi (16 ottobre): giocattoli sparsi nell'area e
# sulla strada della scia rosa (tappa 8), i cannoncini, la balena della vasca piccola. I nomi degli altri
# oggetti non cambiano (il numero nel nome resta quello di prima).
TOGLI_OGGETTI = {'ogg_balena_gonfiabile_sgonfia_26', 'ogg_cannoncino_acqua_29', 'ogg_cannoncino_acqua_30',
                 'ogg_cannoncino_acqua_31', 'ogg_cartello_pavimento_bagnato_92', 'ogg_cestino_pesce_87',
                 'ogg_lettino_plastica_75', 'ogg_orsacchiotto_grande_35', 'ogg_pallone_spiaggia_33',
                 'ogg_pallone_spiaggia_53', 'ogg_pallone_spiaggia_67', 'ogg_paperella_gigante_32',
                 'ogg_paperella_gigante_34', 'ogg_paperella_gigante_60', 'ogg_tubi_galleggianti_46'}
# funghi-fontana nella piazza: (x, y, rotazione, scala)
FUNGHI = [(-17.8, 12.2, 20, 1.0), (-12.2, 14.4, 75, 0.75)]
# pulsante della botola, versione A (16 ottobre): centro del fungo sulla parete sud, tra due bocchette
PULSANTE_BOTOLA = dict(x=2.25, y=-5.0, z=-1.12)
# sala della torre (versione 2, 16 ottobre): dietro la parete est, varco con il portone scorrevole.
# Per ora solo il guscio della sala; torre e scivoli nuovi si propongono a parte.
SALA_TORRE = dict(cy=15.0, largo=6.0, alto=5.0, x1=X1 + 20.0, y0=4.0, y1=26.0, h=14.0)
# il portone della sala della torre si apre del tutto (prova del 19 ottobre): scorre verso sud di tutta la sua
# larghezza (6,3 m) più 10 cm. Lungo la corsa il muro est resta libero: panca, plafoniera calda, luce d'emergenza
# e il neon che c'erano sono stati spostati (vedi corsa_portone).
CORSA_PORTONE = 6.4
# telecamera di sorveglianza del monitor della sala pompe (sul muro sud, prima era sul soppalco)
TELECAMERA_MONITOR = dict(x=-5.0, z=5.3, mira=(0.0, -11.0, 1.1))
TORRE = dict(cx=13.5, cy=17.5, lato=6.0, piani=(3.0, 6.0, 8.6))
SPIRALE = dict(cx=8.6, cy=10.6, r=2.5)   # pennone dello scivolo a spirale (il tubo dell'inseguimento)
SCIVOLO_INSEGUIMENTO_R = 0.8             # raggio interno del tubo dell'inseguimento (Ø 1,6 m)
# vano verso gli spogliatoi nel muro sud (lo chiede il gioco): luce 1,2 x 2,2 m, x da -0,6 a 0,6
VANO = dict(cx=0.0, luce=1.2, h=2.2)
# varco della serranda del magazzino dei gonfiabili (tappa 7, ambienti-1, 16 ottobre): angolo sud-ovest,
# modulo da x -16 a -14 del muro sud, luce 1,8 x 2,5 m. Dietro c'è il magazzino (raccordo.gltf dei tecnici).
VANO_SERRANDA = dict(cx=-15.0, luce=1.8, h=2.5)
# lastre della cupola rotte (costolone k da 0 a 31, anello j da 0 = tamburo a 6 = oculo): lì piove dentro
LASTRE_ROTTE = {(3, 2), (11, 4), (12, 4), (20, 1), (27, 5), (7, 1), (24, 1), (16, 0)}


_CONTA = {}


def un(nome):
    """Nome unico (Blender aggiunge .001 ai doppioni e Godot non riconoscerebbe più -colonly)."""
    _CONTA[nome] = _CONTA.get(nome, 0) + 1
    return f'{nome}_{_CONTA[nome]}'


def metti(ob, pos, rot_z_gradi=0.0):
    ob.location = Vector(pos)
    ob.rotation_euler = Euler((0, 0, math.radians(rot_z_gradi)))
    for ch in ob.children:
        ch.hide_render = True
    return ob


def unisci(oggetti, nome):
    """Unisce più oggetti in uno solo, con trasformazioni applicate (nodo in identità).
    Le collisioni figlie restano figlie, ma con la posizione 'cotta' nei vertici: così nel GLB
    non dipendono da nessuna matrice (bug delle collisioni ammucchiate intorno all'origine)."""
    oggetti = [o for o in oggetti if o is not None]
    if not oggetti:
        return None
    bpy.context.view_layer.update()          # matrix_world aggiornate dopo metti()
    figli = []
    for o in oggetti:
        for ch in list(o.children):
            figli.append((ch, ch.matrix_world.copy()))
            ch.parent = None
    bpy.ops.object.select_all(action='DESELECT')
    for o in oggetti:
        o.select_set(True)
    bpy.context.view_layer.objects.active = oggetti[0]
    if len(oggetti) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = nome
    ob.data.name = nome
    for ch, mw in figli:
        if ch.data.users > 1:
            ch.data = ch.data.copy()
        ch.data.transform(mw)                 # vertici in coordinate della sala
        ch.matrix_parent_inverse = Matrix.Identity(4)
        ch.parent = ob
        ch.matrix_basis = Matrix.Identity(4)
        ch.hide_render = True
    return ob


def controlla_collisioni(oggetti):
    """Ogni collisione deve toccare geometria visibile: si costruisce una griglia di celle da 0,5 m
    occupate dai vertici delle mesh visibili e si verifica che il riquadro di ogni collisione ne
    contenga almeno una. Restituisce l'elenco delle collisioni sospette."""
    import numpy as np
    bpy.context.view_layer.update()
    celle = set()
    vis = [o for o in oggetti if o.type == 'MESH' and '-col' not in o.name and '-convcol' not in o.name]
    for o in vis:
        mw = np.array(o.matrix_world)
        co = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get('co', co)
        co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
        for c in np.unique(np.floor(co / 0.5).astype(np.int64), axis=0):
            celle.add(tuple(c))
    sospette = []
    for o in oggetti:
        for ch in o.children_recursive:
            if '-colonly' not in ch.name and '-convcolonly' not in ch.name:
                continue
            mw = np.array(ch.matrix_world)
            co = np.empty(len(ch.data.vertices) * 3)
            ch.data.vertices.foreach_get('co', co)
            co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
            lo = np.floor(co.min(axis=0) / 0.5).astype(int) - 1
            hi = np.floor(co.max(axis=0) / 0.5).astype(int) + 1
            trovata = False
            for x in range(lo[0], hi[0] + 1):
                for y in range(lo[1], hi[1] + 1):
                    for z in range(lo[2], hi[2] + 1):
                        if (x, y, z) in celle:
                            trovata = True
                            break
                    if trovata:
                        break
                if trovata:
                    break
            if not trovata:
                sospette.append(ch.name)
    return sospette


def rumore(x, y, s=1.0):
    """Rumore morbido deterministico (somma di seni) 0..1, per lo sporco dei vertici."""
    v = (math.sin(x * 0.37 * s + 1.3) * math.sin(y * 0.29 * s + 0.7) +
         0.5 * math.sin(x * 0.91 * s + y * 0.63 * s + 2.1) +
         0.25 * math.sin(x * 2.3 * s - y * 1.7 * s + 0.4))
    return 0.5 + 0.5 * v / 1.75


# ----------------------------------------------------------------------------- pavimenti e soffitti

def pavimento_regione(mats, x0, x1, y0, y1, buchi=(), passo=0.25, z=0.0, nome='sala_pavimento', passo_col=0.5,
                      esatti=()):
    """Pavimento unico a celle di 'passo' metri (una piastrella antiscivolo da 25 cm), con buchi
    rettangolari (vasche). Un solo materiale: sporco e umidità sono nei colori dei vertici in spazio
    mondo (sfumati, niente chiazze a quadretti) e l'acqua vera sta nelle pozzanghere. Collisione
    trimesh a parte, più rada (passo_col), con gli stessi buchi."""
    def linee(a0, a1, p, extra):
        v = [round(a0 + i * p, 4) for i in range(int(round((a1 - a0) / p)) + 1)]
        return sorted(set(v + [round(e, 4) for e in extra if a0 < e < a1]))
    def celle(p):
        # buchi esatti (per esempio la fossa dell'area bimbi): i loro bordi diventano linee della griglia
        xs = linee(x0, x1, p, [e for r in esatti for e in (r[0], r[2])])
        ys = linee(y0, y1, p, [e for r in esatti for e in (r[1], r[3])])
        out = []
        for i in range(len(xs) - 1):
            for j in range(len(ys) - 1):
                a, b, a2, b2 = xs[i], ys[j], xs[i + 1], ys[j + 1]
                cx, cy = (a + a2) / 2, (b + b2) / 2
                if any(bx0 < cx < bx1 and by0 < cy < by1 for bx0, by0, bx1, by1 in list(buchi) + list(esatti)):
                    continue
                out.append((a, b, a2, b2))
        return out
    c = K.Costruttore(mats)
    for (a, b, a2, b2) in celle(passo):
        c.faccia([(a, b, z), (a2, b, z), (a2, b2, z), (a, b2, z)], 'pavimento')
    ob = c.crea(nome)
    D.colora(ob, D.sporco_pavimento)
    cc = K.Costruttore(mats)
    for (a, b, a2, b2) in celle(passo_col):
        cc.faccia([(a, b, z), (a2, b, z), (a2, b2, z), (a, b2, z)], 'pavimento')
    col = cc.crea(nome + '-colonly')
    col.parent = ob
    col.hide_render = True
    return ob


def soffitto_con_foro(mats, x0, x1, y0, y1, z, cx, cy, r, mat='intonaco_alto', nome='sala_soffitto', seg=128):
    """Soffitto piano (normale -z) con un foro circolare per la cupola."""
    c = K.Costruttore(mats)
    angoli = sorted(set([2 * math.pi * k / seg for k in range(seg)] +
                        [math.atan2(py - cy, px - cx) % (2 * math.pi) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]))
    def bordo(t):
        dx, dy = math.cos(t), math.sin(t)
        ts = []
        for (px, d) in ((x0, dx), (x1, dx)):
            if abs(d) > 1e-9:
                ts.append((px - cx) / d)
        for (py, d) in ((y0, dy), (y1, dy)):
            if abs(d) > 1e-9:
                ts.append((py - cy) / d)
        tt = min(t_ for t_ in ts if t_ > 0)
        return (cx + dx * tt, cy + dy * tt, z)
    n = len(angoli)
    for k in range(n):
        t0, t1 = angoli[k], angoli[(k + 1) % n]
        a0 = (cx + math.cos(t0) * r, cy + math.sin(t0) * r, z)
        a1 = (cx + math.cos(t1) * r, cy + math.sin(t1) * r, z)
        c.faccia([a0, bordo(t0), bordo(t1), a1][::-1], mat)
    return c.crea(nome)


# ----------------------------------------------------------------------------- pareti e galleria

def lineare(hexa):
    """Colore sRGB '#rrggbb' -> lineare (Blender lavora in lineare)."""
    c = [int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def materiali_nuovi(mats):
    """Materiali dei pezzi scelti dall'utente il 16 ottobre (pulsante A della botola, portone e guscio della
    sala della torre): le tinte unite delle proposte approvate e le due texture disegnate di
    ambiente_disegni.py (strisce gialle e nere, portone con la torre dipinta)."""
    import ambiente_disegni as DIS
    DIS.disegna_tutto()
    for nome, hexa, rough, metallo, emissione in (
            ('pulsante_rosso', '#d01810', 0.22, 0.0, 0.0), ('giallo_sicurezza', '#f2b705', 0.5, 0.0, 0.0),
            ('nero_opaco', '#141414', 0.6, 0.0, 0.0), ('faro_giallo', '#ffb300', 0.25, 0.0, 6.0),
            ('faro_rosso', '#ff2a10', 0.25, 0.0, 6.0), ('acciaio_portone', '#3b4043', 0.55, 0.6, 0.0),
            ('stanza_muro', '#4d5652', 0.85, 0.0, 0.0), ('stanza_soffitto', '#2a2e2d', 0.9, 0.0, 0.0)):
        if nome in mats.cache:
            continue
        m = mats._semplice(nome, lineare(hexa), rough, metallo)
        if emissione > 0:
            b = m.node_tree.nodes['Principled BSDF']
            b.inputs['Emission Color'].default_value = (*lineare(hexa), 1)
            b.inputs['Emission Strength'].default_value = emissione
        mats.cache[nome] = m
    for nome, file, rough, metallo in (('strisce', DIS.percorso('strisce'), 0.5, 0.2),
                                        ('portone', DIS.percorso('portone'), 0.6, 0.3)):
        if nome in mats.cache:
            continue
        m, nt, b = mats._base(nome)
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(file, check_existing=True)
        nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
        nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
        b.inputs['Roughness'].default_value = rough
        b.inputs['Metallic'].default_value = metallo
        mats.cache[nome] = m
        mats.lati[nome] = 1.0


def calotta(c, centro, asse, r, h, mat, seg=32, anelli=8):
    """Calotta (mezzo ellissoide) con la base in 'centro' e la cima verso 'asse'."""
    C = Vector(centro); a = Vector(asse).normalized()
    u = a.orthogonal().normalized(); v = a.cross(u)
    for i in range(anelli):
        t0, t1 = (math.pi / 2) * i / anelli, (math.pi / 2) * (i + 1) / anelli
        r0, r1 = r * math.cos(t0), r * math.cos(t1)
        h0, h1 = h * math.sin(t0), h * math.sin(t1)
        for j in range(seg):
            p0, p1 = 2 * math.pi * j / seg, 2 * math.pi * (j + 1) / seg
            d0 = u * math.cos(p0) + v * math.sin(p0); d1 = u * math.cos(p1) + v * math.sin(p1)
            q = [C + a * h0 + d0 * r0, C + a * h0 + d1 * r0, C + a * h1 + d1 * r1, C + a * h1 + d0 * r1]
            if r1 < 1e-6:
                q = q[:3]
            c.faccia([tuple(p) for p in q], mat, liscia=True)


def con_perno(ob, perno):
    """Porta l'origine dell'oggetto nel punto 'perno' (coordinate della sala) senza spostare la geometria:
    nel GLB il nodo sta lì, e lì gira o scorre. Le collisioni figlie si aggiungono dopo, in coordinate locali."""
    ob.data.transform(Matrix.Translation(-Vector(perno)))
    ob.location = Vector(perno)
    return ob


def varco_torre():
    """Varco della sala della torre nella parete est: (y iniziale, y finale, altezza)."""
    T = SALA_TORRE
    return T['cy'] - T['largo'] / 2, T['cy'] + T['largo'] / 2, T['alto']


def corsa_portone():
    """Il tratto del muro est (y iniziale, y finale) che il portone aperto occupa, con il suo binario."""
    T = SALA_TORRE
    ya = T['cy'] - T['largo'] / 2 - 0.15
    return ya - CORSA_PORTONE - 0.1, ya


def pulsante_botola(mats):
    """Pulsante della botola, versione A (scelta dall'utente il 16 ottobre): cassetta gialla sulla parete
    sud della piscina (tra due bocchette), fungo rosso grosso (Ø 50 cm, sporge 48 cm dalla parete) e sopra
    il lampeggiante (giallo quando la piscina è vuota, verde quando la botola si apre: lo decide il gioco).
    Restituisce i tre nodi e i dati per il gioco:
      sala_pulsante_portello_cassetta  fisso: cassetta, piastra, bulloni, collare, base e gabbia del
                                       lampeggiante; la sua collisione copre anche il fungo
      sala_pulsante_portello           il fungo (gambo e testa) con il perno sul collare: si preme lungo il
                                       suo -Z di Godot, come il pulsante di prima (stesso nome del nodo)
      sala_lampeggiante_portello       il vetro del lampeggiante, con il perno alla sua base"""
    B = PULSANTE_BOTOLA
    x, y, z = B['x'], B['y'], B['z']
    yf = y + 0.21                                    # fronte della cassetta
    c = K.Costruttore(mats)
    c.scatola_smussata((x - 0.33, y, z - 0.5), (x + 0.33, yf, z + 0.47), 'giallo_sicurezza', s=0.025)
    c.scatola((x - 0.27, yf, z - 0.27), (x + 0.27, yf + 0.012, z + 0.27), 'nero_opaco')
    for (bx, bz) in ((x - 0.28, z - 0.43), (x + 0.28, z - 0.43), (x - 0.28, z + 0.4), (x + 0.28, z + 0.4)):
        c.cilindro((bx, yf, bz), (bx, yf + 0.012, bz), 0.016, 'inox', seg=8)
    c.cilindro((x, yf + 0.012, z), (x, yf + 0.07, z), 0.14, 'nero_opaco', seg=32)          # collare
    yb, zb = (y + yf) / 2, z + 0.47                  # lampeggiante sulla cassetta
    c.cilindro((x, yb, zb), (x, yb, zb + 0.07), 0.13, 'nero_opaco', seg=32)
    for k in range(4):   # gabbia
        a = math.radians(45 + 90 * k)
        d = Vector((math.cos(a), math.sin(a), 0))
        P = Vector((x, yb, zb + 0.07))
        c.tubo([tuple(P + d * 0.12), tuple(P + d * 0.12 + Vector((0, 0, 0.16))), tuple(P + d * 0.08 + Vector((0, 0, 0.26))),
                tuple(P + Vector((0, 0, 0.29)))], 0.007, 'nero_opaco', seg=6)
    c.toro((x, yb, zb + 0.16), (0, 0, 1), 0.12, 0.007, 'nero_opaco', seg=32, seg_r=4)
    cassetta = c.crea('sala_pulsante_portello_cassetta')
    K.collisione_scatola('pulsante_portello', (x - 0.33, y, z - 0.5), (x + 0.33, yf + 0.25, z + 0.47), padre=cassetta)
    # il fungo, in coordinate locali come pulsante(): il perno sul collare, la testa verso -y (girato di 180
    # gradi guarda la piscina; in Godot la testa è sul +Z locale e si preme verso -Z)
    f = K.Costruttore(mats)
    f.cilindro((0, 0, 0), (0, -0.06, 0), 0.075, 'inox', seg=24)                          # gambo
    f.disco((0, -0.06, 0), (0, 1, 0), 0.25, 'pulsante_rosso', seg=48)
    f.cilindro((0, -0.06, 0), (0, -0.09, 0), 0.25, 'pulsante_rosso', seg=48, tappi=False)
    f.toro((0, -0.09, 0), (0, -1, 0), 0.235, 0.015, 'pulsante_rosso', seg=48, seg_r=6)
    calotta(f, (0, -0.09, 0), (0, -1, 0), 0.25, 0.11, 'pulsante_rosso', seg=48)
    fungo = f.crea('sala_pulsante_portello')
    fungo.location = (x, yf + 0.07, z)
    fungo.rotation_euler = Euler((0, 0, math.pi))
    v = K.Costruttore(mats)
    v.cilindro((0, 0, 0), (0, 0, 0.15), 0.105, 'faro_giallo', seg=32, tappi=False)
    calotta(v, (0, 0, 0.15), (0, 0, 1), 0.105, 0.1, 'faro_giallo', seg=32)
    vetro = v.crea('sala_lampeggiante_portello')
    vetro.location = (x, yb, zb + 0.07)
    testa = (x, yf + 0.07 + 0.2, z)
    dati = dict(
        nota=("pulsante della botola, versione A (16 ottobre): fungo rosso Ø 50 cm su una cassetta gialla nella parete "
              "sud della piscina, tra due bocchette; sopra il lampeggiante (vetro giallo, il gioco lo fa verde)"),
        fungo=dict(nodo='sala_pulsante_portello', perno_godot=a_godot(tuple(fungo.location)), verso_godot=[0, 0, -1],
                   corsa=0.025, nota="si preme come prima: _press_with lo sposta di 2,5 cm lungo il suo -Z locale (verso la parete)"),
        bersaglio_getto=dict(centro_testa_godot=a_godot((x, yf + 0.2, z)), fronte_testa_godot=a_godot(testa), raggio_testa=0.25,
                             nota="per il WaterButton PulsantePortello: centro sulla testa del fungo, raggio circa 0,26"),
        cassetta=dict(nodo='sala_pulsante_portello_cassetta', collisione='pulsante_portello (copre anche il fungo)'),
        lampeggiante=dict(nodo='sala_lampeggiante_portello', vetro_centro_godot=a_godot((x, yb, zb + 0.2)),
                          luce_godot=a_godot((x, yb + 0.25, zb + 0.25)),
                          nota=("il vetro ha il materiale M_amb_faro_giallo (emissivo): per il verde basta un altro materiale o "
                                "l'emissione cambiata. Nelle proposte la luce era una OmniLight3D in luce_godot, energia 4, raggio 7, "
                                "attenuazione 1,3, con le ombre")))
    return [cassetta, fungo, vetro], dati


def portone_torre(mats):
    """Sala della torre, versione 2 (scelta dall'utente il 16 ottobre): portone scorrevole davanti al varco
    della parete est, lamiera gialla con la torre dipinta, binario in alto, bande a strisce ai lati e il
    lampeggiante rosso sopra. Senza l'insegna sopra (nota dell'utente: "basta il cancello con il suo
    disegno"). Restituisce i tre nodi e i dati per il gioco:
      sala_portone_torre          l'anta con i carrelli e il maniglione; perno al centro della base. Si apre
                                  scorrendo verso sud (-y qui, +Z in Godot) di CORSA_PORTONE (6,4 m: del tutto),
                                  fino alla fine del binario
      sala_portone_torre_telaio   fisso: binario con le staffe, bande a strisce sugli stipiti, base del lampeggiante
      sala_lampeggiante_torre     il vetro rosso del lampeggiante, perno alla sua base"""
    T = SALA_TORRE
    cy, w, h = T['cy'], T['largo'], T['alto']
    x = X1 - 0.12                                   # retro dell'anta (verso il muro)
    ya, yb = cy - w / 2 - 0.15, cy + w / 2 + 0.15
    corsa = CORSA_PORTONE
    c = K.Costruttore(mats)
    c.scatola((x - 0.08, ya, 0.06), (x, yb, h + 0.1), 'acciaio_portone')
    # faccia dipinta verso la sala (-x); u da y alto a y basso (chi guarda verso +x ha +y a sinistra)
    c.faccia([(x - 0.081, yb, 0.06), (x - 0.081, ya, 0.06), (x - 0.081, ya, h + 0.1), (x - 0.081, yb, h + 0.1)], 'portone',
             uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for yy in (ya + 0.5, yb - 0.5):   # carrelli appesi al binario
        c.cilindro((x - 0.14, yy, h + 0.1), (x - 0.14, yy, h + 0.25), 0.07, 'nero_opaco', seg=16)
        c.cilindro((x - 0.24, yy, h + 0.19), (x - 0.04, yy, h + 0.19), 0.05, 'inox', seg=12)
    c.cilindro((x - 0.2, ya + 0.35, 1.0), (x - 0.2, ya + 0.35, 1.6), 0.03, 'inox', seg=10)   # maniglione
    for zz in (1.0, 1.6):
        c.cilindro((x - 0.2, ya + 0.35, zz), (x - 0.08, ya + 0.35, zz), 0.02, 'inox', seg=8)
    perno = (x - 0.04, cy, 0.0)
    anta = con_perno(c.crea('sala_portone_torre'), perno)
    K.collisione_scatola('portone_torre', (-0.04, ya - cy, 0.0), (0.04, yb - cy, h + 0.1), padre=anta)
    p = K.Costruttore(mats)
    y0r, y1r = ya - corsa - 0.1, yb + 0.6
    p.scatola((x - 0.2, y0r, h + 0.25), (x - 0.02, y1r, h + 0.4), 'acciaio_portone')   # binario
    n = int(math.ceil((y1r - y0r) / 1.6))
    for k in range(n + 1):   # staffe del binario fino al muro
        yy = y0r + 0.1 + k * (y1r - y0r - 0.2) / n
        p.scatola((x - 0.02, yy - 0.04, h + 0.27), (X1, yy + 0.04, h + 0.38), 'acciaio_portone')
        p.scatola((X1 - 0.012, yy - 0.08, h + 0.22), (X1, yy + 0.08, h + 0.43), 'acciaio_portone')
    zl = h + 0.55
    p.scatola((X1 - 0.08, cy - 0.15, zl - 0.12), (X1, cy + 0.15, zl + 0.05), 'nero_opaco')   # staffa del lampeggiante
    p.cilindro((X1 - 0.2, cy, zl), (X1 - 0.2, cy, zl + 0.08), 0.13, 'nero_opaco', seg=24)
    for sy in (-1, 1):   # bande a strisce sui due stipiti del varco
        y0_ = cy + sy * (w / 2 + 0.15)
        a_, b_ = min(y0_, y0_ + sy * 0.4), max(y0_, y0_ + sy * 0.4)
        p.scatola((X1 - 0.04, a_, 0), (X1, b_, h + 0.2), 'nero_opaco')
        p.faccia([(X1 - 0.041, b_, 0), (X1 - 0.041, a_, 0), (X1 - 0.041, a_, h + 0.2), (X1 - 0.041, b_, h + 0.2)],
                 'strisce', uv=[(0, 0), (0.25, 0), (0.25, 1), (0, 1)])
    telaio = p.crea('sala_portone_torre_telaio')
    v = K.Costruttore(mats)
    v.cilindro((0, 0, 0), (0, 0, 0.18), 0.105, 'faro_rosso', seg=24, tappi=False)
    calotta(v, (0, 0, 0.18), (0, 0, 1), 0.105, 0.1, 'faro_rosso', seg=24)
    vetro = v.crea('sala_lampeggiante_torre')
    vetro.location = (X1 - 0.2, cy, zl + 0.08)
    va, vb, vh = varco_torre()
    dati = dict(
        nota=("sala della torre, versione 2 (16 ottobre): varco nella parete est (y Blender da %g a %g, alto %g m) chiuso dal "
              "portone scorrevole; dietro c'è solo il guscio della sala (l'interno si decide dopo)") % (va, vb, vh),
        varco_godot=dict(x=X1, z=[-vb, -va], altezza=vh),
        anta=dict(nodo='sala_portone_torre', perno_godot=a_godot(perno), larghezza=round(yb - ya, 3), altezza=round(h + 0.04, 3),
                  apertura=dict(tipo='scorre', verso_godot=[0, 0, 1], corsa_massima=corsa,
                                nota="scorre verso sud lungo il muro (+Z in Godot) di 6,4 m, fino alla fine del binario: si apre del tutto"),
                  collisione='portone_torre (figlia: scorre con l\'anta)'),
        telaio=dict(nodo='sala_portone_torre_telaio', nota='binario con le staffe, bande a strisce, base del lampeggiante (fisso)'),
        lampeggiante=dict(nodo='sala_lampeggiante_torre', vetro_centro_godot=a_godot((X1 - 0.2, cy, zl + 0.2)),
                          luce_godot=a_godot((X1 - 0.45, cy, zl + 0.25)),
                          nota="vetro rosso M_amb_faro_rosso (emissivo); il gioco può farlo verde quando si apre"),
        davanti_al_portone_godot=a_godot((X1 - 2.5, cy, 0.0)),
        dentro_la_sala_godot=a_godot((X1 + 3.0, cy, 0.0)),
        sala=dict(x_godot=[X1 + K.SPESSORE_PARETE, T['x1']], z_godot=[-T['y1'], -T['y0']], altezza=T['h'],
                  nota="guscio vuoto (pavimento, pareti, soffitto, collisioni), sala_torre_guscio in sala_architettura.glb"))
    return [anta, telaio, vetro], dati


def guscio_sala_torre(mats):
    """Guscio della sala della torre dietro il varco della parete est (per ora vuoto: l'interno si decide
    dopo con l'utente): pavimento come la sala, pareti in cemento verniciato sopra uno zoccolo di cemento,
    soffitto scuro. A ovest c'è il retro della parete est della sala; qui si chiude quello che resta: sopra
    il soffitto della sala e il pezzo a nord della sala (da y 24 a 26). Collisioni su tutti i lati."""
    T = SALA_TORRE
    x0, x1, y0, y1, h = X1, T['x1'], T['y0'], T['y1'], T['h']
    xo = X1 + K.SPESSORE_PARETE                      # retro della parete est della sala
    c = K.Costruttore(mats)
    c.faccia_griglia([(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0)], 'pavimento', 2.0)
    c.faccia_griglia([(x0, y1, h), (x1, y1, h), (x1, y0, h), (x0, y0, h)], 'stanza_soffitto', 4.0)
    muri = {'s': [(x1, y0), (xo, y0)], 'n': [(xo, y1), (x1, y1)], 'e': [(x1, y1), (x1, y0)]}
    for lato, (p, q) in muri.items():
        c.faccia_griglia([(p[0], p[1], 1.2), (q[0], q[1], 1.2), (q[0], q[1], h), (p[0], p[1], h)], 'stanza_muro', 2.0)
        c.faccia_griglia([(p[0], p[1], 0), (q[0], q[1], 0), (q[0], q[1], 1.2), (p[0], p[1], 1.2)], 'cemento', 2.0)
    # lato ovest: sopra la parete della sala (da 11,5 a 14) e il pezzo a nord della sala (da y 24 a 26)
    c.faccia_griglia([(xo, y0, Z_SOFF), (xo, y1, Z_SOFF), (xo, y1, h), (xo, y0, h)], 'stanza_muro', 2.0)
    c.faccia_griglia([(xo, Y1, 1.2), (xo, y1, 1.2), (xo, y1, Z_SOFF), (xo, Y1, Z_SOFF)], 'stanza_muro', 2.0)
    c.faccia_griglia([(xo, Y1, 0), (xo, y1, 0), (xo, y1, 1.2), (xo, Y1, 1.2)], 'cemento', 2.0)
    ob = c.crea('sala_torre_guscio', sporco=lambda co: 0.55 + 0.45 * min(1.0, co.z / 3.0))
    K.collisione_scatola('torre_guscio_pavimento', (x0, y0, -0.2), (x1, y1, 0.0), padre=ob)
    K.collisione_scatola('torre_guscio_soffitto', (x0, y0, h), (x1, y1, h + 0.2), padre=ob)
    K.collisione_scatola('torre_guscio_sud', (x0, y0 - 0.2, 0), (x1, y0, h), padre=ob)
    K.collisione_scatola('torre_guscio_nord', (x0, y1, 0), (x1, y1 + 0.2, h), padre=ob)
    K.collisione_scatola('torre_guscio_est', (x1, y0, 0), (x1 + 0.2, y1, h), padre=ob)
    K.collisione_scatola('torre_guscio_ovest_alto', (X1, y0, Z_SOFF), (xo, y1, h), padre=ob)
    K.collisione_scatola('torre_guscio_ovest_nord', (X1, Y1, 0), (xo, y1, Z_SOFF), padre=ob)
    return ob


def fari_parete(mats, bersaglio=None):
    """Due fari da palcoscenico su due bracci fissati alla parete sud (prima erano sulla ringhiera del
    soppalco, tolto il 16 ottobre: stessa quota), puntati sulla medusa affacciata alla vasca (o sulla
    statua). Stesso nome dell'oggetto e delle luci di prima (luce_faro_0 e luce_faro_1)."""
    P = PIEDISTALLO
    c = K.Costruttore(mats)
    luci = []
    bersaglio = Vector(bersaglio) if bersaglio else Vector((P['cx'], P['cy'], P['h'] + 3.4))   # busto e viso
    for i, x in enumerate((-2.1, 2.1)):
        z = Z_GAL + SP_GAL + RINGHIERA_H_SALA
        piastra = Vector((x, Y0, z))
        corpo = Vector((x, Y0 + 0.55, z + 0.2))
        d = (bersaglio - corpo).normalized()
        c.scatola(tuple(piastra + Vector((-0.12, 0, -0.12))), tuple(piastra + Vector((0.12, 0.02, 0.12))), 'nero')   # piastra
        c.tubo([tuple(piastra + Vector((0, 0.02, 0))), tuple(piastra + Vector((0, 0.35, 0.0))), tuple(corpo - Vector((0, 0, 0.12)))],
               0.025, 'nero', seg=8)   # braccio
        lato = d.cross(Vector((0, 0, 1))).normalized()
        for sgn in (-1, 1):   # forcella
            c.cilindro(tuple(corpo - Vector((0, 0, 0.12)) + lato * 0.15 * sgn), tuple(corpo + lato * 0.15 * sgn), 0.012, 'nero', seg=6)
        c.cilindro(tuple(corpo - lato * 0.15), tuple(corpo + lato * 0.15), 0.012, 'nero', seg=6, tappi=False)
        c.cilindro(tuple(corpo - d * 0.22), tuple(corpo + d * 0.2), 0.14, 'nero', seg=16)
        c.anello(tuple(corpo + d * 0.2), tuple(d), 0.1, 0.15, 0.03, 'nero', seg=16)
        c.disco(tuple(corpo + d * 0.205), tuple(d), 0.1, 'lampadina', seg=16)
        for k in range(4):   # alette di raffreddamento
            o = d * (-0.15 + k * 0.08)
            c.toro(tuple(corpo + o), tuple(d), 0.15, 0.01, 'nero', seg=16, seg_r=4)
        luci.append(dict(nome=f'luce_faro_{i}', pos=tuple(corpo + d * 0.3), dir=tuple(d), colore=(1.0, 0.9, 0.76)))
    return c.crea('sala_monumento_fari'), luci


def pareti(mats):
    """Pareti perimetrali: sotto (0-4 m, piastrelle + intonaco, oblò sui fianchi dello scafo) e sopra
    (4-11,5 m, intonaco grigio-verde, oblò sui fianchi). Porta degli spogliatoi a sud, al centro.
    Nella parete est c'è il varco della sala della torre (16 ottobre): y da 12 a 18, alto 5 m. Lì resta
    solo il muro sopra il varco (senza oblò) e sotto si chiude con l'intradosso (sala_varco_intradosso)."""
    sotto, sopra, oblo = [], [], []
    H1, H2 = Z_GAL, Z_SOFF - Z_GAL
    va, vb, vh = varco_torre()
    # sud (y = Y0), fronte verso +y: rotazione 180, il modulo va da T.x - L a T.x. Sotto la galleria
    # moduli da 2 m con il modulo del vano (2 m) centrato sul vano verso gli spogliatoi: i moduli
    # accanto si accorciano a 1 m. (Prima il vano non c'era: i moduli cadevano a cavallo di x = 0.)
    x, i = X0, 0
    a_vano = VANO['cx'] - 1.0
    a_serranda = VANO_SERRANDA['cx'] - 1.0
    while x < X1 - 1e-6:
        if abs(x - a_vano) < 1e-6:   # vano 1,2 x 2,2 m con la porta stagna aperta
            sotto.append(metti(K.parete_porta(mats, 2.0, H1, luce=VANO['luce'], h_porta=VANO['h'], nome=f'ps_{i}',
                                              suddividi=0.25, ante=False, telaio=False, cornici=True), (x + 2.0, Y0, 0), 180))
            x += 2.0; i += 1
            continue
        if abs(x - a_serranda) < 1e-6:   # varco della serranda del magazzino (la serranda è nel raccordo dei tecnici)
            sotto.append(metti(K.parete_porta(mats, 2.0, H1, luce=VANO_SERRANDA['luce'], h_porta=VANO_SERRANDA['h'], nome=f'ps_{i}',
                                              suddividi=0.25, ante=False, telaio=False, cornici=True), (x + 2.0, Y0, 0), 180))
            x += 2.0; i += 1
            continue
        w = min(2.0, X1 - x)
        if x < a_vano < x + w - 1e-6:
            w = a_vano - x
        sotto.append(metti(K.parete(mats, w, altezza=H1, nome=f'ps_{i}', suddividi=0.25, cornici=True), (x + w, Y0, 0), 180))
        x += w; i += 1
    for i in range(20):
        xa = X0 + 2 * i
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, mat_alta='intonaco_alto', nome=f'pss_{i}', suddividi=0.5), (xa + 2, Y0, Z_GAL), 180))
    # nord (y = 24), fronte verso -y
    for i in range(20):
        xa = X0 + 2 * i
        sotto.append(metti(K.parete(mats, 2.0, altezza=H1, nome=f'pn_{i}', suddividi=0.25, cornici=True), (xa, Y1, 0)))
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, mat_alta='intonaco_alto', nome=f'pns_{i}', suddividi=0.5), (xa, Y1, Z_GAL)))
    # est (x = 20), fronte verso -x; ovest (x = -20), fronte verso +x: oblò a moduli alterni
    intradosso = K.Costruttore(mats)
    for i in range(int(round((Y1 - Y0) / 2))):
        yb = Y0 + 2 * i
        ob_s = (i % 2 == 1)
        ob_a = (i % 2 == 0)
        if va - 1e-6 <= yb and yb + 2 <= vb + 1e-6:   # modulo nel varco della sala della torre
            sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=Z_SOFF - vh, mat_alta='intonaco_alto',
                                        nome=f'pes_{i}', suddividi=0.5), (X1, yb + 2, vh), -90))
            intradosso.faccia([(X1, yb, vh), (X1, yb + 2, vh), (X1 + K.SPESSORE_PARETE, yb + 2, vh), (X1 + K.SPESSORE_PARETE, yb, vh)], 'metallo')
        else:
            sotto.append(metti(K.parete(mats, 2.0, altezza=H1, oblo=ob_s, nome=f'pe_{i}', suddividi=0.25, cornici=True), (X1, yb + 2, 0), -90))
            sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, oblo=ob_a, oblo_z=2.2, mat_alta='intonaco_alto',
                                        nome=f'pes_{i}', suddividi=0.5), (X1, yb + 2, Z_GAL), -90))
            if ob_s:
                oblo.append(metti(K.oblo(mats, nome=f'oblo_e_{i}'), (X1, yb + 1, K.OBLO_Z), -90))
            if ob_a:
                oblo.append(metti(K.oblo(mats, nome=f'obloa_e_{i}'), (X1, yb + 1, Z_GAL + 2.2), -90))
        sotto.append(metti(K.parete(mats, 2.0, altezza=H1, oblo=ob_s, nome=f'po_{i}', suddividi=0.25, cornici=True), (X0, yb, 0), 90))
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, oblo=ob_a, oblo_z=2.2, mat_alta='intonaco_alto',
                                    nome=f'pos_{i}', suddividi=0.5), (X0, yb, Z_GAL), 90))
        if ob_s:
            oblo.append(metti(K.oblo(mats, nome=f'oblo_o_{i}'), (X0, yb + 1, K.OBLO_Z), 90))
        if ob_a:
            oblo.append(metti(K.oblo(mats, nome=f'obloa_o_{i}'), (X0, yb + 1, Z_GAL + 2.2), 90))
    basse, alte = unisci(sotto, 'sala_pareti_basse'), unisci(sopra, 'sala_pareti_alte')
    D.colora(basse, D.sporco_pareti_basse)
    D.colora(alte, D.sporco_pareti_alte)
    return [basse, alte, unisci(oblo, 'sala_obloi'), intradosso.crea('sala_varco_intradosso', sporco=lambda co: 0.75)]


def galleria(mats):
    """Balconata a 4 m tutto intorno, colonne sotto il bordo, ringhiera. NON USATA dal 16 ottobre (soppalco
    tolto, scelta dell'utente C1): resta per riferimento."""
    pezzi = []
    pezzi.append(metti(K.galleria_bordo(mats, 40.0, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_s', suddividi=0.5, cornice=True), (X1, Y0 + PROF_GAL, 0), 180))
    pezzi.append(metti(K.galleria_bordo(mats, 40.0, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_n', suddividi=0.5, cornice=True), (X0, Y1 - PROF_GAL, 0)))
    L = (Y1 - Y0) - 2 * PROF_GAL
    pezzi.append(metti(K.galleria_bordo(mats, L, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_e', suddividi=0.5, cornice=True), (X1 - PROF_GAL, Y1 - PROF_GAL, 0), -90))
    pezzi.append(metti(K.galleria_bordo(mats, L, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_o', suddividi=0.5, cornice=True), (X0 + PROF_GAL, Y0 + PROF_GAL, 0), 90))
    gal = unisci(pezzi, 'sala_galleria')
    col = []
    xi, yi = X1 - PROF_GAL, Y1 - PROF_GAL   # bordi interni: x = +-17, y = -9 / 21
    ys = Y0 + PROF_GAL
    punti_col = [(x, ys - 0.35) for x in (-15.0, -9.0, -3.0, 3.0, 9.0, 15.0)] + [(x, yi + 0.35) for x in (-15.0, -9.0, -3.0, 3.0, 9.0, 15.0)]
    ys_col = (-15.0, -9.0, -3.0, 3.0, 9.0, 15.0)
    punti_col += [(xi + 0.35, y) for y in ys_col] + [(-xi - 0.35, y) for y in ys_col]
    for (x, y) in punti_col:
        cc = K.colonna(mats, (x, y, 0), Z_GAL, raggio=0.2, nome=un('colonna'), capitello=True)
        K.collisione_scatola(cc.name, (x - 0.21, y - 0.21, 0), (x + 0.21, y + 0.21, Z_GAL), padre=cc)
        col.append(cc)
    colonne = unisci(col, 'sala_colonne')
    ring = []
    z = Z_GAL + SP_GAL
    for i in range(17):     # sud e nord, da x -17 a 17
        x = -xi + 2 * i
        w = min(2.0, xi - x)
        if w <= 0.01:
            continue
        ring.append(metti(K.ringhiera(mats, w, nome=un('ring_s'), paletto_fine=(x + w >= xi - 0.01)), (x, ys - 0.06, z)))
        ring.append(metti(K.ringhiera(mats, w, nome=un('ring_n'), paletto_fine=(x + w >= xi - 0.01)), (x, yi + 0.06, z)))
    for i in range(int(round((yi - ys) / 2))):     # est e ovest (a est si apre dove arriva la scala, y 1..3)
        y = ys + 2 * i
        if abs(y - 1.0) > 0.01:
            ring.append(metti(K.ringhiera(mats, 2.0, nome=un('ring_e'), paletto_fine=abs(y + 2 - 1.0) < 0.01), (xi + 0.06, y, z), 90))
        ring.append(metti(K.ringhiera(mats, 2.0, nome=un('ring_o')), (-xi - 0.06, y, z), 90))
    ringhiere = unisci(ring, 'sala_ringhiere')
    return [gal, colonne, ringhiere]


def soffitto_struttura(mats):
    """Travi a doppia T sotto il soffitto (interrotte dal foro della cupola) e due condotte di
    ventilazione lungo i fianchi, con staffe: il soffitto di una nave non è liscio."""
    c = K.Costruttore(mats)
    cx, cy, R = CUPOLA['cx'], CUPOLA['cy'], CUPOLA['r'] + 0.3
    zt = Z_SOFF
    def trave(x0, x1, y):
        if x1 - x0 < 0.3:
            return
        c.scatola((x0, y - 0.13, zt - 0.06), (x1, y + 0.13, zt), 'ferro_cupola', senza=('+z',))          # ala alta
        c.scatola((x0, y - 0.025, zt - 0.5), (x1, y + 0.025, zt - 0.06), 'ferro_cupola', senza=('+z',))  # anima
        c.scatola((x0, y - 0.13, zt - 0.56), (x1, y + 0.13, zt - 0.5), 'ferro_cupola')                   # ala bassa
        n = int((x1 - x0) / 0.3)
        for i in range(n):   # rivetti sotto l'ala bassa, su due file
            x = x0 + (i + 0.5) * (x1 - x0) / n
            for yy in (y - 0.09, y + 0.09):
                c.rivetto((x, yy, zt - 0.561), (0, 0, -1), 'ferro_cupola', r=0.013, h=0.008)
        m = max(1, int((x1 - x0) / 1.5))
        for i in range(1, m):   # irrigidimenti d'anima
            x = x0 + i * (x1 - x0) / m
            for sy in (-1, 1):
                c.scatola((x - 0.006, y + sy * 0.025 if sy > 0 else y - 0.12, zt - 0.5),
                          (x + 0.006, y + 0.12 if sy > 0 else y - 0.025, zt - 0.06), 'ferro_cupola', senza=('+z', '-z'))
    for k in range(int(Y0) + 2, int(Y1) - 1, 3):
        y = float(k)
        dy = abs(y - cy)
        if dy < R:
            dx = math.sqrt(R * R - dy * dy)
            trave(X0, cx - dx, y)
            trave(cx + dx, X1, y)
        else:
            trave(X0, X1, y)
    # condotte di ventilazione (tonde) lungo i muri est e ovest, con staffe ogni 3 m
    for x in (X0 + 1.2, X1 - 1.2):
        c.cilindro((x, Y0 + 0.3, zt - 1.05), (x, Y1 - 0.3, zt - 1.05), 0.32, 'metallo', seg=16, tappi=False)
        for k in range(int(Y0) + 1, int(Y1), 3):
            c.toro((x, k + 0.0, zt - 1.05), (0, 1, 0), 0.34, 0.025, 'metallo', seg=20, seg_r=4)
            c.scatola((x - 0.03, k - 0.03, zt - 0.72), (x + 0.03, k + 0.03, zt - 0.56), 'metallo')
    return c.crea('sala_soffitto_travi', sporco=lambda co: 0.8)


def colature(mats):
    """Colature di ruggine e calcare sotto gli oblò alti e sui muri bassi (piani con alfa a 1 cm dal muro:
    in Godot si possono sostituire con nodi Decal). Quelle sul fronte del soppalco (tolto il 16 ottobre) e
    quelle nel varco della sala della torre non ci sono più: i loro numeri casuali si consumano lo stesso,
    così le altre restano dov'erano."""
    m = bpy.data.materials.get('M_amb_decal_colatura')
    if m is None:
        m = bpy.data.materials.new('M_amb_decal_colatura')
        m.use_nodes = True
        nt = m.node_tree
        b = nt.nodes['Principled BSDF']
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(os.path.join(K.TEX, 'decal', 'colatura_col.png'), check_existing=True)
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
        nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
        nt.links.new(t.outputs['Alpha'], b.inputs['Alpha'])
        b.inputs['Roughness'].default_value = 0.7
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'BLENDED'
    class _M:
        def lato(self, n): return 1.0
        def get(self, n): return m
    c = K.Costruttore(_M())
    import random
    rnd = random.Random(21)
    va, vb, vh = varco_torre()
    def colatura(centro, normale, w, h, metti=True):
        cx_, cy_, zc = centro
        nx, ny = normale
        if not metti:
            return
        if abs(cx_ - X1) < 0.1 and cy_ + w / 2 > va - 0.15 and cy_ - w / 2 < vb + 0.15 and zc - h < vh + 0.1:
            return            # nel varco della sala della torre (o dietro il portone)
        tx, ty = -ny, nx          # direzione orizzontale lungo il muro
        p = lambda a, b: (cx_ + nx * 0.012 + tx * a, cy_ + ny * 0.012 + ty * a, zc + b)
        q = [p(-w / 2, -h), p(w / 2, -h), p(w / 2, 0), p(-w / 2, 0)]
        uv = [(0, 0), (1, 0), (1, 1), (0, 1)]
        c.faccia(q, 'decal', uv=uv)
    # sotto gli oblò alti (est e ovest, z = 6,2)
    for i in range(int(round((Y1 - Y0) / 2))):
        yb = Y0 + 2 * i + 1
        if i % 2 == 0 and rnd.random() < 0.75:
            colatura((X1, yb, Z_GAL + 2.2 - 0.38), (-1, 0), rnd.uniform(0.7, 1.1), rnd.uniform(1.0, 1.8))
        if i % 2 == 0 and rnd.random() < 0.75:
            colatura((X0, yb, Z_GAL + 2.2 - 0.38), (1, 0), rnd.uniform(0.7, 1.1), rnd.uniform(1.0, 1.8))
    # erano sotto il bordo del soppalco (fronte): si consumano i numeri ma non si mettono
    for i in range(14):
        x = rnd.uniform(-16, 16)
        colatura((x, Y1 - PROF_GAL, Z_GAL - 0.12), (0, -1), rnd.uniform(1.0, 2.2), rnd.uniform(0.8, 1.6), metti=False)
        x = rnd.uniform(-16, 16)
        colatura((x, Y0 + PROF_GAL, Z_GAL - 0.12), (0, 1), rnd.uniform(1.0, 2.2), rnd.uniform(0.8, 1.6), metti=False)
    # muri bassi, sopra le piastrelle
    for i in range(16):
        y = rnd.uniform(Y0 + 1, Y1 - 1)
        colatura((X1, y, Z_GAL - 0.05), (-1, 0), rnd.uniform(0.8, 1.6), rnd.uniform(1.2, 2.0))
        y = rnd.uniform(Y0 + 1, Y1 - 1)
        colatura((X0, y, Z_GAL - 0.05), (1, 0), rnd.uniform(0.8, 1.6), rnd.uniform(1.2, 2.0))
    ob = c.crea('sala_colature')
    ob.visible_shadow = False
    return ob


def scala_galleria(mats):
    """Scala in acciaio per salire sulla galleria est: parte a terra in y = 9,6 e arriva in y = 3,0 a
    4,3 m, con pianerottolo che entra nella galleria (lì la ringhiera è aperta). NON USATA dal 16 ottobre."""
    c = K.Costruttore(mats)
    g = K.Costruttore(mats)
    x0, x1 = 15.7, 16.9
    yb, yt = 9.6, 3.0
    zt = Z_GAL + SP_GAL
    n = 24
    alzata, pedata = zt / n, (yb - yt) / (n - 1)
    for k in range(n - 1):
        z = alzata * (k + 1)
        y = yb - pedata * k
        q = [(x0, y, z), (x1, y, z), (x1, y - pedata, z), (x0, y - pedata, z)]
        g.faccia(q[::-1], 'alfa_grata'); g.faccia(q, 'alfa_grata')
        c.scatola((x0, y - pedata, z - 0.03), (x1, y - pedata + 0.03, z), 'torre')
    # pianerottolo che si appoggia alla galleria
    q = [(x0, yt, zt), (17.0, yt, zt), (17.0, yt - 2.0, zt), (x0, yt - 2.0, zt)]
    g.faccia(q, 'alfa_grata'); g.faccia(q[::-1], 'alfa_grata')
    c.scatola((x0, yt - 2.0, zt - 0.2), (x0 + 0.08, yt, zt), 'torre')
    # cosciali, corrimano e montanti
    for x in (x0, x1):
        c.tubo([(x, yb + 0.2, 0.0), (x, yt, zt)], 0.06, 'torre', seg=6)
    for x in (x0 - 0.02, x1 + 0.02):
        c.tubo([(x, yb + 0.2, 1.0), (x, yt, zt + 1.0)], 0.03, 'torre', seg=8)
        for k in range(0, n, 4):
            y = yb - pedata * k
            z = alzata * (k + 1)
            c.cilindro((x, y, z), (x, y, z + 1.0), 0.022, 'torre', seg=6)
    c.tubo([(x0 - 0.02, yt, zt + 1.0), (x0 - 0.02, yt - 2.0, zt + 1.0), (17.0, yt - 2.0, zt + 1.0)], 0.03, 'torre', seg=8)
    c.cilindro((x0 - 0.02, yt - 2.0, zt), (x0 - 0.02, yt - 2.0, zt + 1.0), 0.022, 'torre', seg=6)
    c.cilindro((x0, yt - 1.0, 0.0), (x0, yt - 1.0, zt - 0.2), 0.08, 'torre', seg=10)
    ob = c.crea('sala_scala_galleria', sporco=lambda co: 0.8)
    gr = g.crea('sala_scala_galleria_grigliato')
    K.collisione_punti('scala_galleria', [(x0, yb + 0.3, 0.0), (x1, yb + 0.3, 0.0), (x0, yt, zt), (x1, yt, zt),
                                          (x0, yb + 0.3, -0.1), (x1, yb + 0.3, -0.1), (x0, yt, zt - 0.15), (x1, yt, zt - 0.15)], padre=ob)
    K.collisione_scatola('scala_pianerottolo', (x0, yt - 2.0, zt - 0.15), (17.0, yt, zt), padre=ob)
    K.collisione_scatola('scala_corrimano_o', (x0 - 0.06, yt - 2.0, 0.0), (x0, yb, zt + 1.05), padre=ob)
    return [ob, gr]


def pulsante(mats, nome, pos, verso, colore='gioco_rosso'):
    """Fungo da premere (nodo a parte, perno alla base; si preme muovendolo lungo -verso)."""
    c = K.Costruttore(mats)
    c.cilindro((0, 0, 0), (0, -0.05, 0), 0.07, 'inox', seg=16)
    c.cilindro((0, -0.05, 0), (0, -0.09, 0), 0.11, colore, seg=24)
    ob = c.crea(nome)
    ob.location = pos
    ob.rotation_euler = Euler((0, 0, math.atan2(-verso[0], verso[1]) + math.pi))
    return ob


def interattivi(mats, zf):
    """Elementi degli enigmi come nodi separati, ognuno con il perno dove ruota o si muove.
    Le posizioni sono in sala_dati.json; si possono spostare senza toccare il resto.
    Dal 16 ottobre (tappa 5 rifatta, sala della torre a est) non ci sono più la turbina dello scarico, il
    recinto con il cancello della spiaggia, la ruota del cancello con la trasmissione e il quadro elettrico;
    ci sono il pulsante A della botola e il portone della sala della torre. Restituisce (nodi, dati)."""
    obs = []
    P = PISCINA
    sx, sy = P['scarico']
    zp = zf(sx, sy)
    # portello dello scarico (cerniera sul lato nord): sotto la pozza, si apre dopo averla svuotata
    c = K.Costruttore(mats)
    # portello quadrato: copre il buco del pozzo (1,28 m) e appoggia sulle piastrelle intorno (7 cm per
    # lato; 2 cm oltre la cerniera a nord). Lamiera con il bordo rialzato, due costole e i bulloni.
    W, S_, N_ = 0.71, -1.35, 0.02
    c.scatola_smussata((-W, S_, 0.0), (W, N_, 0.04), 'torre', s=0.012)
    for (a0, b0, a1, b1) in ((-W, S_, W, S_ + 0.06), (-W, N_ - 0.06, W, N_), (-W, S_, -W + 0.06, N_), (W - 0.06, S_, W, N_)):
        c.scatola_smussata((a0, b0, 0.04), (a1, b1, 0.065), 'torre', s=0.008)            # bordo rialzato
    for yy in (-0.9, -0.45):
        c.scatola_smussata((-W + 0.06, yy - 0.025, 0.04), (W - 0.06, yy + 0.025, 0.058), 'torre', s=0.006)   # costole
    for k in range(7):
        t = -W + 0.09 + k * (2 * W - 0.18) / 6
        for (bx, by) in ((t, S_ + 0.03), (t, N_ - 0.03)):
            c.cilindro((bx, by, 0.065), (bx, by, 0.078), 0.012, 'inox', seg=6)
    for k in range(1, 6):
        t = S_ + 0.03 + k * (N_ - S_ - 0.06) / 6
        for bx in (-W + 0.03, W - 0.03):
            c.cilindro((bx, t, 0.065), (bx, t, 0.078), 0.012, 'inox', seg=6)
    c.cilindro((-0.25, -0.68, 0.10), (0.25, -0.68, 0.10), 0.022, 'inox', seg=8)        # maniglia
    for x in (-0.25, 0.25):
        c.cilindro((x, -0.68, 0.04), (x, -0.68, 0.10), 0.018, 'inox', seg=8)
    for x in (-0.4, 0.4):
        c.cilindro((x - 0.1, 0.0, 0.03), (x + 0.1, 0.0, 0.03), 0.035, 'inox', seg=10)  # cerniere
    port = c.crea('sala_portello_scarico')
    # poggia sugli spigoli più alti del fondo intorno al buco: il fondo è a conca, e a zp - 0,01 (la quota del centro)
    # il portellone piatto entrava di 2-4 cm nelle piastrelle ai bordi (controllo di posizionamento del 22 ottobre)
    bordo = [(sx + u, sy + 0.64 + v) for u in (-W, -W / 2, 0.0, W / 2, W) for v in (S_, (S_ + N_) / 2, N_)]
    port.location = (sx, sy + 0.64, max(zf(x, y) for x, y in bordo) + 0.001)
    K.collisione_scatola('portello', (-0.64, -1.28, 0.0), (0.64, 0.0, 0.06), padre=port)
    obs.append(port)
    # pulsante della botola, versione A: cassetta, fungo e lampeggiante sulla parete sud della vasca
    pulsante_a, dati_pulsante = pulsante_botola(mats)
    obs += pulsante_a
    # portone scorrevole della sala della torre, nel varco della parete est
    portone, dati_portone = portone_torre(mats)
    obs += portone
    # pulsante dei bambini sul piedistallo (il fungo rosso; la scatola gialla è nel piedistallo)
    PD = PIEDISTALLO
    if CENTRO['modo'] == 'monumento':
        obs.append(pulsante(mats, 'sala_pulsante_piedistallo', (PD['cx'], PD['cy'] - PD['r_tamburo'] - 0.13, PD['z_pulsante']), (0, -1)))
    else:   # sul muro davanti della vasca sollevata (il nome del nodo resta lo stesso per il gioco)
        V = VASCA_CENTRALE
        yf = V['cy'] - V['ly'] / 2 + (V['coping'] / 2 - 0.12)
        obs.append(pulsante(mats, 'sala_pulsante_piedistallo', (V['cx'], yf - 0.13, V['z_pulsante']), (0, -1)))
    for o in obs:
        for ch in o.children:
            ch.hide_render = True
    return obs, dict(pulsante_botola=dati_pulsante, portone_torre=dati_portone)


def altoparlanti(mats):
    """Altoparlanti a tromba (da qui parte la sigla): erano sulle colonne del soppalco; dal 16 ottobre sulle
    pareti nord e sud, stessa x e stessa quota."""
    c = K.Costruttore(mats)
    for (x, y, v) in ((-9.0, Y0, 1), (9.0, Y0, 1), (-9.0, Y1, -1), (9.0, Y1, -1)):
        z = 3.3
        b = Vector((x, y + 0.08 * v, z))
        if v > 0:
            c.scatola((x - 0.1, y, z - 0.1), (x + 0.1, y + 0.08 * v, z + 0.1), 'metallo')
        else:
            c.scatola((x - 0.1, y + 0.08 * v, z - 0.1), (x + 0.1, y, z + 0.1), 'metallo')
        d = Vector((0, v, -0.25)).normalized()
        pts = [b + d * 0.05, b + d * 0.45]
        u = Vector((1, 0, 0)); w = d.cross(u).normalized()
        for k in range(16):
            a0, a1 = 2 * math.pi * k / 16, 2 * math.pi * (k + 1) / 16
            q = [pts[0] + (u * math.cos(a0) + w * math.sin(a0)) * 0.06, pts[0] + (u * math.cos(a1) + w * math.sin(a1)) * 0.06,
                 pts[1] + (u * math.cos(a1) + w * math.sin(a1)) * 0.24, pts[1] + (u * math.cos(a0) + w * math.sin(a0)) * 0.24]
            c.faccia([tuple(p_) for p_ in q], 'metallo', liscia=True)
            c.faccia([tuple(p_) for p_ in q[::-1]], 'nero', liscia=True)
    return c.crea('sala_altoparlanti')


def corridoio_spogliatoi(mats):
    """Primo tratto del corridoio degli spogliatoi dietro la porta (3 m), perché dalla sala non si
    veda il vuoto. Il resto degli spogliatoi è un'altra zona."""
    c = K.Costruttore(mats)
    x0, x1 = -1.2, 1.2
    y0, y1 = Y0 - 0.2 - 3.0, Y0 - 0.2
    h = 2.6
    c.faccia([(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0)], 'pavimento')
    c.faccia([(x0, y0, h), (x0, y1, h), (x1, y1, h), (x1, y0, h)], 'intonaco')
    for (xa, sgn) in ((x0, 1), (x1, -1)):
        for z0, z1, mat in ((0, 0.25, 'zoccolo'), (0.25, 2.0, 'parete'), (2.0, h, 'intonaco')):
            q = [(xa, y1, z0), (xa, y0, z0), (xa, y0, z1), (xa, y1, z1)]
            c.faccia(q if sgn > 0 else q[::-1], mat)
    c.faccia([(x1, y0, 0), (x0, y0, 0), (x0, y0, h), (x1, y0, h)][::-1], 'nero')
    ob = c.crea('sala_corridoio_spogliatoi', sporco=K.sporco_basso())
    K.collisione_scatola('corridoio_pav', (x0, y0, -0.1), (x1, y1, 0), padre=ob)
    K.collisione_scatola('corridoio_sx', (x0 - 0.2, y0, 0), (x0, y1, h), padre=ob)
    K.collisione_scatola('corridoio_dx', (x1, y0, 0), (x1 + 0.2, y1, h), padre=ob)
    K.collisione_scatola('corridoio_fondo', (x0, y0 - 0.2, 0), (x1, y0, h), padre=ob)
    return ob


# ----------------------------------------------------------------------------- cupola e cielo

def geometria_cupola():
    """Sfera della cupola: centro, raggio, angoli degli anelli (dal tamburo all'oculo)."""
    cx, cy, R0 = CUPOLA['cx'], CUPOLA['cy'], CUPOLA['r']
    zt = Z_SOFF + CUPOLA['tamburo']
    f = CUPOLA['freccia']
    Rs = (R0 * R0 + f * f) / (2 * f)            # raggio della sfera
    zc = zt + f - Rs                              # centro della sfera
    phi0 = math.asin(R0 / Rs)
    nm, npar = 32, 7
    phis = [phi0 * (1 - j / npar) for j in range(npar + 1)]
    phi_ocu = math.asin(1.3 / Rs)
    phis[-1] = phi_ocu
    return dict(cx=cx, cy=cy, R0=R0, zt=zt, Rs=Rs, zc=zc, phi0=phi0, phis=phis, phi_ocu=phi_ocu, nm=nm, npar=npar)


def lastre_rotte_xy():
    """Centri (x, y) delle lastre rotte della cupola: sotto piove dentro (pavimento bagnato)."""
    g = geometria_cupola()
    out = []
    for (k, j) in sorted(LASTRE_ROTTE):
        th = 2 * math.pi * (k + 0.5) / g['nm']
        phi = (g['phis'][j] + g['phis'][j + 1]) / 2
        r = g['Rs'] * math.sin(phi)
        out.append((g['cx'] + r * math.cos(th), g['cy'] + r * math.sin(th)))
    return out


def cupola(mats):
    """Cupola di vetro su tamburo. Costoloni e anelli a T (piatto fuori, sopra i bordi delle lastre;
    anima dentro, quella che si vede dal basso), piastre imbullonate negli incroci, lesene sul
    tamburo. Lastre sporche con i rivoli di pioggia (atlante a 4 varianti: sporca, molto sporca con le
    alghe in basso, incrinata, velata), alcune ROTTE con le schegge rimaste nel telaio (sotto piove
    dentro: vedi ambiente_dettagli.bagnato). Oculo in cima."""
    import random
    g = geometria_cupola()
    cx, cy, R0, Rs, zc, zt = g['cx'], g['cy'], g['R0'], g['Rs'], g['zc'], g['zt']
    phi0, phis, phi_ocu, nm, npar = g['phi0'], g['phis'], g['phi_ocu'], g['nm'], g['npar']
    C = Vector((cx, cy, zc))
    c = K.Costruttore(mats)
    # tamburo (cilindro interno), cornici e lesene
    seg = 96
    for k in range(seg):
        t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        p = lambda t, r, z: (cx + math.cos(t) * r, cy + math.sin(t) * r, z)
        c.faccia([p(t0, R0, Z_SOFF), p(t0, R0, zt), p(t1, R0, zt), p(t1, R0, Z_SOFF)], 'ferro_cupola')
    c.toro((cx, cy, Z_SOFF + 0.05), (0, 0, 1), R0 - 0.1, 0.0, 'ferro_cupola', seg=128, sezione=(0.35, 0.3))
    c.toro((cx, cy, zt), (0, 0, 1), R0 - 0.05, 0.0, 'ferro_cupola', seg=128, sezione=(0.45, 0.35))
    for k in range(32):
        a = 2 * math.pi * (k + 0.5) / 32
        rad = Vector((math.cos(a), math.sin(a), 0)); tan = Vector((-math.sin(a), math.cos(a), 0))
        c.scatola_assi(Vector((cx, cy, (Z_SOFF + 0.2 + zt - 0.17) / 2)) + rad * (R0 - 0.07), (tan, rad, (0, 0, 1)),
                       (0.11, 0.06, (zt - 0.17 - Z_SOFF - 0.2) / 2), 'ferro_cupola')
    def P(phi, th):
        return Vector((cx + Rs * math.sin(phi) * math.cos(th), cy + Rs * math.sin(phi) * math.sin(th), zc + Rs * math.cos(phi)))
    T = [(-0.055, 0.018), (-0.055, 0.0), (-0.012, 0.0), (-0.012, -0.14), (0.012, -0.14), (0.012, 0.0), (0.055, 0.0), (0.055, 0.018)]
    # costoloni (meridiani)
    for k in range(nm):
        th = 2 * math.pi * k / nm
        pts = [P(phi0 - (phi0 - phi_ocu) * i / 24, th) for i in range(25)]
        c.profilo_lungo(pts, [(q - C) for q in pts], T, 'ferro_cupola')
    # anelli (paralleli)
    for phi in phis[1:-1]:
        pts = [P(phi, 2 * math.pi * i / 128) for i in range(128)]
        c.profilo_lungo(pts, [(q - C) for q in pts], T, 'ferro_cupola', chiuso_percorso=True)
    c.toro((cx, cy, zc + Rs * math.cos(phi_ocu)), (0, 0, 1), 1.3, 0.12, 'ferro_cupola', seg=48, seg_r=8)
    # piastre imbullonate negli incroci (dentro, sotto le anime)
    for phi in phis[1:-1]:
        for k in range(nm):
            th = 2 * math.pi * k / nm
            p = P(phi, th)
            n = (p - C).normalized()
            e_th = Vector((-math.sin(th), math.cos(th), 0))
            e_ph = n.cross(e_th).normalized()
            centro = p - n * 0.147
            c.scatola_assi(centro, (e_th, e_ph, n), (0.11, 0.11, 0.007), 'ferro_cupola')
            for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                c.rivetto(centro - n * 0.007 + e_th * 0.075 * a + e_ph * 0.075 * b, -n, 'ferro_cupola', r=0.014, h=0.01)
    ob_ferro = c.crea('sala_cupola_ferro', sporco=lambda co: 0.8)
    # lastre di vetro: una variante dell'atlante per lastra (0 sporca, 1 molto sporca, 2 incrinata, 3 velata)
    v = K.Costruttore(mats)
    rnd = random.Random(3)
    rotte = LASTRE_ROTTE
    def cella(kv, s_, t_):
        e = 0.008
        u0, v0 = 0.5 * (kv % 2), (0.5 if kv // 2 == 0 else 0.0)
        return (u0 + e + (0.5 - 2 * e) * s_, v0 + e + (0.5 - 2 * e) * t_)
    def bil(q, s_, t_):
        return (q[0] * (1 - s_) + q[1] * s_) * (1 - t_) + (q[3] * (1 - s_) + q[2] * s_) * t_
    def schegge(q):
        """Schegge rimaste nel telaio di una lastra rotta: denti lungo il bordo basso e i lati."""
        ss = [0.0] + sorted(rnd.uniform(0.08, 0.92) for _ in range(5)) + [1.0]
        for s0, s1 in zip(ss, ss[1:]):
            tip_s, tip_t = (s0 + s1) / 2 + rnd.uniform(-0.05, 0.05), rnd.uniform(0.12, 0.55)
            tri = [(s0, 0.0), (s1, 0.0), (tip_s, tip_t)]
            v.faccia([tuple(bil(q, a, b)) for a, b in tri], 'vetro_cupola', uv=[cella(2, a, b) for a, b in tri], liscia=True)
        for lato in (0.0, 1.0):
            tt = [0.0] + sorted(rnd.uniform(0.15, 0.85) for _ in range(2)) + [1.0]
            for t0_, t1_ in zip(tt, tt[1:]):
                if rnd.random() < 0.45:
                    continue
                tip = (abs(lato - rnd.uniform(0.1, 0.35)), (t0_ + t1_) / 2)
                tri = [(lato, t0_), (lato, t1_), tip]
                v.faccia([tuple(bil(q, a, b)) for a, b in tri], 'vetro_cupola', uv=[cella(2, a, b) for a, b in tri], liscia=True)
    for k in range(nm):
        for j in range(npar):
            th0, th1 = 2 * math.pi * k / nm, 2 * math.pi * (k + 1) / nm
            a, b = phis[j], phis[j + 1]
            q = [P(a, th0), P(a, th1), P(b, th1), P(b, th0)]
            if (k, j) in rotte:
                schegge(q)
                continue
            r_ = rnd.random()
            kv = 2 if r_ < 0.1 else (1 if r_ < 0.38 else (0 if r_ < 0.78 else 3))
            v.faccia([tuple(x) for x in q], 'vetro_cupola', uv=[cella(kv, 0, 0), cella(kv, 1, 0), cella(kv, 1, 1), cella(kv, 0, 1)], liscia=True)
    zo = zc + Rs * math.cos(phi_ocu) + 0.02
    pts = [(cx + math.cos(2 * math.pi * i / 24) * 1.3, cy + math.sin(2 * math.pi * i / 24) * 1.3, zo) for i in range(24)]
    v.faccia(pts, 'vetro_cupola', uv=[cella(3, 0.5 + 0.5 * math.cos(2 * math.pi * i / 24), 0.5 + 0.5 * math.sin(2 * math.pi * i / 24)) for i in range(24)])
    ob_vetro = v.crea('sala_cupola_vetro')
    ob_vetro.visible_shadow = True
    return [ob_ferro, ob_vetro]


def schegge_a_terra(mats, zf_piscina):
    """Vetri della cupola caduti sotto le lastre rotte: schegge piatte e lucide sul pavimento o sul
    fondo della piscina (vetro scuro degli oblò, così riflettono)."""
    import random
    rnd = random.Random(19)
    c = K.Costruttore(mats)
    P = PISCINA
    for (x, y) in lastre_rotte_xy():
        for _ in range(9):
            px, py = x + rnd.gauss(0, 0.9), y + rnd.gauss(0, 0.9)
            z = 0.003
            if P['x0'] < px < P['x1'] and P['y0'] < py < P['y1']:
                z = zf_piscina(px, py) + 0.004
            elif P['x0'] - 0.55 < px < P['x1'] + 0.55 and P['y0'] - 0.55 < py < P['y1'] + 0.55:
                continue   # sopra il bordo e la griglia no
            r = rnd.uniform(0.04, 0.16)
            a0 = rnd.uniform(0, 6.28)
            n = rnd.choice((3, 3, 4))
            pts = [(px + math.cos(a0 + 2 * math.pi * i / n + rnd.uniform(-0.4, 0.4)) * r * rnd.uniform(0.5, 1.0),
                    py + math.sin(a0 + 2 * math.pi * i / n + rnd.uniform(-0.4, 0.4)) * r * rnd.uniform(0.5, 1.0), z) for i in range(n)]
            c.faccia_verso(pts, 'vetro_oblo', (0, 0, 1), uv=[(0.3 + 0.4 * rnd.random(), 0.3 + 0.4 * rnd.random()) for _ in pts])
    ob = c.crea('sala_schegge_cupola')
    return ob


def cielo_tempesta():
    """Cielo di notte in tempesta (sfera emissiva, nuvole procedurali) e un fulmine."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=150, location=(0, 5, 0), segments=48, ring_count=24)
    sf = bpy.context.active_object
    sf.name = 'cielo'
    m = bpy.data.materials.new('M_cielo_tempesta')
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    no = nt.nodes.new('ShaderNodeTexNoise')
    no.inputs['Scale'].default_value = 3.2; no.inputs['Detail'].default_value = 10.0
    no.inputs['Roughness'].default_value = 0.66; no.inputs['Distortion'].default_value = 0.6
    nt.links.new(tc.outputs['Generated'], no.inputs['Vector'])
    cr = nt.nodes.new('ShaderNodeValToRGB')
    e = cr.color_ramp.elements
    e[0].position = 0.38; e[0].color = (0.003, 0.005, 0.01, 1)
    e[1].position = 0.68; e[1].color = (0.11, 0.13, 0.19, 1)
    e.new(0.52).color = (0.025, 0.032, 0.05, 1)
    nt.links.new(no.outputs['Fac'], cr.inputs['Fac'])
    nt.links.new(cr.outputs['Color'], em.inputs['Color'])
    em.inputs['Strength'].default_value = 1.0
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    sf.data.materials.append(m)
    sf.visible_shadow = False
    # fulmine: polilinea a zig-zag emissiva, lontano a nord-ovest, visibile dalla cupola
    import random
    rnd = random.Random(5)
    pts = []
    p = Vector((-40.0, 118.0, 105.0))
    for i in range(26):
        pts.append(p.copy())
        p += Vector((rnd.uniform(-3.0, 3.6), rnd.uniform(-1.2, 1.2), -rnd.uniform(2.0, 3.6)))
    mf = bpy.data.materials.new('M_fulmine')
    mf.use_nodes = True
    b = mf.node_tree.nodes['Principled BSDF']
    b.inputs['Emission Color'].default_value = (0.7, 0.78, 1.0, 1)
    b.inputs['Emission Strength'].default_value = 16.0
    b.inputs['Base Color'].default_value = (0, 0, 0, 1)
    class _M:
        def lato(self, n): return 1.0
        def get(self, n): return mf
    c = K.Costruttore(_M())
    c.tubo(pts, 0.05, 'fulmine', seg=6)
    for j in (7, 12, 17):  # rami
        q = pts[j].copy(); ramo = [q.copy()]
        for i in range(7):
            q += Vector((rnd.uniform(0.8, 3.0), rnd.uniform(-0.8, 0.8), -rnd.uniform(1.2, 2.4)))
            ramo.append(q.copy())
        c.tubo(ramo, 0.03, 'fulmine', seg=6)
    fl = c.crea('fulmine')
    fl.visible_shadow = False
    # alone: le nuvole intorno al fulmine si illuminano (piano emissivo sfumato)
    mg = bpy.data.materials.new('M_alone_fulmine')
    mg.use_nodes = True
    nt2 = mg.node_tree
    for n_ in list(nt2.nodes):
        nt2.nodes.remove(n_)
    o2 = nt2.nodes.new('ShaderNodeOutputMaterial')
    e2 = nt2.nodes.new('ShaderNodeEmission'); e2.inputs['Color'].default_value = (0.55, 0.65, 1.0, 1)
    tc2 = nt2.nodes.new('ShaderNodeTexCoord')
    gr = nt2.nodes.new('ShaderNodeTexGradient'); gr.gradient_type = 'SPHERICAL'
    mp = nt2.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (2.1, 2.1, 2.1)  # 0 ai bordi
    nt2.links.new(tc2.outputs['Object'], mp.inputs['Vector']); nt2.links.new(mp.outputs['Vector'], gr.inputs['Vector'])
    nz = nt2.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 3.0; nz.inputs['Detail'].default_value = 6.0
    nt2.links.new(tc2.outputs['Object'], nz.inputs['Vector'])
    mm = nt2.nodes.new('ShaderNodeMath'); mm.operation = 'MULTIPLY'
    nt2.links.new(gr.outputs['Fac'], mm.inputs[0]); nt2.links.new(nz.outputs['Fac'], mm.inputs[1])
    pw = nt2.nodes.new('ShaderNodeMath'); pw.operation = 'MULTIPLY'; pw.inputs[1].default_value = 3.2
    nt2.links.new(mm.outputs['Value'], pw.inputs[0])
    nt2.links.new(pw.outputs['Value'], e2.inputs['Strength'])
    tr = nt2.nodes.new('ShaderNodeBsdfTransparent')
    ad = nt2.nodes.new('ShaderNodeAddShader')
    nt2.links.new(e2.outputs['Emission'], ad.inputs[0]); nt2.links.new(tr.outputs['BSDF'], ad.inputs[1])
    nt2.links.new(ad.outputs['Shader'], o2.inputs['Surface'])
    bpy.ops.mesh.primitive_plane_add(size=1, location=(-34.0, 122.0, 92.0), rotation=(math.radians(80), 0, math.radians(-15)))
    al = bpy.context.active_object; al.name = 'alone_fulmine'; al.scale = (70, 60, 1)
    al.data.materials.append(mg); al.visible_shadow = False
    return [sf, fl, al]


# ----------------------------------------------------------------------------- vasche

def bordi_rettangolo(mats, x0, x1, y0, y1, prof, nome, con_parete=True, lati=('s', 'n', 'e', 'o')):
    """Bordo a sfioro (griglia + copertina) intorno a una vasca rettangolare, con i 4 angoli."""
    pezzi = []
    def tratti(a, b):
        out, t = [], a
        while t < b - 1e-6:
            w = min(2.0, b - t)
            out.append((t, w))
            t += w
        return out
    if 's' in lati:
        for t, w in tratti(x0, x1):
            pezzi.append(metti(K.bordo_vasca(mats, w, prof, nome=un(f'{nome}_s'), con_parete=con_parete), (t, y0, 0)))
    if 'n' in lati:
        for t, w in tratti(x0, x1):
            pezzi.append(metti(K.bordo_vasca(mats, w, prof, nome=un(f'{nome}_n'), con_parete=con_parete), (t + w, y1, 0), 180))
    if 'e' in lati:
        for t, w in tratti(y0, y1):
            pezzi.append(metti(K.bordo_vasca(mats, w, prof, nome=un(f'{nome}_e'), con_parete=con_parete), (x1, t, 0), 90))
    if 'o' in lati:
        for t, w in tratti(y0, y1):
            pezzi.append(metti(K.bordo_vasca(mats, w, prof, nome=un(f'{nome}_o'), con_parete=con_parete), (x0, t + w, 0), -90))
    # angoli (spigoli della vasca): rotazione che porta (-x,-y) del pezzo verso l'interno della vasca
    for (px, py, rot) in ((x1, y1, 0), (x0, y1, 90), (x0, y0, 180), (x1, y0, -90)):
        pezzi.append(metti(K.bordo_vasca_angolo(mats, prof, nome=un(f'{nome}_ang')), (px, py, 0), rot))
    return unisci(pezzi, nome + '_bordi')


def piscina_onde(mats):
    """Piscina a onde vuota: fondo con pendenza verso la spiaggia (nord) e conca dello scarico a sud,
    pareti che seguono il fondo, bocchette della camera delle onde, portello, pozza torbida."""
    P = PISCINA
    x0, x1, y0, y1, H = P['x0'], P['x1'], P['y0'], P['y1'], P['prof']
    sx, sy = P['scarico']
    def zf(x, y):
        if y <= P['y_pendenza']:
            z = -H
        else:
            z = -H + H * (y - P['y_pendenza']) / (y1 - P['y_pendenza'])
        d = math.hypot(x - sx, y - sy)
        t = max(0.0, min(1.0, d / 4.6))
        conca = -0.24 * (1 - t * t * (3 - 2 * t))
        return z + conca
    c = K.Costruttore(mats)
    passo = 0.5
    nx, ny = int((x1 - x0) / passo), int((y1 - y0) / passo)
    # buco del pozzo della camera delle onde sotto il portello (1,28 x 1,28 m, centrato sullo scarico:
    # Godot x +-0,64, z da 1,36 a 2,64), con il bordo smussato a 45 gradi (SM) e il collare piastrellato
    bx0, by0, bx1, by1 = BUCO_POZZO
    SM = 0.03
    xs = sorted(set([round(x0 + i * passo, 4) for i in range(nx + 1)] + [round(bx0 - SM, 4), round(bx1 + SM, 4)]))
    ys = sorted(set([round(y0 + j * passo, 4) for j in range(ny + 1)] + [round(by0 - SM, 4), round(by1 + SM, 4)]))
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            a, b, a2, b2 = xs[i], ys[j], xs[i + 1], ys[j + 1]
            if bx0 - SM < (a + a2) / 2 < bx1 + SM and by0 - SM < (b + b2) / 2 < by1 + SM:
                continue
            q = [(a, b), (a2, b), (a2, b2), (a, b2)]
            c.faccia([(x, y, zf(x, y)) for x, y in q], 'vasca', liscia=True)
    # anello esterno (sul fondo, sugli stessi vertici della griglia) e interno (in fondo allo smusso)
    ex0, ey0, ex1, ey1 = round(bx0 - SM, 4), round(by0 - SM, 4), round(bx1 + SM, 4), round(by1 + SM, 4)
    fuori = ([(x, ey0) for x in xs if ex0 <= x < ex1] + [(ex1, y) for y in ys if ey0 <= y < ey1] +
             [(x, ey1) for x in xs[::-1] if ex0 < x <= ex1] + [(ex0, y) for y in ys[::-1] if ey0 < y <= ey1])
    dentro = [(min(max(x, bx0), bx1), min(max(y, by0), by1)) for x, y in fuori]
    z_coll = zf(sx, sy) - 0.24          # fondo del collare: lo spessore della soletta, poi c'è il pozzo
    cx_b, cy_b = (bx0 + bx1) / 2, (by0 + by1) / 2
    n_b = len(fuori)
    for k in range(n_b):
        (xa, ya), (xb, yb) = fuori[k], fuori[(k + 1) % n_b]
        (ia, ja), (ib, jb) = dentro[k], dentro[(k + 1) % n_b]
        za, zb_ = zf(xa, ya), zf(xb, yb)
        verso_dentro = Vector((cx_b - (ia + ib) / 2, cy_b - (ja + jb) / 2, 0)).normalized()
        c.faccia_verso([(xa, ya, za), (xb, yb, zb_), (ib, jb, zb_ - SM), (ia, ja, za - SM)], 'vasca',
                       verso_dentro + Vector((0, 0, 1)), liscia=True)
        if (ia, ja) != (ib, jb):
            c.faccia_verso([(ia, ja, za - SM), (ib, jb, zb_ - SM), (ib, jb, z_coll), (ia, ja, z_coll)], 'vasca', verso_dentro)
    # pareti (seguono il fondo): sud (normale +y), est (-x), ovest (+x). A fasce orizzontali, fitte
    # intorno alla linea dell'ultimo livello dell'acqua (z -0,36), per lo sporco nei colori dei vertici
    livelli = [-0.2, -0.3, -0.345, -0.36, -0.375, -0.42, -0.6, -0.9, -1.25, -1.6, -1.95, -2.4]
    def parete_a_fasce(A, B, zbA, zbB):
        su = -0.04
        for giu in livelli:
            tA, tB = max(su, zbA), max(su, zbB)
            bA, bB = max(giu, zbA), max(giu, zbB)
            hA, hB = tA - bA, tB - bB
            if hA > 1e-4 and hB > 1e-4:
                c.faccia([(*A, tA), (*B, tB), (*B, bB), (*A, bA)], 'vasca')
            elif hA > 1e-4:
                c.faccia([(*A, tA), (*B, tB), (*A, bA)], 'vasca')
            elif hB > 1e-4:
                c.faccia([(*A, tA), (*B, tB), (*B, bB)], 'vasca')
            su = giu
    for i in range(nx):
        a, b = x0 + i * passo, x0 + (i + 1) * passo
        parete_a_fasce((a, y0), (b, y0), zf(a, y0), zf(b, y0))
    for j in range(ny):
        a, b = y0 + j * passo, y0 + (j + 1) * passo
        if zf(x1, a) < -0.045 or zf(x1, b) < -0.045:
            parete_a_fasce((x1, a), (x1, b), min(-0.04, zf(x1, a)), min(-0.04, zf(x1, b)))
            parete_a_fasce((x0, b), (x0, a), min(-0.04, zf(x0, b)), min(-0.04, zf(x0, a)))
    vasca = c.crea('sala_piscina_onde')
    D.colora(vasca, D.sporco_piscina)
    # collisione: fondo e pareti come trimesh
    col = vasca.copy(); col.data = vasca.data.copy(); col.name = 'sala_piscina_onde-colonly'
    bpy.context.scene.collection.objects.link(col); col.parent = vasca; col.hide_render = True
    bordi = bordi_rettangolo(mats, x0, x1, y0, y1, H, 'piscina', con_parete=False)
    # bocchette della camera delle onde nella parete sud + portello sul fondo
    g = K.Costruttore(mats)
    for bx in (-4.5, 0.0, 4.5):
        w, h, zb = 2.0, 0.9, -1.75
        g.faccia([(bx - w / 2, y0 + 0.01, zb), (bx + w / 2, y0 + 0.01, zb), (bx + w / 2, y0 + 0.01, zb + h), (bx - w / 2, y0 + 0.01, zb + h)], 'nero')
        for (a0, a1, b0, b1) in ((bx - w / 2 - 0.08, bx + w / 2 + 0.08, zb - 0.08, zb), (bx - w / 2 - 0.08, bx + w / 2 + 0.08, zb + h, zb + h + 0.08),
                                 (bx - w / 2 - 0.08, bx - w / 2, zb, zb + h), (bx + w / 2, bx + w / 2 + 0.08, zb, zb + h)):
            g.scatola((a0, y0, b0), (a1, y0 + 0.05, b1), 'torre')
        for k in range(1, 12):
            xx = bx - w / 2 + k * w / 12
            g.cilindro((xx, y0 + 0.04, zb), (xx, y0 + 0.04, zb + h), 0.014, 'torre', seg=6, tappi=False)
        g.cilindro((bx - w / 2, y0 + 0.04, zb + h / 2), (bx + w / 2, y0 + 0.04, zb + h / 2), 0.02, 'torre', seg=6, tappi=False)
    dett = g.crea('sala_piscina_bocchette')
    # rosa dei venti a mosaico sul fondo (parte profonda): piano RGBA appena sopra il fondo
    rc = (0.0, 3.6)
    rv = K.Costruttore(mats)
    n = 16
    for i in range(n):
        for j in range(n):
            a, b = rc[0] - 2.0 + 4.0 * i / n, rc[1] - 2.0 + 4.0 * j / n
            q = [(a, b), (a + 4.0 / n, b), (a + 4.0 / n, b + 4.0 / n), (a, b + 4.0 / n)]
            uv = [((x - rc[0] + 2.0) / 4.0, (y - rc[1] + 2.0) / 4.0) for x, y in q]
            rv.faccia([(x, y, zf(x, y) + 0.006) for x, y in q], 'alfa_rosa_venti', uv=uv, liscia=True)
    rosa = rv.crea('sala_piscina_rosa_venti')
    # pozza torbida sul fondo (sopra il portello)
    acqua = acqua_piana('sala_pozza', x0 + 0.01, x1 - 0.01, y0 + 0.01, 3.0, zf(sx, sy) + 0.17, torbida=True)
    # scalette nella parte profonda
    sc1 = metti(K.scaletta_vasca(mats, profondita=H, gradini=5, nome='sala_scaletta_e'), (x1, -3.2, 0), 90)
    sc2 = metti(K.scaletta_vasca(mats, profondita=H, gradini=5, nome='sala_scaletta_o'), (x0, -2.2, 0), -90)
    return [vasca, bordi, dett, rosa, acqua, sc1, sc2], zf


def acqua_piana(nome, x0, x1, y0, y1, z, torbida=False, colore=None):
    m = bpy.data.materials.get('M_acqua_torbida' if torbida else 'M_acqua_vasca')
    if m is None:
        m = bpy.data.materials.new('M_acqua_torbida' if torbida else 'M_acqua_vasca')
        m.use_nodes = True
        nt = m.node_tree
        b = nt.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = colore or ((0.09, 0.12, 0.07, 1) if torbida else (0.06, 0.16, 0.15, 1))
        b.inputs['Roughness'].default_value = 0.035
        b.inputs['Transmission Weight'].default_value = 0.55 if torbida else 0.9
        b.inputs['IOR'].default_value = 1.333
        no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 2.5
        no.inputs['Detail'].default_value = 4.0
        bu = nt.nodes.new('ShaderNodeBump'); bu.inputs['Strength'].default_value = 0.035
        nt.links.new(no.outputs['Fac'], bu.inputs['Height'])
        nt.links.new(bu.outputs['Normal'], b.inputs['Normal'])
    bpy.ops.mesh.primitive_plane_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, z))
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = (x1 - x0, y1 - y0, 1)
    ob.data.materials.append(m)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob


def vasca_arrivo(mats):
    V = VASCA_ARRIVO
    x0, x1, y0, y1, H = V['x0'], V['x1'], V['y0'], V['y1'], V['prof']
    pezzi = [bordi_rettangolo(mats, x0, x1, y0, y1, H, 'arrivo', con_parete=True)]
    c = K.Costruttore(mats)
    c.faccia([(x0, y0, -H), (x1, y0, -H), (x1, y1, -H), (x0, y1, -H)], 'vasca')
    fondo = c.crea('sala_vasca_arrivo_fondo', sporco=lambda co: 0.7)
    K.collisione_scatola('vasca_arrivo_fondo', (x0, y0, -H - 0.2), (x1, y1, -H), padre=fondo)
    pezzi.append(fondo)
    pezzi.append(acqua_piana('sala_vasca_arrivo_acqua', x0, x1, y0, y1, V['acqua']))
    return pezzi


def vasca_bassa(mats, cx, cy, lx, ly, nome, acqua=0.3, bordi=None):
    """Vasca bassa dell'area bimbi: bordo rialzato 0,45 m a scacchi blu e bianchi (come nello
    storyboard S09), fondo azzurro, acqua che sale. 'bordi': le scatole del bordo (x0, y0, x1, y1), se
    non è l'anello di serie (la VascaBimbi1 ha il lato sud aperto sulla fossa)."""
    c = K.Costruttore(mats)
    h, s = 0.45, 0.3
    x0, x1, y0, y1 = cx - lx / 2, cx + lx / 2, cy - ly / 2, cy + ly / 2
    # anello del bordo come 4 scatole
    bordi = bordi or ((x0 - s, y0 - s, x1 + s, y0), (x0 - s, y1, x1 + s, y1 + s), (x0 - s, y0, x0, y1), (x1, y0, x1 + s, y1))
    for (a0, b0, a1, b1) in bordi:
        c.scatola((a0, b0, 0), (a1, b1, h), 'scacchi', senza=('-z',))
    c.faccia([(x0, y0, 0.02), (x1, y0, 0.02), (x1, y1, 0.02), (x0, y1, 0.02)], 'vasca_bimbi')
    ob = c.crea(nome, sporco=lambda co: 0.85 if co.z < 0.1 else 1.0)
    for i, (a0, b0, a1, b1) in enumerate(bordi):
        K.collisione_scatola(f'{nome}_{i}', (a0, b0, 0), (a1, b1, h), padre=ob)
    acq = acqua_piana(nome + '_acqua', x0, x1, y0, y1, acqua)
    return [ob, acq]


def fossa_bimbi_punti():
    """Punti della fossa (Blender): poligono interno (in senso orario visto dall'alto: NO, O, S, SE, NE),
    esagono dell'angolo tagliato del bordo e triangolo di pavimento fuori dalla diagonale esterna."""
    F = FOSSA_BIMBI
    x0, x1, y0, y1, c, s = F['x0'], F['x1'], F['y0'], F['y1'], F['taglio'], F['bordo']
    r2 = math.sqrt(2.0)
    interno = [(x0, y1), (x0, y0 + c), (x0 + c, y0), (x1, y0), (x1, y1)]
    yo = y0 + c - s * r2 + s           # diagonale esterna del bordo sul filo esterno ovest (x0 - s)
    xo = x0 + c - s * r2 + s           # e sul filo esterno sud (y0 - s)
    angolo = [(x0 - s, y0 + c), (x0, y0 + c), (x0 + c, y0), (x0 + c, y0 - s), (xo, y0 - s), (x0 - s, yo)]
    t = c - s * r2                     # il triangolo di pavimento dentro il rettangolo, fuori dal bordo
    triangolo = [(x0, y0), (x0 + t, y0), (x0, y0 + t)]
    return interno, angolo, triangolo


def bordi_vasca_bimbi_1():
    """Bordo della VascaBimbi1 con il lato sud aperto sulla fossa (le scatole che restano)."""
    F = FOSSA_BIMBI
    s = F['bordo']
    x0, x1, y0, y1 = -12.6 - 2.2, -12.6 + 2.2, 9.6 - 1.6, 9.6 + 1.6
    return ((x0 - s, y1, x1 + s, y1 + s),                 # nord
            (x1, y0, x1 + s, y1),                         # est
            (F['x1'], y0 - s, x1 + s, y0),                # sud, solo a est della fossa
            (x0 - s, F['y0'] + F['taglio'], x0, y1))      # ovest, fino all'angolo tagliato della fossa


def fossa_bimbi(mats):
    """Fossa dello scarico di compensazione rotto della VascaBimbi1 (tappa 8): la parte profonda della vasca.
    Pareti piastrellate fino a -0,6 e poi cemento grezzo, fondo a -3, condotto orizzontale verso est in
    fondo, griglia divelta e piegata sul lato nord, bordo a scacchi tutto intorno (con l'angolo tagliato
    a sud-ovest su cui appoggia le mani la medusa). Collisioni: pareti e fondo; il coperchio a filo del
    fondo della vasca è un oggetto a parte (coperchio_fossa_col), da accendere e spegnere nel gioco.
    Restituisce (oggetti, acqua segnaposto, coperchio)."""
    F = FOSSA_BIMBI
    x0, x1, y0, y1, s, hb = F['x0'], F['x1'], F['y0'], F['y1'], F['bordo'], F['h_bordo']
    zf_, zp = F['fondo'], F['piastrelle']
    C = F['condotto']
    interno, angolo, triangolo = fossa_bimbi_punti()
    cx_, cy_ = sum(p[0] for p in interno) / len(interno), sum(p[1] for p in interno) / len(interno)
    c = K.Costruttore(mats)
    # pareti: piastrelle in alto, cemento sotto (la parete est ha il buco del condotto)
    for k in range(len(interno)):
        (ax, ay), (bx, by) = interno[k], interno[(k + 1) % len(interno)]
        dentro = Vector((cx_ - (ax + bx) / 2, cy_ - (ay + by) / 2, 0)).normalized()
        if abs(by - ay) < 1e-6 and ay == y1:
            zt = 0.02                                   # lato nord: sotto il bordo del fondo della vasca
        else:
            zt = 0.0
        c.faccia_verso([(ax, ay, zt), (bx, by, zt), (bx, by, zp), (ax, ay, zp)], 'vasca_bimbi', dentro)
        if abs(ax - x1) < 1e-6 and abs(bx - x1) < 1e-6:
            continue                                    # parete est: sotto, il ventaglio intorno al condotto
        c.faccia_verso([(ax, ay, zp), (bx, by, zp), (bx, by, zf_), (ax, ay, zf_)], 'cemento', dentro)
    # parete est sotto le piastrelle: ventaglio tra il cerchio del condotto e il rettangolo
    yc, zc, r = C['y'], C['z'], C['r']
    def bordo_rett(t):
        dy, dz = math.cos(t), math.sin(t)
        ts = [v for v in [((y0 - yc) / dy) if abs(dy) > 1e-9 else None, ((y1 - yc) / dy) if abs(dy) > 1e-9 else None,
                          ((zf_ - zc) / dz) if abs(dz) > 1e-9 else None, ((zp - zc) / dz) if abs(dz) > 1e-9 else None]
              if v is not None and v > 0]
        tt = min(ts)
        return (x1, yc + dy * tt, zc + dz * tt)
    n = 40
    angoli = sorted(set([2 * math.pi * k / n for k in range(n)] +
                        [math.atan2(pz - zc, py - yc) % (2 * math.pi) for py, pz in ((y0, zf_), (y1, zf_), (y1, zp), (y0, zp))]))
    for k in range(len(angoli)):
        t0, t1 = angoli[k], angoli[(k + 1) % len(angoli)]
        q = [(x1, yc + math.cos(t0) * r, zc + math.sin(t0) * r), bordo_rett(t0), bordo_rett(t1),
             (x1, yc + math.cos(t1) * r, zc + math.sin(t1) * r)]
        c.faccia_verso(q, 'cemento', (-1, 0, 0))
    # condotto: tubo di cemento verso est, con la ghiera arrugginita alla bocca e il buio in fondo
    xf = C['x_fine']
    for k in range(32):
        t0, t1 = 2 * math.pi * k / 32, 2 * math.pi * (k + 1) / 32
        p0 = (yc + math.cos(t0) * r, zc + math.sin(t0) * r); p1 = (yc + math.cos(t1) * r, zc + math.sin(t1) * r)
        verso = Vector((0, -(math.cos(t0) + math.cos(t1)), -(math.sin(t0) + math.sin(t1))))
        c.faccia_verso([(x1, *p0), (xf, *p0), (xf, *p1), (x1, *p1)], 'cemento', verso)
    c.disco((xf, yc, zc), (-1, 0, 0), r, 'nero', seg=32)
    c.toro((x1 - 0.02, yc, zc), (1, 0, 0), r + 0.03, 0.035, 'torre', seg=40, seg_r=6)
    # fondo di cemento
    c.faccia_verso([(x, y, zf_) for x, y in interno], 'cemento', (0, 0, 1))
    # bordo a scacchi intorno alla fossa: lato sud, lato est e l'angolo tagliato (esagono)
    for (a0, b0, a1, b1) in ((x0 + F['taglio'], y0 - s, x1, y0), (x1, y0 - s, x1 + s, y1 - s)):
        c.scatola((a0, b0, 0), (a1, b1, hb), 'scacchi', senza=('-z',))
    c.faccia_verso([(x, y, hb) for x, y in angolo], 'scacchi', (0, 0, 1))
    for k in range(len(angolo)):
        (ax, ay), (bx, by) = angolo[k], angolo[(k + 1) % len(angolo)]
        mx, my = (ax + bx) / 2, (ay + by) / 2
        ccx, ccy = sum(p[0] for p in angolo) / 6, sum(p[1] for p in angolo) / 6
        c.faccia_verso([(ax, ay, 0), (bx, by, 0), (bx, by, hb), (ax, ay, hb)], 'scacchi', (mx - ccx, my - ccy, 0))
    # pavimento della sala nel triangolo fuori dalla diagonale esterna del bordo
    c.faccia_verso([(x, y, 0.0) for x, y in triangolo], 'pavimento', (0, 0, 1))
    # griglia di scarico divelta: ancora agganciata al lato nord, piegata giù nella fossa in due tratti
    ga, gb = -14.1, -12.6
    def tratto(origine, v, lunghezza, nome):
        v = Vector(v).normalized(); u = Vector((1, 0, 0)); w = u.cross(v).normalized()
        O = Vector(origine)
        nb = 26
        for i in range(nb + 1):
            x = ga + (gb - ga) * i / nb
            centro = O + Vector((x - O.x, 0, 0)) + v * (lunghezza / 2)
            c.scatola_assi(tuple(centro), (u, v, w), (0.004, lunghezza / 2, 0.016), 'torre')
        for (x, mz) in ((ga, 0.006), (gb, 0.006)):
            centro = O + Vector((x - O.x, 0, 0)) + v * (lunghezza / 2)
            c.scatola_assi(tuple(centro), (u, v, w), (0.012, lunghezza / 2, 0.02), 'torre')
        for j in range(1, int(lunghezza / 0.1)):
            p = O + v * (j * 0.1)
            c.cilindro((ga, p.y, p.z), (gb, p.y, p.z), 0.005, 'torre', seg=5, tappi=False)
        return O + v * lunghezza
    piega = tratto(((ga + gb) / 2, y1 - 0.02, -0.01), (0, -math.cos(math.radians(14)), -math.sin(math.radians(14))), 0.34, 'a')
    tratto(tuple(piega), (0, -math.cos(math.radians(72)), -math.sin(math.radians(72))), 0.86, 'b')
    def sporco(co):
        if co.z > -0.05:
            return 0.85
        return max(0.38, 0.8 + 0.14 * co.z)          # più buio e sporco andando giù
    ob = c.crea('sala_fossa_bimbi', sporco=sporco)
    # collisioni: pareti, fondo, bordo e triangolo di pavimento (figlie); il condotto resta chiuso dalla parete est
    K.collisione_scatola('fossa_parete_o', (x0 - 0.2, y0 + F['taglio'], zf_), (x0, y1, 0.0), padre=ob)
    K.collisione_scatola('fossa_parete_n', (x0, y1, zf_), (x1, y1 + 0.2, 0.02), padre=ob)
    K.collisione_scatola('fossa_parete_e', (x1, y0, zf_), (x1 + 0.2, y1, 0.0), padre=ob)
    K.collisione_scatola('fossa_parete_s', (x0 + F['taglio'], y0 - 0.2, zf_), (x1, y0, 0.0), padre=ob)
    (bx_, by_), (cx2, cy2) = interno[1], interno[2]
    off = Vector((-1, -1, 0)).normalized() * 0.2
    K.collisione_punti('fossa_parete_diagonale', [(px + dx, py + dy, z) for (px, py) in ((bx_, by_), (cx2, cy2))
                                                   for (dx, dy) in ((0, 0), (off.x, off.y)) for z in (zf_, 0.0)], padre=ob)
    K.collisione_scatola('fossa_fondo', (x0, y0, zf_ - 0.2), (x1, y1, zf_), padre=ob)
    K.collisione_scatola('fossa_bordo_s', (x0 + F['taglio'], y0 - s, 0), (x1, y0, hb), padre=ob)
    K.collisione_scatola('fossa_bordo_e', (x1, y0 - s, 0), (x1 + s, y1 - s, hb), padre=ob)
    K.collisione_punti('fossa_bordo_angolo', [(x, y, z) for x, y in angolo for z in (0.0, hb)], padre=ob)
    K.collisione_punti('fossa_pavimento_angolo', [(x, y, z) for x, y in triangolo for z in (-0.2, 0.0)], padre=ob)
    for ch in ob.children:
        ch.hide_render = True
    # coperchio invisibile a filo del fondo della vasca: oggetto a parte, il gioco lo accende e lo spegne
    coperchio = K.collisione_scatola('coperchio_fossa_col', (x0, y0, -0.1), (x1, y1, 0.02))
    coperchio.hide_render = True
    acqua = acqua_piana('sala_fossa_bimbi_acqua', x0, x1, y0, y1, 0.30)
    return [ob], acqua, coperchio


def pozzanghere(mats, n=34, seme=8):
    """Pozzanghere sul pavimento: poligoni irregolari appena sopra il pavimento, materiale scuro e
    lucidissimo (opaco, così in Godot riflettono con SSR). Evitano vasche, piedistallo e colonne."""
    import random
    rnd = random.Random(seme)
    m = bpy.data.materials.get('M_amb_pozzanghera') or bpy.data.materials.new('M_amb_pozzanghera')
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.022, 0.026, 0.028, 1)
    b.inputs['Roughness'].default_value = 0.03
    b.inputs['Specular IOR Level'].default_value = 0.5
    class _M:
        def lato(self, nn): return 2.0
        def get(self, nn): return m
    c = K.Costruttore(_M())
    vietati = [(PISCINA['x0'] - 0.7, PISCINA['y0'] - 0.7, PISCINA['x1'] + 0.7, PISCINA['y1'] + 0.7),
               (VASCA_ARRIVO['x0'] - 0.7, VASCA_ARRIVO['y0'] - 0.7, VASCA_ARRIVO['x1'] + 0.7, VASCA_ARRIVO['y1'] + 0.7),
               (PIEDISTALLO['cx'] - 1.5, PIEDISTALLO['cy'] - 1.5, PIEDISTALLO['cx'] + 1.5, PIEDISTALLO['cy'] + 1.5),
               (STRUTTURA['cx'] - 4.6, STRUTTURA['cy'] - 5.6, STRUTTURA['cx'] + 2.0, STRUTTURA['cy'] + 3.4),
               (TORRE['cx'] - 3.3, TORRE['cy'] - 4.5, TORRE['cx'] + 3.3, TORRE['cy'] + 3.3)] + \
              [(a - 0.3, b_ - 0.3, c_ + 0.3, d + 0.3) for a, b_, c_, d in VASCHE_BASSE]
    # zone preferite: intorno alla piscina, sotto le gallerie, vicino ai muri
    fatti = 0
    tent = 0
    while fatti < n and tent < 2000:
        tent += 1
        zona = rnd.random()
        if zona < 0.45:   # anello intorno alla piscina
            ang = rnd.uniform(0, 2 * math.pi)
            x = max(PISCINA['x0'] - 3.5, min(PISCINA['x1'] + 3.5, math.cos(ang) * 10.0))
            y = 4.0 + math.sin(ang) * 11.5
        else:
            x, y = rnd.uniform(X0 + 0.6, X1 - 0.6), rnd.uniform(Y0 + 0.6, Y1 - 0.6)
        r0 = rnd.uniform(0.35, 1.5)
        if any(a - r0 < x < c_ + r0 and b_ - r0 < y < d + r0 for a, b_, c_, d in vietati):
            continue
        if not (X0 + r0 + 0.2 < x < X1 - r0 - 0.2 and Y0 + r0 + 0.2 < y < Y1 - r0 - 0.2):
            continue
        k = 28
        fase = [rnd.uniform(0, 6.28) for _ in range(3)]
        sx, sy = rnd.uniform(0.7, 1.4), rnd.uniform(0.6, 1.2)
        pts = []
        for i in range(k):
            t = 2 * math.pi * i / k
            rr = r0 * (1 + 0.22 * math.sin(2 * t + fase[0]) + 0.12 * math.sin(3 * t + fase[1]) + 0.07 * math.sin(5 * t + fase[2]))
            pts.append((x + math.cos(t) * rr * sx, y + math.sin(t) * rr * sy, 0.004))
        c.faccia(pts, 'pozzanghera')
        fatti += 1
    return c.crea('sala_pozzanghere')


# ----------------------------------------------------------------------------- piedistallo e lampione

def _verso_quat(d):
    return Vector(d).normalized().to_track_quat('-Z', 'Y')


def conchiglia(c, base, normale, R, mat, su=(0, 0, 1)):
    """Conchiglia a ventaglio (pettine) con le coste: cerniera in 'base', si apre verso 'su',
    sporge lungo 'normale'. Serve sul piedistallo (in ottone) e tra le offerte (piccole)."""
    b = Vector(base); n = Vector(normale).normalized(); up = Vector(su).normalized()
    up = (up - n * up.dot(n)).normalized(); lato = up.cross(n)
    na, nr = 15, 4
    def P(i, j):
        a = math.radians(-72 + 144 * i / (na - 1))
        r = R * j / nr
        costa = 0.18 * R * abs(math.cos(i * math.pi / 2)) * (j / nr)
        h = 0.32 * R * math.sqrt(max(0.0, 1 - (j / nr) ** 2 * 0.85)) * min(1.0, j / 1.2) + costa * 0.35
        return b + lato * (math.sin(a) * r) + up * (math.cos(a) * r) + n * h
    for i in range(na - 1):
        for j in range(nr):
            q = [P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)]
            if j == 0:
                q = [P(i, 0), P(i + 1, 1), P(i, 1)]
            c.faccia([tuple(v) for v in q][::-1], mat, liscia=True)


def stella_marina(c, centro, R, mat, rot=0.0, z_su=(0, 0, 1)):
    """Stella marina piatta a 5 braccia (spessore 1,5 cm, centro rialzato)."""
    cx, cy, cz = centro
    pts = []
    for i in range(10):
        a = rot + i * math.pi / 5
        rr = R if i % 2 == 0 else R * 0.38
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    alto = (cx, cy, cz + 0.022)
    for i in range(10):
        a, b = pts[i], pts[(i + 1) % 10]
        c.faccia([(a[0], a[1], cz + 0.012), (b[0], b[1], cz + 0.012), alto], mat, liscia=True)
        c.faccia([(a[0], a[1], cz), (b[0], b[1], cz), (b[0], b[1], cz + 0.012), (a[0], a[1], cz + 0.012)], mat)


def piedistallo(mats):
    """Piedistallo MONUMENTALE della statua (VUOTO: la medusa la mette il gruppo "medusa"): due
    gradoni (Ø 4,0 e 3,24 m) piastrellati, tamburo Ø 2,6 m con il fregio a mosaico marino, cornice
    in ceramica con il toro d'ottone, piano a 1,15 m (Ø 2,84 m). Conchiglie d'ottone sul secondo
    gradino, scatola gialla del pulsante dei bambini sul davanti (verso l'ingresso, -y), quattro
    faretti incassati sul primo gradino che illuminano la statua dal basso.
    Restituisce (oggetto, luci) con le luci come dizionari (nome, posizione, direzione)."""
    P = PIEDISTALLO
    c = K.Costruttore(mats)
    cx, cy = P['cx'], P['cy']
    z1, z2, z3, h = P['z1'], P['z2'], P['z3'], P['h']
    seg = 96
    def parete_cil(r, za, zb, mat, lato_u=None, alto_v=None):
        lt = mats.lato(mat)
        for k in range(seg):
            t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
            q = [(cx + math.cos(t0) * r, cy + math.sin(t0) * r, za), (cx + math.cos(t1) * r, cy + math.sin(t1) * r, za),
                 (cx + math.cos(t1) * r, cy + math.sin(t1) * r, zb), (cx + math.cos(t0) * r, cy + math.sin(t0) * r, zb)]
            if lato_u:   # fregio: u = arco / ripetizione, v da 0 a 1 sull'altezza
                uv = [(r * t0 / lato_u, 0.0), (r * t1 / lato_u, 0.0), (r * t1 / lato_u, 1.0), (r * t0 / lato_u, 1.0)]
            else:
                uv = [(r * t0 / lt, za / lt), (r * t1 / lt, za / lt), (r * t1 / lt, zb / lt), (r * t0 / lt, zb / lt)]
            c.faccia(q, mat, uv=uv, liscia=True)
    def corona(r_in, r_out, z, mat, giu=False):
        for k in range(seg):
            t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
            q = [(cx + math.cos(t0) * r_in, cy + math.sin(t0) * r_in, z), (cx + math.cos(t0) * r_out, cy + math.sin(t0) * r_out, z),
                 (cx + math.cos(t1) * r_out, cy + math.sin(t1) * r_out, z), (cx + math.cos(t1) * r_in, cy + math.sin(t1) * r_in, z)]
            c.faccia(q[::-1] if giu else q, mat)
    # gradoni
    parete_cil(P['r_base'], 0.0, z1, 'zoccolo')
    corona(P['r_gradino'], P['r_base'], z1, 'bordo')
    c.toro((cx, cy, z1 - 0.012), (0, 0, 1), P['r_base'] - 0.004, 0.016, 'bordo', seg=120, seg_r=6)
    parete_cil(P['r_gradino'], z1, z2, 'piedistallo')
    corona(P['r_tamburo'], P['r_gradino'], z2, 'bordo')
    c.toro((cx, cy, z2 - 0.012), (0, 0, 1), P['r_gradino'] - 0.004, 0.016, 'bordo', seg=120, seg_r=6)
    # tamburo con il fregio (una ripetizione ogni 2 m circa)
    giro = 2 * math.pi * P['r_tamburo']
    parete_cil(P['r_tamburo'], z2, z3, 'fregio', lato_u=giro / max(1, round(giro / 2.04)))
    c.toro((cx, cy, z2 + 0.02), (0, 0, 1), P['r_tamburo'] + 0.008, 0.02, 'cornice_oblo', seg=120, seg_r=8)
    # cornice e piano
    corona(P['r_tamburo'] - 0.01, P['r_piano'], z3, 'bordo', giu=True)
    parete_cil(P['r_piano'], z3, h - 0.03, 'bordo')
    c.toro((cx, cy, h - 0.03), (0, 0, 1), P['r_piano'] - 0.03, 0.03, 'bordo', seg=120, seg_r=8)
    c.disco((cx, cy, h), (0, 0, 1), P['r_piano'] - 0.03, 'piano_statua', seg=seg)
    c.toro((cx, cy, z3 + 0.005), (0, 0, 1), P['r_piano'] + 0.012, 0.028, 'cornice_oblo', seg=120, seg_r=8)
    # conchiglie d'ottone sul secondo gradino (non sul davanti, dove c'è il pulsante)
    for a in (-30, 30, 90, 150, 210):
        t = math.radians(a)
        nrm = (math.cos(t), math.sin(t), 0.0)
        base = (cx + nrm[0] * (P['r_gradino'] - 0.01), cy + nrm[1] * (P['r_gradino'] - 0.01), z1 + 0.035)
        conchiglia(c, base, nrm, 0.2, 'cornice_oblo')
    # pulsante dei bambini: scatola gialla sul davanti del tamburo (il fungo rosso è in sala_interattivi)
    by = cy - P['r_tamburo']
    zb = P['z_pulsante']
    c.scatola((cx - 0.21, by - 0.13, zb - 0.18), (cx + 0.21, by + 0.08, zb + 0.18), 'gioco_giallo')
    # faretti incassati sul primo gradino, puntati sulla statua
    luci = []
    bersaglio = Vector((cx, cy, h + 2.9))     # busto e campana della statua (alta 4,5 m sul piano)
    for i, a in enumerate((45, 135, 225, 315)):
        t = math.radians(a)
        r = (P['r_base'] + P['r_gradino']) / 2
        p = Vector((cx + math.cos(t) * r, cy + math.sin(t) * r, z1))
        c.scatola(tuple(p + Vector((-0.1, -0.1, 0.0))), tuple(p + Vector((0.1, 0.1, 0.035))), 'metallo')
        d = (bersaglio - p).normalized()
        testa = p + Vector((0, 0, 0.09))
        c.cilindro(tuple(testa - d * 0.06), tuple(testa + d * 0.06), 0.055, 'metallo', seg=12)
        c.disco(tuple(testa + d * 0.061), tuple(d), 0.045, 'lampadina', seg=12)
        c.scatola(tuple(p + Vector((-0.02, -0.02, 0.03))), tuple(p + Vector((0.02, 0.02, 0.08))), 'metallo')
        luci.append(dict(nome=f'luce_monumento_basso_{i}', pos=tuple(testa + d * 0.09), dir=tuple(d), colore=(1.0, 0.82, 0.58)))
    ob = c.crea('amb_piedistallo', sporco=lambda co: 0.82 + 0.18 * min(1.0, co.z / 0.6))
    # collisioni: tre prismi a 16 lati (gradoni e tamburo con il piano)
    for nome_c, r, za, zb_ in (('piedistallo_gradino1', P['r_base'], 0.0, z1), ('piedistallo_gradino2', P['r_gradino'], z1, z2),
                               ('piedistallo_tamburo', P['r_piano'], z2, h)):
        pts = [(cx + math.cos(2 * math.pi * k / 16) * r, cy + math.sin(2 * math.pi * k / 16) * r, z) for k in range(16) for z in (za, zb_)]
        K.collisione_punti(nome_c, pts, padre=ob)
    return ob, luci


def colonnine(c, pali, H, prefisso):
    """Colonnine d'ottone del cordone: il modello HQ (Meshy) se c'è, altrimenti tornite a mano nel
    costruttore c. Restituisce le copie HQ (oggetti da mettere nel gruppo)."""
    if os.path.exists(os.path.join(OGGETTI_HQ, 'colonnina_ottone.glb')):
        return [copia_modello('colonnina_ottone', (x, y, 0.0), (37 * i) % 360, 1.0, nome_ob=f'{prefisso}_{i}',
                              collisione=False) for i, (x, y) in enumerate(pali)]
    for (x, y) in pali:
        c.anello((x, y, 0.0), (0, 0, 1), 0.0, 0.16, 0.025, 'cornice_oblo', seg=20)
        c.cilindro((x, y, 0.025), (x, y, 0.08), 0.06, 'cornice_oblo', seg=14)
        c.cilindro((x, y, 0.08), (x, y, H), 0.022, 'cornice_oblo', seg=12)
        c.cilindro((x, y, H), (x, y, H + 0.05), 0.045, 'cornice_oblo', seg=14)
        c.disco((x, y, H + 0.05), (0, 0, 1), 0.045, 'cornice_oblo', seg=14)
    return []


def cordone(mats):
    """Cordone di velluto rosso su colonnine d'ottone intorno al monumento (raggio 3 m), aperto sul
    davanti verso l'ingresso. Collisioni: un prisma sottile per ogni campata."""
    P = PIEDISTALLO
    c = K.Costruttore(mats)
    cx, cy, R = P['cx'], P['cy'], P['r_cordone']
    angoli = [a for a in range(-60, 241, 30)]       # varco di 60 gradi sul davanti (270 = -y)
    pali = [(cx + math.cos(math.radians(a)) * R, cy + math.sin(math.radians(a)) * R) for a in angoli]
    H = 0.95
    copie = colonnine(c, pali, H, 'sala_monumento_colonnina')
    ob_pts = []
    for (a, b) in zip(pali, pali[1:]):
        A = Vector((a[0], a[1], H - 0.07)); B = Vector((b[0], b[1], H - 0.07))
        curva = []
        for k in range(13):
            t = k / 12
            p = A.lerp(B, t)
            p.z -= 0.16 * (1 - (2 * t - 1) ** 2)
            curva.append(tuple(p))
        c.tubo(curva, 0.024, 'velluto', seg=10)
        for e in (A, B):  # ganci
            c.cilindro(tuple(e + Vector((0, 0, -0.03))), tuple(e + Vector((0, 0, 0.03))), 0.03, 'cornice_oblo', seg=8)
        ob_pts.append((a, b))
    ob = c.crea('sala_monumento_cordone', sporco=lambda co: 0.85)
    for i, (a, b) in enumerate(ob_pts):
        d = Vector((b[0] - a[0], b[1] - a[1], 0)).normalized()
        n = Vector((-d.y, d.x, 0)) * 0.04
        pts = [tuple(Vector((p[0], p[1], z)) + s_ * n) for p in (a, b) for z in (0.0, 1.0) for s_ in (-1, 1)]
        K.collisione_punti(f'cordone_{i}', pts, padre=ob)
    return [ob] + copie


def fari_galleria(mats, bersaglio=None):
    """Due fari da palcoscenico fissati alla ringhiera della galleria sud, puntati sulla statua (o
    sulla medusa affacciata alla vasca)."""
    P = PIEDISTALLO
    c = K.Costruttore(mats)
    luci = []
    bersaglio = Vector(bersaglio) if bersaglio else Vector((P['cx'], P['cy'], P['h'] + 3.4))   # busto e viso
    yr = Y0 + PROF_GAL - 0.06
    for i, x in enumerate((-2.1, 2.1)):
        attacco = Vector((x, yr, Z_GAL + SP_GAL + RINGHIERA_H_SALA))
        corpo = attacco + Vector((0, 0.16, 0.24))
        d = (bersaglio - corpo).normalized()
        c.scatola(tuple(attacco + Vector((-0.06, -0.05, -0.05))), tuple(attacco + Vector((0.06, 0.05, 0.05))), 'nero')   # morsetto
        c.cilindro(tuple(attacco), tuple(corpo - Vector((0, 0, 0.12))), 0.02, 'nero', seg=8)
        lato = d.cross(Vector((0, 0, 1))).normalized()
        for sgn in (-1, 1):   # forcella
            c.cilindro(tuple(corpo - Vector((0, 0, 0.12)) + lato * 0.15 * sgn), tuple(corpo + lato * 0.15 * sgn), 0.012, 'nero', seg=6)
        c.cilindro(tuple(corpo - lato * 0.15), tuple(corpo + lato * 0.15), 0.012, 'nero', seg=6, tappi=False)
        c.cilindro(tuple(corpo - d * 0.22), tuple(corpo + d * 0.2), 0.14, 'nero', seg=16)
        c.anello(tuple(corpo + d * 0.2), tuple(d), 0.1, 0.15, 0.03, 'nero', seg=16)
        c.disco(tuple(corpo + d * 0.205), tuple(d), 0.1, 'lampadina', seg=16)
        for k in range(4):   # alette di raffreddamento
            o = d * (-0.15 + k * 0.08)
            c.toro(tuple(corpo + o), tuple(d), 0.15, 0.01, 'nero', seg=16, seg_r=4)
        luci.append(dict(nome=f'luce_faro_{i}', pos=tuple(corpo + d * 0.3), dir=tuple(d), colore=(1.0, 0.9, 0.76)))
    return c.crea('sala_monumento_fari'), luci


def offerte_monumento(mats):
    """Offerte lasciate dai bambini alla base del monumento (indizio silenzioso della storia):
    disegni a pastello (nessuna scritta), conchiglie, stelle marine, secchiello con paletta.
    Gli oggetti di Meshy (salvagente, orsetto, paperelle, pallone) sono in disponi_oggetti()."""
    import random
    rnd = random.Random(77)
    P = PIEDISTALLO
    cx, cy = P['cx'], P['cy']
    c = K.Costruttore(mats)
    def foglio(i, centro, asse_u, asse_v, curva=0.012):
        """Foglio A4 (0,21 x 0,297 m) un po' imbarcato; i = disegno dell'atlante 2 x 2."""
        C = Vector(centro); U = Vector(asse_u).normalized(); V = Vector(asse_v).normalized()
        N = U.cross(V).normalized()
        u0, v1 = (i % 2) * 0.5, 1.0 - (i // 2) * 0.5
        for k in range(3):
            a, b = k / 3, (k + 1) / 3
            def pt(s, t):
                return tuple(C + U * (s - 0.5) * 0.21 + V * (t - 0.5) * 0.297 + N * curva * math.sin(math.pi * s))
            q = [pt(a, 0), pt(b, 0), pt(b, 1), pt(a, 1)]
            uv = [(u0 + a * 0.5, v1 - 0.5), (u0 + b * 0.5, v1 - 0.5), (u0 + b * 0.5, v1), (u0 + a * 0.5, v1)]
            c.faccia(q, 'disegni', uv=uv)
            c.faccia(q[::-1], 'disegni', uv=uv[::-1])
    # due disegni attaccati al tamburo (davanti, ai lati del pulsante) e quattro sui gradini
    for i, a in ((0, 245), (3, 295)):
        t = math.radians(a)
        n = Vector((math.cos(t), math.sin(t), 0))
        cen = Vector((cx, cy, 0)) + n * (P['r_tamburo'] + 0.012) + Vector((0, 0, P['z2'] + 0.24))
        foglio(i, cen, Vector((-math.sin(t), math.cos(t), 0)), Vector((0, 0.0, 1)), curva=-0.006)
    r1 = (P['r_gradino'] + P['r_base']) / 2          # metà della pedata bassa
    r2 = (P['r_tamburo'] + P['r_gradino']) / 2        # metà della pedata alta
    rt = (P['r_base'] + P['r_cordone']) / 2           # a terra, tra il gradone e il cordone
    for i, (a, r, z) in enumerate(((228, r1, P['z1']), (312, r1 + 0.02, P['z1']), (262, r2, P['z2']), (200, rt, 0.0))):
        t = math.radians(a)
        cen = Vector((cx + math.cos(t) * r, cy + math.sin(t) * r, z + 0.006))
        rot = t + rnd.uniform(-0.5, 0.5)
        foglio((i + 1) % 4, cen, Vector((math.cos(rot), math.sin(rot), 0)), Vector((-math.sin(rot), math.cos(rot), 0)), curva=0.01)
    # conchiglie e stelle marine sui gradini
    for k in range(9):
        a = math.radians(rnd.choice([rnd.uniform(195, 345), rnd.uniform(0, 360)]))
        if rnd.random() < 0.6:
            r, z = rnd.uniform(P['r_gradino'] + 0.06, P['r_base'] - 0.06), P['z1']
        else:
            r, z = rnd.uniform(P['r_tamburo'] + 0.06, P['r_gradino'] - 0.06), P['z2']
        p = (cx + math.cos(a) * r, cy + math.sin(a) * r, z + 0.004)
        if k % 3 == 2:
            stella_marina(c, p, rnd.uniform(0.06, 0.09), 'gioco_arancio', rot=rnd.uniform(0, 6.28))
        else:
            d = rnd.uniform(0, 6.28)
            conchiglia(c, p, (0, 0, 1), rnd.uniform(0.045, 0.07), 'conchiglia', su=(math.cos(d), math.sin(d), 0))
    # secchiello con paletta, a terra davanti a sinistra
    a = math.radians(222)
    b = Vector((cx + math.cos(a) * rt, cy + math.sin(a) * rt, 0.0))
    seg = 16
    for k in range(seg):
        t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        q = [b + Vector((math.cos(t0) * 0.075, math.sin(t0) * 0.075, 0)), b + Vector((math.cos(t1) * 0.075, math.sin(t1) * 0.075, 0)),
             b + Vector((math.cos(t1) * 0.095, math.sin(t1) * 0.095, 0.14)), b + Vector((math.cos(t0) * 0.095, math.sin(t0) * 0.095, 0.14))]
        c.faccia([tuple(v) for v in q], 'gioco_rosso', liscia=True)
        c.faccia([tuple(v) for v in q[::-1]], 'gioco_rosso', liscia=True)
    c.disco(tuple(b + Vector((0, 0, 0.004))), (0, 0, 1), 0.075, 'gioco_rosso', seg=seg)
    c.tubo([tuple(b + Vector((math.cos(t) * 0.095, 0.0, 0.14 + math.sin(t) * 0.1))) for t in [math.pi * k / 10 for k in range(11)]], 0.005, 'inox', seg=5)
    c.cilindro(tuple(b + Vector((0.16, 0.05, 0.012))), tuple(b + Vector((0.36, 0.12, 0.012))), 0.01, 'gioco_giallo', seg=6)
    c.scatola(tuple(b + Vector((0.08, 0.0, 0.004))), tuple(b + Vector((0.17, 0.09, 0.012))), 'gioco_giallo')
    return c.crea('sala_monumento_offerte', sporco=lambda co: 0.9)


# ----------------------------------------------------------------------------- vasca sollevata al centro

def rett_arrotondato(cx, cy, lx, ly, r, z=0.0, passo=0.25, seg_arco=12):
    """Perimetro di un rettangolo con gli angoli arrotondati, in senso antiorario visto dall'alto, a
    partire dal centro del lato nord (la giunta delle UV resta sul retro). Restituisce la lista di
    (punto, normale verso fuori) e le lunghezze d'arco cumulate (una in più: il giro chiuso)."""
    hx, hy = lx / 2 - r, ly / 2 - r
    C = Vector((cx, cy, z))
    pts = []
    def linea(a, b, n):
        L = (b - a).length
        k = max(1, int(math.ceil(L / passo - 1e-6)))
        for i in range(k):
            pts.append((a.lerp(b, i / k), Vector(n)))
    def arco(c, a0):
        for i in range(seg_arco):
            a = math.radians(a0 + 90.0 * i / seg_arco)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            pts.append((c + d * r, d))
    linea(C + Vector((0, ly / 2, 0)), C + Vector((-hx, ly / 2, 0)), (0, 1, 0))
    arco(C + Vector((-hx, hy, 0)), 90)
    linea(C + Vector((-lx / 2, hy, 0)), C + Vector((-lx / 2, -hy, 0)), (-1, 0, 0))
    arco(C + Vector((-hx, -hy, 0)), 180)
    linea(C + Vector((-hx, -ly / 2, 0)), C + Vector((hx, -ly / 2, 0)), (0, -1, 0))
    arco(C + Vector((hx, -hy, 0)), 270)
    linea(C + Vector((lx / 2, -hy, 0)), C + Vector((lx / 2, hy, 0)), (1, 0, 0))
    arco(C + Vector((hx, hy, 0)), 0)
    linea(C + Vector((hx, ly / 2, 0)), C + Vector((0, ly / 2, 0)), (0, 1, 0))
    s = [0.0]
    for i in range(1, len(pts) + 1):
        s.append(s[-1] + (pts[i % len(pts)][0] - pts[i - 1][0]).length)
    return pts, s


def _parete_lungo(c, giro, zs, mat, verso, lato_uv, v0=0.0, v_scala=None):
    """Parete verticale lungo un perimetro chiuso, a fasce alle quote zs. verso +1 = facce verso fuori.
    UV: u = lunghezza d'arco / lato_uv, v = (z - v0) / (v_scala o lato_uv)."""
    pts, s = giro
    n = len(pts)
    vs = v_scala or lato_uv
    for i in range(n):
        (a, na), (b, nb) = pts[i], pts[(i + 1) % n]
        for z0, z1 in zip(zs, zs[1:]):
            q = [(a.x, a.y, z0), (b.x, b.y, z0), (b.x, b.y, z1), (a.x, a.y, z1)]
            uv = [(s[i] / lato_uv, (z0 - v0) / vs), (s[i + 1] / lato_uv, (z0 - v0) / vs),
                  (s[i + 1] / lato_uv, (z1 - v0) / vs), (s[i] / lato_uv, (z1 - v0) / vs)]
            c.faccia_verso(q, mat, tuple((na + nb) * verso), uv=uv, liscia=True)


def materiale_acqua(torbida=False):
    """Materiale segnaposto dell'acqua (lo stesso di acqua_piana)."""
    nome = 'M_acqua_torbida' if torbida else 'M_acqua_vasca'
    m = bpy.data.materials.get(nome)
    if m is None:
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        nt = m.node_tree
        b = nt.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (0.09, 0.12, 0.07, 1) if torbida else (0.06, 0.16, 0.15, 1)
        b.inputs['Roughness'].default_value = 0.035
        b.inputs['Transmission Weight'].default_value = 0.55 if torbida else 0.9
        b.inputs['IOR'].default_value = 1.333
        no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 2.5
        no.inputs['Detail'].default_value = 4.0
        bu = nt.nodes.new('ShaderNodeBump'); bu.inputs['Strength'].default_value = 0.035
        nt.links.new(no.outputs['Fac'], bu.inputs['Height'])
        nt.links.new(bu.outputs['Normal'], b.inputs['Normal'])
    return m


def vasca_centrale(mats):
    """Vasca sollevata al centro della sala (concept medusa_sbircia): muro alto 1 m piastrellato a
    scacchi blu notte e crema (piastrelle da 25 cm, fughe scure in rilievo), coping largo 0,30 m con il
    toro esterno, bagnato e lucido; dentro alghe e calcare sulla linea dell'acqua; acqua a 0,88 quasi al
    bordo. La medusa (gruppo "medusa") si affaccia sul lato verso l'ingresso (-y Blender, +Z Godot).
    Restituisce (oggetti, acqua, luci)."""
    V = VASCA_CENTRALE
    cx, cy, lx, ly, r, H, cp = V['cx'], V['cy'], V['lx'], V['ly'], V['r'], V['h'], V['coping']
    c = K.Costruttore(mats)
    d_c = cp / 2                                    # linea di mezzo del coping, dal filo esterno
    z_sotto = H - 0.075                             # sotto del coping
    # muro esterno (rientra di 3 cm sotto il toro), a fasce da 12,5 cm per lo sporco nei colori dei vertici
    est = rett_arrotondato(cx, cy, lx - 2 * (d_c - 0.12), ly - 2 * (d_c - 0.12), r - (d_c - 0.12))
    zs = [0.0] + [0.125 * k for k in range(1, 8)] + [z_sotto]
    _parete_lungo(c, est, zs, 'vasca_alta', +1, 3.0)
    # muro interno e fondo
    inn = rett_arrotondato(cx, cy, lx - 2 * cp, ly - 2 * cp, r - cp)
    _parete_lungo(c, inn, [0.004, 0.25, 0.5, 0.75, 0.8, 0.85, V['acqua'], z_sotto], 'vasca_alta', -1, 3.0)
    c.faccia_verso([tuple(p_ + Vector((0, 0, 0.004))) for p_, n_ in inn[0]], 'vasca', (0, 0, 1))
    # coping: profilo con lo spigolo interno smussato e il toro esterno, fatto scorrere sul perimetro
    mezzo = rett_arrotondato(cx, cy, lx - 2 * d_c, ly - 2 * d_c, r - d_c, z=H, passo=0.25)
    rb = 0.0375
    prof = [(-cp / 2, -0.075), (-cp / 2, -0.012), (-cp / 2 + 0.008, -0.002), (-cp / 2 + 0.02, 0.0), (cp / 2 - 0.045, 0.0)]
    prof += [(cp / 2 - 0.045 + rb * math.cos(math.radians(a)), -rb + rb * math.sin(math.radians(a))) for a in (60, 30, 0, -30, -60, -90)]
    c.profilo_lungo([p_ for p_, n_ in mezzo[0]], [(0, 0, 1)] * len(mezzo[0]), prof, 'vasca_alta_bordo', chiuso_percorso=True, liscia=True)
    # scatola gialla del pulsante dei bambini (sigla) sul muro davanti, tra le mani della medusa
    yf = cy - ly / 2 + (d_c - 0.12) + 0.0
    zb = V['z_pulsante']
    c.scatola((cx - 0.2, yf - 0.13, zb - 0.18), (cx + 0.2, yf + 0.02, zb + 0.18), 'gioco_giallo', smusso=0.012)
    ob = c.crea('sala_vasca_centrale')
    D.colora(ob, D.sporco_vasca_centrale)
    # alghe e calcare sulla linea dell'acqua (fascia RGBA 2 mm davanti al muro interno)
    f = K.Costruttore(mats)
    fascia = rett_arrotondato(cx, cy, lx - 2 * cp - 0.004, ly - 2 * cp - 0.004, r - cp - 0.002)
    zb0 = V['acqua'] - 0.45 * 0.256
    _parete_lungo(f, fascia, [zb0, min(H - 0.015, zb0 + 0.256)], 'decal_calcare', -1, 2.048, v0=zb0, v_scala=0.256)
    ob_f = f.crea('sala_vasca_centrale_calcare')
    # acqua (segnaposto, gruppo acqua)
    w = K.Costruttore(type('M', (), {'lato': lambda self_, n: 1.0, 'get': lambda self_, n: materiale_acqua()})())
    w.faccia_verso([tuple(p_ + Vector((0, 0, V['acqua']))) for p_, n_ in rett_arrotondato(cx, cy, lx - 2 * cp - 0.002, ly - 2 * cp - 0.002, r - cp - 0.001)[0]], 'acqua', (0, 0, 1))
    acqua = w.crea('sala_vasca_centrale_acqua')
    # collisioni: quattro tratti dritti di muro (con il coping) e quattro angoli convessi
    hx, hy = lx / 2 - r, ly / 2 - r
    for nome_, lo, hi in (('vasca_c_sud', (cx - hx, cy - ly / 2, 0), (cx + hx, cy - ly / 2 + cp, H)),
                          ('vasca_c_nord', (cx - hx, cy + ly / 2 - cp, 0), (cx + hx, cy + ly / 2, H)),
                          ('vasca_c_ovest', (cx - lx / 2, cy - hy, 0), (cx - lx / 2 + cp, cy + hy, H)),
                          ('vasca_c_est', (cx + lx / 2 - cp, cy - hy, 0), (cx + lx / 2, cy + hy, H))):
        K.collisione_scatola(nome_, lo, hi, padre=ob)
    for k, (sx, sy) in enumerate(((-1, 1), (-1, -1), (1, -1), (1, 1))):
        cc = Vector((cx + sx * hx, cy + sy * hy, 0))
        a0 = math.atan2(sy, sx) - math.pi / 4
        pts = []
        for i in range(7):
            a = a0 + (math.pi / 2) * i / 6
            d = Vector((math.cos(a), math.sin(a), 0))
            for z in (0.0, H):
                pts.append(tuple(cc + d * r + Vector((0, 0, z))))
                pts.append(tuple(cc + d * (r - cp) + Vector((0, 0, z))))
        K.collisione_punti(f'vasca_c_angolo_{k}', pts, padre=ob)
    # luci sott'acqua: due faretti dal fondo verso il davanti (la campana della medusa si accende)
    luci = []
    for i, sx in enumerate((-1, 1)):
        p = Vector((cx + sx * 1.4, cy - 0.2, 0.25))
        d = (Vector((cx, cy - ly / 2 + 0.55, 0.95)) - p).normalized()
        luci.append(dict(nome=f'luce_vasca_{i}', pos=tuple(p), dir=tuple(d), colore=(0.35, 0.9, 0.85)))
    return [ob, ob_f], acqua, luci


def ingombro_centro(modo=None):
    """Rettangolo (x0, y0, x1, y1) occupato al centro (vasca o monumento, con il cordone)."""
    if (modo or CENTRO['modo']) == 'monumento':
        P = PIEDISTALLO
        rc = P['r_cordone'] + 0.3
        return (P['cx'] - rc, P['cy'] - rc, P['cx'] + rc, P['cy'] + rc)
    V = VASCA_CENTRALE
    m = V['cordone'] + 0.3
    return (V['cx'] - V['lx'] / 2 - m, V['cy'] - V['ly'] / 2 - m, V['cx'] + V['lx'] / 2 + m, V['cy'] + V['ly'] / 2 + m)


def cordone_vasca(mats):
    """Cordone di velluto su colonnine d'ottone intorno alla vasca della medusa (1,3 m dal bordo). Dal 16
    ottobre è chiuso (20 colonnine, niente varco davanti) e ogni campata ha un muro invisibile alto 2,5 m:
    non ci si avvicina e non lo si salta (D1, nota dell'utente)."""
    V = VASCA_CENTRALE
    m = V['cordone']
    giro, s = rett_arrotondato(V['cx'], V['cy'], V['lx'] + 2 * m, V['ly'] + 2 * m, V['r'] + m, passo=0.05, seg_arco=24)
    totale = s[-1]
    n = max(8, int(round(totale / 1.45)))
    pali = []
    for k in range(n):
        target = totale * k / n
        i = min(range(len(giro)), key=lambda j: abs(s[j] - target))
        p = giro[i][0]
        pali.append((p.x, p.y))
    c = K.Costruttore(mats)
    H = 0.95
    copie = colonnine(c, pali, H, 'sala_vasca_colonnina')
    for i in range(len(pali)):
        a, b = pali[i], pali[(i + 1) % len(pali)]
        A = Vector((a[0], a[1], H - 0.07)); B = Vector((b[0], b[1], H - 0.07))
        curva = []
        for k in range(13):
            t = k / 12
            p = A.lerp(B, t)
            p.z -= 0.16 * (1 - (2 * t - 1) ** 2)
            curva.append(tuple(p))
        c.tubo(curva, 0.024, 'velluto', seg=10)
        for e in (A, B):
            c.cilindro(tuple(e + Vector((0, 0, -0.03))), tuple(e + Vector((0, 0, 0.03))), 0.03, 'cornice_oblo', seg=8)
    ob = c.crea('sala_vasca_cordone', sporco=lambda co: 0.85)
    for i in range(len(pali)):
        a, b = pali[i], pali[(i + 1) % len(pali)]
        d = Vector((b[0] - a[0], b[1] - a[1], 0)).normalized()
        nn = Vector((-d.y, d.x, 0)) * 0.06
        pts = [tuple(Vector((p[0], p[1], z)) + s_ * nn) for p in (a, b) for z in (0.0, 2.5) for s_ in (-1, 1)]
        K.collisione_punti(f'cordone_vasca_{i}', pts, padre=ob)
    return [ob] + copie


def offerte_vasca(mats):
    """Offerte dei bambini intorno alla vasca: disegni attaccati al muro davanti e a terra, conchiglie
    e stelle marine sugli angoli del bordo, secchiello con paletta. (Salvagente, orsetto, paperelle,
    pallone e ciambella sono in disponi_oggetti.)"""
    import random
    rnd = random.Random(78)
    V = VASCA_CENTRALE
    cx, cy, lx, ly = V['cx'], V['cy'], V['lx'], V['ly']
    c = K.Costruttore(mats)
    yf = cy - ly / 2 + (V['coping'] / 2 - 0.12)            # faccia del muro davanti
    def foglio(i, centro, U, Vv, curva=0.01):
        C = Vector(centro); U = Vector(U).normalized(); Vv = Vector(Vv).normalized()
        N = U.cross(Vv).normalized()
        u0, v1 = (i % 2) * 0.5, 1.0 - (i // 2) * 0.5
        for k in range(3):
            a, b = k / 3, (k + 1) / 3
            def pt(s_, t_):
                return tuple(C + U * (s_ - 0.5) * 0.21 + Vv * (t_ - 0.5) * 0.297 + N * curva * math.sin(math.pi * s_))
            q = [pt(a, 0), pt(b, 0), pt(b, 1), pt(a, 1)]
            uv = [(u0 + a * 0.5, v1 - 0.5), (u0 + b * 0.5, v1 - 0.5), (u0 + b * 0.5, v1), (u0 + a * 0.5, v1)]
            c.faccia(q, 'disegni', uv=uv)
            c.faccia(q[::-1], 'disegni', uv=uv[::-1])
    # due disegni attaccati al muro davanti (ai lati del pulsante), due a terra, uno sul fianco
    for i, x in ((0, -1.15), (3, 1.25)):
        foglio(i, (cx + x, yf - 0.006, 0.6), (1, 0, 0), (0, 0, 1), curva=-0.004)
    for i, (x, y, rot) in ((1, (-0.75, yf - 0.45, 0.3)), (2, (0.9, yf - 0.5, -0.4))):
        foglio(i, (cx + x, y, 0.005), (math.cos(rot), math.sin(rot), 0), (-math.sin(rot), math.cos(rot), 0))
    foglio(2, (cx - lx / 2 + 0.12 - 0.006 + (V['coping'] / 2 - 0.12) * 0, cy - 0.9, 0.55), (0, -1, 0), (0, 0, 1), curva=0.004)
    # conchiglie e stelle marine sugli angoli del coping (non davanti, dove ci sono le mani)
    for k, (x, y) in enumerate(((-lx / 2 + 0.2, ly / 2 - 0.2), (lx / 2 - 0.2, ly / 2 - 0.22), (-lx / 2 + 0.22, -ly / 2 + 0.25),
                                (lx / 2 - 0.25, -ly / 2 + 0.2), (-1.6, ly / 2 - 0.15), (1.3, ly / 2 - 0.14))):
        p = (cx + x + rnd.uniform(-0.04, 0.04), cy + y + rnd.uniform(-0.04, 0.04), V['h'] + 0.002)
        if k % 3 == 1:
            stella_marina(c, p, rnd.uniform(0.06, 0.08), 'gioco_arancio', rot=rnd.uniform(0, 6.28))
        else:
            dd = rnd.uniform(0, 6.28)
            conchiglia(c, p, (0, 0, 1), rnd.uniform(0.045, 0.065), 'conchiglia', su=(math.cos(dd), math.sin(dd), 0))
    for k in range(4):   # qualcuna anche a terra, contro il muro davanti
        p = (cx + rnd.uniform(-2.4, 2.4), yf - rnd.uniform(0.08, 0.3), 0.003)
        if abs(p[0] - cx) < 0.35:
            continue
        conchiglia(c, p, (0, 0, 1), rnd.uniform(0.045, 0.065), 'conchiglia', su=(rnd.uniform(-1, 1), -1, 0))
    # secchiello con paletta, a terra davanti a sinistra
    b = Vector((cx - 2.0, yf - 0.55, 0.0))
    seg = 16
    for k in range(seg):
        t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        q = [b + Vector((math.cos(t0) * 0.075, math.sin(t0) * 0.075, 0)), b + Vector((math.cos(t1) * 0.075, math.sin(t1) * 0.075, 0)),
             b + Vector((math.cos(t1) * 0.095, math.sin(t1) * 0.095, 0.14)), b + Vector((math.cos(t0) * 0.095, math.sin(t0) * 0.095, 0.14))]
        c.faccia([tuple(v) for v in q], 'gioco_blu', liscia=True)
        c.faccia([tuple(v) for v in q[::-1]], 'gioco_blu', liscia=True)
    c.disco(tuple(b + Vector((0, 0, 0.004))), (0, 0, 1), 0.075, 'gioco_blu', seg=seg)
    c.tubo([tuple(b + Vector((math.cos(t) * 0.095, 0.0, 0.14 + math.sin(t) * 0.1))) for t in [math.pi * k / 10 for k in range(11)]], 0.005, 'inox', seg=5)
    c.cilindro(tuple(b + Vector((0.16, 0.05, 0.012))), tuple(b + Vector((0.36, 0.12, 0.012))), 0.01, 'gioco_rosso', seg=6)
    c.scatola(tuple(b + Vector((0.08, 0.0, 0.004))), tuple(b + Vector((0.17, 0.09, 0.012))), 'gioco_rosso')
    return c.crea('sala_vasca_offerte', sporco=lambda co: 0.9)


def lampione_hq(mats, b, lamp, nome):
    """Il lampione HQ (Meshy, palo in ghisa verde col braccio a pastorale e il paralume smaltato)
    messo in modo che la lampadina cada dove c'è la luce del gioco (luce_lampione, in lamp) e il palo
    in b: il modello si gira col braccio verso -x e si scala (in pianta per lo sbraccio, in altezza
    per la lampadina). La lampadina vera (M_amb_lampadina, per lo sfarfallio del gioco) resta un
    pezzo a mano dentro quella del modello."""
    m = modello('lampione_braccio')
    me = m.data.copy()
    co = [v.co.copy() for v in me.vertices]
    Hm = max(v.z for v in co)
    base = [v for v in co if v.z < 0.05 * Hm]
    bx = sum(v.x for v in base) / len(base); by = sum(v.y for v in base) / len(base)
    fascia = [v for v in co if 0.68 * Hm < v.z < 0.88 * Hm and math.hypot(v.x - bx, v.y - by) > 0.06 * Hm]
    sx = (min(v.x for v in fascia) + max(v.x for v in fascia)) / 2
    sy = (min(v.y for v in fascia) + max(v.y for v in fascia)) / 2
    sotto = [v for v in co if math.hypot(v.x - sx, v.y - sy) < 0.03 * Hm and v.z > 0.5 * Hm]
    zb = min(v.z for v in sotto) + 0.025 * Hm             # centro della lampadina del modello
    sbraccio = math.hypot(sx - bx, sy - by)
    ang = math.atan2(sy - by, sx - bx)
    voluto = Vector((lamp.x - b.x, lamp.y - b.y, 0))
    k = (lamp.z - b.z) / zb                               # scala uniforme: la lampadina all'altezza della luce
    me.transform(Matrix.Translation((-bx, -by, 0)))
    me.transform(Matrix.Rotation(math.atan2(voluto.y, voluto.x) - ang, 4, 'Z'))
    me.transform(Matrix.Scale(k, 4))
    me.transform(Matrix.Translation(b))
    ob = bpy.data.objects.new(nome + '_hq', me)
    bpy.context.scene.collection.objects.link(ob)
    # la lampadina che sfarfalla, dentro quella del modello (la luce del gioco resta in lamp, a pochi cm)
    lb = b + voluto.normalized() * (sbraccio * k) + Vector((0, 0, lamp.z - b.z))
    c = K.Costruttore(mats)
    c.cilindro(lb + Vector((0, 0, -0.07)), lb + Vector((0, 0, 0.06)), 0.065, 'lampadina', seg=16)
    c.disco(lb + Vector((0, 0, -0.07)), (0, 0, -1), 0.065, 'lampadina', seg=16)
    bulbo = c.crea(nome + '_bulbo')
    ob = unisci([ob, bulbo], nome)
    senza_colori(ob)
    print(f'lampione HQ: scala x{k:.2f}, sbraccio {sbraccio * k:.2f} m (luce a {voluto.length:.2f}), '
          f'cima {max(v.co.z for v in ob.data.vertices):.2f} m')
    K.collisione_scatola(nome, tuple(b - Vector((0.14, 0.14, 0))), tuple(b + Vector((0.14, 0.14, 4.3))), padre=ob)
    return ob, lamp


def lampione(mats, base, nome='amb_lampione'):
    """Lampione su palo accanto al piedistallo (storyboard S04): palo in ghisa, braccio curvo,
    paralume industriale con lampadina calda. Restituisce (oggetto, posizione della lampadina)."""
    b = Vector(base)
    H = 4.3
    if os.path.exists(os.path.join(OGGETTI_HQ, 'lampione_braccio.glb')):
        return lampione_hq(mats, b, b + Vector((-1.15, 0, H + 0.45 - 0.33)), nome)
    c = K.Costruttore(mats)
    c.anello(b, (0, 0, 1), 0.0, 0.22, 0.06, 'torre', seg=20)
    c.cilindro(b + Vector((0, 0, 0.06)), b + Vector((0, 0, 0.5)), 0.09, 'torre', seg=16)
    c.cilindro(b + Vector((0, 0, 0.5)), b + Vector((0, 0, H)), 0.055, 'torre', seg=16)
    arco = []
    for k in range(13):
        t = math.pi / 2 * k / 12
        arco.append(b + Vector((-0.55 * (1 - math.cos(t)), 0, H + 0.45 * math.sin(t))))
    arco.append(b + Vector((-1.15, 0, H + 0.45)))
    c.tubo(arco, 0.035, 'torre', seg=10)
    top = b + Vector((-1.15, 0, H + 0.45))
    c.cilindro(top, top - Vector((0, 0, 0.18)), 0.03, 'torre', seg=8)
    # paralume conico
    seg = 32
    for k in range(seg):
        t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        z0, z1 = H + 0.27, H + 0.02
        r0, r1 = 0.08, 0.36
        q = [top + Vector((math.cos(t0) * r0, math.sin(t0) * r0, z0 - H - 0.45)), top + Vector((math.cos(t1) * r0, math.sin(t1) * r0, z0 - H - 0.45)),
             top + Vector((math.cos(t1) * r1, math.sin(t1) * r1, z1 - H - 0.45)), top + Vector((math.cos(t0) * r1, math.sin(t0) * r1, z1 - H - 0.45))]
        c.faccia(q, 'torre', liscia=True)
        c.faccia(q[::-1], 'metallo', liscia=True)
    lamp = top + Vector((0, 0, -0.33))
    c.disco(lamp, (0, 0, 1), 0.06, 'lampadina', seg=16)
    ob = c.crea(nome)
    K.collisione_scatola(nome, tuple(b - Vector((0.12, 0.12, 0))), tuple(b + Vector((0.12, 0.12, H))), padre=ob)
    return ob, lamp


# ----------------------------------------------------------------------------- area bimbi

def scivolo_solido(c, pts, W=0.40, D=0.22, T=0.04, H=0.16, R=0.025, mat='gioco_giallo'):
    """Scivolo aperto di vetroresina come solido (prima era una superficie senza spessore): canale a U
    largo 2W con il fondo a mezza ellisse profondo D, sponde dritte alte H sopra il bordo della curva,
    spessore T, bordo superiore arrotondato (raggio R) e le due testate chiuse. 'pts' è la linea del
    bordo del canale (dove finisce la curva e cominciano le sponde); la sezione è perpendicolare alla
    pendenza."""
    n_curva, n_bordo = 14, 6

    def mezza(a, b):                        # da sinistra a destra passando per il fondo
        return [(-a * math.cos(math.pi * j / n_curva), -b * math.sin(math.pi * j / n_curva)) for j in range(n_curva + 1)]
    dentro = [(-W, H)] + mezza(W, D) + [(W, H)]
    fuori = [(-W - T, H)] + mezza(W + T, D + T) + [(W + T, H)]
    cb = W + T / 2

    def bordo(lato):                        # dal filo interno al filo esterno, sopra
        return [(lato * (cb - (T / 2 + 0.005) * math.cos(math.pi * j / n_bordo)),
                 H + R * math.sin(math.pi * j / n_bordo)) for j in range(n_bordo + 1)]
    anello = (dentro + bordo(1)[1:-1] + fuori[::-1] + bordo(-1)[::-1][1:-1])[::-1]   # normali verso fuori

    def assi(i):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        d = (b - a).normalized()
        lato = d.cross(Vector((0, 0, 1))).normalized()
        su = lato.cross(d).normalized()
        return d, lato, su

    def punto(i, s, h, dentro_di=0.0):
        d, lato, su = assi(i)
        return pts[i] + lato * s + su * h + d * dentro_di
    n = len(anello)
    for i in range(len(pts) - 1):
        for k in range(n):
            s0, h0 = anello[k]
            s1, h1 = anello[(k + 1) % n]
            c.faccia([punto(i, s0, h0), punto(i + 1, s0, h0), punto(i + 1, s1, h1), punto(i, s1, h1)], mat, liscia=True)
    # testate: fra la curva interna e quella esterna, più i bordi arrotondati (1 mm dentro, così non
    # condividono i vertici con le facce lisce e l'ombreggiatura del canale non si piega)
    for i, verso, dd in ((0, -1, 0.001), (len(pts) - 1, 1, -0.001)):
        d = assi(i)[0]
        for k in range(len(dentro) - 1):
            q = [punto(i, *dentro[k], dd), punto(i, *dentro[k + 1], dd), punto(i, *fuori[k + 1], dd), punto(i, *fuori[k], dd)]
            c.faccia_verso(q, mat, d * verso)
        for lato in (1, -1):
            arco = bordo(lato)
            centro = punto(i, lato * cb, H, dd)
            for j in range(len(arco) - 1):
                c.faccia_verso([centro, punto(i, *arco[j], dd), punto(i, *arco[j + 1], dd)], mat, d * verso)


def struttura_gioco(mats):
    """Struttura di gioco a più piani con il secchio gigante in cima (area bimbi, angolo nord-ovest dal
    16 ottobre: la scala guarda verso chi arriva, lo scivolo scende nella vasca piccola)."""
    cx, cy = STRUTTURA['cx'], STRUTTURA['cy']
    c = K.Costruttore(mats)
    torri = [((-2.6, -1.2), 1.4, 'gioco_verde'), ((0.2, -1.2), 2.6, 'gioco_arancio'),
             ((0.2, 1.6), 3.8, None), ((-2.6, 1.6), 2.6, 'gioco_rosso')]
    L = 2.4
    def post(x, y, z1, mat='gioco_blu', r=0.065):
        # palo tondo con il cappuccio arrotondato e la piastra di base (bordi morbidi, come nel campione)
        c.cilindro((x, y, 0.02), (x, y, z1), r, mat, seg=18, tappi=False)
        c.toro((x, y, z1), (0, 0, 1), r * 0.62, r * 0.38, mat, seg=18, seg_r=6)
        c.disco((x, y, z1 + r * 0.38), (0, 0, 1), r * 0.64, mat, seg=18)
        c.anello((x, y, 0), (0, 0, 1), 0.0, r + 0.07, 0.02, 'inox', seg=18)
        c.toro((x, y, 0.06), (0, 0, 1), r + 0.004, 0.018, mat, seg=18, seg_r=5)
    for (ox, oy), zp, tetto in torri:
        x0, y0 = cx + ox - L / 2, cy + oy - L / 2
        x1, y1 = x0 + L, y0 + L
        hpost = zp + (2.0 if tetto else 1.1)
        for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
            post(px, py, hpost)
        # pedana
        c.scatola((x0, y0, zp - 0.08), (x1, y1, zp), 'gioco_giallo', smusso=0.03)
        # parapetti a tubi su tre lati, con pannelli
        for (a, b) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x0, y1), (x0, y0))):
            for zz in (zp + 0.5, zp + 0.95):
                c.cilindro((a[0], a[1], zz), (b[0], b[1], zz), 0.035, 'gioco_rosso', seg=14, tappi=False)
            n = 8
            for k in range(1, n):
                px = a[0] + (b[0] - a[0]) * k / n; py = a[1] + (b[1] - a[1]) * k / n
                c.cilindro((px, py, zp), (px, py, zp + 0.95), 0.016, 'gioco_blu', seg=10, tappi=False)
        if tetto:  # tetto a piramide: stesso profilo, stesse misure e stessa sporgenza di prima, ma solido
            # (lastra spessa 6 cm sotto la superficie di sempre: prima era una superficie e da sotto spariva)
            ztop, sp = hpost, 0.06
            apice = Vector((cx + ox, cy + oy, ztop + 1.0))
            bordo = [Vector(p) for p in ((x0 - 0.25, y0 - 0.25, ztop), (x1 + 0.25, y0 - 0.25, ztop),
                                         (x1 + 0.25, y1 + 0.25, ztop), (x0 - 0.25, y1 + 0.25, ztop))]
            giu = Vector((0, 0, -sp))
            for i in range(4):
                a, b = bordo[i], bordo[(i + 1) % 4]
                fuori = ((a + b) / 2 - Vector((cx + ox, cy + oy, ztop))).normalized()
                c.faccia_verso([a, b, apice], tetto, fuori + Vector((0, 0, 1)))                    # sopra
                c.faccia_verso([a + giu, b + giu, apice + giu], tetto, -fuori - Vector((0, 0, 1)))  # sotto
                c.faccia_verso([a, b, b + giu, a + giu], tetto, fuori)                            # costa della lastra
    # passerelle tra le torri e scalette
    c.scatola((cx - 1.4, cy - 1.7, 1.32), (cx - 1.0, cy - 0.7, 1.4), 'gioco_giallo', smusso=0.02)
    for k in range(9):  # scala dal pavimento alla prima torre (lato sud)
        z = 0.16 * (k + 1)
        y = cy - 2.4 - 0.28 * (9 - k)
        c.scatola((cx - 3.3, y, z - 0.05), (cx - 1.9, y + 0.28, z), 'gioco_giallo', smusso=0.02)
    for x in (cx - 3.3, cx - 1.9):
        c.cilindro((x, cy - 2.4 - 0.28 * 9, 0.9), (x, cy - 2.4, 2.4), 0.035, 'gioco_rosso', seg=14)
    c.scatola((cx - 1.4, cy + 1.2, 2.52), (cx - 1.0, cy + 2.0, 2.6), 'gioco_giallo', smusso=0.02)
    # ponte sospeso tra la torre 2 e la torre 3 (assi)
    for k in range(7):
        y = cy - 0.0 + 0.2 * k - 0.6
        c.scatola((cx - 0.6, y, 3.0 + 0.12 * k), (cx + 1.0, y + 0.14, 3.06 + 0.12 * k), 'gioco_giallo', smusso=0.015)
    # scivolo aperto dalla torre 2 verso est: un solido (riscontro della v0.3.1: "lo scivolo giallo è bidimensionale")
    scivolo_solido(c, [Vector((cx + 1.40, cy - 1.2, 2.85))] +
                   [Vector((cx + 1.6 + 3.2 * k / 16, cy - 1.2 - 0.6 * math.sin(k / 16 * math.pi),
                            2.6 * (1 - k / 16) ** 1.3 + 0.25)) for k in range(17)])
    # telaio del secchio gigante sopra la torre 3
    tx, ty = cx + 0.2, cy + 1.6
    for (px, py) in ((tx - 1.5, ty - 1.55), (tx + 1.5, ty - 1.55), (tx + 1.5, ty + 1.55), (tx - 1.5, ty + 1.55)):
        c.cilindro((px, py, 3.8), (px, py, 7.4), 0.08, 'torre', seg=16)
    for py in (ty - 1.55, ty + 1.55):
        c.cilindro((tx - 1.5, py, 5.6), (tx + 1.5, py, 5.6), 0.05, 'torre', seg=8)
    for px in (tx - 1.5, tx + 1.5):
        c.cilindro((px, ty - 1.55, 7.4), (px, ty + 1.55, 7.4), 0.07, 'torre', seg=10)
        c.cilindro((px, ty - 1.55, 5.6), (px, ty + 1.55, 7.3), 0.05, 'torre', seg=8)
    c.cilindro((tx - 1.6, ty, 7.1), (tx + 1.6, ty, 7.1), 0.06, 'inox', seg=16)
    # tubo dell'acqua che sale al secchio
    c.tubo([(tx + 1.9, ty + 1.0, 0.0), (tx + 1.9, ty + 1.0, 6.6), (tx + 1.6, ty + 0.4, 7.6), (tx + 0.6, ty + 0.1, 8.2)], 0.07, 'gioco_blu', seg=16)
    ob = c.crea('sala_struttura_gioco', sporco=lambda co: 0.7 + 0.3 * min(1.0, co.z / 1.0))
    # collisioni: pedane, scala, passerelle e ponte (si sale davvero); pali sottili esclusi
    for i, ((ox, oy), zp, tetto) in enumerate(torri):
        x0_, y0_ = cx + ox - L / 2, cy + oy - L / 2
        K.collisione_scatola(f'gioco_pedana_{i}', (x0_, y0_, zp - 0.08), (x0_ + L, y0_ + L, zp), padre=ob)
        for j, (a, b) in enumerate((((x0_, y0_), (x0_ + L, y0_)), ((x0_ + L, y0_), (x0_ + L, y0_ + L)), ((x0_, y0_ + L), (x0_, y0_)))):
            K.collisione_scatola(f'gioco_parapetto_{i}_{j}', (min(a[0], b[0]) - 0.04, min(a[1], b[1]) - 0.04, zp),
                                 (max(a[0], b[0]) + 0.04, max(a[1], b[1]) + 0.04, zp + 1.0), padre=ob)
    ys0 = cy - 2.4 - 0.28 * 9
    K.collisione_punti('gioco_scala', [(cx - 3.3, ys0, 0.0), (cx - 1.9, ys0, 0.0), (cx - 3.3, cy - 2.4, 1.44), (cx - 1.9, cy - 2.4, 1.44),
                                       (cx - 3.3, cy - 2.4, 0.0), (cx - 1.9, cy - 2.4, 0.0)], padre=ob)
    K.collisione_scatola('gioco_passerella_1', (cx - 1.4, cy - 1.7, 1.32), (cx - 1.0, cy - 0.7, 1.4), padre=ob)
    K.collisione_scatola('gioco_passerella_2', (cx - 1.4, cy + 1.2, 2.52), (cx - 1.0, cy + 2.0, 2.6), padre=ob)
    K.collisione_punti('gioco_ponte', [(cx - 0.6, cy - 0.6, 2.95), (cx + 1.0, cy - 0.6, 2.95), (cx - 0.6, cy + 0.8, 3.75),
                                       (cx + 1.0, cy + 0.8, 3.75), (cx - 0.6, cy - 0.6, 3.05), (cx + 1.0, cy + 0.8, 3.85)], padre=ob)
    # (la ruota a pale che riempiva il secchio non c'è più: tolta il 16 ottobre con la tappa 5 rifatta,
    #  il secchio gigante resta come scenografia)
    # secchio gigante (oggetto a parte, ruota sull'asse x)
    s = K.Costruttore(mats)
    Rb, Rt, Hb = 0.9, 1.15, 1.5
    seg = 40
    for k in range(seg):
        t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        q = [(math.cos(t0) * Rb, math.sin(t0) * Rb, -Hb / 2), (math.cos(t1) * Rb, math.sin(t1) * Rb, -Hb / 2),
             (math.cos(t1) * Rt, math.sin(t1) * Rt, Hb / 2), (math.cos(t0) * Rt, math.sin(t0) * Rt, Hb / 2)]
        s.faccia(q, 'gioco_rosso', liscia=True)
        q2 = [(p[0] * 0.97, p[1] * 0.97, p[2]) for p in q]
        s.faccia(q2[::-1], 'torre', liscia=True)
    s.faccia([(math.cos(2 * math.pi * k / seg) * Rb, math.sin(2 * math.pi * k / seg) * Rb, -Hb / 2) for k in reversed(range(seg))], 'gioco_rosso')
    s.faccia([(math.cos(2 * math.pi * k / seg) * Rb * 0.97, math.sin(2 * math.pi * k / seg) * Rb * 0.97, -Hb / 2 + 0.03) for k in range(seg)], 'torre')
    s.toro((0, 0, Hb / 2), (0, 0, 1), Rt, 0.05, 'gioco_giallo', seg=48, seg_r=8)
    s.toro((0, 0, -Hb / 2 + 0.2), (0, 0, 1), Rb + 0.05, 0.035, 'gioco_giallo', seg=48, seg_r=6)
    for sx in (-1, 1):
        s.cilindro((sx * Rt * 0.98, 0, 0.1), (sx * (Rt + 0.35), 0, 0.1), 0.07, 'inox', seg=10)
    secchio = s.crea('sala_secchio_gigante')
    secchio.data.transform(Matrix.Translation((0, 0, -0.1)))   # perno sui perni (asse x)
    if os.path.exists(os.path.join(OGGETTI_HQ, 'secchio_gigante.glb')):
        secchio_hq(secchio, mats)
    secchio.location = (tx, ty, 7.1)
    secchio.rotation_euler = Euler((math.radians(-14), 0, 0))
    K.collisione_scatola('secchio', (-1.2, -1.2, -0.85), (1.2, 1.2, 0.65), padre=secchio)
    secchio.children[0].hide_render = True
    return [ob, secchio]


def senza_colori(ob):
    """Toglie i colori dei vertici (dopo l'unione con un modello HQ: altrimenti la parte HQ resterebbe nera)."""
    for a in list(ob.data.color_attributes):
        ob.data.color_attributes.remove(a)


def secchio_hq(secchio, mats):
    """Mette nel secchio gigante (stesso nodo, stesso perno sull'asse x, stessa collisione) il modello
    HQ di Meshy al posto di quello fatto a mano: i mozzi del modello sul perno, il corpo alto 1,6 m
    come prima, più i due perni d'acciaio fino al telaio."""
    m = modello('secchio_gigante')
    a = bpy.data.objects.new('tmp_secchio_hq', m.data.copy())
    bpy.context.scene.collection.objects.link(a)
    xmax = max(abs(v.co.x) for v in a.data.vertices)
    mozzi = [v.co.z for v in a.data.vertices if abs(v.co.x) > 0.9 * xmax]
    a.data.transform(Matrix.Translation((0, 0, -sum(mozzi) / len(mozzi))))
    c = K.Costruttore(mats)
    for sx in (-1, 1):
        c.cilindro((sx * (xmax - 0.05), 0, 0.0), (sx * 1.5, 0, 0.0), 0.07, 'inox', seg=12)
    unito = unisci([a, c.crea('tmp_secchio_perni')], 'tmp_secchio_unito')
    senza_colori(unito)
    vecchio = secchio.data
    secchio.data = unito.data
    bpy.data.objects.remove(unito, do_unlink=True)
    bpy.data.meshes.remove(vecchio)
    secchio.data.name = 'sala_secchio_gigante'


# ----------------------------------------------------------------------------- torre degli scivoli

def torre_scivoli(mats):
    """Impalcatura di acciaio arrugginito: 4 colonne, pozzo centrale aperto, piattaforme a grigliato
    a 3, 6 e 8,6 m, controventi a croce, scale a rampe sul lato est, parapetti. NON USATA dal 16 ottobre:
    la torre lascia la sala grande e si rifà nella sala della torre, con una proposta a parte."""
    T = TORRE
    cx, cy, Lt = T['cx'], T['cy'], T['lato']
    x0, x1, y0, y1 = cx - Lt / 2, cx + Lt / 2, cy - Lt / 2, cy + Lt / 2
    c = K.Costruttore(mats)
    g = K.Costruttore(mats)   # grigliati (materiale con alfa)
    Hc = T['piani'][-1] + 1.15
    for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        c.scatola((px - 0.12, py - 0.12, 0), (px + 0.12, py + 0.12, Hc), 'torre', smusso=0.014)
        c.scatola((px - 0.25, py - 0.25, 0), (px + 0.25, py + 0.25, 0.04), 'torre', smusso=0.008)
    sx0, sx1, sy0, sy1 = cx - 1.1, cx + 1.1, cy - 1.1, cy + 1.1   # pozzo centrale
    livelli = [0.0] + list(T['piani'])
    for z in T['piani']:
        # travi di bordo
        for (a, b) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
            lo = (min(a[0], b[0]) - 0.1, min(a[1], b[1]) - 0.1, z - 0.3)
            hi = (max(a[0], b[0]) + 0.1, max(a[1], b[1]) + 0.1, z - 0.02)
            c.scatola(lo, hi, 'torre', smusso=0.012)
        for (a, b) in (((sx0, sy0), (sx1, sy0)), ((sx1, sy0), (sx1, sy1)), ((sx1, sy1), (sx0, sy1)), ((sx0, sy1), (sx0, sy0))):
            lo = (min(a[0], b[0]) - 0.06, min(a[1], b[1]) - 0.06, z - 0.2)
            hi = (max(a[0], b[0]) + 0.06, max(a[1], b[1]) + 0.06, z - 0.02)
            c.scatola(lo, hi, 'torre')
        # grigliato intorno al pozzo (4 rettangoli)
        for (a0, b0, a1, b1) in ((x0, y0, x1, sy0), (x0, sy1, x1, y1), (x0, sy0, sx0, sy1), (sx1, sy0, x1, sy1)):
            g.faccia([(a0, b0, z), (a1, b0, z), (a1, b1, z), (a0, b1, z)], 'alfa_grata')
            g.faccia([(a0, b1, z - 0.01), (a1, b1, z - 0.01), (a1, b0, z - 0.01), (a0, b0, z - 0.01)], 'alfa_grata')
        # parapetti esterni (tranne l'apertura della scala sul lato est e le partenze a ovest)
        for (a, b, salta) in (((x0, y0), (x1, y0), True), ((x1, y0), (x1, y1), False), ((x1, y1), (x0, y1), False),
                              ((x0, y1), (x0, y0), z >= T['piani'][1] - 0.01)):
            if salta:
                continue
            for zz in (z + 0.55, z + 1.05):
                c.cilindro((a[0], a[1], zz), (b[0], b[1], zz), 0.03, 'torre', seg=8, tappi=False)
            n = int((Vector(b) - Vector(a)).length / 1.0)
            for k in range(1, n):
                px = a[0] + (b[0] - a[0]) * k / n; py = a[1] + (b[1] - a[1]) * k / n
                c.cilindro((px, py, z), (px, py, z + 1.05), 0.025, 'torre', seg=6, tappi=False)
        # parapetto del pozzo
        for (a, b) in (((sx0, sy0), (sx1, sy0)), ((sx1, sy0), (sx1, sy1)), ((sx1, sy1), (sx0, sy1)), ((sx0, sy1), (sx0, sy0))):
            c.cilindro((a[0], a[1], z + 1.0), (b[0], b[1], z + 1.0), 0.03, 'torre', seg=8, tappi=False)
            c.cilindro((a[0], a[1], z + 0.5), (b[0], b[1], z + 0.5), 0.025, 'torre', seg=6, tappi=False)
            c.cilindro((a[0], a[1], z), (a[0], a[1], z + 1.0), 0.03, 'torre', seg=6, tappi=False)
    # controventi a croce sulle facce nord e sud tra i livelli
    for z0, z1 in zip(livelli, livelli[1:]):
        for yy in (y0, y1):
            c.tubo([(x0, yy, z0 + 0.2), (x1, yy, z1 - 0.3)], 0.045, 'torre', seg=6)
            c.tubo([(x1, yy, z0 + 0.2), (x0, yy, z1 - 0.3)], 0.045, 'torre', seg=6)
        c.tubo([(x0, y0, z0 + 0.2), (x0, y1, z1 - 0.3)], 0.045, 'torre', seg=6)
    # scale a rampe sul lato sud (fuori dalla torre, y da y0-1,2 a y0-0,1), corsa lungo x
    yb0, yb1 = y0 - 1.2, y0 - 0.1
    for i, (z0, z1) in enumerate(zip(livelli, livelli[1:])):
        n = int(round((z1 - z0) / 0.18))
        verso = 1 if i % 2 == 0 else -1
        xa = x0 + 0.4 if verso > 0 else x1 - 0.4
        corsa = (x1 - x0 - 0.8)
        dx = verso * corsa / n
        for k in range(n):
            z = z0 + (k + 1) * (z1 - z0) / n
            xs = xa + dx * k
            q = [(xs, yb0, z), (xs + dx, yb0, z), (xs + dx, yb1, z), (xs, yb1, z)]
            g.faccia(q if verso > 0 else q[::-1], 'alfa_grata')
            g.faccia(q[::-1] if verso > 0 else q, 'alfa_grata')
        for yy in (yb0, yb1):
            c.tubo([(xa, yy, z0), (xa + verso * corsa, yy, z1)], 0.05, 'torre', seg=6)
            c.tubo([(xa, yy, z0 + 1.0), (xa + verso * corsa, yy, z1 + 1.0)], 0.03, 'torre', seg=6)
        K.collisione_punti(f'torre_rampa_{i}', [(xa, yb0, z0), (xa, yb1, z0), (xa + verso * corsa, yb0, z1), (xa + verso * corsa, yb1, z1),
                                                (xa, yb0, z0 - 0.1), (xa, yb1, z0 - 0.1), (xa + verso * corsa, yb0, z1 - 0.1), (xa + verso * corsa, yb1, z1 - 0.1)])
        # pianerottolo in cima alla rampa
        xe = xa + verso * corsa
        q = [(min(xe, xe + verso * 0.4), yb0, z1), (max(xe, xe + verso * 0.4), yb0, z1), (max(xe, xe + verso * 0.4), y0, z1), (min(xe, xe + verso * 0.4), y0, z1)]
        g.faccia(q, 'alfa_grata'); g.faccia(q[::-1], 'alfa_grata')
        c.cilindro((xe, yb0, 0 if i == 0 else z0), (xe, yb0, z1), 0.06, 'torre', seg=8)
    ob = c.crea('sala_torre', sporco=lambda co: 0.75 + 0.25 * min(1.0, co.z / 2.0))
    gr = g.crea('sala_torre_grigliati')
    for z in T['piani']:   # piani calpestabili intorno al pozzo (il pozzo resta aperto)
        for j, (a0, b0, a1, b1) in enumerate(((x0, y0, x1, sy0), (x0, sy1, x1, y1), (x0, sy0, sx0, sy1), (sx1, sy0, x1, sy1))):
            K.collisione_scatola(f'torre_piano_{z}_{j}', (a0, b0, z - 0.1), (a1, b1, z), padre=ob)
        K.collisione_scatola(f'torre_parapetto_n_{z}', (x0, y1 - 0.05, z), (x1, y1 + 0.05, z + 1.05), padre=ob)
        K.collisione_scatola(f'torre_parapetto_e_{z}', (x1 - 0.05, y0, z), (x1 + 0.05, y1, z + 1.05), padre=ob)
    for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        K.collisione_scatola(f'torre_colonna_{px}_{py}', (px - 0.13, py - 0.13, 0), (px + 0.13, py + 0.13, Hc), padre=ob)
    for o in bpy.context.scene.objects:
        if o.name.startswith('torre_rampa_') and o.parent is None:
            o.parent = ob
    return [ob, gr]


def percorsi_scivoli():
    """Tre tubi chiusi dalla torre alla vasca d'arrivo. Il grande gira lungo i bordi nord e ovest,
    il medio corre più basso a nord e scende a ovest della piscina, quello a spirale gira intorno
    a un pennone e attraversa la sala in diagonale sopra la piscina."""
    T = TORRE
    zt = T['piani'][-1]
    p1 = [(10.9, 19.3, zt + 0.55), (8.5, 19.6, zt + 0.3), (3.0, 19.8, 8.0), (-3.0, 19.8, 7.2), (-8.0, 19.8, 6.5),
          (-12.0, 19.9, 6.0), (-15.4, 19.5, 5.5), (-16.1, 16.5, 4.9), (-16.2, 12.5, 4.1), (-16.0, 8.5, 3.2),
          (-15.7, 5.5, 2.2), (-15.2, 3.6, 1.2), (-14.7, 2.0, 0.3)]
    p3 = [(10.9, 15.6, T['piani'][1] + 0.55), (8.0, 16.6, 6.2), (3.0, 17.2, 5.6), (-3.0, 17.2, 5.0), (-6.2, 16.6, 4.6),
          (-7.9, 14.5, 4.1), (-8.1, 11.5, 3.4), (-8.0, 8.5, 2.6), (-8.2, 5.8, 1.8), (-8.8, 4.2, 1.0),
          (-10.0, 3.3, 0.45), (-10.9, 2.0, 0.22)]
    # spirale intorno al pennone in (8,6 / 10,6): è il TUBO DELL'INSEGUIMENTO (rosso, Ø interno 1,6 m
    # come i moduli di ambienti_tecnici/scivoli_kit). Parte dal piano in cima alla torre, esce dalla
    # faccia ovest sopra la trave di bordo, gira a ovest della colonna d'angolo e scende a spirale.
    sx, sy, R = SPIRALE['cx'], SPIRALE['cy'], SPIRALE['r']
    p2 = [(12.2, 16.3, zt + 1.0), (10.3, 16.15, zt + 0.95), (9.2, 15.0, zt + 0.6)]
    a0, a1 = math.radians(60), math.radians(60 - 540)
    n = 19
    for k in range(n):
        t = k / (n - 1)
        a = a0 + (a1 - a0) * t
        p2.append((sx + math.cos(a) * R, sy + math.sin(a) * R, zt - 0.2 - 3.8 * t))
    p2 += [(4.6, 7.4, 4.45), (0.0, 3.6, 3.95), (-4.6, 0.0, 3.3), (-7.6, -2.2, 2.4), (-8.9, -3.0, 1.62),
           (-9.9, -3.4, 1.05), (-10.9, -3.6, 0.8)]   # la bocca resta 15 cm sopra l'acqua della vasca d'arrivo
    # (nome, punti, colori dei segmenti, raggio interno, spessore della parete)
    return [('scivolo_grande', p1, ['scivolo_b'] * 5 + ['scivolo_d'] + ['scivolo_b'] * 3 + ['scivolo'], K.SCIVOLO_R, K.SCIVOLO_SPESSORE),
            ('scivolo_spirale', p2, ['scivolo'] * 7 + ['scivolo_d'] + ['scivolo'] * 6, SCIVOLO_INSEGUIMENTO_R, 0.06),
            ('scivolo_medio', p3, ['scivolo_c'] * 4 + ['scivolo_d'] + ['scivolo_c'] * 5, K.SCIVOLO_R, K.SCIVOLO_SPESSORE)]


def campiona(pts, passo=0.25):
    """Punti lungo la curva Catmull-Rom usata dal tubo (per i controlli e i sostegni)."""
    P = [Vector(p) for p in pts]
    E = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    def cr(p0, p1, p2, p3, t):
        return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
    out = []
    for i in range(1, len(E) - 2):
        n = max(2, int((E[i + 1] - E[i]).length / passo))
        for k in range(n):
            out.append(cr(E[i - 1], E[i], E[i + 1], E[i + 2], k / n))
    out.append(P[-1])
    return out


def controlla_scivoli():
    """Stampa le distanze minime tra i tubi e dagli ostacoli principali (per i ritocchi)."""
    tubi = [(n, campiona(p)) for n, p, *_ in percorsi_scivoli()]
    for i in range(len(tubi)):
        for j in range(i + 1, len(tubi)):
            d = min((a - b).length for a in tubi[i][1][::2] for b in tubi[j][1][::2])
            ri, rj = [r + sp for n_, p_, q_, r, sp in percorsi_scivoli() if n_ in (tubi[i][0], tubi[j][0])]
            print(f'distanza {tubi[i][0]} - {tubi[j][0]}: {d:.2f} m (serve > {ri + rj + 0.1:.2f})')
    for n, Q in tubi:
        alto = max(q.z for q in Q)
        gal = [q for q in Q if (q.x > X1 - PROF_GAL - 0.6 or q.x < X0 + PROF_GAL + 0.6 or q.y > Y1 - PROF_GAL - 0.6
                                or q.y < Y0 + PROF_GAL + 0.6) and Z_GAL - 0.6 < q.z < Z_GAL + SP_GAL + 1.05 + 0.6]
        print(f'{n}: quota massima {alto:.2f} (soffitto {Z_SOFF}), punti sopra la galleria in conflitto: {len(gal)}')


def scivoli(mats, zf_piscina):
    obs = []
    sostegni = []
    for nome, pts, seq, r_tubo, sp_tubo in percorsi_scivoli():
        tubo = K.tubo_scivolo(mats, pts, nome='sala_' + nome, materiali=seq, r=r_tubo, spessore=sp_tubo,
                              seg=32 if r_tubo > 0.6 else 24)
        obs.append(tubo)
        # collisione semplificata: tratti convessi di circa 2 m intorno al tubo
        Q = campiona(pts, 0.5)
        for i in range(0, len(Q) - 1, 4):
            a, b = Q[i], Q[min(i + 4, len(Q) - 1)]
            d = (b - a).normalized()
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            u = (ref - d * ref.dot(d)).normalized(); v = d.cross(u)
            R_ = r_tubo + sp_tubo + 0.02
            punti = [p + (u * math.cos(2 * math.pi * k / 8) + v * math.sin(2 * math.pi * k / 8)) * R_ for p in (a, b) for k in range(8)]
            K.collisione_punti(f'{nome}_{i}', [tuple(p) for p in punti], padre=tubo)
        # colonne di sostegno ogni ~5 m dove il tubo è alto
        P = [Vector(p) for p in pts]
        dist = 0.0
        prossimo = 3.0
        for a, b in zip(P, P[1:]):
            L = (b - a).length
            t = 0.0
            while dist + L >= prossimo:
                t = (prossimo - dist) / L
                q = a.lerp(b, t)
                prossimo += 5.0
                if q.z < 1.2:
                    continue
                if TORRE['cx'] - 3.6 < q.x < TORRE['cx'] + 3.6 and TORRE['cy'] - 4.4 < q.y < TORRE['cy'] + 3.6:
                    continue  # vicino alla torre: è appeso alla torre
                if math.hypot(q.x - SPIRALE['cx'], q.y - SPIRALE['cy']) < SPIRALE['r'] + 0.8:
                    continue  # la spirale è retta dal pennone
                if any(bx0 - 0.4 < q.x < bx1 + 0.4 and by0 - 0.4 < q.y < by1 + 0.4 for bx0, by0, bx1, by1 in VASCHE_BASSE):
                    continue
                zb = 0.0
                if PISCINA['x0'] < q.x < PISCINA['x1'] and PISCINA['y0'] < q.y < PISCINA['y1']:
                    zb = zf_piscina(q.x, q.y)
                if VASCA_ARRIVO['x0'] < q.x < VASCA_ARRIVO['x1'] and VASCA_ARRIVO['y0'] < q.y < VASCA_ARRIVO['y1']:
                    zb = -VASCA_ARRIVO['prof']
                col_ = K.colonna(mats, (q.x, q.y, zb), q.z - r_tubo - sp_tubo - 0.02 - zb, raggio=0.11 if r_tubo < 0.6 else 0.15, nome=un('sost'))
                K.collisione_scatola(col_.name, (q.x - 0.12, q.y - 0.12, zb), (q.x + 0.12, q.y + 0.12, q.z - r_tubo - sp_tubo), padre=col_)
                sostegni.append(col_)
            dist += L
    # pennone della spirale con i bracci
    pen = K.colonna(mats, (SPIRALE['cx'], SPIRALE['cy'], 0.0), TORRE['piani'][-1] + 0.4, raggio=0.2, nome='pennone')
    K.collisione_scatola('pennone', (SPIRALE['cx'] - 0.22, SPIRALE['cy'] - 0.22, 0), (SPIRALE['cx'] + 0.22, SPIRALE['cy'] + 0.22, TORRE['piani'][-1] + 0.4), padre=pen)
    sostegni.append(pen)
    pts2 = dict((n, p) for n, p, *_ in percorsi_scivoli())['scivolo_spirale']
    for q in campiona(pts2)[8:-30:14]:
        if math.hypot(q.x - SPIRALE['cx'], q.y - SPIRALE['cy']) < SPIRALE['r'] + 0.3:
            d = (Vector((q.x, q.y, 0)) - Vector((SPIRALE['cx'], SPIRALE['cy'], 0))).normalized()
            a = Vector((SPIRALE['cx'], SPIRALE['cy'], q.z - SCIVOLO_INSEGUIMENTO_R - 0.1)) + d * 0.2
            b = Vector((q.x, q.y, q.z - SCIVOLO_INSEGUIMENTO_R - 0.1)) - d * 0.1
            c = K.Costruttore(mats)
            c.cilindro(a, b, 0.06, 'metallo', seg=8)
            sostegni.append(c.crea('braccio'))
    obs.append(unisci(sostegni, 'sala_sostegni_scivoli'))
    return obs


# ----------------------------------------------------------------------------- arredi dell'architettura

def cartelloni(mats):
    """Cartelloni disegnati (nessuna scritta): erano appesi alle ringhiere del soppalco; dal 16 ottobre
    stanno sulle pareti nord e sud, alla stessa quota, con la cornice appoggiata al muro."""
    obs = []
    zr = Z_GAL + SP_GAL - 0.15
    for i, (x, chiave) in enumerate(((-9.0, 'p1'), (-1.5, 'p2'), (6.0, 'p3'))):
        ob = K.cartellone(mats, 3.2, 1.8, nome=f'sala_cartellone_n{i}')
        obs.append(metti(ob, (x, Y1 - 0.005, zr)))
    # (i due cartelloni sul lato est sono stati sostituiti dai teli con la mascotte, vedi cartelloni_mascotte)
    ob = K.cartellone(mats, 3.2, 1.8, nome='sala_cartellone_s0')
    obs.append(metti(ob, (-8.0, Y0 + 0.005, zr), 180))
    # ogni cartellone con la sua grafica
    grafiche = ['p1', 'p2', 'p3', 'p3']
    for ob, g in zip(obs, grafiche):
        for i, m in enumerate(ob.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                ob.data.materials[i] = mats.get('cartellone_' + g)
    return obs


def cartelloni_mascotte(mats):
    """Due teli da 2 x 3 m con la mascotte (la medusa e il bagnino), appesi con i cavi alla trave del
    soffitto ai lati della statua: entrando la incorniciano. Ognuno ha un faretto caldo su un braccio.
    Restituisce (oggetti, luci)."""
    P = PIEDISTALLO
    obs, luci = [], []
    ytrave = -9.0                       # trave del soffitto (ogni 3 m da Y0 + 2)
    zb, W, H = 3.7, 2.0, 3.0
    for i, (sx, chiave) in enumerate(((-1, 'medusa'), (1, 'bagnino'))):
        x, y = sx * 5.6, P['cy'] + 0.2
        rot = -sx * 28.0                # girati verso l'ingresso
        ob = K.cartellone(mats, W, H, nome=f'sala_cartellone_mascotte_{i}')
        for k, m in enumerate(ob.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                ob.data.materials[k] = mats.get('cartellone_' + chiave)
        metti(ob, (x, y, zb), rot)
        obs.append(ob)
        c = K.Costruttore(mats)
        R = Matrix.Rotation(math.radians(rot), 4, 'Z')
        def mondo(lx, ly, lz):
            return Vector((x, y, zb)) + (R @ Vector((lx, ly, lz)))
        for lx in (-W / 2 + 0.15, W / 2 - 0.15):   # cavi fino alla trave
            a = mondo(lx, -0.015, H + 0.035)
            c.tubo([tuple(a), (a.x, ytrave, Z_SOFF - 0.56)], 0.006, 'inox', seg=5)
        # faretto caldo su un braccio sopra il telo
        base = mondo(0.0, -0.03, H + 0.04)
        testa = mondo(0.0, -0.75, H + 0.25)
        c.tubo([tuple(base), tuple(mondo(0.0, -0.4, H + 0.3)), tuple(testa)], 0.015, 'nero', seg=6)
        bersaglio = mondo(0.0, 0.0, H * 0.45)
        d = (bersaglio - testa).normalized()
        c.cilindro(tuple(testa - d * 0.08), tuple(testa + d * 0.1), 0.07, 'nero', seg=12)
        c.disco(tuple(testa + d * 0.101), tuple(d), 0.055, 'lampadina', seg=12)
        obs.append(c.crea(f'sala_cartellone_mascotte_{i}_luce'))
        luci.append(dict(nome=f'luce_cartellone_{i}', pos=tuple(testa + d * 0.15), dir=tuple(d), colore=(1.0, 0.78, 0.5)))
    return obs, luci


def lampade(mats):
    """Plafoniere al neon (accese, spente o a metà) e luci d'emergenza rosse. Dal 16 ottobre (soppalco tolto)
    ogni plafoniera sta su due staffe fissate alla parete, alla quota di prima (3,88 m) e a 32 cm dal
    muro: stesso seme, quindi le stesse lampade accese e le luci con gli stessi nomi. Quelle che cadono
    nel varco della sala della torre non ci sono più ma tengono il loro numero, così i nomi delle altre
    luci non cambiano. Restituisce gli oggetti e le sorgenti (tipo, posizione, rotazione, intensità, tolta)."""
    obs, sorgenti = [], []
    zl = Z_GAL - 0.12  # quota di prima (sotto la veletta del soppalco)
    import random
    rnd = random.Random(11)
    D_ = 0.32
    va, vb, vh = varco_torre()
    def nel_varco(p):   # parete est, nel varco o accanto al portone
        return abs(p[0] - X1) < 0.5 and va - 1.4 < p[1] < vb + 1.4 and p[2] < vh + 3.0
    c0, c1 = corsa_portone()
    def sopra_binario(p):
        """Il neon che cade nella corsa del portone aperto sale sopra il binario, a metà tra i due oblò
        alti (y 7: gli oblò alti sono in y 5 e 9): stesso numero e stessa luce."""
        if abs(p[0] - (X1 - D_)) < 0.01 and c0 - 0.7 < p[1] < c1 and p[2] < vh + 0.6:
            return (p[0], 7.0, vh + 1.0)
        return p
    stati = []
    # lato est e ovest: plafoniere orientate lungo y; nord e sud lungo x (verso: dalla lampada al muro)
    for y in range(int(Y0) + 4, 21, 4):
        stati.append(((X1 - D_, y + 0.0, zl), 90, (1, 0)))
        stati.append(((X0 + D_, y + 0.0, zl), 90, (-1, 0)))
    for x in range(-16, 17, 4):
        if abs(x) < 1:
            continue
        stati.append(((x + 0.0, Y0 + D_, zl), 0, (0, -1)))
        stati.append(((x + 0.0, Y1 - D_, zl), 0, (0, 1)))
    for i, (pos, rot, verso) in enumerate(stati):
        pos = sopra_binario(pos)
        r = rnd.random()
        acc = (True, True) if r < 0.5 else ((True, False) if r < 0.75 else (False, False))
        via = nel_varco(pos)
        if acc[0]:
            sorgenti.append(('neon', pos, rot, 1.0 if acc[1] else 0.45, via))
        if via:
            continue
        obs.append(metti(K.lampada_neon(mats, accesa=acc, nome=f'neon_{i}'), pos, rot))
        c = K.Costruttore(mats)
        lungo = Vector((0, 1, 0)) if rot == 90 else Vector((1, 0, 0))
        n = Vector((verso[0], verso[1], 0))
        muro = Vector((pos[0] + verso[0] * D_, pos[1] + verso[1] * D_, pos[2]))
        for s_ in (-0.42, 0.42):
            a = muro + lungo * s_
            b = Vector(pos) + lungo * s_
            lo = Vector((min(a.x, b.x), min(a.y, b.y), pos[2] - 0.005))
            hi = Vector((max(a.x, b.x), max(a.y, b.y), pos[2] + 0.035))
            if rot == 90:
                lo.y -= 0.02; hi.y += 0.02
            else:
                lo.x -= 0.02; hi.x += 0.02
            c.scatola(tuple(lo), tuple(hi), 'metallo')                     # staffa
            c.scatola_assi(tuple(muro + lungo * s_ - n * 0.005), (tuple(lungo), (0, 0, 1), tuple(n)), (0.05, 0.07, 0.008), 'metallo')   # piastra
        obs.append(c.crea(f'staffe_{i}'))
    # luci d'emergenza rosse sulle pareti (in basso e in alto)
    # (quella in y 6 era nella corsa del portone aperto: ora è in y 5)
    emerg = [((X1, -6.0, 2.9), -90), ((X1, 5.0, 2.9), -90), ((X1, 18.0, 2.9), -90),
             ((X0, -4.0, 2.9), 90), ((X0, 8.0, 2.9), 90), ((X0, 20.0, 2.9), 90),
             ((-6.0, Y1, 2.9), 0), ((8.0, Y1, 2.9), 0), ((-5.0, Y0, 2.9), 180), ((5.0, Y0, 2.9), 180),
             ((X1, 0.0, 8.6), -90), ((X0, 12.0, 8.6), 90), ((-12.0, Y1, 8.6), 0), ((12.0, Y0, 8.6), 180),
             ((2.0, Y1, 8.6), 0), ((X1, 14.0, 8.6), -90), ((X0, -6.0, 8.6), 90),
             ((X1, -14.0, 2.9), -90), ((X0, -16.0, 2.9), 90), ((X1, -12.0, 8.6), -90), ((-14.0, Y0, 8.6), 180)]
    for i, (pos, rot) in enumerate(emerg):
        via = nel_varco(pos)
        d = Vector((0, -0.12, 0))
        d.rotate(Euler((0, 0, math.radians(rot))))
        sorgenti.append(('rossa', tuple(Vector(pos) + d), rot, 1.0, via))
        if not via:
            obs.append(metti(K.luce_emergenza(mats, nome=f'emerg_{i}'), pos, rot))
    return obs, sorgenti


def insegna_neon(nome='sala_insegna_pesce', centro=(-3.0, Y1 - 0.05, 7.4), scala=1.6):
    """Insegna al neon rosa a forma di pesce (nessuna scritta), sulla parete nord in alto."""
    m = bpy.data.materials.get('M_amb_neon_rosa') or bpy.data.materials.new('M_amb_neon_rosa')
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (1.0, 0.25, 0.6, 1)
    b.inputs['Emission Color'].default_value = (1.0, 0.18, 0.55, 1)
    b.inputs['Emission Strength'].default_value = 22.0
    class _M:
        def lato(self, n): return 1.0
        def get(self, n): return m
    c = K.Costruttore(_M())
    cx, cy, cz = centro
    corpo = []
    for k in range(41):
        t = 2 * math.pi * k / 40
        x = math.cos(t) * 1.0
        z = math.sin(t) * 0.45 * (1 - 0.35 * math.cos(t))
        corpo.append((cx + x * scala, cy, cz + z * scala))
    c.tubo(corpo, 0.025, 'n', seg=8)
    coda = [(cx - 1.0 * scala, cy, cz), (cx - 1.5 * scala, cy, cz + 0.4 * scala), (cx - 1.5 * scala, cy, cz - 0.4 * scala), (cx - 1.0 * scala, cy, cz)]
    c.tubo(coda, 0.025, 'n', seg=8)
    occhio = [(cx + 0.55 * scala + math.cos(2 * math.pi * k / 16) * 0.08 * scala, cy, cz + 0.1 * scala + math.sin(2 * math.pi * k / 16) * 0.08 * scala) for k in range(17)]
    c.tubo(occhio, 0.02, 'n', seg=6)
    for k in range(3):  # bollicine
        bx, bz = cx + (1.35 + 0.25 * k) * scala, cz + (0.5 + 0.35 * k) * scala
        c.tubo([(bx + math.cos(2 * math.pi * j / 12) * 0.07 * (k + 1), cy, bz + math.sin(2 * math.pi * j / 12) * 0.07 * (k + 1)) for j in range(13)], 0.018, 'n', seg=6)
    return c.crea(nome)


# ----------------------------------------------------------------------------- oggetti di scena (Meshy)

def file_oggetto(nome):
    """GLB di un oggetto di scena: la versione HQ se c'è, altrimenti quella vecchia."""
    if nome == 'panca':
        return PANCA_HQ
    hq = os.path.join(OGGETTI_HQ, nome + '.glb')
    return hq if os.path.exists(hq) else os.path.join(OGGETTI, nome, nome + '_meshy.glb')


_MODELLI = {}


def modello(nome):
    """Il modello (nascosto) di un oggetto di scena, importato una volta sola."""
    if nome not in _MODELLI:
        _MODELLI[nome] = importa_oggetto(nome)
    return _MODELLI[nome]


def copia_modello(nome, pos, rot=0.0, scala=1.0, incl=(0.0, 0.0), nome_ob=None, collisione=True):
    """Copia di un oggetto di scena (mesh condivisa: nel GLB è un'istanza), con la sua scatola di
    collisione figlia sui limiti del modello."""
    m = modello(nome)
    o = m.copy()
    o.hide_render = False; o.hide_viewport = False
    bpy.context.scene.collection.objects.link(o)
    o.location = pos
    # l'importatore glTF lascia la rotazione in quaternioni: senza questo la rotazione non conta
    # (fino alla passata HQ gli oggetti di scena erano tutti dritti e allineati agli assi)
    o.rotation_mode = 'XYZ'
    o.rotation_euler = Euler((math.radians(incl[0]), math.radians(incl[1]), math.radians(rot)))
    o.scale = (scala, scala, scala)
    o.name = nome_ob or f'ogg_{nome}'
    if collisione:
        me = m.data
        xs = [v.co.x for v in me.vertices]; ys_ = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        cb = K.collisione_scatola(o.name, (min(xs), min(ys_), min(zs)), (max(xs), max(ys_), max(zs)), padre=o)
        cb.hide_render = True
    return o


def importa_oggetto(nome):
    """Importa un GLB di Meshy una volta sola e lo porta a misura (pivot alla base, al centro).
    Restituisce un oggetto modello da duplicare (dati condivisi = istanze nel GLB)."""
    sys.path.insert(0, OGGETTI)
    from meshy_oggetti import MISURE  # noqa: E402
    MISURE = dict(MISURE, **MISURE_HQ)
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=file_oggetto(nome))
    nuovi = [o for o in bpy.data.objects if o not in prima]
    mesh = [o for o in nuovi if o.type == 'MESH']
    # unisci in un solo oggetto con trasformazioni applicate
    bpy.ops.object.select_all(action='DESELECT')
    for o in mesh:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(mesh) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in nuovi:
        if o.name in bpy.data.objects and o is not ob and o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    me = ob.data
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    asse, misura = MISURE[nome]
    dim = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    s = misura / (dim[2] if asse == 'z' else max(dim[0], dim[1]))
    centro = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs)))
    me.transform(Matrix.Translation(-centro))
    me.transform(Matrix.Scale(s, 4))
    ob.location = (0, 0, 0)
    ob.name = 'prop_' + nome
    me.name = 'prop_' + nome
    for i, m in enumerate(me.materials):
        if m:
            m.name = f'M_prop_{nome}' + (f'_{i}' if i else '')
    # texture per il gioco proporzionate all'oggetto: 2K per i grandi, 1K per i piccoli (sempre JPG)
    lato_max = 2048 if misura >= 1.5 and nome not in PICCOLI_1K else 1024
    immagini = set()
    for m in me.materials:
        if m and m.node_tree:
            for nd in m.node_tree.nodes:
                if nd.type == 'TEX_IMAGE' and nd.image:
                    immagini.add(nd.image)
    cartella_tmp = os.path.join(tempfile.gettempdir(), 'ambiente_prop_tex')
    os.makedirs(cartella_tmp, exist_ok=True)
    for i, img in enumerate(sorted(immagini, key=lambda x: x.name)):
        lato = min(lato_max, max(img.size))
        if lato <= 0:
            continue
        # riscrive i pixel ridotti in un JPG vero e lo ricarica (altrimenti l'export usa i dati originali)
        img.scale(lato, lato)
        f = os.path.join(cartella_tmp, f'{nome}_{i}.jpg')
        sc = bpy.context.scene
        sc.render.image_settings.file_format = 'JPEG'
        sc.render.image_settings.quality = 88
        cs = img.colorspace_settings.name
        img.save_render(f, scene=sc)
        nuova = bpy.data.images.load(f, check_existing=False)
        nuova.colorspace_settings.name = cs
        nuova.name = f'{nome}_{i}'
        for m in me.materials:
            if m and m.node_tree:
                for nd in m.node_tree.nodes:
                    if nd.type == 'TEX_IMAGE' and nd.image == img:
                        nd.image = nuova
    ob.hide_render = True  # il modello resta nascosto: in scena vanno le copie
    ob.hide_viewport = True
    return ob


def appoggia(o, zf_piscina):
    """Porta un oggetto messo a terra a toccare il pavimento (o il fondo della piscina) con il suo punto più
    basso. Con l'inclinazione a caso alcuni entravano nel pavimento e altri restavano sollevati (riscontro C3
    dell'utente: niente oggetti compenetrati con lo sfondo). Gli oggetti dritti non si muovono."""
    import numpy as np
    bpy.context.view_layer.update()
    me = o.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get('co', co)
    mw = np.array(o.matrix_world)
    co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    P = PISCINA
    dentro = (co[:, 0] > P['x0']) & (co[:, 0] < P['x1']) & (co[:, 1] > P['y0']) & (co[:, 1] < P['y1'])
    base = np.zeros(len(co))
    if dentro.any():
        base[dentro] = [zf_piscina(float(x), float(y)) for x, y in co[dentro][:, :2]]
    dz = float((base - co[:, 2]).max())
    o.location.z += dz
    return dz


def appoggia_muro(o):
    """Porta un oggetto appeso a toccare il muro della sala più vicino con il suo punto più vicino al muro: i
    salvagenti appesi restavano staccati di qualche centimetro (controllo degli oggetti, riscontro C3)."""
    import numpy as np
    if o is None:
        return 0.0
    bpy.context.view_layer.update()
    me = o.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get('co', co)
    mw = np.array(o.matrix_world)
    co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    x, y = o.location.x, o.location.y
    vicino = min((X1 - x, 'e'), (x - X0, 'o'), (Y1 - y, 'n'), (y - Y0, 's'))[1]
    d = {'e': X1 - co[:, 0].max(), 'o': X0 - co[:, 0].min(), 'n': Y1 - co[:, 1].max(), 's': Y0 - co[:, 1].min()}[vicino]
    if vicino in 'eo':
        o.location.x += d
    else:
        o.location.y += d
    return d


def disponi_oggetti(zf_piscina):
    """Oggetti di scena messi in modo credibile (lasciati lì, spostati dall'acqua, ammucchiati).
    Restituisce (copie, offerte, modelli): le offerte dei bambini intorno al centro (vasca o
    monumento) vanno nel GLB del centro, così sala_oggetti.glb è uguale con la vasca e con il
    monumento."""
    copie, offerte = [], []
    dest = [copie]
    conta = [0]
    def metti_ogg(n, pos, rot=0.0, scala=1.0, incl=(0.0, 0.0)):
        nome_ob = f'ogg_{n}_{conta[0]}'
        conta[0] += 1                    # anche per quelli tolti: i nomi degli altri restano gli stessi
        if nome_ob in TOGLI_OGGETTI:
            return None
        x, y, z = pos
        a_terra = z is None or z == 0.0
        if z is None:
            z = 0.0
            if PISCINA['x0'] < x < PISCINA['x1'] and PISCINA['y0'] < y < PISCINA['y1']:
                z = zf_piscina(x, y)
        o = copia_modello(n, (x, y, z), rot, scala, incl, nome_ob=nome_ob)
        if a_terra:
            appoggia(o, zf_piscina)
        dest[0].append(o)
        return o
    # --- fondo della piscina e pozza (S06): giocattoli trascinati verso lo scarico
    # fuori dall'anello di luce intorno al portellone (raggio 1-1,09 m): prima ci stava sopra (22 ottobre)
    metti_ogg('paperella_gigante', (1.6, -1.25, None), 40, 0.45, (8, 0))
    metti_ogg('paperella_gigante', (-1.6, -2.9, None), 200, 0.4, (-12, 6))
    metti_ogg('pallone_spiaggia', (1.9, -3.4, None), 30)
    metti_ogg('pallone_spiaggia', (-3.8, 2.6, None), 80, 0.9)
    metti_ogg('ciambella_gonfiabile', (-1.0, -0.4, None), 70, 1.0, (4, -3))
    metti_ogg('ciambella_gonfiabile', (3.4, 4.8, None), 10, 0.95, (6, 0))
    metti_ogg('salvagente_nave', (2.9, -1.0, None), 150, 1.0, (3, 0))
    metti_ogg('tubi_galleggianti', (-2.6, -0.9, None), 120)
    metti_ogg('delfino_gonfiabile_sgonfio', (-4.2, 6.5, None), 205, 1.1)
    metti_ogg('paperella_gigante', (4.5, 9.4, None), 290, 0.35, (0, 60))
    # --- lato est sotto la galleria (S04 a destra): orsacchiotto e giocattoli contro il muro
    metti_ogg('orsacchiotto_grande', (19.15, -4.2, 0.0), -105, 1.15, (-8, 0))
    metti_ogg('pallone_spiaggia', (18.2, -5.6, 0.0), 0, 1.0)
    metti_ogg('ciambella_gonfiabile', (17.6, -2.4, 0.0), 30, 1.0)
    metti_ogg('paperella_gigante', (18.6, -2.9, 0.0), -120, 0.5)
    metti_ogg('tubi_galleggianti', (16.4, -6.4, 0.0), 75)
    # salvagenti appesi ai muri (in piedi, con il retro contro le piastrelle: appoggia_muro li porta a toccarle)
    appoggia_muro(metti_ogg('salvagente_nave', (X1 - 0.04, -7.6, 1.15), -90, 1.0, (90, 0)))
    appoggia_muro(metti_ogg('salvagente_nave', (X1 - 0.04, 4.0, 1.15), -90, 1.0, (88, 0)))
    # accanto all'oblò basso (in y -1), non sopra: lo copriva a metà (collaudo della sala, 22 ottobre)
    appoggia_muro(metti_ogg('salvagente_nave', (X0 + 0.04, -2.2, 1.15), 90, 1.0, (88, 0)))
    appoggia_muro(metti_ogg('salvagente_nave', (X0 + 0.04, 11.0, 1.15), 90, 1.0, (92, 0)))
    appoggia_muro(metti_ogg('salvagente_nave', (-3.2, Y0 + 0.04, 1.25), 180, 1.0, (90, 0)))
    # --- bordo piscina: sedia del bagnino, lettini in fila (uno rovesciato)
    metti_ogg('sedia_bagnino', (8.6, 2.5, 0.0), -90)
    for i, y in enumerate((-3.5, -1.2, 5.6, 8.0)):
        incl = (0, 0) if i != 2 else (0, 85)
        metti_ogg('lettino_plastica', (11.8, y, 0.0 if i != 2 else 0.47), 180 + (6 if i % 2 else -4), 1.0, incl)
    metti_ogg('lettino_plastica', (-6.0, -8.2, 0.0), 75)
    # --- area bimbi: balena sgonfia nella vasca bassa, funghi, cannoncini, paperelle
    metti_ogg('balena_gonfiabile_sgonfia', (-15.0, 12.1, 0.33), 140, 0.95)
    for (fx, fy, fr, fs) in FUNGHI:   # nella piazza della disposizione 1 (prima: (-10,4; 12,4) e (-9,4; 9,8))
        metti_ogg('fungo_fontana', (fx, fy, 0.0), fr, fs)
    metti_ogg('cannoncino_acqua', (-12.0, 13.9, 2.6), 160, 0.85)
    metti_ogg('cannoncino_acqua', (-14.0, 14.0, 1.4), 200, 0.85)
    metti_ogg('cannoncino_acqua', (-10.8, 5.6, 0.0), 120, 1.0)
    metti_ogg('paperella_gigante', (-11.6, 8.0, 0.30), 210, 0.4)
    metti_ogg('pallone_spiaggia', (-13.1, 8.9, 0.30), 0, 0.85)
    metti_ogg('paperella_gigante', (-9.0, 13.6, 0.0), 160, 1.0)
    metti_ogg('orsacchiotto_grande', (-17.3, 18.8, 0.0), 60, 0.8, (0, -10))
    # --- offerte dei bambini alla base del monumento (con disegni e conchiglie di offerte_monumento)
    dest[0] = offerte
    PD = PIEDISTALLO
    def sul_gradino(a, r, z):
        t = math.radians(a)
        return (PD['cx'] + math.cos(t) * r, PD['cy'] + math.sin(t) * r, z)
    if CENTRO['modo'] == 'monumento':
        r1 = (PD['r_gradino'] + PD['r_base']) / 2      # pedata bassa
        r2 = (PD['r_tamburo'] + PD['r_gradino']) / 2    # pedata alta
        rt = (PD['r_base'] + PD['r_cordone']) / 2       # a terra, dentro il cordone
        metti_ogg('salvagente_nave', sul_gradino(238, PD['r_gradino'] + 0.1, PD['z1']), 238 + 90, 1.0, (75, 0))
        metti_ogg('orsacchiotto_grande', sul_gradino(300, r1, PD['z1']), 300 + 90, 0.38)
        metti_ogg('paperella_gigante', sul_gradino(276, r2, PD['z2']), 276 + 90, 0.22)
        metti_ogg('paperella_gigante', sul_gradino(205, r1, PD['z1']), 160, 0.2)
        metti_ogg('paperella_gigante', sul_gradino(330, r2, PD['z2']), 20, 0.18)
        metti_ogg('pallone_spiaggia', sul_gradino(196, rt, 0.0), 0, 0.75)
        metti_ogg('ciambella_gonfiabile', sul_gradino(322, r1, PD['z1']), 40, 0.45, (4, 0))
    else:
        V = VASCA_CENTRALE
        yf = V['cy'] - V['ly'] / 2 + (V['coping'] / 2 - 0.12)
        metti_ogg('salvagente_nave', (V['cx'] - 1.75, yf - 0.1, 0.0), 0, 1.0, (75, 0))          # appoggiato al muro davanti
        metti_ogg('orsacchiotto_grande', (V['cx'] + 1.9, yf - 0.35, 0.0), 160, 0.38)          # seduto a terra, guarda l'ingresso
        metti_ogg('paperella_gigante', (V['cx'] - 2.62, V['cy'] + V['ly'] / 2 - 0.16, V['h']), 210, 0.2)
        metti_ogg('paperella_gigante', (V['cx'] + 2.85, V['cy'] + 0.4, V['h']), 120, 0.18)   # sul bordo (a 2,6 era sospesa sull'acqua)
        metti_ogg('paperella_gigante', (V['cx'] + 1.2, V['cy'] + 0.9, V['acqua'] - 0.03), 70, 0.24)   # galleggia
        metti_ogg('ciambella_gonfiabile', (V['cx'] - 1.4, V['cy'] + 0.7, V['acqua'] - 0.06), 25, 0.6, (3, 0))
        metti_ogg('pallone_spiaggia', (V['cx'] - 3.45, V['cy'] - 1.2, 0.0), 0, 0.75)
    dest[0] = copie
    # --- altri giocattoli sparsi (la sala è grande: nel concept è piena di roba lasciata lì)
    import random
    rnd = random.Random(31)
    sparsi = [('pallone_spiaggia', 1.0), ('ciambella_gonfiabile', 0.95), ('paperella_gigante', 0.4),
              ('tubi_galleggianti', 1.0), ('pallone_spiaggia', 0.8), ('paperella_gigante', 0.3)]
    zone = [(-6.5, 6.5, -4.6, 12.6, None), (8.6, 16.6, -8.0, 12.0, 0.0), (-8.4, -7.8, -8.0, 6.0, 0.0),
            (-16.5, -9.5, 4.5, 6.0, 0.0), (-15.0, -5.0, -18.5, -12.5, 0.0), (-6.0, 6.0, 14.0, 20.5, 0.0),
            (5.0, 15.0, -18.5, -12.5, 0.0)]
    vietati = [tuple(v + d for v, d in zip(ingombro_centro('vasca'), (-0.2, -0.2, 0.2, 0.2))),
               (LAMPIONE[0] - 0.5, LAMPIONE[1] - 0.5, LAMPIONE[0] + 0.5, LAMPIONE[1] + 0.5),
               (-1.0, Y0, 1.0, Y0 + 2.5),
               (SPIRALE['cx'] - 0.6, SPIRALE['cy'] - 0.6, SPIRALE['cx'] + 0.6, SPIRALE['cy'] + 0.6),
               (15.5, 2.8, 17.1, 9.8)]
    Fb = FOSSA_BIMBI
    fossa = (Fb['x0'] - 0.6, Fb['y0'] - 0.6, Fb['x1'] + 0.6, Fb['y1'])
    for i in range(30):
        n_, sc_ = sparsi[i % len(sparsi)]
        x0_, x1_, y0_, y1_, z_ = zone[i % len(zone)]
        for _ in range(20):
            x, y = rnd.uniform(x0_, x1_), rnd.uniform(y0_, y1_)
            if not any(a < x < c_ and b < y < d for a, b, c_, d in vietati):
                break
        if fossa[0] < x < fossa[2] and fossa[1] < y < fossa[3]:
            y = fossa[1] - 0.4          # sulla fossa: si sposta poco più a sud (stessi numeri casuali per gli altri)
        metti_ogg(n_, (x, y, z_), rnd.uniform(0, 360), sc_ * rnd.uniform(0.85, 1.1), (rnd.uniform(-8, 8), rnd.uniform(-8, 8)))
    for (x, y, r_) in ((-6.0, -10.3, 100), (6.0, -10.4, 80), (-11.0, 19.0, 190)):
        metti_ogg('lettino_plastica', (x, y, 0.0), r_)
    # --- vasca d'arrivo: galleggianti
    metti_ogg('ciambella_gonfiabile', (-12.4, -3.0, VASCA_ARRIVO['acqua'] - 0.05), 40, 1.0)
    metti_ogg('tubi_galleggianti', (-14.2, -0.8, VASCA_ARRIVO['acqua'] - 0.02), 15)
    metti_ogg('pallone_spiaggia', (-10.2, -5.4, VASCA_ARRIVO['acqua'] - 0.12), 0, 0.9)
    arredi(metti_ogg)
    return copie, offerte, list(_MODELLI.values())


def arredi(metti_ogg):
    """Arredi della sala aggiunti nella passata di qualità (modelli HQ): panche lungo i muri (la panca
    degli spogliatoi), cestini a pesce e cartelli gialli del pavimento bagnato. Fuori dai percorsi:
    sotto la galleria, ai lati della porta, accanto ai lettini. Il fronte dei modelli è -y: con la
    rotazione r guarda verso (sin r, -cos r)."""
    yp = Y0 + 0.42                         # contro il muro sud, ai lati della porta
    metti_ogg('panca', (-6.0, yp, 0.0), 0)
    metti_ogg('panca', (6.0, yp, 0.0), 0)
    metti_ogg('panca', (X0 + 0.42, -12.0, 0.0), 90)
    metti_ogg('panca', (X1 - 0.42, -14.0, 0.0), 90)
    # (era in y 10, poi in y 6,6: lì scorre il portone della sala della torre, che si apre del tutto verso sud;
    # ora sta sotto la plafoniera calda del muro est)
    metti_ogg('panca', (X1 - 0.42, 2.0, 0.0), 90)
    metti_ogg('cestino_pesce', (-4.5, Y0 + 0.5, 0.0), 180 + 8)
    metti_ogg('cestino_pesce', (7.6, Y0 + 0.5, 0.0), 180 - 12)
    metti_ogg('cestino_pesce', (13.2, 10.6, 0.0), -90 + 15)
    metti_ogg('cestino_pesce', (-8.6, 18.4, 0.0), 90 - 10)       # vicino alla struttura di gioco (tolto con la disposizione 1)
    metti_ogg('cestino_pesce', (X0 + 0.7, -9.0, 0.0), 90 + 6, 1.0, (0, -4))
    # (fuori dai punti dove il giocatore si ferma: il test della sala parte da (2,5; 18) Godot verso il
    # lampione e aspira dalla vasca d'arrivo da (-8,3; 2))
    metti_ogg('cartello_pavimento_bagnato', (-3.4, -15.0, 0.0), 15)
    metti_ogg('cartello_pavimento_bagnato', (-3.0, -6.2, 0.0), 10)
    metti_ogg('cartello_pavimento_bagnato', (-8.2, 2.6, 0.0), 75)
    metti_ogg('cartello_pavimento_bagnato', (-9.4, 4.6, 0.2), 30, 1.0, (88, 0))      # caduto (tolto con la disposizione 1)


# ----------------------------------------------------------------------------- luci, nebbia, camere

def luce(nome, tipo, pos, energia, colore, **kw):
    d = bpy.data.lights.new(nome, tipo)
    d.energy = energia
    d.color = colore
    for k, v in kw.items():
        setattr(d, k, v)
    ob = bpy.data.objects.new(nome, d)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = pos
    if tipo == 'AREA':
        ob.visible_camera = False
        ob.visible_glossy = True
    return ob


def illumina(sorgenti, lampadina_lampione, lampo=False):
    """Luci della sala. La luna (blu) entra dalla cupola e proietta l'ombra dei costoloni."""
    l = luce('luna', 'SUN', (0, 5, 30), 0.9, (0.55, 0.66, 1.0), angle=math.radians(1.5))
    l.rotation_euler = Vector((0.25, -0.18, -1.0)).to_track_quat('-Z', 'Y').to_euler()
    if lampo:
        f = luce('lampo', 'SUN', (0, 5, 30), 3.2, (0.72, 0.8, 1.0), angle=math.radians(6))
        f.rotation_euler = Vector((0.45, -0.55, -1.0)).to_track_quat('-Z', 'Y').to_euler()
    # cielo diffuso attraverso la cupola
    luce('cielo_cupola', 'AREA', (0, 5, Z_SOFF + CUPOLA['tamburo'] + 5.2), 600, (0.42, 0.52, 0.85), size=18.0, shape='DISK')
    for tipo, pos, rot, k, via in sorgenti:
        if via:
            continue
        if tipo == 'neon':
            p = Vector(pos) + Vector((0, 0, -0.11))
            ob = luce('neon_luce', 'AREA', tuple(p), 70 * k, (0.80, 1.0, 0.93), size=1.25, size_y=0.12, shape='RECTANGLE')
            ob.rotation_euler = Euler((0, 0, math.radians(rot)))
        else:
            luce('rossa_luce', 'POINT', pos, 26, (1.0, 0.035, 0.02), shadow_soft_size=0.06)
    # lampione accanto al piedistallo: luce calda che ronza
    lp = luce('lampione_luce', 'SPOT', tuple(lampadina_lampione - Vector((0, 0, 0.03))), 1300, (1.0, 0.72, 0.42),
              spot_size=math.radians(120), spot_blend=0.55, shadow_soft_size=0.05)
    lp.rotation_euler = Euler((0, 0, 0))
    luce('lampione_alone', 'POINT', tuple(lampadina_lampione + Vector((0, 0, 0.12))), 18, (1.0, 0.72, 0.42), shadow_soft_size=0.05)
    # monumento: faretti dal basso e fari dalla parete sud
    for L in LUCI_MONUMENTO:
        faro = L['nome'].startswith('luce_faro')
        vasca = L['nome'].startswith('luce_vasca')
        ob = luce(L['nome'], 'SPOT', L['pos'], 2600 if faro else (120 if vasca else 260), L['colore'],
                  spot_size=math.radians(24 if faro else (70 if vasca else 46)), spot_blend=0.35 if faro else 0.6, shadow_soft_size=0.04)
        ob.rotation_euler = Vector(L['dir']).to_track_quat('-Z', 'Y').to_euler()
    for L in LUCI_CARTELLONI:   # faretti dei teli con la mascotte
        ob = luce(L['nome'], 'SPOT', L['pos'], 380, L['colore'], spot_size=math.radians(60), spot_blend=0.5, shadow_soft_size=0.05)
        ob.rotation_euler = Vector(L['dir']).to_track_quat('-Z', 'Y').to_euler()
    for L in LUCI_EXTRA:   # plafoniere calde e insegne
        luce(L['nome'], 'POINT', L['pos'], 70 if 'calda' in L['nome'] else 45, L['colore'], shadow_soft_size=0.08)
    # luci subacquee della vasca d'arrivo (verde acqua)
    for (x, y) in ((-12.5, -7.0 + 0.15), (-12.5, 3.0 - 0.15)):
        luce('subacquea', 'POINT', (x, y, -0.7), 45, (0.25, 0.95, 0.75), shadow_soft_size=0.2)
    # insegna rosa
    luce('insegna_rosa', 'AREA', (-3.0, Y1 - 0.5, 7.4), 120, (1.0, 0.22, 0.6), size=3.2, size_y=1.6, shape='RECTANGLE').rotation_euler = Euler((math.radians(-90), 0, 0))
    # struttura di gioco: una vecchia lampada gialla ancora accesa
    luce('bimbi_lampada', 'POINT', (STRUTTURA['cx'] + 0.2, STRUTTURA['cy'] + 1.6, 3.6), 60, (1.0, 0.8, 0.5), shadow_soft_size=0.1)


def nebbia(densita=1.0):
    """Nebbia in tutta la sala: velo leggero + nebbia bassa sopra pavimento e vasche."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=((X0 + X1) / 2, (Y0 + Y1) / 2, (Z_SOFF - 2.2) / 2))
    cubo = bpy.context.active_object
    cubo.name = 'nebbia'
    cubo.scale = (X1 - X0 - 0.4, Y1 - Y0 - 0.4, Z_SOFF + 2.2)
    m = bpy.data.materials.new('M_nebbia')
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    vol = nt.nodes.new('ShaderNodeVolumePrincipled')
    vol.inputs['Color'].default_value = (0.6, 0.66, 0.72, 1)
    vol.inputs['Anisotropy'].default_value = 0.5
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Position'], sep.inputs['Vector'])
    mr = nt.nodes.new('ShaderNodeMapRange'); mr.interpolation_type = 'SMOOTHSTEP'
    mr.inputs['From Min'].default_value = -0.6; mr.inputs['From Max'].default_value = 1.4
    mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.0
    nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
    no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 0.12
    no.inputs['Detail'].default_value = 2.0
    nt.links.new(geo.outputs['Position'], no.inputs['Vector'])
    mn = nt.nodes.new('ShaderNodeMapRange')
    mn.inputs['From Min'].default_value = 0.3; mn.inputs['From Max'].default_value = 0.7
    mn.inputs['To Min'].default_value = 0.15; mn.inputs['To Max'].default_value = 1.5
    nt.links.new(no.outputs['Fac'], mn.inputs['Value'])
    m1 = nt.nodes.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
    nt.links.new(mr.outputs['Result'], m1.inputs[0]); nt.links.new(mn.outputs['Result'], m1.inputs[1])
    m2 = nt.nodes.new('ShaderNodeMath'); m2.operation = 'MULTIPLY_ADD'
    nt.links.new(m1.outputs['Value'], m2.inputs[0])
    m2.inputs[1].default_value = 0.14 * densita
    m2.inputs[2].default_value = 0.0055 * densita
    nt.links.new(m2.outputs['Value'], vol.inputs['Density'])
    nt.links.new(vol.outputs['Volume'], out.inputs['Volume'])
    cubo.data.materials.append(m)
    cubo.visible_shadow = False
    return cubo


CAMERE = {
    # nome: (posizione, bersaglio, lente mm) -- occhio del giocatore a 1,65 m
    'S04_statua': ((0.35, -19.2, 1.65), (0.0, -10.0, 3.1), 18.0),
    'ingresso': ((0.0, -19.2, 1.65), (0.0, -10.0, 3.1), 13.9),   # come lo scatto in Godot (FOV verticale 72)
    'S06_pozza': ((5.6, -6.9, 1.9), (-0.6, -0.4, -1.1), 18.0),
    'S08_piedistallo': ((3.6, -14.9, 1.55), (0.0, -10.0, 1.3), 24.0),
    'S09_vasca_bimbi': ((-12.2, 5.4, 0.95), (-12.9, 12.5, 1.9), 20.0),
    'S10_torre': ((12.3, 16.6, 10.25), (-4.0, 6.0, -3.0), 17.0),
    'panoramica': ((16.5, -10.0, 6.4), (-3.0, 8.0, 2.0), 16.0),
}


def camera(nome):
    pos, bers, lente = CAMERE[nome]
    cd = bpy.data.cameras.get('cam') or bpy.data.cameras.new('cam')
    cd.lens = lente
    cd.sensor_width = 36
    cd.clip_end = 400
    cam = bpy.data.objects.get('cam') or bpy.data.objects.new('cam', cd)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = (Vector(bers) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam


def impostazioni(campioni, larghezza, altezza, fili):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = campioni
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.05
    sc.render.use_persistent_data = True  # più inquadrature senza ricostruire la scena
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.cycles.diffuse_bounces = 2
    sc.cycles.glossy_bounces = 3
    sc.cycles.transmission_bounces = 4
    sc.cycles.volume_bounces = 0
    sc.cycles.transparent_max_bounces = 10
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.cycles.sample_clamp_indirect = 4.0
    sc.cycles.volume_step_rate = 4.0
    sc.cycles.volume_max_steps = 256
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = fili
    sc.render.resolution_x, sc.render.resolution_y = larghezza, altezza
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    sc.view_settings.exposure = -0.1
    w = bpy.data.worlds.new('notte')
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.003, 0.004, 0.007, 1)


# ----------------------------------------------------------------------------- costruzione completa

GRUPPI = {}
LUCI_MONUMENTO = []          # faretti dal basso e fari dalla galleria (riempita da costruisci)
LUCI_EXTRA = []              # plafoniere calde e insegne al neon (riempita da costruisci)
LUCI_CARTELLONI = []         # faretti caldi dei teli con la mascotte (riempita da costruisci)
DATI_NUOVI = {}              # pulsante della botola e portone della sala della torre (riempita da costruisci)
LAMPIONE = (2.8, -13.2, 0.0)  # lampione accanto al monumento: il braccio porta la lampada verso la statua


def gruppo(nome, obs):
    """Registra gli oggetti di un pezzo della sala (un GLB per gruppo)."""
    GRUPPI.setdefault(nome, [])
    for o in (obs if isinstance(obs, (list, tuple)) else [obs]):
        if o is not None:
            GRUPPI[nome].append(o)
    return obs


def costruisci(con_oggetti=True, per_render=True, con_corridoio=False):
    K.svuota()
    GRUPPI.clear()
    _CONTA.clear()
    _MODELLI.clear()
    mats = K.Materiali(PALETTE_SALA, per_render=per_render)
    materiali_nuovi(mats)
    DATI_NUOVI.clear()
    arch = []
    buchi = [(PISCINA['x0'] - 0.5, PISCINA['y0'] - 0.5, PISCINA['x1'] + 0.5, PISCINA['y1'] + 0.5),
             (VASCA_ARRIVO['x0'] - 0.5, VASCA_ARRIVO['y0'] - 0.5, VASCA_ARRIVO['x1'] + 0.5, VASCA_ARRIVO['y1'] + 0.5)]
    F = FOSSA_BIMBI
    arch.append(gruppo('architettura', pavimento_regione(mats, X0, X1, Y0, Y1, buchi, esatti=[(F['x0'], F['y0'], F['x1'], F['y1'])])))
    arch += gruppo('architettura', pareti(mats))
    # (soppalco, colonne e ringhiere tolti il 16 ottobre: galleria() non si usa più)
    arch.append(gruppo('architettura', soffitto_con_foro(mats, X0, X1, Y0, Y1, Z_SOFF, CUPOLA['cx'], CUPOLA['cy'], CUPOLA['r'])))
    arch += gruppo('cupola', cupola(mats))
    pis, zf = piscina_onde(mats)
    arch += pis
    gruppo('piscina', [o for o in pis if o.name != 'sala_pozza'])
    arch.append(gruppo('architettura', schegge_a_terra(mats, zf)))
    gruppo('acqua', [o for o in pis if o.name == 'sala_pozza'])
    va = vasca_arrivo(mats)
    arch += va
    gruppo('torre_scivoli', [o for o in va if not o.name.endswith('_acqua')])
    gruppo('acqua', [o for o in va if o.name.endswith('_acqua')])
    VB = VASCA_BIMBI_2
    for args in ((-12.6, 9.6, 4.4, 3.2, 'sala_vasca_bimbi_1', 0.3),
                 (VB['cx'], VB['cy'], VB['lato'], VB['lato'], 'sala_vasca_bimbi_2', VB['acqua'])):
        bordi = bordi_vasca_bimbi_1() if args[4] == 'sala_vasca_bimbi_1' else None
        vb = vasca_bassa(mats, *args[:5], acqua=args[5], bordi=bordi)
        arch += vb
        gruppo('area_bimbi', vb[0]); gruppo('acqua', vb[1])
    fossa, acqua_fossa, coperchio = fossa_bimbi(mats)     # tappa 8: la parte profonda della VascaBimbi1
    arch += fossa
    gruppo('area_bimbi', fossa + [coperchio]); gruppo('acqua', acqua_fossa)
    lamp, lampadina = lampione(mats, LAMPIONE)
    if CENTRO['modo'] == 'monumento':     # la statua sul monumento (per più avanti)
        ped, luci_mon = piedistallo(mats)
        fari, luci_fari = fari_parete(mats)
        LUCI_MONUMENTO[:] = luci_mon + luci_fari
        arch += gruppo('monumento', [ped] + cordone(mats) + [lamp, fari, offerte_monumento(mats)])
    else:                                 # la vasca sollevata con la medusa affacciata
        VC = VASCA_CENTRALE
        vasca, acqua_vc, luci_vasca = vasca_centrale(mats)
        fari, luci_fari = fari_parete(mats, (VC['cx'], VC['cy'] - VC['ly'] / 2 + 0.55, 1.75))
        LUCI_MONUMENTO[:] = luci_vasca + luci_fari
        arch += gruppo('vasca_centrale', vasca + cordone_vasca(mats) + [lamp, fari, offerte_vasca(mats)])
        gruppo('acqua', acqua_vc)
    arch += gruppo('area_bimbi', struttura_gioco(mats))
    # (la torre degli scivoli e gli scivoli non sono più nella sala dal 16 ottobre: si rifanno nella sala
    #  della torre con una proposta a parte; sala_torre_scivoli.glb tiene solo la vasca d'arrivo)
    arch.append(gruppo('architettura', guscio_sala_torre(mats)))
    arch += gruppo('architettura', cartelloni(mats))
    teli, luci_teli = cartelloni_mascotte(mats)
    arch += gruppo('architettura', teli)
    LUCI_CARTELLONI[:] = luci_teli
    lamp_obs, sorgenti = lampade(mats)
    arch.append(gruppo('architettura', unisci(lamp_obs, 'sala_lampade')))
    arch.append(gruppo('architettura', insegna_neon()))
    insegne, luci_ins = D.insegne_neon(mats)
    plaf, luci_cal = D.plafoniere_calde(mats)
    arch += gruppo('architettura', [insegne, plaf, D.piastrelle_mancanti(mats)])
    LUCI_EXTRA[:] = luci_ins + luci_cal
    arch.append(gruppo('architettura', D.pozzanghere(mats)))
    arch.append(gruppo('architettura', soffitto_struttura(mats)))
    arch.append(gruppo('architettura', colature(mats)))
    arch.append(gruppo('architettura', altoparlanti(mats)))
    porta = metti(K.porta_stagna(mats, VANO['luce'], VANO['h'], nome='sala_porta_stagna'), (VANO['cx'], Y0, 0.0), 180)
    arch.append(gruppo('architettura', unisci([porta], 'sala_porta_stagna')))
    if con_corridoio:   # solo per i render: il corridoio vero è negli spogliatoi (assets_src/ambienti_interni)
        arch.append(gruppo('architettura', corridoio_spogliatoi(mats)))
    inter, dati_inter = interattivi(mats, zf)
    arch += gruppo('interattivi', inter)
    DATI_NUOVI.update(dati_inter)
    # sporco in spazio mondo nei colori dei vertici (passata di qualità)
    for nome_ob, funz in (('sala_galleria', D.sporco_galleria), ('sala_colonne', D.sporco_metallo),
                          ('sala_soffitto', D.sporco_soffitto), ('sala_torre', D.sporco_metallo),
                          ('sala_struttura_gioco', D.sporco_giochi), ('sala_scivolo_grande', D.sporco_scivolo),
                          ('sala_scivolo_spirale', D.sporco_scivolo), ('sala_scivolo_medio', D.sporco_scivolo),
                          ('sala_sostegni_scivoli', D.sporco_metallo), ('sala_scala_galleria', D.sporco_metallo),
                          ('sala_lampione', D.sporco_metallo)):
        ob_ = bpy.data.objects.get(nome_ob)
        if ob_ is not None:
            D.colora(ob_, funz)
    copie, modelli = ([], [])
    if con_oggetti:
        copie, offerte, modelli = disponi_oggetti(zf)
        gruppo('oggetti', copie)
        gruppo('monumento' if CENTRO['modo'] == 'monumento' else 'vasca_centrale', offerte)
        copie = copie + offerte
    for o in bpy.context.scene.objects:   # le forme di collisione non si disegnano
        if o.name.lower().endswith(('-colonly', '-convcolonly')) or '-colonly' in o.name or '-convcolonly' in o.name:
            o.hide_render = True
            o.display_type = 'WIRE'
    return mats, arch, copie, modelli, sorgenti, lampadina, zf


def medusa_segnaposto(percorso):
    """Solo per i render: la medusa del gioco (posa statua) come segnaposto. Sulla vasca la mette con
    la campana all'altezza dell'acqua, dietro il muro davanti; sul monumento sul piano."""
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(percorso))
    nuovi = [o for o in bpy.data.objects if o not in prima]
    bpy.context.view_layer.update()
    pts = []
    for o in nuovi:
        if o.type == 'MESH':
            pts += [o.matrix_world @ v.co for v in o.data.vertices]
    if not pts:
        return
    zmin = min(p.z for p in pts); zmax = max(p.z for p in pts)
    xm = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    ym = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    radici = [o for o in nuovi if o.parent is None]
    vuoto = bpy.data.objects.new('medusa_segnaposto', None)
    bpy.context.scene.collection.objects.link(vuoto)
    for o in radici:
        o.parent = vuoto
    altezza = zmax - zmin
    if CENTRO['modo'] == 'monumento':
        k = 4.5 / altezza
        P = PIEDISTALLO
        base = (P['cx'], P['cy'], P['h'])
    else:
        k = 2.6 / altezza                    # più piccola: è affacciata, la campana in acqua
        V = VASCA_CENTRALE
        base = (V['cx'], V['cy'] - V['ly'] / 2 + V['coping'] + 0.3, V['acqua'] - 0.393 * 2.6)
    vuoto.scale = (k, k, k)
    vuoto.location = (base[0] - xm * k, base[1] - ym * k, base[2] - zmin * k)
    # nel GLB guarda verso +Z di Godot, che dopo l'import è -y di Blender: già verso la porta
    print('medusa segnaposto: altezza', round(altezza * k, 2), 'm')


def a_godot(p):
    """Coordinate Blender (Z in alto) -> Godot (Y in alto): (x, y, z) -> (x, z, -y)."""
    return [round(p[0], 3), round(p[2], 3), round(-p[1], 3)]


def dati_integrazione(sorgenti, lampadina):
    """Posizioni utili per montare la sala in Godot (scritte in sala_dati.json)."""
    luci = []
    for i, (tipo, pos, rot, k, via) in enumerate(sorgenti):
        if via:          # nel varco della sala della torre: la luce non c'è più (il numero resta preso)
            continue
        if tipo == 'neon':
            luci.append(dict(nome=f'luce_neon_{i:02d}', tipo='neon (OmniLight3D o SpotLight3D verso il basso)', blender=list(pos),
                             godot=a_godot(pos), colore=[0.80, 1.0, 0.93], intensita='piena' if k >= 1 else 'metà (un tubo spento: sfarfallio)'))
        else:
            luci.append(dict(nome=f'luce_emergenza_{i:02d}', tipo="emergenza rossa (OmniLight3D, raggio 6-8 m)", blender=list(pos),
                             godot=a_godot(pos), colore=[1.0, 0.035, 0.02]))
    lp = tuple(lampadina)
    luci.append(dict(nome='luce_lampione', tipo='SpotLight3D verso il basso, angolo 60 gradi, calda, ronza', blender=list(lp), godot=a_godot(lp), colore=[1.0, 0.72, 0.42]))
    for L in LUCI_EXTRA:
        luci.append(dict(nome=L['nome'], tipo=('OmniLight3D calda (plafoniera navale accesa)' if 'calda' in L['nome'] else
                                               "OmniLight3D davanti all'insegna al neon"),
                         blender=[round(v, 3) for v in L['pos']], godot=a_godot(L['pos']), colore=list(L['colore'])))
    for L in LUCI_CARTELLONI:
        luci.append(dict(nome=L['nome'], tipo='SpotLight3D: faretto caldo sul telo con la mascotte',
                         blender=[round(v, 3) for v in L['pos']], godot=a_godot(L['pos']),
                         direzione_blender=[round(v, 3) for v in L['dir']], direzione_godot=a_godot(L['dir']), colore=list(L['colore'])))
    for L in LUCI_MONUMENTO:
        faro = L['nome'].startswith('luce_faro')
        luci.append(dict(nome=L['nome'], tipo=('SpotLight3D: faro sulla ringhiera della galleria, punta la statua o la medusa affacciata' if faro else
                                               ("SpotLight3D sott'acqua nella vasca sollevata, verso la medusa" if L['nome'].startswith('luce_vasca') else
                                                'SpotLight3D: faretto nel gradino, illumina la statua dal basso')),
                         blender=[round(v, 3) for v in L['pos']], godot=a_godot(L['pos']),
                         direzione_blender=[round(v, 3) for v in L['dir']], direzione_godot=a_godot(L['dir']), colore=list(L['colore'])))
    for j, (x, y) in enumerate(((-12.5, -6.85), (-12.5, 2.85))):
        luci.append(dict(nome=f'luce_subacquea_{j}', tipo="OmniLight3D sott'acqua, vasca d'arrivo", blender=[x, y, -0.7], godot=a_godot((x, y, -0.7)), colore=[0.25, 0.95, 0.75]))
    luci.append(dict(nome='luce_insegna_rosa', tipo='OmniLight3D davanti all insegna a pesce', blender=[-3.0, Y1 - 0.5, 7.4], godot=a_godot((-3.0, Y1 - 0.5, 7.4)), colore=[1.0, 0.22, 0.6]))
    luci.append(dict(nome='luce_area_bimbi', tipo='OmniLight3D gialla sulla struttura', blender=[STRUTTURA['cx'] + 0.2, STRUTTURA['cy'] + 1.6, 3.6],
                     godot=a_godot((STRUTTURA['cx'] + 0.2, STRUTTURA['cy'] + 1.6, 3.6)), colore=[1.0, 0.8, 0.5]))
    luci.append(dict(nome='luce_luna', tipo='DirectionalLight3D blu dalla cupola (ombre dei costoloni)', direzione_blender=[0.25, -0.18, -1.0],
                     direzione_godot=a_godot((0.25, -0.18, -1.0)), colore=[0.55, 0.66, 1.0]))
    P, V = PISCINA, VASCA_ARRIVO
    acqua = [
        dict(nome='sala_pozza', cosa="pozza torbida sul fondo della piscina a onde (sopra il portello dello scarico)",
             centro_blender=[P['scarico'][0], P['scarico'][1], -2.07], quota_blender=-2.07, nota="il fondo è a conca: l'acqua visibile è circa un cerchio di raggio 3-3,5 m intorno a (0, -2); scende fino a -2,24 al centro"),
        dict(nome='sala_vasca_arrivo_acqua', cosa="vasca d'arrivo degli scivoli (piena)", x=[V['x0'], V['x1']], y=[V['y0'], V['y1']], quota_blender=V['acqua'], fondo_blender=-V['prof']),
        dict(nome='sala_vasca_bimbi_1_acqua', cosa='vasca bassa a scacchi (area bimbi, scena "lei sbuca dal bordo")', x=[-14.8, -10.4], y=[8.0, 11.2], quota_blender=0.30, bordo_blender=0.45),
        dict(nome='sala_vasca_bimbi_2_acqua', cosa='vasca bassa piccola, dove finisce lo scivolo della struttura di gioco',
             x=[VASCA_BIMBI_2['cx'] - VASCA_BIMBI_2['lato'] / 2, VASCA_BIMBI_2['cx'] + VASCA_BIMBI_2['lato'] / 2],
             y=[VASCA_BIMBI_2['cy'] - VASCA_BIMBI_2['lato'] / 2, VASCA_BIMBI_2['cy'] + VASCA_BIMBI_2['lato'] / 2],
             quota_blender=VASCA_BIMBI_2['acqua'], bordo_blender=0.45),
        dict(nome='sala_fossa_bimbi_acqua', cosa="fossa dello scarico rotto, la parte profonda della VascaBimbi1 (stessa acqua): pianta nel poligono 'fossa_bimbi.pianta_godot'",
             x=[FOSSA_BIMBI['x0'], FOSSA_BIMBI['x1']], y=[FOSSA_BIMBI['y0'], FOSSA_BIMBI['y1']], quota_blender=0.30,
             fondo_blender=FOSSA_BIMBI['fondo'], profondita_sotto_il_fondo_della_vasca=round(0.02 - FOSSA_BIMBI['fondo'], 2), bordo_blender=0.45),
    ]
    for a in acqua:
        if 'centro_blender' in a:
            a['centro_godot'] = a_godot(a['centro_blender'])
    pd = PIEDISTALLO
    centro = {}
    if CENTRO['modo'] == 'monumento':
        pulsante = (pd['cx'], pd['cy'] - pd['r_tamburo'] - 0.13, pd['z_pulsante'])
        centro['piedistallo'] = dict(
            nota='monumento della statua: piano superiore libero per la medusa, rivolta verso la porta (+z Godot)',
            centro_blender=[pd['cx'], pd['cy'], 0.0], centro_godot=a_godot((pd['cx'], pd['cy'], 0.0)),
            quota_piano=pd['h'], diametro_piano=round(2 * (pd['r_piano'] - 0.03), 2), diametro_tamburo=2 * pd['r_tamburo'],
            diametro_gradino_basso=2 * pd['r_base'], diametro_gradino_alto=2 * pd['r_gradino'],
            quote_gradini=[pd['z1'], pd['z2']], raggio_cordone=pd['r_cordone'],
            statua=dict(appoggio_godot=a_godot((pd['cx'], pd['cy'], pd['h'])), altezza_prevista=4.5, cima_godot=round(pd['h'] + 4.5, 2)),
            pulsante_bimbi=dict(blender=[round(v, 3) for v in pulsante], godot=a_godot(pulsante), verso_godot=[0, 0, 1]))
    else:
        V = VASCA_CENTRALE
        yf = V['cy'] - V['ly'] / 2 + (V['coping'] / 2 - 0.12)
        pulsante = (V['cx'], yf - 0.13, V['z_pulsante'])
        centro['vasca_centrale'] = dict(
            nota="vasca sollevata al centro della sala (concept medusa_sbircia): la medusa si affaccia sul lato verso l'ingresso (+Z Godot)",
            centro_godot=a_godot((V['cx'], V['cy'], 0.0)), pianta_esterna_godot=dict(x=V['lx'], z=V['ly']), raggio_angoli=V['r'],
            cima_bordo=V['h'], larghezza_coping=V['coping'], pelo_acqua=V['acqua'], fondo=0.0,
            filo_esterno_davanti_godot_z=round(-(V['cy'] - V['ly'] / 2), 3), filo_interno_davanti_godot_z=round(-(V['cy'] - V['ly'] / 2 + V['coping']), 3),
            muro_davanti_godot_z=round(-yf, 3), raggio_cordone_dal_bordo=V['cordone'],
            pulsante_bimbi=dict(nodo='sala_pulsante_piedistallo', blender=[round(v, 3) for v in pulsante], godot=a_godot(pulsante), verso_godot=[0, 0, 1]))
        mani = [(V['cx'] + sx * 0.45, V['cy'] - V['ly'] / 2 + 0.15, V['h']) for sx in (-1, 1)]
        origine = (V['cx'], V['cy'] - V['ly'] / 2 + V['coping'] + 0.2, V['acqua'])
        centro['medusa_affacciata'] = dict(
            nota=("posizione consigliata dell'origine della medusa affacciata: sul pelo dell'acqua, 20 cm dentro il muro davanti, "
                  "rivolta verso +Z (l'ingresso). Le mani sul coping in x +-0,45, z 12,1 (cima del bordo a y 1,0). "
                  "La campana in acqua, i tentacoli che ricadono fuori dal bordo davanti."),
            posizione_godot=a_godot(origine), rotazione_gradi_godot=[0.0, 0.0, 0.0], guarda_verso_godot=[0, 0, 1],
            mani_godot=[a_godot(m) for m in mani], cima_bordo=V['h'], pelo_acqua=V['acqua'])
    return dict(
        nota='Coordinate in metri. Blender: Z in alto. Godot/glTF: Y in alto, (x, y, z)_blender -> (x, z, -y)_godot.',
        **centro,
        lampione=dict(base_blender=list(LAMPIONE), base_godot=a_godot(LAMPIONE)),
        fossa_bimbi=dati_fossa_bimbi(),
        spawn_ingresso=dict(blender=[0.0, Y0 + 0.8, 0.0], godot=a_godot((0.0, Y0 + 0.8, 0.0)), guarda_verso='nord (+y Blender, -z Godot), verso la statua'),
        vano_spogliatoi=dict(nota='vano libero nel muro sud (spessore 0,2 m), con la porta stagna aperta verso la sala',
                             x=[VANO['cx'] - VANO['luce'] / 2, VANO['cx'] + VANO['luce'] / 2], altezza=VANO['h'],
                             faccia_sala_godot_z=-Y0, faccia_retro_godot_z=-(Y0 - K.SPESSORE_PARETE),
                             attacco_spogliatoi_godot=a_godot((VANO['cx'], Y0 - K.SPESSORE_PARETE, 0.0)),
                             nota_attacco="il marker_uscita_sala_principale degli spogliatoi (9,7; 0; -20,7) va sul retro del muro, in (0; 0; 20,2): traslare i tre glTF di (-9,7; 0; 40,9)"),
        vano_serranda=dict(nota=("varco della serranda del magazzino dei gonfiabili (tappa 7 B, ambienti-1) nel muro sud, angolo "
                                 "sud-ovest: la serranda e il magazzino sono nel raccordo dei tecnici"),
                           x=[VANO_SERRANDA['cx'] - VANO_SERRANDA['luce'] / 2, VANO_SERRANDA['cx'] + VANO_SERRANDA['luce'] / 2],
                           altezza=VANO_SERRANDA['h'], faccia_sala_godot_z=-Y0),
        sala=dict(x=[X0, X1], y=[Y0, Y1], soffitto=Z_SOFF, cupola=CUPOLA,
                  nota="niente soppalco dal 16 ottobre: plafoniere, fari, cartelloni e altoparlanti sono sulle pareti"),
        piscina_onde=dict(x=[P['x0'], P['x1']], y=[P['y0'], P['y1']], profondita=P['prof'], spiaggia='nord (y=13)', scarico_portello=list(P['scarico'])),
        struttura_gioco=dict(centro_blender=[STRUTTURA['cx'], STRUTTURA['cy']], centro_godot=a_godot((STRUTTURA['cx'], STRUTTURA['cy'], 0.0)),
                             nota="disposizione 1 (16 ottobre): nell'angolo nord-ovest, scala verso sud, scivolo verso est nella vasca piccola"),
        secchio=dict(nodo='sala_secchio_gigante', perno_blender=[STRUTTURA['cx'] + 0.2, STRUTTURA['cy'] + 1.6, 7.1],
                     perno_godot=a_godot((STRUTTURA['cx'] + 0.2, STRUTTURA['cy'] + 1.6, 7.1)), asse='x', nota='solo scenografia (niente ruota a pale)'),
        funghi=[dict(pos_godot=a_godot((x, y, 0.0)), rotazione_gradi=r, scala=sc) for (x, y, r, sc) in FUNGHI],
        pulsante_botola=DATI_NUOVI.get('pulsante_botola'),
        sala_torre=DATI_NUOVI.get('portone_torre'),
        telecamera_monitor=dict(pos_godot=a_godot((TELECAMERA_MONITOR['x'], Y0 + 0.4, TELECAMERA_MONITOR['z'])),
                                guarda_godot=a_godot(TELECAMERA_MONITOR['mira']),
                                nota="punto di vista della telecamera di sorveglianza del monitor della sala pompe: sul muro sud (prima era sul soppalco)"),
        interattivi={o.name: dict(perno_blender=[round(v, 3) for v in o.location], perno_godot=a_godot(tuple(o.location)))
                     for o in GRUPPI.get('interattivi', []) if o.name in bpy.data.objects},
        luci=luci, acqua=acqua,
        camere={k: dict(pos_blender=list(v[0]), guarda_blender=list(v[1]), lente_mm=v[2]) for k, v in CAMERE.items()})


def dati_fossa_bimbi():
    """Marker della fossa della VascaBimbi1 (tappa 8), in coordinate Godot. medusa_sbuca segue la posa
    'affacciata' della vasca centrale: origine della posa, guarda verso +Z locale, coping 1,0 m sopra
    l'origine, pelo dell'acqua 0,88 m sopra, spigolo esterno del bordo 2,1 m davanti."""
    F = FOSSA_BIMBI
    interno, angolo, triangolo = fossa_bimbi_punti()
    r2 = math.sqrt(0.5)
    f = Vector((-r2, 0.0, r2))                                   # verso il giocatore: sud-ovest in Godot
    # spigolo esterno del bordo sull'angolo tagliato: metà della diagonale esterna (punti E e F dell'esagono)
    (ex, ey), (fx, fy) = angolo[4], angolo[5]
    spigolo = Vector(a_godot(((ex + fx) / 2, (ey + fy) / 2, F['h_bordo'])))
    (bx, by), (cx_, cy_) = angolo[1], angolo[2]
    interno_mid = Vector(a_godot(((bx + cx_) / 2, (by + cy_) / 2, F['h_bordo'])))
    origine = spigolo - f * 2.1
    origine.y = F['h_bordo'] - 1.0
    lungo = Vector(a_godot((cx_, cy_, 0))) - Vector(a_godot((bx, by, 0)))
    lungo.y = 0.0
    lungo.normalize()
    mani = [interno_mid + f * 0.15 + lungo * d for d in (-0.45, 0.45)]
    C = F['condotto']
    g3 = lambda v: [round(v[0], 3), round(v[1], 3), round(v[2], 3)]
    return dict(
        nota=("scarico di compensazione rotto attaccato al lato sud della VascaBimbi1: la parte profonda della vasca. "
              "Il bordo a scacchi (alto 0,45, largo 0,3) gira intorno alla fossa; l'angolo sud-ovest è tagliato a 45 gradi "
              "e lì la medusa appoggia le mani, rivolta verso chi arriva lungo il muro ovest. Pareti piastrellate fino a "
              "y -0,6, poi cemento grezzo; fondo a y -3,0; in fondo il condotto verso est; griglia divelta e piegata sul lato nord."),
        pianta_godot=[g3(a_godot((x, y, 0.0))) for x, y in interno],
        fondo_y=F['fondo'], fondo_vasca_y=0.02, cima_bordo_y=F['h_bordo'], piastrelle_fino_a_y=F['piastrelle'],
        coperchio=dict(nodo='coperchio_fossa_col', gruppo='sala_area_bimbi.glb',
                       nota="corpo di collisione invisibile a filo del fondo della vasca (y 0,02), sopra tutta la fossa: acceso il giocatore non ci cade"),
        medusa_sbuca=dict(posizione_godot=g3(origine), rotazione_gradi_godot=[0.0, -45.0, 0.0], guarda_verso_godot=g3(f),
                          spigolo_esterno_bordo_godot=g3(spigolo), spigolo_interno_bordo_godot=g3(interno_mid),
                          mani_godot=[g3(m) for m in mani], coping_y=F['h_bordo'], fondo_fossa_y=F['fondo'],
                          nota=("origine della posa 'affacciata' (come medusa_affacciata della vasca centrale): coping 1,0 m sopra, "
                                "spigolo esterno del bordo 2,1 m davanti; il pelo pieno è più alto di 9 cm rispetto alla posa (0,42 invece di 0,33)")),
        medusa_fuga=dict(posizione_godot=g3(a_godot((C['x_fine'], C['y'], C['z']))), bocca_godot=g3(a_godot((F['x1'], C['y'], C['z']))),
                         verso_godot=[1.0, 0.0, 0.0], raggio_condotto=C['r'],
                         nota="fondo del condotto (buio): da lì la luce della medusa si allontana verso est; la bocca è nella parete est della fossa"),
        livello_acqua_pieno=dict(y=F['acqua_piena'], nota="vasca e fossa riempite fino a 3 cm sotto il bordo (cima del bordo a y 0,45)",
                                 vasca_x=[-14.8, -10.4], vasca_z=[-11.2, -8.0], fossa=[g3(a_godot((x, y, 0.0))) for x, y in interno]),
    )


def esporta_luci(cartella, sorgenti, lampadina):
    """GLB con le luci puntiformi (KHR_lights_punctual): Godot crea Omni/Spot/Directional al posto
    giusto. Le intensità vanno regolate in Godot (le unità non coincidono)."""
    d = dati_integrazione(sorgenti, lampadina)
    obs = []
    for L in d['luci']:
        if L['nome'] == 'luce_luna':
            ld = bpy.data.lights.new(L['nome'], 'SUN'); ld.energy = 0.9
        elif L['nome'].startswith('luce_neon') or L['nome'] == 'luce_lampione':
            ld = bpy.data.lights.new(L['nome'], 'SPOT'); ld.energy = 60 if 'neon' in L['nome'] else 300
            ld.spot_size = math.radians(150 if 'neon' in L['nome'] else 110)
        elif L['nome'].startswith(('luce_faro', 'luce_monumento', 'luce_cartellone', 'luce_vasca')):
            ld = bpy.data.lights.new(L['nome'], 'SPOT'); ld.energy = 400 if 'faro' in L['nome'] else 80
            ld.spot_size = math.radians(24 if 'faro' in L['nome'] else (60 if 'cartellone' in L['nome'] else 46))
        else:
            ld = bpy.data.lights.new(L['nome'], 'POINT'); ld.energy = 26
        ld.color = L['colore']
        ob = bpy.data.objects.new(L['nome'], ld)
        bpy.context.scene.collection.objects.link(ob)
        if 'blender' in L:
            ob.location = L['blender']
        if 'direzione_blender' in L:
            ob.rotation_euler = Vector(L['direzione_blender']).to_track_quat('-Z', 'Y').to_euler()
        obs.append(ob)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(cartella, 'sala_luci.glb'), export_format='GLB', use_selection=True,
                              export_lights=True, export_yup=True, export_import_convert_lighting_mode='COMPAT')
    for o in obs:
        bpy.data.objects.remove(o, do_unlink=True)
    import json
    with open(os.path.join(cartella, 'sala_dati.json'), 'w') as f:
        json.dump(d, f, indent=1, ensure_ascii=False)
    print('luci e dati ->', cartella)


def controlla_corsa_portone():
    """Nomi degli oggetti con vertici nel volume che il portone della sala della torre attraversa aprendosi
    (davanti al muro est, da corsa_portone()[0] al varco, fino a sopra il binario). Deve essere vuoto."""
    c0, c1 = corsa_portone()
    vh = varco_torre()[2]
    lo, hi = Vector((X1 - 0.45, c0, 0.02)), Vector((X1 - 0.1, c1, vh + 0.5))
    propri = ('sala_portone_torre', 'sala_lampeggiante_torre', 'sala_pavimento', 'sala_pozzanghere')
    trovati = []
    for o in bpy.context.scene.objects:
        if o.type != 'MESH' or o.name.startswith(propri) or 'colonly' in o.name:
            continue
        mw = o.matrix_world
        if any(lo.x < p.x < hi.x and lo.y < p.y < hi.y and lo.z < p.z < hi.z for p in (mw @ v.co for v in o.data.vertices)):
            trovati.append(o.name)
    return trovati


def esporta_glb(cartella):
    """Un GLB per pezzo della sala, tutti con lo stesso riferimento (origine della sala): in Godot si
    istanziano tutti in (0, 0, 0). Collisioni come nodi '-colonly'/'-convcolonly' (Godot le converte)."""
    os.makedirs(cartella, exist_ok=True)
    nella_corsa = controlla_corsa_portone()
    if nella_corsa:
        print(f'ATTENZIONE: nella corsa del portone della sala della torre ci sono {nella_corsa}')
    for nome, obs in GRUPPI.items():
        obs = [o for o in obs if o.name in bpy.data.objects]
        if not obs:
            continue
        p = os.path.join(cartella, f'sala_{nome}.glb')
        sosp = controlla_collisioni(obs)
        if sosp:
            print(f'ATTENZIONE {nome}: {len(sosp)} collisioni lontane dalla geometria: {sosp[:8]}')
        K.esporta(obs, p)
        tri = sum(sum(len(pp.vertices) - 2 for pp in o.data.polygons) for o in obs if o.type == 'MESH')
        print(f'GLB {os.path.basename(p)}: {len(obs)} oggetti, {tri} triangoli, {os.path.getsize(p) / 1e6:.1f} MB')


def main():
    import argparse
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--render', default='', help='inquadrature separate da virgole (vedi CAMERE) o "tutte"')
    ap.add_argument('--uscita', default=os.path.join(tempfile.gettempdir(), 'ambiente_sala'))
    ap.add_argument('--larghezza', type=int, default=1600)
    ap.add_argument('--altezza', type=int, default=900)
    ap.add_argument('--campioni', type=int, default=64)
    ap.add_argument('--fili', type=int, default=3)
    ap.add_argument('--rapida', action='store_true', help='senza nebbia (prove veloci)')
    ap.add_argument('--senza-oggetti', action='store_true')
    ap.add_argument('--lampo', default='', help='inquadrature con il lampo acceso')
    ap.add_argument('--glb', default='')
    ap.add_argument('--blend', default='')
    ap.add_argument('--controlla', action='store_true', help='solo i controlli degli scivoli')
    ap.add_argument('--monumento', action='store_true', help='al centro il monumento della statua (per più avanti) invece della vasca')
    ap.add_argument('--medusa', default='', help='GLB della medusa da mettere come segnaposto nei render')
    a = ap.parse_args(argv)
    if a.monumento:
        CENTRO['modo'] = 'monumento'
    if a.controlla:
        controlla_scivoli()
        return
    mats, arch, copie, modelli, sorgenti, lampadina, zf = costruisci(con_oggetti=not a.senza_oggetti,
                                                                     per_render=not a.glb, con_corridoio=not a.glb)
    if a.glb:
        esporta_glb(a.glb)
        esporta_luci(a.glb, sorgenti, lampadina)
        if not a.render:
            return
    cielo_tempesta()
    if a.medusa:
        medusa_segnaposto(a.medusa)
    impostazioni(a.campioni, a.larghezza, a.altezza, a.fili)
    if not a.rapida:
        nebbia()
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
    viste = list(CAMERE) if a.render == 'tutte' else [v for v in a.render.split(',') if v]
    mesh = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.hide_render]
    tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in mesh)
    print(f'scena: {len(mesh)} oggetti visibili, {tri} triangoli, {len(bpy.data.materials)} materiali')
    lampi = set(a.lampo.split(','))
    os.makedirs(a.uscita, exist_ok=True)
    illumina(sorgenti, lampadina, lampo=False)
    for v in viste:
        lp = bpy.data.objects.get('lampo')
        if v in lampi and lp is None:
            f = luce('lampo', 'SUN', (0, 5, 30), 3.2, (0.72, 0.8, 1.0), angle=math.radians(6))
            f.rotation_euler = Vector((0.45, -0.55, -1.0)).to_track_quat('-Z', 'Y').to_euler()
        elif v not in lampi and lp is not None:
            bpy.data.objects.remove(lp, do_unlink=True)
        camera(v)
        out = os.path.abspath(os.path.join(a.uscita, f'sala_{v}.png'))
        bpy.context.scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        print('render ->', out)


if __name__ == '__main__':
    import ambiente_sala   # una sola copia del modulo (ambiente_dettagli la importa per le costanti)
    ambiente_sala.main()
