"""Sala principale dell'acquapark (capitolo 1, vertical slice): costruzione, luci, render, export.

Layout da docs/livello/capitolo1.md (mappa del percorso A): una sola grande sala sotto la cupola di
vetro. Coordinate in metri, Z in alto; +Y = prua (nord), +X = dritta (est).
  - sala: x -20..20, y -12..24; galleria a 4,0 m tutto intorno (profonda 3 m); soffitto a 11,5 m
  - cupola: centro (0, 5), raggio 13 m, chiave a 18 m
  - piscina a onde VUOTA: x -7..7, y -5..13; parte profonda (2 m) a sud, spiaggia a nord;
    pozza torbida sul fondo intorno allo scarico (0, -2)
  - piedistallo della statua: sul bordo sud, sopra la parte profonda (vedi PIEDISTALLO)
  - ingresso dagli spogliatoi: porta a doppia anta nella parete sud (x = 0)
  - area bimbi a nord-ovest (struttura di gioco con il secchio gigante, vasche basse a scacchi)
  - vasca d'arrivo a ovest (x -16..-9, y -7..3), dove finiscono gli scivoli
  - torre degli scivoli a nord-est (centro 13,5 / 17,5), tubi colorati lungo i bordi

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

RADICE = K.RADICE
OGGETTI = os.path.join(RADICE, 'assets_src', 'ambiente', 'oggetti')
PALETTE_SALA = 'sala_a'

# ----------------------------------------------------------------------------- misure della sala
X0, X1, Y0, Y1 = -20.0, 20.0, -12.0, 24.0
Z_GAL, SP_GAL, PROF_GAL = 4.0, 0.3, 3.0
Z_SOFF = 11.5
CUPOLA = dict(cx=0.0, cy=5.0, r=13.0, tamburo=1.0, freccia=5.5)
PISCINA = dict(x0=-7.0, x1=7.0, y0=-5.0, y1=13.0, prof=2.0, y_pendenza=1.0, scarico=(0.0, -2.0))
VASCA_ARRIVO = dict(x0=-16.0, x1=-9.0, y0=-7.0, y1=3.0, prof=1.1, acqua=-0.22)
# piedistallo della statua (vuoto: la medusa la mette il gruppo "medusa")
PIEDISTALLO = dict(cx=0.0, cy=-6.9, r_base=1.15, r_tamburo=1.0, r_piano=1.1, h=0.9)
STRUTTURA = dict(cx=-13.0, cy=16.0)
# vasche basse dell'area bimbi: (x0, y0, x1, y1) del bordo esterno
VASCHE_BASSE = [(-15.1, 7.7, -10.1, 11.5), (-17.0, 10.7, -13.6, 14.1)]
TORRE = dict(cx=13.5, cy=17.5, lato=6.0, piani=(3.0, 6.0, 8.6))
SPIRALE = dict(cx=8.6, cy=10.6, r=2.5)   # pennone dello scivolo a spirale


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
    """Unisce più oggetti (stessa scena) in uno solo; le collisioni figlie restano figlie."""
    oggetti = [o for o in oggetti if o is not None]
    if not oggetti:
        return None
    figli = []
    for o in oggetti:
        for ch in list(o.children):
            mw = ch.matrix_world.copy()
            ch.parent = None
            ch.matrix_world = mw
            figli.append(ch)
    bpy.ops.object.select_all(action='DESELECT')
    for o in oggetti:
        o.select_set(True)
    bpy.context.view_layer.objects.active = oggetti[0]
    if len(oggetti) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome
    ob.data.name = nome
    for ch in figli:
        mw = ch.matrix_world.copy()
        ch.parent = ob
        ch.matrix_parent_inverse = ob.matrix_world.inverted()
        ch.hide_render = True
    return ob


def rumore(x, y, s=1.0):
    """Rumore morbido deterministico (somma di seni) 0..1, per lo sporco dei vertici."""
    v = (math.sin(x * 0.37 * s + 1.3) * math.sin(y * 0.29 * s + 0.7) +
         0.5 * math.sin(x * 0.91 * s + y * 0.63 * s + 2.1) +
         0.25 * math.sin(x * 2.3 * s - y * 1.7 * s + 0.4))
    return 0.5 + 0.5 * v / 1.75


# ----------------------------------------------------------------------------- pavimenti e soffitti

def pavimento_regione(mats, x0, x1, y0, y1, buchi=(), passo=0.5, z=0.0, mat='pavimento', nome='sala_pavimento'):
    """Pavimento unico a celle di 'passo' metri, con buchi rettangolari (vasche). Colori dei vertici
    per lo sporco a grande scala (niente ripetizioni) e collisione trimesh con gli stessi buchi."""
    c = K.Costruttore(mats)
    nx, ny = int(round((x1 - x0) / passo)), int(round((y1 - y0) / passo))
    for i in range(nx):
        for j in range(ny):
            a, b = x0 + i * passo, y0 + j * passo
            cx, cy = a + passo / 2, b + passo / 2
            if any(bx0 < cx < bx1 and by0 < cy < by1 for bx0, by0, bx1, by1 in buchi):
                continue
            c.faccia([(a, b, z), (a + passo, b, z), (a + passo, b + passo, z), (a, b + passo, z)], mat)
    def sporco(co):
        n = rumore(co.x, co.y, 1.0)
        bordo = min(co.x - X0, X1 - co.x, co.y - Y0, Y1 - co.y)
        muro = 0.82 + 0.18 * min(1.0, bordo / 1.5)   # più sporco lungo i muri
        return max(0.35, min(1.0, (0.62 + 0.38 * n) * muro))
    ob = c.crea(nome, sporco=sporco)
    col = ob.copy()
    col.data = ob.data.copy()
    col.name = nome + '-colonly'
    bpy.context.scene.collection.objects.link(col)
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

def pareti(mats):
    """Pareti perimetrali: sotto (0-4 m, piastrelle + intonaco, oblò sui fianchi dello scafo) e sopra
    (4-10 m, intonaco grigio-verde, oblò sui fianchi). Porta degli spogliatoi a sud, al centro."""
    sotto, sopra, oblo = [], [], []
    H1, H2 = Z_GAL, Z_SOFF - Z_GAL
    # sud (y = -12), fronte verso +y: rotazione 180, il modulo va da T.x-2 a T.x
    for i in range(20):
        xa = X0 + 2 * i
        if abs(xa + 1.0) < 1e-6:  # modulo x -1..1: porta
            sotto.append(metti(K.parete_porta(mats, 2.0, H1, nome=f'ps_{i}'), (xa + 2, Y0, 0), 180))
        else:
            sotto.append(metti(K.parete(mats, 2.0, altezza=H1, nome=f'ps_{i}'), (xa + 2, Y0, 0), 180))
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, mat_alta='intonaco_alto', nome=f'pss_{i}'), (xa + 2, Y0, Z_GAL), 180))
    # nord (y = 24), fronte verso -y
    for i in range(20):
        xa = X0 + 2 * i
        sotto.append(metti(K.parete(mats, 2.0, altezza=H1, nome=f'pn_{i}'), (xa, Y1, 0)))
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, mat_alta='intonaco_alto', nome=f'pns_{i}'), (xa, Y1, Z_GAL)))
    # est (x = 20), fronte verso -x; ovest (x = -20), fronte verso +x: oblò a moduli alterni
    for i in range(18):
        yb = Y0 + 2 * i
        ob_s = (i % 2 == 1)
        ob_a = (i % 2 == 0)
        sotto.append(metti(K.parete(mats, 2.0, altezza=H1, oblo=ob_s, nome=f'pe_{i}'), (X1, yb + 2, 0), -90))
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, oblo=ob_a, oblo_z=2.2, mat_alta='intonaco_alto',
                                    nome=f'pes_{i}'), (X1, yb + 2, Z_GAL), -90))
        sotto.append(metti(K.parete(mats, 2.0, altezza=H1, oblo=ob_s, nome=f'po_{i}'), (X0, yb, 0), 90))
        sopra.append(metti(K.parete(mats, 2.0, alta=True, altezza=H2, oblo=ob_a, oblo_z=2.2, mat_alta='intonaco_alto',
                                    nome=f'pos_{i}'), (X0, yb, Z_GAL), 90))
        if ob_s:
            oblo.append(metti(K.oblo(mats, nome=f'oblo_e_{i}'), (X1, yb + 1, K.OBLO_Z), -90))
            oblo.append(metti(K.oblo(mats, nome=f'oblo_o_{i}'), (X0, yb + 1, K.OBLO_Z), 90))
        if ob_a:
            oblo.append(metti(K.oblo(mats, nome=f'obloa_e_{i}'), (X1, yb + 1, Z_GAL + 2.2), -90))
            oblo.append(metti(K.oblo(mats, nome=f'obloa_o_{i}'), (X0, yb + 1, Z_GAL + 2.2), 90))
    return [unisci(sotto, 'sala_pareti_basse'), unisci(sopra, 'sala_pareti_alte'), unisci(oblo, 'sala_obloi')]


def galleria(mats):
    """Balconata a 4 m tutto intorno, colonne sotto il bordo, ringhiera."""
    pezzi = []
    pezzi.append(metti(K.galleria_bordo(mats, 40.0, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_s'), (X1, Y0 + PROF_GAL, 0), 180))
    pezzi.append(metti(K.galleria_bordo(mats, 40.0, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_n'), (X0, Y1 - PROF_GAL, 0)))
    L = (Y1 - Y0) - 2 * PROF_GAL
    pezzi.append(metti(K.galleria_bordo(mats, L, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_e'), (X1 - PROF_GAL, Y1 - PROF_GAL, 0), -90))
    pezzi.append(metti(K.galleria_bordo(mats, L, PROF_GAL, z=Z_GAL, spessore=SP_GAL, nome='gal_o'), (X0 + PROF_GAL, Y0 + PROF_GAL, 0), 90))
    gal = unisci(pezzi, 'sala_galleria')
    col = []
    xi, yi = X1 - PROF_GAL, Y1 - PROF_GAL   # bordi interni: x = +-17, y = -9 / 21
    ys = Y0 + PROF_GAL
    punti_col = [(x, ys - 0.35) for x in (-15.0, -9.0, -3.0, 3.0, 9.0, 15.0)] + [(x, yi + 0.35) for x in (-15.0, -9.0, -3.0, 3.0, 9.0, 15.0)]
    punti_col += [(xi + 0.35, y) for y in (-3.0, 3.0, 9.0, 15.0)] + [(-xi - 0.35, y) for y in (-3.0, 3.0, 9.0, 15.0)]
    for (x, y) in punti_col:
        cc = K.colonna(mats, (x, y, 0), Z_GAL, raggio=0.2, nome=un('colonna'))
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
    for i in range(15):     # est e ovest, da y -9 a 21 (a est si apre dove arriva la scala, y 1..3)
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
    """Colature di ruggine e calcare sotto gli oblò alti e lungo il fronte della galleria (piani con
    alfa a 1 cm dal muro: in Godot si possono sostituire con nodi Decal)."""
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
    def colatura(centro, normale, w, h):
        cx_, cy_, zc = centro
        nx, ny = normale
        tx, ty = -ny, nx          # direzione orizzontale lungo il muro
        p = lambda a, b: (cx_ + nx * 0.012 + tx * a, cy_ + ny * 0.012 + ty * a, zc + b)
        q = [p(-w / 2, -h), p(w / 2, -h), p(w / 2, 0), p(-w / 2, 0)]
        uv = [(0, 0), (1, 0), (1, 1), (0, 1)]
        c.faccia(q, 'decal', uv=uv)
    # sotto gli oblò alti (est e ovest, z = 6,2)
    for i in range(18):
        yb = Y0 + 2 * i + 1
        if i % 2 == 0 and rnd.random() < 0.75:
            colatura((X1, yb, Z_GAL + 2.2 - 0.38), (-1, 0), rnd.uniform(0.7, 1.1), rnd.uniform(1.0, 1.8))
        if i % 2 == 0 and rnd.random() < 0.75:
            colatura((X0, yb, Z_GAL + 2.2 - 0.38), (1, 0), rnd.uniform(0.7, 1.1), rnd.uniform(1.0, 1.8))
    # sotto il bordo della galleria (fronte), qua e là
    for i in range(14):
        x = rnd.uniform(-16, 16)
        colatura((x, Y1 - PROF_GAL, Z_GAL - 0.12), (0, -1), rnd.uniform(1.0, 2.2), rnd.uniform(0.8, 1.6))
        x = rnd.uniform(-16, 16)
        colatura((x, Y0 + PROF_GAL, Z_GAL - 0.12), (0, 1), rnd.uniform(1.0, 2.2), rnd.uniform(0.8, 1.6))
    # muri bassi sotto la galleria, sopra le piastrelle
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
    4,3 m, con pianerottolo che entra nella galleria (lì la ringhiera è aperta)."""
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


# ----------------------------------------------------------------------------- cupola e cielo

def cupola(mats):
    """Cupola di vetro su tamburo: costoloni (meridiani), anelli, lastre (alcune rotte), oculo."""
    cx, cy, R0 = CUPOLA['cx'], CUPOLA['cy'], CUPOLA['r']
    zt = Z_SOFF + CUPOLA['tamburo']
    f = CUPOLA['freccia']
    Rs = (R0 * R0 + f * f) / (2 * f)            # raggio della sfera
    zc = zt + f - Rs                              # centro della sfera
    phi0 = math.asin(R0 / Rs)
    c = K.Costruttore(mats)
    # tamburo (cilindro interno ed esterno) con lesene
    seg = 96
    for k in range(seg):
        t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        p = lambda t, r, z: (cx + math.cos(t) * r, cy + math.sin(t) * r, z)
        c.faccia([p(t0, R0, Z_SOFF), p(t0, R0, zt), p(t1, R0, zt), p(t1, R0, Z_SOFF)], 'ferro_cupola')
    c.toro((cx, cy, Z_SOFF + 0.05), (0, 0, 1), R0 - 0.1, 0.0, 'ferro_cupola', seg=128, sezione=(0.35, 0.3))
    c.toro((cx, cy, zt), (0, 0, 1), R0 - 0.05, 0.0, 'ferro_cupola', seg=128, sezione=(0.45, 0.35))
    def P(phi, th):
        return Vector((cx + Rs * math.sin(phi) * math.cos(th), cy + Rs * math.sin(phi) * math.sin(th), zc + Rs * math.cos(phi)))
    nm, npar = 32, 7
    phis = [phi0 * (1 - j / npar) for j in range(npar + 1)]   # dal tamburo verso la chiave
    phi_ocu = math.asin(1.3 / Rs)
    phis[-1] = phi_ocu
    # costoloni
    for k in range(nm):
        th = 2 * math.pi * k / nm
        pts = [P(phi0 - (phi0 - phi_ocu) * i / 24, th) for i in range(25)]
        c.tubo(pts, 0.075, 'ferro_cupola', seg=8)
    # anelli
    for phi in phis[1:-1]:
        r = Rs * math.sin(phi)
        c.toro((cx, cy, zc + Rs * math.cos(phi)), (0, 0, 1), r, 0.055, 'ferro_cupola', seg=128, seg_r=6)
    c.toro((cx, cy, zc + Rs * math.cos(phi_ocu)), (0, 0, 1), 1.3, 0.12, 'ferro_cupola', seg=48, seg_r=8)
    ob_ferro = c.crea('sala_cupola_ferro')
    # lastre di vetro (alcune mancanti)
    v = K.Costruttore(mats)
    rotte = {(3, 2), (11, 4), (12, 4), (20, 1), (27, 5)}
    for k in range(nm):
        for j in range(npar):
            if (k, j) in rotte:
                continue
            th0, th1 = 2 * math.pi * k / nm, 2 * math.pi * (k + 1) / nm
            a, b = phis[j], phis[j + 1]
            q = [P(a, th0), P(a, th1), P(b, th1), P(b, th0)]
            v.faccia(q, 'vetro_cupola', uv=[(0, 0), (1, 0), (1, 1), (0, 1)], liscia=True)
    v.disco((cx, cy, zc + Rs * math.cos(phi_ocu) + 0.02), (0, 0, 1), 1.3, 'vetro_cupola', seg=24)
    ob_vetro = v.crea('sala_cupola_vetro')
    ob_vetro.visible_shadow = True
    return [ob_ferro, ob_vetro]


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
    for i in range(nx):
        for j in range(ny):
            a, b = x0 + i * passo, y0 + j * passo
            q = [(a, b), (a + passo, b), (a + passo, b + passo), (a, b + passo)]
            c.faccia([(x, y, zf(x, y)) for x, y in q], 'vasca', liscia=True)
    # pareti (seguono il fondo): sud (normale +y), est (-x), ovest (+x)
    for i in range(nx):
        a, b = x0 + i * passo, x0 + (i + 1) * passo
        c.faccia([(a, y0, -0.04), (b, y0, -0.04), (b, y0, zf(b, y0)), (a, y0, zf(a, y0))], 'vasca')
    for j in range(ny):
        a, b = y0 + j * passo, y0 + (j + 1) * passo
        if zf(x1, a) < -0.045 or zf(x1, b) < -0.045:
            c.faccia([(x1, a, -0.04), (x1, b, -0.04), (x1, b, min(-0.04, zf(x1, b))), (x1, a, min(-0.04, zf(x1, a)))], 'vasca')
            c.faccia([(x0, b, -0.04), (x0, a, -0.04), (x0, a, min(-0.04, zf(x0, a))), (x0, b, min(-0.04, zf(x0, b)))], 'vasca')
    def sporco(co):
        prof = max(0.0, -co.z) / H
        return max(0.4, min(1.0, 0.95 - 0.3 * prof + 0.15 * (rumore(co.x, co.y, 1.7) - 0.5)))
    vasca = c.crea('sala_piscina_onde', sporco=sporco)
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
    zp = zf(sx, sy)
    g.anello((sx, sy, zp - 0.01), (0, 0, 1), 0.0, 0.62, 0.05, 'torre', seg=40)
    g.toro((sx, sy, zp + 0.05), (0, 0, 1), 0.5, 0.025, 'torre', seg=40, seg_r=6)
    for k in range(10):
        t = 2 * math.pi * k / 10
        g.cilindro((sx + math.cos(t) * 0.56, sy + math.sin(t) * 0.56, zp + 0.03), (sx + math.cos(t) * 0.56, sy + math.sin(t) * 0.56, zp + 0.06), 0.02, 'inox', seg=6)
    g.cilindro((sx - 0.25, sy, zp + 0.06), (sx + 0.25, sy, zp + 0.06), 0.025, 'inox', seg=8)
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


def vasca_bassa(mats, cx, cy, lx, ly, nome, acqua=0.3):
    """Vasca bassa dell'area bimbi: bordo rialzato 0,45 m a scacchi blu e bianchi (come nello
    storyboard S09), fondo azzurro, acqua che sale."""
    c = K.Costruttore(mats)
    h, s = 0.45, 0.3
    x0, x1, y0, y1 = cx - lx / 2, cx + lx / 2, cy - ly / 2, cy + ly / 2
    # anello del bordo come 4 scatole
    for (a0, b0, a1, b1) in ((x0 - s, y0 - s, x1 + s, y0), (x0 - s, y1, x1 + s, y1 + s), (x0 - s, y0, x0, y1), (x1, y0, x1 + s, y1)):
        c.scatola((a0, b0, 0), (a1, b1, h), 'scacchi', senza=('-z',))
    c.faccia([(x0, y0, 0.02), (x1, y0, 0.02), (x1, y1, 0.02), (x0, y1, 0.02)], 'vasca_bimbi')
    ob = c.crea(nome, sporco=lambda co: 0.85 if co.z < 0.1 else 1.0)
    for i, (a0, b0, a1, b1) in enumerate(((x0 - s, y0 - s, x1 + s, y0), (x0 - s, y1, x1 + s, y1 + s), (x0 - s, y0, x0, y1), (x1, y0, x1 + s, y1))):
        K.collisione_scatola(f'{nome}_{i}', (a0, b0, 0), (a1, b1, h), padre=ob)
    acq = acqua_piana(nome + '_acqua', x0, x1, y0, y1, acqua)
    return [ob, acq]


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

def piedistallo(mats):
    """Piedistallo rotondo della statua, VUOTO. Zoccolo, tamburo a mosaico blu con onde, piano in
    ceramica, grosso pulsante per i bambini sul davanti (verso l'ingresso, -y)."""
    P = PIEDISTALLO
    c = K.Costruttore(mats)
    cx, cy = P['cx'], P['cy']
    seg = 48
    def cil(r, z0, z1, mat, tappo=True):
        for k in range(seg):
            t0, t1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
            q = [(cx + math.cos(t0) * r, cy + math.sin(t0) * r, z0), (cx + math.cos(t1) * r, cy + math.sin(t1) * r, z0),
                 (cx + math.cos(t1) * r, cy + math.sin(t1) * r, z1), (cx + math.cos(t0) * r, cy + math.sin(t0) * r, z1)]
            lt = mats.lato(mat)
            uv = [(2 * math.pi * r * k / seg / lt, z0 / lt), (2 * math.pi * r * (k + 1) / seg / lt, z0 / lt),
                  (2 * math.pi * r * (k + 1) / seg / lt, z1 / lt), (2 * math.pi * r * k / seg / lt, z1 / lt)]
            c.faccia(q, mat, uv=uv, liscia=True)
        if tappo:
            c.faccia([(cx + math.cos(2 * math.pi * k / seg) * r, cy + math.sin(2 * math.pi * k / seg) * r, z1) for k in range(seg)], mat)
    cil(P['r_base'], 0.0, 0.14, 'bordo')
    cil(P['r_tamburo'], 0.14, P['h'] - 0.12, 'piedistallo', tappo=False)
    cil(P['r_piano'], P['h'] - 0.12, P['h'], 'bordo')
    # pulsante: scatola gialla con fungo rosso, verso l'ingresso
    by = cy - P['r_tamburo']
    c.scatola((cx - 0.18, by - 0.12, 0.32), (cx + 0.18, by + 0.05, 0.62), 'gioco_giallo')
    c.cilindro((cx, by - 0.12, 0.47), (cx, by - 0.2, 0.47), 0.11, 'gioco_rosso', seg=20)
    ob = c.crea('amb_piedistallo', sporco=lambda co: 0.75 + 0.25 * min(1.0, co.z / 0.5))
    col = K.collisione_scatola('amb_piedistallo', (cx - P['r_base'], cy - P['r_base'], 0), (cx + P['r_base'], cy + P['r_base'], P['h']), padre=ob)
    return ob


def lampione(mats, base, nome='amb_lampione'):
    """Lampione su palo accanto al piedistallo (storyboard S04): palo in ghisa, braccio curvo,
    paralume industriale con lampadina calda. Restituisce (oggetto, posizione della lampadina)."""
    b = Vector(base)
    c = K.Costruttore(mats)
    H = 4.3
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

def struttura_gioco(mats):
    """Struttura di gioco a più piani con il secchio gigante in cima (area bimbi, nord-ovest)."""
    cx, cy = STRUTTURA['cx'], STRUTTURA['cy']
    c = K.Costruttore(mats)
    torri = [((-2.6, -1.2), 1.4, 'gioco_verde'), ((0.2, -1.2), 2.6, 'gioco_arancio'),
             ((0.2, 1.6), 3.8, None), ((-2.6, 1.6), 2.6, 'gioco_rosso')]
    L = 2.4
    def post(x, y, z1, mat='gioco_blu', r=0.06):
        c.cilindro((x, y, 0), (x, y, z1), r, mat, seg=10)
        c.anello((x, y, 0), (0, 0, 1), 0.0, r + 0.06, 0.02, mat, seg=10)
    for (ox, oy), zp, tetto in torri:
        x0, y0 = cx + ox - L / 2, cy + oy - L / 2
        x1, y1 = x0 + L, y0 + L
        hpost = zp + (2.0 if tetto else 1.1)
        for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
            post(px, py, hpost)
        # pedana
        c.scatola((x0, y0, zp - 0.08), (x1, y1, zp), 'gioco_giallo')
        # parapetti a tubi su tre lati, con pannelli
        for (a, b) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x0, y1), (x0, y0))):
            for zz in (zp + 0.5, zp + 0.95):
                c.cilindro((a[0], a[1], zz), (b[0], b[1], zz), 0.035, 'gioco_rosso', seg=8, tappi=False)
            n = 8
            for k in range(1, n):
                px = a[0] + (b[0] - a[0]) * k / n; py = a[1] + (b[1] - a[1]) * k / n
                c.cilindro((px, py, zp), (px, py, zp + 0.95), 0.016, 'gioco_blu', seg=6, tappi=False)
        if tetto:  # tetto a piramide
            ztop = hpost
            apice = (cx + ox, cy + oy, ztop + 1.0)
            bordo = [(x0 - 0.25, y0 - 0.25, ztop), (x1 + 0.25, y0 - 0.25, ztop), (x1 + 0.25, y1 + 0.25, ztop), (x0 - 0.25, y1 + 0.25, ztop)]
            for i in range(4):
                c.faccia([bordo[i], bordo[(i + 1) % 4], apice], tetto)
                c.faccia([bordo[(i + 1) % 4], bordo[i], apice], tetto)
    # passerelle tra le torri e scalette
    c.scatola((cx - 1.4, cy - 1.7, 1.32), (cx - 1.0, cy - 0.7, 1.4), 'gioco_giallo')
    for k in range(9):  # scala dal pavimento alla prima torre (lato sud)
        z = 0.16 * (k + 1)
        y = cy - 2.4 - 0.28 * (9 - k)
        c.scatola((cx - 3.3, y, z - 0.05), (cx - 1.9, y + 0.28, z), 'gioco_giallo')
    for x in (cx - 3.3, cx - 1.9):
        c.cilindro((x, cy - 2.4 - 0.28 * 9, 0.9), (x, cy - 2.4, 2.4), 0.035, 'gioco_rosso', seg=8)
    c.scatola((cx - 1.4, cy + 1.2, 2.52), (cx - 1.0, cy + 2.0, 2.6), 'gioco_giallo')
    # ponte sospeso tra la torre 2 e la torre 3 (assi)
    for k in range(7):
        y = cy - 0.0 + 0.2 * k - 0.6
        c.scatola((cx - 0.6, y, 3.0 + 0.12 * k), (cx + 1.0, y + 0.14, 3.06 + 0.12 * k), 'gioco_giallo')
    # scivolo aperto dalla torre 2 verso est (mezza canna)
    pts = []
    for k in range(17):
        t = k / 16
        pts.append(Vector((cx + 1.6 + 3.2 * t, cy - 1.2 - 0.6 * math.sin(t * math.pi), 2.6 * (1 - t) ** 1.3 + 0.25)))
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = (b - a).normalized(); side = d.cross(Vector((0, 0, 1))).normalized()
        for j in range(8):
            t0, t1 = math.pi * j / 8, math.pi * (j + 1) / 8
            def q(p, t):
                return p + side * math.cos(t) * 0.42 - Vector((0, 0, 1)) * math.sin(t) * 0.3
            c.faccia([q(a, t0), q(b, t0), q(b, t1), q(a, t1)], 'gioco_giallo', liscia=True)
            c.faccia([q(a, t1), q(b, t1), q(b, t0), q(a, t0)], 'gioco_giallo', liscia=True)
    # telaio del secchio gigante sopra la torre 3
    tx, ty = cx + 0.2, cy + 1.6
    for (px, py) in ((tx - 1.5, ty - 1.55), (tx + 1.5, ty - 1.55), (tx + 1.5, ty + 1.55), (tx - 1.5, ty + 1.55)):
        c.cilindro((px, py, 3.8), (px, py, 7.4), 0.08, 'torre', seg=10)
    for py in (ty - 1.55, ty + 1.55):
        c.cilindro((tx - 1.5, py, 5.6), (tx + 1.5, py, 5.6), 0.05, 'torre', seg=8)
    for px in (tx - 1.5, tx + 1.5):
        c.cilindro((px, ty - 1.55, 7.4), (px, ty + 1.55, 7.4), 0.07, 'torre', seg=10)
        c.cilindro((px, ty - 1.55, 5.6), (px, ty + 1.55, 7.3), 0.05, 'torre', seg=8)
    c.cilindro((tx - 1.6, ty, 7.1), (tx + 1.6, ty, 7.1), 0.06, 'inox', seg=10)
    # tubo dell'acqua che sale al secchio
    c.tubo([(tx + 1.9, ty + 1.0, 0.0), (tx + 1.9, ty + 1.0, 6.6), (tx + 1.6, ty + 0.4, 7.6), (tx + 0.6, ty + 0.1, 8.2)], 0.07, 'gioco_blu', seg=10)
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
    # ruota a pale (oggetto a parte, perno sull'asse x: la fa girare il getto)
    r = K.Costruttore(mats)
    r.toro((0, 0, 0), (1, 0, 0), 0.85, 0.035, 'gioco_rosso', seg=32, seg_r=6)
    r.toro((0.3, 0, 0), (1, 0, 0), 0.85, 0.035, 'gioco_rosso', seg=32, seg_r=6)
    r.cilindro((-0.1, 0, 0), (0.55, 0, 0), 0.06, 'inox', seg=10)
    for k in range(10):
        t = 2 * math.pi * k / 10
        dy, dz = math.cos(t), math.sin(t)
        pal = [Vector((0.0, dy * 0.2, dz * 0.2)), Vector((0.3, dy * 0.2, dz * 0.2)), Vector((0.0, dy * 0.85, dz * 0.85)), Vector((0.3, dy * 0.85, dz * 0.85))]
        n_ = Vector((0, -dz, dy)) * 0.02
        q = [pal[0] - n_, pal[1] - n_, pal[3] - n_, pal[2] - n_]
        r.faccia(q, 'gioco_giallo'); r.faccia(q[::-1], 'gioco_giallo')
        r.cilindro((0.15, dy * 0.06, dz * 0.06), (0.15, dy * 0.82, dz * 0.82), 0.025, 'gioco_rosso', seg=6, tappi=False)
    ruota = r.crea('sala_ruota_pale')
    ruota.location = (cx - 4.2, cy - 1.2, 1.3)
    K.collisione_scatola('ruota_pale', (-0.1, -0.9, -0.9), (0.4, 0.9, 0.9), padre=ruota)
    ruota.children[0].hide_render = True
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
    secchio.location = (tx, ty, 7.1)
    secchio.rotation_euler = Euler((math.radians(-14), 0, 0))
    K.collisione_scatola('secchio', (-1.2, -1.2, -0.85), (1.2, 1.2, 0.65), padre=secchio)
    secchio.children[0].hide_render = True
    return [ob, secchio, ruota]


# ----------------------------------------------------------------------------- torre degli scivoli

def torre_scivoli(mats):
    """Impalcatura di acciaio arrugginito: 4 colonne, pozzo centrale aperto, piattaforme a grigliato
    a 3, 6 e 8,6 m, controventi a croce, scale a rampe sul lato est, parapetti."""
    T = TORRE
    cx, cy, Lt = T['cx'], T['cy'], T['lato']
    x0, x1, y0, y1 = cx - Lt / 2, cx + Lt / 2, cy - Lt / 2, cy + Lt / 2
    c = K.Costruttore(mats)
    g = K.Costruttore(mats)   # grigliati (materiale con alfa)
    Hc = T['piani'][-1] + 1.15
    for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        c.scatola((px - 0.12, py - 0.12, 0), (px + 0.12, py + 0.12, Hc), 'torre')
        c.scatola((px - 0.25, py - 0.25, 0), (px + 0.25, py + 0.25, 0.04), 'torre')
    sx0, sx1, sy0, sy1 = cx - 1.1, cx + 1.1, cy - 1.1, cy + 1.1   # pozzo centrale
    livelli = [0.0] + list(T['piani'])
    for z in T['piani']:
        # travi di bordo
        for (a, b) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
            lo = (min(a[0], b[0]) - 0.1, min(a[1], b[1]) - 0.1, z - 0.3)
            hi = (max(a[0], b[0]) + 0.1, max(a[1], b[1]) + 0.1, z - 0.02)
            c.scatola(lo, hi, 'torre')
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
    # spirale intorno al pennone in (8,6 / 10,6)
    sx, sy, R = SPIRALE['cx'], SPIRALE['cy'], SPIRALE['r']
    p2 = [(10.9, 14.9, zt + 0.55), (10.6, 13.6, zt + 0.25)]
    a0, a1 = math.radians(60), math.radians(60 - 540)
    n = 19
    for k in range(n):
        t = k / (n - 1)
        a = a0 + (a1 - a0) * t
        p2.append((sx + math.cos(a) * R, sy + math.sin(a) * R, zt - 0.2 - 3.8 * t))
    p2 += [(4.6, 7.4, 4.35), (0.0, 3.6, 3.8), (-4.6, 0.0, 3.15), (-7.6, -2.2, 2.2), (-8.9, -3.0, 1.3),
           (-9.9, -3.4, 0.55), (-10.9, -3.6, 0.2)]
    return [('scivolo_grande', p1, ['scivolo_b'] * 5 + ['scivolo_d'] + ['scivolo_b'] * 3 + ['scivolo']),
            ('scivolo_spirale', p2, ['scivolo'] * 6 + ['scivolo_d'] + ['scivolo'] * 4 + ['scivolo_c']),
            ('scivolo_medio', p3, ['scivolo_c'] * 4 + ['scivolo_d'] + ['scivolo_c'] * 5)]


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
    tubi = [(n, campiona(p)) for n, p, _ in percorsi_scivoli()]
    for i in range(len(tubi)):
        for j in range(i + 1, len(tubi)):
            d = min((a - b).length for a in tubi[i][1][::2] for b in tubi[j][1][::2])
            print(f'distanza {tubi[i][0]} - {tubi[j][0]}: {d:.2f} m (serve > 1,15)')
    for n, Q in tubi:
        alto = max(q.z for q in Q)
        gal = [q for q in Q if (q.x > X1 - PROF_GAL - 0.6 or q.x < X0 + PROF_GAL + 0.6 or q.y > Y1 - PROF_GAL - 0.6
                                or q.y < Y0 + PROF_GAL + 0.6) and Z_GAL - 0.6 < q.z < Z_GAL + SP_GAL + 1.05 + 0.6]
        print(f'{n}: quota massima {alto:.2f} (soffitto {Z_SOFF}), punti sopra la galleria in conflitto: {len(gal)}')


def scivoli(mats, zf_piscina):
    obs = []
    sostegni = []
    for nome, pts, seq in percorsi_scivoli():
        tubo = K.tubo_scivolo(mats, pts, nome='sala_' + nome, materiali=seq)
        obs.append(tubo)
        # collisione semplificata: tratti convessi di circa 2 m intorno al tubo
        Q = campiona(pts, 0.5)
        for i in range(0, len(Q) - 1, 4):
            a, b = Q[i], Q[min(i + 4, len(Q) - 1)]
            d = (b - a).normalized()
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            u = (ref - d * ref.dot(d)).normalized(); v = d.cross(u)
            R_ = K.SCIVOLO_R + 0.03
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
                col_ = K.colonna(mats, (q.x, q.y, zb), q.z - K.SCIVOLO_R - 0.03 - zb, raggio=0.11, nome=un('sost'))
                K.collisione_scatola(col_.name, (q.x - 0.12, q.y - 0.12, zb), (q.x + 0.12, q.y + 0.12, q.z - K.SCIVOLO_R), padre=col_)
                sostegni.append(col_)
            dist += L
    # pennone della spirale con i bracci
    pen = K.colonna(mats, (SPIRALE['cx'], SPIRALE['cy'], 0.0), TORRE['piani'][-1] + 0.4, raggio=0.2, nome='pennone')
    K.collisione_scatola('pennone', (SPIRALE['cx'] - 0.22, SPIRALE['cy'] - 0.22, 0), (SPIRALE['cx'] + 0.22, SPIRALE['cy'] + 0.22, TORRE['piani'][-1] + 0.4), padre=pen)
    sostegni.append(pen)
    pts2 = dict((n, p) for n, p, _ in percorsi_scivoli())['scivolo_spirale']
    for q in campiona(pts2)[8:-30:14]:
        if math.hypot(q.x - SPIRALE['cx'], q.y - SPIRALE['cy']) < SPIRALE['r'] + 0.3:
            d = (Vector((q.x, q.y, 0)) - Vector((SPIRALE['cx'], SPIRALE['cy'], 0))).normalized()
            a = Vector((SPIRALE['cx'], SPIRALE['cy'], q.z - K.SCIVOLO_R - 0.05)) + d * 0.2
            b = Vector((q.x, q.y, q.z - K.SCIVOLO_R - 0.05)) - d * 0.1
            c = K.Costruttore(mats)
            c.cilindro(a, b, 0.06, 'metallo', seg=8)
            sostegni.append(c.crea('braccio'))
    obs.append(unisci(sostegni, 'sala_sostegni_scivoli'))
    return obs


# ----------------------------------------------------------------------------- arredi dell'architettura

def cartelloni(mats):
    """Cartelloni disegnati (nessuna scritta) appesi alle ringhiere della galleria."""
    obs = []
    zr = Z_GAL + SP_GAL - 0.15
    for i, (x, chiave) in enumerate(((-9.0, 'p1'), (-1.5, 'p2'), (6.0, 'p3'))):
        ob = K.cartellone(mats, 3.2, 1.8, nome=f'sala_cartellone_n{i}')
        obs.append(metti(ob, (x, Y1 - PROF_GAL - 0.06, zr)))
    for i, (y, chiave) in enumerate(((-4.0, 'p2'), (10.0, 'p1'))):   # non davanti alla scala (y 1..3)
        ob = K.cartellone(mats, 3.2, 1.8, nome=f'sala_cartellone_e{i}')
        obs.append(metti(ob, (X1 - PROF_GAL - 0.06, y, zr), -90))
    ob = K.cartellone(mats, 3.2, 1.8, nome='sala_cartellone_s0')
    obs.append(metti(ob, (-8.0, Y0 + PROF_GAL + 0.06, zr), 180))
    # ogni cartellone con la sua grafica
    grafiche = ['p1', 'p2', 'p3', 'p2', 'p1', 'p3']
    for ob, g in zip(obs, grafiche):
        for i, m in enumerate(ob.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                ob.data.materials[i] = mats.get('cartellone_' + g)
    return obs


def lampade(mats):
    """Plafoniere al neon sotto la galleria (accese, spente o a metà) e luci d'emergenza rosse.
    Restituisce gli oggetti e l'elenco delle sorgenti (tipo, posizione, ...) per le luci."""
    obs, sorgenti = [], []
    zl = Z_GAL - 0.12  # sotto la veletta del fronte
    import random
    rnd = random.Random(11)
    stati = []
    # lato est e ovest: plafoniere orientate lungo y; nord e sud lungo x
    for y in range(-8, 21, 4):
        stati.append(((X1 - 1.5, y + 0.0, zl), 90))
        stati.append(((X0 + 1.5, y + 0.0, zl), 90))
    for x in range(-16, 17, 4):
        if abs(x) < 1:
            continue
        stati.append(((x + 0.0, Y0 + 1.5, zl), 0))
        stati.append(((x + 0.0, Y1 - 1.5, zl), 0))
    for i, (pos, rot) in enumerate(stati):
        r = rnd.random()
        acc = (True, True) if r < 0.5 else ((True, False) if r < 0.75 else (False, False))
        obs.append(metti(K.lampada_neon(mats, accesa=acc, nome=f'neon_{i}'), pos, rot))
        if acc[0]:
            sorgenti.append(('neon', pos, rot, 1.0 if acc[1] else 0.45))
    # luci d'emergenza rosse sulle pareti (sotto e sopra la galleria)
    emerg = [((X1, -6.0, 2.9), -90), ((X1, 6.0, 2.9), -90), ((X1, 18.0, 2.9), -90),
             ((X0, -4.0, 2.9), 90), ((X0, 8.0, 2.9), 90), ((X0, 20.0, 2.9), 90),
             ((-6.0, Y1, 2.9), 0), ((8.0, Y1, 2.9), 0), ((-5.0, Y0, 2.9), 180), ((5.0, Y0, 2.9), 180),
             ((X1, 0.0, 8.6), -90), ((X0, 12.0, 8.6), 90), ((-12.0, Y1, 8.6), 0), ((12.0, Y0, 8.6), 180),
             ((2.0, Y1, 8.6), 0), ((X1, 14.0, 8.6), -90), ((X0, -6.0, 8.6), 90)]
    for i, (pos, rot) in enumerate(emerg):
        obs.append(metti(K.luce_emergenza(mats, nome=f'emerg_{i}'), pos, rot))
        d = Vector((0, -0.12, 0))
        d.rotate(Euler((0, 0, math.radians(rot))))
        sorgenti.append(('rossa', tuple(Vector(pos) + d), rot, 1.0))
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

def importa_oggetto(nome):
    """Importa un GLB di Meshy una volta sola e lo porta a misura (pivot alla base, al centro).
    Restituisce un oggetto modello da duplicare (dati condivisi = istanze nel GLB)."""
    sys.path.insert(0, OGGETTI)
    from meshy_oggetti import MISURE  # noqa: E402
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OGGETTI, nome, nome + '_meshy.glb'))
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
    # texture per il gioco: 1K per gli oggetti piccoli, 2K per i grandi (sempre JPG)
    lato_max = 2048 if misura >= 1.5 else 1024
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


def disponi_oggetti(zf_piscina):
    """Oggetti di scena messi in modo credibile (lasciati lì, spostati dall'acqua, ammucchiati)."""
    modelli = {}
    def mod(n):
        if n not in modelli:
            modelli[n] = importa_oggetto(n)
        return modelli[n]
    copie = []
    def metti_ogg(n, pos, rot=0.0, scala=1.0, incl=(0.0, 0.0)):
        m = mod(n)
        o = m.copy()
        o.hide_render = False; o.hide_viewport = False
        bpy.context.scene.collection.objects.link(o)
        x, y, z = pos
        if z is None:
            z = 0.0
            if PISCINA['x0'] < x < PISCINA['x1'] and PISCINA['y0'] < y < PISCINA['y1']:
                z = zf_piscina(x, y)
        o.location = (x, y, z)
        o.rotation_euler = Euler((math.radians(incl[0]), math.radians(incl[1]), math.radians(rot)))
        o.scale = (scala, scala, scala)
        o.name = f'ogg_{n}_{len(copie)}'
        # collisione: scatola sui limiti del modello (figlia, segue posizione/rotazione/scala)
        me = m.data
        xs = [v.co.x for v in me.vertices]; ys_ = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        cb = K.collisione_scatola(o.name, (min(xs), min(ys_), min(zs)), (max(xs), max(ys_), max(zs)), padre=o)
        cb.hide_render = True
        copie.append(o)
        return o
    # --- fondo della piscina e pozza (S06): giocattoli trascinati verso lo scarico
    metti_ogg('paperella_gigante', (0.9, -1.4, None), 40, 0.45, (8, 0))
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
    metti_ogg('salvagente_nave', (19.75, -7.6, 1.15), -90, 1.0, (90, 0))
    metti_ogg('salvagente_nave', (19.75, 4.0, 1.15), -90, 1.0, (88, 0))
    metti_ogg('salvagente_nave', (-19.75, -1.0, 1.15), 90, 1.0, (88, 0))
    metti_ogg('salvagente_nave', (-19.75, 11.0, 1.15), 90, 1.0, (92, 0))
    metti_ogg('salvagente_nave', (-3.2, Y0 + 0.25, 1.25), 180, 1.0, (90, 0))
    # --- bordo piscina: sedia del bagnino, lettini in fila (uno rovesciato)
    metti_ogg('sedia_bagnino', (8.6, 2.5, 0.0), -90)
    for i, y in enumerate((-3.5, -1.2, 5.6, 8.0)):
        incl = (0, 0) if i != 2 else (0, 85)
        metti_ogg('lettino_plastica', (11.8, y, 0.0 if i != 2 else 0.3), 180 + (6 if i % 2 else -4), 1.0, incl)
    metti_ogg('lettino_plastica', (-6.0, -8.2, 0.0), 75)
    # --- area bimbi: balena sgonfia nella vasca bassa, funghi, cannoncini, paperelle
    metti_ogg('balena_gonfiabile_sgonfia', (-15.0, 12.1, 0.33), 140, 0.95)
    metti_ogg('fungo_fontana', (-10.4, 12.4, 0.0), 20, 1.0)
    metti_ogg('fungo_fontana', (-9.4, 9.8, 0.0), 75, 0.75)
    metti_ogg('cannoncino_acqua', (-12.0, 13.9, 2.6), 160, 0.85)
    metti_ogg('cannoncino_acqua', (-14.0, 14.0, 1.4), 200, 0.85)
    metti_ogg('cannoncino_acqua', (-10.8, 5.6, 0.0), 120, 1.0)
    metti_ogg('paperella_gigante', (-11.6, 8.0, 0.30), 210, 0.4)
    metti_ogg('pallone_spiaggia', (-13.1, 8.9, 0.30), 0, 0.85)
    metti_ogg('paperella_gigante', (-9.0, 13.6, 0.0), 160, 1.0)
    metti_ogg('orsacchiotto_grande', (-17.3, 18.8, 0.0), 60, 0.8, (0, -10))
    # --- altri giocattoli sparsi (la sala è grande: nel concept è piena di roba lasciata lì)
    import random
    rnd = random.Random(31)
    sparsi = [('pallone_spiaggia', 1.0), ('ciambella_gonfiabile', 0.95), ('paperella_gigante', 0.4),
              ('tubi_galleggianti', 1.0), ('pallone_spiaggia', 0.8), ('paperella_gigante', 0.3)]
    zone = [(-6.5, 6.5, -4.6, 12.6, None), (8.6, 16.6, -8.0, 12.0, 0.0), (-8.4, -7.8, -8.0, 6.0, 0.0),
            (-16.5, -9.5, 4.5, 6.0, 0.0), (-6.0, 6.0, -11.5, -9.6, 0.0), (-6.0, 6.0, 14.0, 20.5, 0.0)]
    vietati = [(PIEDISTALLO['cx'] - 1.6, PIEDISTALLO['cy'] - 1.6, PIEDISTALLO['cx'] + 1.6, PIEDISTALLO['cy'] + 1.6),
               (SPIRALE['cx'] - 0.6, SPIRALE['cy'] - 0.6, SPIRALE['cx'] + 0.6, SPIRALE['cy'] + 0.6),
               (15.5, 2.8, 17.1, 9.8)]
    for i in range(30):
        n_, sc_ = sparsi[i % len(sparsi)]
        x0_, x1_, y0_, y1_, z_ = zone[i % len(zone)]
        for _ in range(20):
            x, y = rnd.uniform(x0_, x1_), rnd.uniform(y0_, y1_)
            if not any(a < x < c_ and b < y < d for a, b, c_, d in vietati):
                break
        metti_ogg(n_, (x, y, z_), rnd.uniform(0, 360), sc_ * rnd.uniform(0.85, 1.1), (rnd.uniform(-8, 8), rnd.uniform(-8, 8)))
    for (x, y, r_) in ((-6.0, -10.3, 100), (6.0, -10.4, 80), (-11.0, 19.0, 190)):
        metti_ogg('lettino_plastica', (x, y, 0.0), r_)
    # --- vasca d'arrivo: galleggianti
    metti_ogg('ciambella_gonfiabile', (-12.4, -3.0, VASCA_ARRIVO['acqua'] - 0.05), 40, 1.0)
    metti_ogg('tubi_galleggianti', (-14.2, -0.8, VASCA_ARRIVO['acqua'] - 0.02), 15)
    metti_ogg('pallone_spiaggia', (-10.2, -5.4, VASCA_ARRIVO['acqua'] - 0.12), 0, 0.9)
    return copie, list(modelli.values())


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
    for tipo, pos, rot, k in sorgenti:
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
    'S04_statua': ((0.35, -11.4, 1.65), (0.0, -3.0, 2.55), 18.0),
    'S06_pozza': ((5.6, -6.9, 1.9), (-0.6, -0.4, -1.1), 18.0),
    'S08_piedistallo': ((2.3, -9.7, 1.35), (-0.2, -6.4, 1.0), 26.0),
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


def gruppo(nome, obs):
    """Registra gli oggetti di un pezzo della sala (un GLB per gruppo)."""
    GRUPPI.setdefault(nome, [])
    for o in (obs if isinstance(obs, (list, tuple)) else [obs]):
        if o is not None:
            GRUPPI[nome].append(o)
    return obs


def costruisci(con_oggetti=True, per_render=True):
    K.svuota()
    GRUPPI.clear()
    _CONTA.clear()
    mats = K.Materiali(PALETTE_SALA, per_render=per_render)
    arch = []
    buchi = [(PISCINA['x0'] - 0.5, PISCINA['y0'] - 0.5, PISCINA['x1'] + 0.5, PISCINA['y1'] + 0.5),
             (VASCA_ARRIVO['x0'] - 0.5, VASCA_ARRIVO['y0'] - 0.5, VASCA_ARRIVO['x1'] + 0.5, VASCA_ARRIVO['y1'] + 0.5)]
    arch.append(gruppo('architettura', pavimento_regione(mats, X0, X1, Y0, Y1, buchi)))
    arch += gruppo('architettura', pareti(mats))
    arch += gruppo('architettura', galleria(mats))
    arch.append(gruppo('architettura', soffitto_con_foro(mats, X0, X1, Y0, Y1, Z_SOFF, CUPOLA['cx'], CUPOLA['cy'], CUPOLA['r'])))
    arch += gruppo('cupola', cupola(mats))
    pis, zf = piscina_onde(mats)
    arch += pis
    gruppo('piscina', [o for o in pis if o.name != 'sala_pozza'])
    gruppo('acqua', [o for o in pis if o.name == 'sala_pozza'])
    va = vasca_arrivo(mats)
    arch += va
    gruppo('torre_scivoli', [o for o in va if not o.name.endswith('_acqua')])
    gruppo('acqua', [o for o in va if o.name.endswith('_acqua')])
    for args in ((-12.6, 9.6, 4.4, 3.2, 'sala_vasca_bimbi_1', 0.3), (-15.3, 12.4, 2.8, 2.8, 'sala_vasca_bimbi_2', 0.22)):
        vb = vasca_bassa(mats, *args[:5], acqua=args[5])
        arch += vb
        gruppo('area_bimbi', vb[0]); gruppo('acqua', vb[1])
    arch.append(gruppo('architettura', piedistallo(mats)))
    lamp, lampadina = lampione(mats, (1.9, -7.9, 0.0))
    arch.append(gruppo('architettura', lamp))
    arch += gruppo('area_bimbi', struttura_gioco(mats))
    arch += gruppo('torre_scivoli', torre_scivoli(mats))
    arch += gruppo('torre_scivoli', scivoli(mats, zf))
    arch += gruppo('architettura', cartelloni(mats))
    lamp_obs, sorgenti = lampade(mats)
    arch.append(gruppo('architettura', unisci(lamp_obs, 'sala_lampade')))
    arch.append(gruppo('architettura', insegna_neon()))
    arch.append(gruppo('architettura', pozzanghere(mats)))
    arch.append(gruppo('architettura', soffitto_struttura(mats)))
    arch.append(gruppo('architettura', colature(mats)))
    arch += gruppo('architettura', scala_galleria(mats))
    copie, modelli = ([], [])
    if con_oggetti:
        copie, modelli = disponi_oggetti(zf)
        gruppo('oggetti', copie)
    for o in bpy.context.scene.objects:   # le forme di collisione non si disegnano
        if o.name.lower().endswith(('-colonly', '-convcolonly')) or '-colonly' in o.name or '-convcolonly' in o.name:
            o.hide_render = True
            o.display_type = 'WIRE'
    return mats, arch, copie, modelli, sorgenti, lampadina, zf


def a_godot(p):
    """Coordinate Blender (Z in alto) -> Godot (Y in alto): (x, y, z) -> (x, z, -y)."""
    return [round(p[0], 3), round(p[2], 3), round(-p[1], 3)]


def dati_integrazione(sorgenti, lampadina):
    """Posizioni utili per montare la sala in Godot (scritte in sala_dati.json)."""
    luci = []
    for i, (tipo, pos, rot, k) in enumerate(sorgenti):
        if tipo == 'neon':
            luci.append(dict(nome=f'luce_neon_{i:02d}', tipo='neon (OmniLight3D o SpotLight3D verso il basso)', blender=list(pos),
                             godot=a_godot(pos), colore=[0.80, 1.0, 0.93], intensita='piena' if k >= 1 else 'metà (un tubo spento: sfarfallio)'))
        else:
            luci.append(dict(nome=f'luce_emergenza_{i:02d}', tipo="emergenza rossa (OmniLight3D, raggio 6-8 m)", blender=list(pos),
                             godot=a_godot(pos), colore=[1.0, 0.035, 0.02]))
    lp = tuple(lampadina)
    luci.append(dict(nome='luce_lampione', tipo='SpotLight3D verso il basso, angolo 60 gradi, calda, ronza', blender=list(lp), godot=a_godot(lp), colore=[1.0, 0.72, 0.42]))
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
        dict(nome='sala_vasca_bimbi_2_acqua', cosa='vasca bassa piccola con la balena sgonfia', x=[-16.7, -13.9], y=[11.0, 13.8], quota_blender=0.22, bordo_blender=0.45),
    ]
    for a in acqua:
        if 'centro_blender' in a:
            a['centro_godot'] = a_godot(a['centro_blender'])
    pd = PIEDISTALLO
    return dict(
        nota='Coordinate in metri. Blender: Z in alto. Godot/glTF: Y in alto, (x, y, z)_blender -> (x, z, -y)_godot.',
        piedistallo=dict(centro_blender=[pd['cx'], pd['cy'], 0.0], centro_godot=a_godot((pd['cx'], pd['cy'], 0.0)),
                         quota_piano=pd['h'], diametro_piano=2 * pd['r_piano'], diametro_tamburo=2 * pd['r_tamburo'],
                         diametro_base=2 * pd['r_base'], pulsante_bimbi=dict(blender=[pd['cx'], pd['cy'] - pd['r_tamburo'] - 0.2, 0.47])),
        spawn_ingresso=dict(blender=[0.0, -11.2, 0.0], godot=a_godot((0.0, -11.2, 0.0)), guarda_verso='nord (+y Blender, -z Godot), verso il piedistallo'),
        sala=dict(x=[X0, X1], y=[Y0, Y1], soffitto=Z_SOFF, galleria=Z_GAL + SP_GAL, cupola=CUPOLA),
        piscina_onde=dict(x=[P['x0'], P['x1']], y=[P['y0'], P['y1']], profondita=P['prof'], spiaggia='nord (y=13)', scarico_portello=list(P['scarico'])),
        torre=dict(centro=[TORRE['cx'], TORRE['cy']], lato=TORRE['lato'], piani=list(TORRE['piani'])),
        secchio=dict(nodo='sala_secchio_gigante', perno_blender=[STRUTTURA['cx'] + 0.2, STRUTTURA['cy'] + 1.6, 7.1], asse='x'),
        ruota_pale=dict(nodo='sala_ruota_pale', perno_blender=[STRUTTURA['cx'] - 4.2, STRUTTURA['cy'] - 1.2, 1.3], asse='x'),
        luci=luci, acqua=acqua,
        camere={k: dict(pos_blender=list(v[0]), guarda_blender=list(v[1]), lente_mm=v[2]) for k, v in CAMERE.items()})


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
        else:
            ld = bpy.data.lights.new(L['nome'], 'POINT'); ld.energy = 26
        ld.color = L['colore']
        ob = bpy.data.objects.new(L['nome'], ld)
        bpy.context.scene.collection.objects.link(ob)
        if 'blender' in L:
            ob.location = L['blender']
        else:
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


def esporta_glb(cartella):
    """Un GLB per pezzo della sala, tutti con lo stesso riferimento (origine della sala): in Godot si
    istanziano tutti in (0, 0, 0). Collisioni come nodi '-colonly'/'-convcolonly' (Godot le converte)."""
    os.makedirs(cartella, exist_ok=True)
    for nome, obs in GRUPPI.items():
        obs = [o for o in obs if o.name in bpy.data.objects]
        if not obs:
            continue
        p = os.path.join(cartella, f'sala_{nome}.glb')
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
    a = ap.parse_args(argv)
    if a.controlla:
        controlla_scivoli()
        return
    mats, arch, copie, modelli, sorgenti, lampadina, zf = costruisci(con_oggetti=not a.senza_oggetti,
                                                                     per_render=not a.glb)
    if a.glb:
        esporta_glb(a.glb)
        esporta_luci(a.glb, sorgenti, lampadina)
        if not a.render:
            return
    cielo_tempesta()
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
    main()
