"""Proposte per la sala della torre (17 ottobre): solo proposte, nel gioco non entra niente finché l'utente non
sceglie.

L'idea dell'utente (docs/GDD.md, "La sala della torre"): una struttura mastodontica di scivoli colorati che
non si scala ma si SCENDE, scivolando tra segmenti di scivoli spezzati senza cadere, a volte con la spinta del
getto per saltare da un pezzo all'altro. Ambiente pieno da subito: un acquapark vero e abbandonato.

La sala è quella dietro la parete est (SALA_TORRE di ambiente_sala.py: x 20-40, y 4-26), ma scende in
profondità nello scafo: il portone, alla quota della sala grande, dà su una passerella in cima; il fondo è
20 m più giù. Nelle scene di proposta il guscio di oggi (sala_torre_guscio) si nasconde e vale quello di qui.

Versioni (un GLB per versione in godot/proposte/torre/, fuori dall'export del gioco):
  A  groviglio: gli scivoli scendono a spirale attorno al vuoto centrale, stringendosi verso il fondo, dove
     nel pozzo c'è la luce di lei.

Coordinate di Blender (Z in alto, metri, come ambiente_sala.py); in Godot (x, z, -y).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/torre_proposte.py A [--blend file.blend]
"""
import json, math, os, sys
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import ambiente_kit as K  # noqa: E402
import ambiente_sala as S  # noqa: E402

USCITA = os.path.normpath(os.path.join(QUI, '..', '..', 'godot', 'proposte', 'torre'))
T = S.SALA_TORRE
XI0, XI1, YI0, YI1, H = S.X1 + K.SPESSORE_PARETE, T['x1'], T['y0'], T['y1'], T['h']   # interno della sala
FONDO = -20.0                                   # il fondo della sala, nello scafo
PORTONE = dict(x=S.X1, y=T['cy'], largo=T['largo'], alto=T['alto'])

PALO, RINGHIERA, BALAUSTRA = 'gioco_blu', 'gioco_rosso', 'gioco_blu'
R_GROVIGLIO = 0.52                               # raggio dei tubi chiusi del groviglio (come K.tubo_scivolo)
LARGO, PROF, SPONDA = 0.62, 0.34, 0.28          # canale degli scivoli: mezza larghezza, profondità, sponde


# --- pezzi del kit ----------------------------------------------------------------------------------

def polare(c, r, a, z=0.0):
    return Vector((c[0] + r * math.cos(math.radians(a)), c[1] + r * math.sin(math.radians(a)), z))


# i canali di tutti gli scivoli della versione (si registrano prima di costruire): i pali non li attraversano
CANALI = []
GRATE = [None]   # il Costruttore dei grigliati (materiale con alfa), uno per versione
PALI_PEDANE = []  # le pedane che vanno sostenute dai pali (si fanno alla fine)
OSTACOLI = []    # pedane, vasche e pozzo: (x0, y0, x1, y1, quota) che i pali non devono attraversare
DECO = []        # gli scivoli che non fanno parte della discesa: (punti fitti, mezza larghezza), stessi controlli


def fitti(pts, passo=0.4):
    """I punti di una spezzata ogni `passo` metri (per i controlli di spazio)."""
    out = []
    for a, b in zip(pts[:-1], pts[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / passo))
        out += [a.lerp(b, k / n) for k in range(n)]
    return out + [Vector(pts[-1])]


def palo_libero(p, z0, z1, r=0.11):
    """Vero se il palo da z0 a z1 non passa dentro il canale di uno scivolo (quelli sopra la sua cima, cioè
    lo scivolo che regge, non contano)."""
    for pts in CANALI:
        for q in pts:
            if z0 - 0.5 < q.z < z1 - 0.3 and math.hypot(q.x - p[0], q.y - p[1]) < LARGO + SPONDA + r + 0.2:
                return False
    for pts, mezza in DECO:
        for q in pts:
            if z0 - 0.5 < q.z < z1 - 0.3 and math.hypot(q.x - p[0], q.y - p[1]) < mezza + r + 0.2:
                return False
    for (x0, y0, x1, y1, z) in OSTACOLI:
        if x0 - r - 0.15 < p[0] < x1 + r + 0.15 and y0 - r - 0.15 < p[1] < y1 + r + 0.15 and z0 - 0.1 < z and z1 > z - 0.2:
            return False
    return True


def cielo_libero(p, z, salta=None):
    """Vero se sopra il punto (fino al soffitto) non passa niente: lì si può appendere un tirante."""
    for pts, mezza in [(c_, LARGO + SPONDA) for c_ in CANALI] + DECO:
        if pts is salta:
            continue
        for q in pts:
            if q.z > z + 0.3 and math.hypot(q.x - p[0], q.y - p[1]) < mezza + 0.5:
                return False
    return True


def spazio_discesa(pts, mezza, nome):
    """Controlla che un tubo decorativo non tolga spazio alla discesa: sopra il canale ci vogliono 2,4 m
    liberi (chi scivola), sotto 1 m (lo scafo del canale e i suoi sostegni). Stampa i punti in conflitto."""
    brutti = 0
    for route in CANALI:
        for q in route:
            for t in pts:
                if math.hypot(q.x - t.x, q.y - t.y) < LARGO + SPONDA + mezza + 0.1:
                    dz = t.z - q.z
                    if -1.0 - mezza < dz < 2.4 + mezza:
                        brutti += 1
                        if brutti <= 3:
                            print(f'  {nome}: troppo vicino alla discesa in {tuple(round(x, 1) for x in t)}')
    for other, m2 in DECO:
        if other is pts:
            continue
        for q in other[::2]:
            for t in pts[::2]:
                if (q - t).length < mezza + m2 + 0.25:
                    brutti += 1
                    if brutti <= 3:
                        print(f'  {nome}: tocca un altro tubo in {tuple(round(x, 1) for x in t)}')
    return brutti



def posto_libero(p, z0, z1, r=0.11, dentro=None, passi=8):
    """Il punto più vicino a p (entro 1,6 m, e dentro il rettangolo `dentro` se c'è) dove il palo è libero."""
    for k in range(passi + 1):
        rr = 0.2 * k
        for a in range(0, 360, 30 if k else 360):
            q = (p[0] + rr * math.cos(math.radians(a)), p[1] + rr * math.sin(math.radians(a)))
            if dentro and not (dentro[0] <= q[0] <= dentro[2] and dentro[1] <= q[1] <= dentro[3]):
                continue
            if palo_libero(q, z0, z1, r):
                return q
    return None


def tirante(c, p, r_tubo, verso=(1, 0, 0)):
    """Due cavi d'acciaio dal soffitto, a V, fino alla fascetta attorno al tubo (o alla piastra della pedana)."""
    p = Vector(p)
    v = Vector(verso)
    v.z = 0
    t = Vector((-v.y, v.x, 0)).normalized() if v.length > 1e-6 else Vector((1, 0, 0))
    for s_ in (-1, 1):
        a = p + t * (s_ * 0.45)
        a.z = H
        b = p + t * (s_ * 0.12) + Vector((0, 0, (r_tubo + 0.05) if r_tubo else 0.0))
        c.cilindro(a, b, 0.022, 'inox', seg=8)
        c.scatola((a.x - 0.12, a.y - 0.12, H - 0.04), (a.x + 0.12, a.y + 0.12, H), 'metallo')
    if r_tubo:
        c.anello(p, Vector(verso).normalized(), r_tubo + 0.01, r_tubo + 0.06, 0.12, 'metallo', seg=20)


def palo(c, p, z0, z1, mat=PALO, r=0.14):
    """Palo tondo con la piastra imbullonata alla base."""
    c.cilindro((p[0], p[1], z0), (p[0], p[1], z1), r, mat, seg=14, tappi=True)
    c.anello((p[0], p[1], z0), (0, 0, 1), 0.0, r + 0.1, 0.025, 'inox', seg=14)


def guscio_profondo(c):
    """La sala dal fondo (FONDO) al soffitto (H): muri di cemento verniciato sopra lo zoccolo, piastrelle
    nel fondo dove c'è l'acqua, il varco del portone nella parete ovest (alla quota della sala grande)."""
    x0, x1, y0, y1 = XI0, XI1, YI0, YI1
    c.faccia_griglia([(x0, y0, FONDO), (x1, y0, FONDO), (x1, y1, FONDO), (x0, y1, FONDO)], 'pavimento', 2.0)
    c.faccia_griglia([(x0, y1, H), (x1, y1, H), (x1, y0, H), (x0, y0, H)], 'stanza_soffitto', 4.0)
    muri = {'s': [(x1, y0), (x0, y0)], 'n': [(x0, y1), (x1, y1)], 'e': [(x1, y1), (x1, y0)]}
    for p, q in muri.values():
        c.faccia_griglia([(p[0], p[1], FONDO), (q[0], q[1], FONDO), (q[0], q[1], FONDO + 1.5), (p[0], p[1], FONDO + 1.5)], 'vasca', 1.0)
        c.faccia_griglia([(p[0], p[1], FONDO + 1.5), (q[0], q[1], FONDO + 1.5), (q[0], q[1], H), (p[0], p[1], H)], 'stanza_muro', 2.0)
    # parete ovest: sotto la sala grande tutta piena, sopra con il varco del portone
    P = PORTONE
    ya, yb = P['y'] - P['largo'] / 2, P['y'] + P['largo'] / 2
    w = [(x0, y1), (x0, y0)]
    c.faccia_griglia([(x0, y1, FONDO), (x0, y0, FONDO), (x0, y0, 0), (x0, y1, 0)], 'stanza_muro', 2.0)
    c.faccia_griglia([(x0, y1, 0), (x0, yb, 0), (x0, yb, H), (x0, y1, H)], 'stanza_muro', 2.0)
    c.faccia_griglia([(x0, ya, 0), (x0, y0, 0), (x0, y0, H), (x0, ya, H)], 'stanza_muro', 2.0)
    c.faccia_griglia([(x0, yb, P['alto']), (x0, ya, P['alto']), (x0, ya, H), (x0, yb, H)], 'stanza_muro', 2.0)
    del w
    # le costole dello scafo sui muri lunghi, ogni 4 m (come nei corridoi della nave)
    for x in range(22, 40, 4):
        for y, s in ((y0, 1), (y1, -1)):
            c.scatola((x - 0.15, min(y, y + s * 0.35), FONDO), (x + 0.15, max(y, y + s * 0.35), H - 0.3), 'metallo_grigio')


def scivolo(c, punti, mat):
    """Tratto di scivolo aperto (canale di vetroresina) lungo i punti del bordo del canale."""
    S.scivolo_solido(c, [Vector(p) for p in punti], W=LARGO, D=PROF, T=0.05, H=SPONDA, R=0.035, mat=mat)


def elica(centro, r0, r1, a0, a1, z0, z1, passo=0.35):
    """Punti lungo un tratto di spirale (raggio da r0 a r1, angolo da a0 ad a1, quota da z0 a z1)."""
    lung = abs(math.radians(a1 - a0)) * (r0 + r1) / 2
    n = max(4, int(lung / passo))
    return [polare(centro, r0 + (r1 - r0) * k / n, a0 + (a1 - a0) * k / n, z0 + (z1 - z0) * k / n) for k in range(n + 1)]


def sostegni(c, punti, ogni=3.2, fuori=0.0, centro=None, mat=PALO):
    """Pali dal fondo sotto lo scivolo, con la sella che lo regge (niente appeso al nulla). Con `fuori` il
    palo sta più all'esterno (verso i muri) e un braccio orizzontale arriva sotto il canale."""
    s = 0.0
    prossimo = ogni * 0.5
    for i in range(1, len(punti)):
        s += (Vector(punti[i]) - Vector(punti[i - 1])).length
        if s < prossimo:
            continue
        prossimo += ogni
        p = Vector(punti[i])
        sotto = p.z - PROF - 0.08
        # il palo più vicino possibile sotto il canale che non attraversi gli scivoli più in basso
        d = Vector((1, 0, 0))
        if centro:
            d = (p - Vector((centro[0], centro[1], p.z)))
            d.z = 0
            d.normalize()
        prove = ([fuori] if fuori else []) + [0.0, 1.0, -1.0, 1.6, -1.6]
        base = None
        for f in prove:
            b = p + d * f
            if palo_libero(b, FONDO, sotto) and XI0 + 0.3 < b.x < XI1 - 0.3 and YI0 + 0.3 < b.y < YI1 - 0.3:
                base = b
                break
        if base is None:
            print('sostegno saltato in', tuple(round(x, 1) for x in p))
            continue
        if (base - p).length > 0.01:
            c.cilindro((base.x, base.y, sotto), (p.x, p.y, sotto), 0.07, 'metallo', seg=10)
        palo(c, base, FONDO, sotto, mat)
        c.scatola((p.x - 0.35, p.y - 0.35, sotto - 0.05), (p.x + 0.35, p.y + 0.35, sotto + 0.02), 'metallo')


def ringhiera_dritta(c, a, b, h=1.0, passo=0.4):
    a, b = Vector(a), Vector(b)
    for zz, r in ((h, 0.03), (h * 0.5, 0.022)):
        c.cilindro(a + Vector((0, 0, zz)), b + Vector((0, 0, zz)), r, RINGHIERA, seg=10, tappi=True)
    n = max(1, int((b - a).length / passo))
    for k in range(n + 1):
        p = a + (b - a) * (k / n)
        c.cilindro(p, p + Vector((0, 0, h)), 0.016, BALAUSTRA, seg=8, tappi=False)


def piattaforma(c, x0, y0, x1, y1, z, lati=('n', 's', 'e', 'o'), aperture=(), pali=True, mat='grata'):
    """Pedana di grata su travi gialle, con la ringhiera sui lati indicati (meno le aperture, come
    (lato, da, a)) e i pali fino al fondo."""
    OSTACOLI.append((x0, y0, x1, y1, z))
    # grigliato vero (si vede sotto), su un telaio di travi gialle lungo i quattro lati e una in mezzo
    q = [(x0, y0, z - 0.01), (x1, y0, z - 0.01), (x1, y1, z - 0.01), (x0, y1, z - 0.01)]
    GRATE[0].faccia(q, 'alfa_grata')
    GRATE[0].faccia([(x, y, zz - 0.012) for (x, y, zz) in q[::-1]], 'alfa_grata')
    c.scatola((x0, y0, z - 0.26), (x1, y0 + 0.12, z - 0.03), 'gioco_giallo')
    c.scatola((x0, y1 - 0.12, z - 0.26), (x1, y1, z - 0.03), 'gioco_giallo')
    c.scatola((x0, y0 + 0.12, z - 0.2), (x0 + 0.1, y1 - 0.12, z - 0.03), 'gioco_giallo')
    c.scatola((x1 - 0.1, y0 + 0.12, z - 0.2), (x1, y1 - 0.12, z - 0.03), 'gioco_giallo')
    ym = (y0 + y1) / 2
    c.scatola((x0 + 0.1, ym - 0.05, z - 0.16), (x1 - 0.1, ym + 0.05, z - 0.03), 'gioco_giallo')
    lato = {'n': ((x0, y1), (x1, y1)), 's': ((x0, y0), (x1, y0)), 'e': ((x1, y0), (x1, y1)), 'o': ((x0, y0), (x0, y1))}
    for l in lati:
        (ax, ay), (bx, by) = lato[l]
        tratti = [(0.0, 1.0)]
        for (la, t0, t1) in aperture:
            if la == l:
                nuovi = []
                for (u0, u1) in tratti:
                    if t1 <= u0 or t0 >= u1:
                        nuovi.append((u0, u1))
                    else:
                        if t0 > u0:
                            nuovi.append((u0, t0))
                        if t1 < u1:
                            nuovi.append((t1, u1))
                tratti = nuovi
        for (u0, u1) in tratti:
            if u1 - u0 < 0.05:
                continue
            a = (ax + (bx - ax) * u0, ay + (by - ay) * u0, z)
            b = (ax + (bx - ax) * u1, ay + (by - ay) * u1, z)
            ringhiera_dritta(c, a, b)
    if pali and z > FONDO + 0.5:
        PALI_PEDANE.append((x0, y0, x1, y1, z))

def pali_pedane(c):
    """I pali delle pedane, fatti per ultimi (quando tutti gli ostacoli sono noti). Se l'angolo è occupato da
    uno scivolo, il palo rientra sotto la grata; se non c'è posto, la pedana si appende al soffitto."""
    for (x0, y0, x1, y1, z) in PALI_PEDANE:
        for (px, py) in ((x0 + 0.15, y0 + 0.15), (x1 - 0.15, y0 + 0.15), (x1 - 0.15, y1 - 0.15), (x0 + 0.15, y1 - 0.15)):
            if palo_libero((px, py), FONDO, z - 0.26):
                palo(c, (px, py), FONDO, z - 0.26)
                continue
            # spostato verso l'interno: arriva sotto la grata, con una trave corta che lo lega alla trave gialla
            q = posto_libero((px, py), FONDO, z - 0.06, dentro=(x0 + 0.15, y0 + 0.15, x1 - 0.15, y1 - 0.15))
            if q is None:
                if cielo_libero((px, py), z):
                    tirante(c, (px, py, z), 0.0)
                else:
                    print('  angolo di pedana senza sostegno in', (round(px, 1), round(py, 1), z))
                continue
            palo(c, q, FONDO, z - 0.06)
            yb = y0 + 0.06 if abs(q[1] - y0) < abs(q[1] - y1) else y1 - 0.06
            c.scatola((q[0] - 0.08, min(q[1], yb), z - 0.22), (q[0] + 0.08, max(q[1], yb), z - 0.06), 'gioco_giallo')


def vasca(c, x0, y0, x1, y1, z, alto=0.45, nome_acqua='acqua'):
    """Vasca di piastrelle con il bordo (la sua acqua è un piano a parte: in Godot prende l'acqua vera)."""
    OSTACOLI.append((x0, y0, x1, y1, z + alto))
    sp = 0.18
    for (a, b) in (((x0, y0), (x1, y0 + sp)), ((x0, y1 - sp), (x1, y1)), ((x0, y0), (x0 + sp, y1)), ((x1 - sp, y0), (x1, y1))):
        c.scatola((a[0], a[1], z), (b[0], b[1], z + alto), 'vasca_bimbi', smusso=0.02)
    c.scatola((x0 + sp, y0 + sp, z), (x1 - sp, y1 - sp, z + 0.02), 'vasca')
    acqua = acqua_piano(nome_acqua, x0 + sp, y0 + sp, x1 - sp, y1 - sp, z + alto - 0.12)
    return acqua


def acqua_piano(nome, x0, y0, x1, y1, z):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def pozzo_lei(c, centro, r=1.8):
    """Il pozzo in mezzo al fondo: da lì sale la luce di lei. Bordo basso di cemento e grata rotta."""
    OSTACOLI.append((centro[0] - r - 0.4, centro[1] - r - 0.4, centro[0] + r + 0.4, centro[1] + r + 0.4, FONDO + 0.65))
    c.anello((centro[0], centro[1], FONDO), (0, 0, 1), r, r + 0.35, 0.6, 'cemento', seg=48)
    c.anello((centro[0], centro[1], FONDO + 0.6), (0, 0, 1), r - 0.02, r + 0.38, 0.05, 'inox', seg=48)
    c.anello((centro[0], centro[1], FONDO - 8.0), (0, 0, 1), r - 0.05, r, 8.6, 'nero', seg=48)
    c.disco((centro[0], centro[1], FONDO - 8.0), (0, 0, 1), r, 'nero', seg=48)
    # due sbarre della grata rimaste, piegate verso il basso
    for a in (20.0, 200.0):
        p = polare(centro, r * 0.55, a, FONDO + 0.55)
        q = polare(centro, -r * 0.1, a, FONDO + 0.1)
        c.cilindro(p, q, 0.035, 'metallo', seg=8)


def balconata(c, x0, x1, y, z, profondita=1.6):
    """Balconata sulla parete nord (B5: in un lampo ci si vede la fila dei bambini), mensole al muro,
    porta buia dietro."""
    y0 = y - profondita
    c.scatola((x0, y0, z - 0.25), (x1, y, z), 'cemento', smusso=0.02)
    for x in (x0 + 0.3, (x0 + x1) / 2, x1 - 0.3):
        c.scatola((x - 0.15, y - 1.2, z - 1.4), (x + 0.15, y, z - 0.25), 'cemento')
    ringhiera_dritta(c, (x0, y0, z), (x1, y0, z))
    ringhiera_dritta(c, (x0, y0, z), (x0, y, z))
    ringhiera_dritta(c, (x1, y0, z), (x1, y, z))
    xm = (x0 + x1) / 2
    c.scatola((xm - 0.7, y - 0.04, z), (xm + 0.7, y, z + 2.2), 'nero')
    c.scatola((xm - 0.85, y - 0.1, z + 2.2), (xm + 0.85, y, z + 2.35), 'metallo')


def tubo_muro(c, punti, r=0.14, mat='metallo'):
    """Tubo di servizio lungo i muri, con le fascette rosse ogni tanto e le staffe al muro."""
    c.tubo(punti, r, mat, seg=12)
    for i in range(len(punti) - 1):
        a, b = Vector(punti[i]), Vector(punti[i + 1])
        m = (a + b) / 2
        c.anello(m, (b - a).normalized(), r, r + 0.04, 0.1, 'gioco_rosso', seg=16)


def cancello_partenza(c, base, verso):
    """Cancello a sbarre all'inizio della discesa (si apre con l'acqua che scorre)."""
    v = Vector(verso).normalized()
    t = Vector((-v.y, v.x, 0))
    b = Vector(base)
    for s in (-1, 1):
        ap = b + t * (s * (LARGO + 0.2))
        c.cilindro(ap, ap + Vector((0, 0, 2.0)), 0.06, 'gioco_rosso', seg=12)
    c.cilindro(b + t * -(LARGO + 0.2) + Vector((0, 0, 2.0)), b + t * (LARGO + 0.2) + Vector((0, 0, 2.0)), 0.06,
               'gioco_rosso', seg=12)
    c.scatola_assi(b + Vector((0, 0, 2.25)), [v, t, Vector((0, 0, 1))], (0.03, LARGO + 0.3, 0.2), 'strisce')
    for k in range(-3, 4):
        g = b + t * (k * (LARGO / 3.2))
        c.cilindro(g + Vector((0, 0, 0.05)), g + Vector((0, 0, 1.3)), 0.02, 'inox', seg=8, tappi=False)
    c.cilindro(b + t * -LARGO + Vector((0, 0, 1.3)), b + t * LARGO + Vector((0, 0, 1.3)), 0.025, 'inox', seg=8)


def polaroid(c, p, verso):
    v = Vector(verso).normalized()
    t = Vector((-v.y, v.x, 0))
    c.scatola_assi(Vector(p) + Vector((0, 0, 0.003)), [t, v, Vector((0, 0, 1))], (0.045, 0.055, 0.003), 'carta')


def materiali_torre(mats):
    for nome, colore, rough, metallo in (('grata', (0.30, 0.31, 0.32), 0.55, 0.85),
                                         ('carta', (0.92, 0.9, 0.84), 0.7, 0.0)):
        if nome not in mats.cache:
            mats.cache[nome] = mats._semplice(nome, colore, rough, metallo)


# --- prop di Meshy, appoggiati per bene --------------------------------------------------------------

def prop(nome, pos, rot=0.0, scala=1.0):
    """Un oggetto di scena HQ della sala (gonfiabili, giocattoli, lettini...) con la base sul piano pos.z."""
    o = S.copia_modello(nome, pos, rot, scala, collisione=False)
    o.name = f'prop_{nome}_{len([x for x in bpy.data.objects if x.name.startswith("prop_" + nome)])}'
    return o


def groviglio_A(c, mats):
    """Scivoli che non fanno parte della discesa (versione A). Restituisce gli oggetti in più (acque, cartelloni)."""
    X0, X1_ = XI0 - 0.3, XI1 + 0.3            # dentro i muri: il tubo continua dall'altra parte
    chiusi = [
        # alti, da muro a muro
        ('scivolo_c', [(X0, 22.5, 9.5), (26.0, 20.0, 8.0), (30.5, 17.0, 6.6), (34.5, 12.0, 4.6), (X1_, 7.5, 2.6)]),
        ('scivolo_b', [(X1_, 21.5, 12.6), (35.5, 20.5, 11.7), (31.0, 20.0, 11.1), (26.5, 18.5, 10.5), (X0, 17.5, 9.8)]),
        # a metà: dal muro sud al muro est, sopra la discesa
        ('scivolo', [(27.5, YI0 - 0.3, -1.2), (29.0, 8.3, -2.0), (32.5, 9.3, -2.8), (36.0, 11.2, -3.4), (X1_, 12.4, -3.8)]),
        # in basso: dal muro est fino alla vasca sud-ovest del fondo (la bocca sopra l'acqua)
        ('scivolo_d', [(X1_, 6.0, -10.5), (35.0, 6.2, -13.2), (29.5, 6.4, -15.8), (26.4, 7.6, -17.6), (23.6, 9.6, -18.7)]),
    ]
    aperti = [
        # il vecchio percorso alto: dalla pedana sul muro nord a quella sul muro ovest, girando largo
        ('scivolo_d', elica(A['centro'], 9.6, 9.3, 66.0, 132.0, 5.9, 2.9)),
        # spezzato: dalla porta sul muro ovest verso est lungo il muro sud, finisce nel vuoto (il pezzo è giù)
        ('scivolo_b', [Vector((22.7, 7.4, -5.05)), Vector((24.6, 6.7, -5.6)), Vector((26.6, 6.3, -6.2)),
                       Vector((28.4, 6.2, -6.75))]),
    ]
    for mat, pts in chiusi:
        DECO.append((fitti(pts), R_GROVIGLIO + 0.08))
    for mat, pts in aperti:
        DECO.append((fitti(pts), LARGO + SPONDA))
    brutti = sum(spazio_discesa(d[0], d[1], f'groviglio {i}') for i, d in enumerate(DECO))
    print('groviglio: punti in conflitto', brutti)
    for i, (mat, pts) in enumerate(chiusi):
        K.tubo_scivolo(mats, pts, nome=f'torre_tubo_{i}', materiali=[mat])
    for mat, pts in aperti:
        scivolo(c, [Vector(p) for p in pts], mat)
    def sostegni_grov():
        # sostegni: tiranti dal soffitto dove sopra non passa niente, altrimenti pali dal fondo
        for k, (dense, mezza) in enumerate(DECO):
            s_ = 0.0
            for j in range(1, len(dense)):
                s_ += (dense[j] - dense[j - 1]).length
                if s_ < 3.0 and j < len(dense) - 1:
                    continue
                p = dense[j]
                if not (XI0 + 0.4 < p.x < XI1 - 0.4 and YI0 + 0.4 < p.y < YI1 - 0.4):
                    continue
                s_ = 0.0
                verso = dense[min(j + 1, len(dense) - 1)] - dense[j - 1]
                aperto = mezza > 0.8
                zsotto = p.z - (PROF + 0.08 if aperto else R_GROVIGLIO + 0.05)
                if cielo_libero(p, p.z, salta=dense) and not aperto:
                    tirante(c, p, R_GROVIGLIO, verso)
                else:
                    w = posto_libero(p, FONDO, zsotto, r=0.13, passi=5)
                    if w is None:
                        print('  sostegno del groviglio saltato in', tuple(round(x, 1) for x in p))
                        continue
                    palo(c, w, FONDO, zsotto, 'gioco_arancio' if k % 2 else PALO, r=0.13)
                    if math.hypot(w[0] - p.x, w[1] - p.y) > 0.05:
                        c.cilindro((w[0], w[1], zsotto), (p.x, p.y, zsotto), 0.08, 'metallo', seg=10)
                    c.scatola((p.x - 0.3, p.y - 0.3, zsotto - 0.05), (p.x + 0.3, p.y + 0.3, zsotto + 0.02), 'metallo')

    extra = []
    # le pedane del vecchio percorso alto, con la porta murata dietro
    e0, e1 = aperti[0][1][0], aperti[0][1][-1]
    piattaforma(c, e0.x - 1.6, YI1 - 2.4, e0.x + 1.6, YI1, e0.z - 0.05, lati=('s', 'e', 'o'),
                aperture=(('s', 0.3, 0.75),), pali=False)
    mensola(c, e0.x - 1.6, e0.x + 1.6, YI1, e0.z - 0.05, 'n')
    piattaforma(c, XI0, e1.y - 1.6, e1.x + 0.3, e1.y + 1.6, e1.z - 0.05, lati=('n', 's', 'e'),
                aperture=(('e', 0.2, 0.75),), pali=True)
    mensola(c, e1.y - 1.6, e1.y + 1.6, XI0, e1.z - 0.05, 'o')
    porta_murata(c, (e0.x, YI1, e0.z - 0.05), 'n')
    porta_murata(c, (XI0, e1.y, e1.z - 0.05), 'o')
    # la porta sul muro ovest da cui partiva lo scivolo spezzato, con la sua pedana
    sp = aperti[1][1]
    piattaforma(c, XI0, sp[0].y - 1.3, sp[0].x + 0.1, sp[0].y + 1.3, sp[0].z - 0.05, lati=('n', 's'), pali=False)
    mensola(c, sp[0].y - 1.3, sp[0].y + 1.3, XI0, sp[0].z - 0.05, 'o')
    porta_murata(c, (XI0, sp[0].y, sp[0].z - 0.05), 'o')
    # il pezzo caduto: un tratto di canale sul fondo, di traverso, sotto la fine dello spezzato
    caduto = [Vector((29.4, 6.0, FONDO + 0.42)), Vector((30.6, 6.5, FONDO + 0.5)), Vector((31.9, 7.3, FONDO + 0.62))]
    scivolo(c, caduto, 'scivolo_b')
    c.scatola((29.2, 5.75, FONDO), (29.7, 6.25, FONDO + 0.12), 'cemento')   # calcinacci sotto
    # la vasca sud-ovest dove finisce il tubo basso
    extra.append(vasca(c, 21.0, 7.6, 25.8, 11.8, FONDO, alto=0.55, nome_acqua='acqua_vasca_sud'))
    return extra, sostegni_grov


def mensola(c, a0, a1, muro, z, lato):
    """Due mensole a squadra che reggono al muro una pedana senza pali (lato: 'n' muro nord, 'o' muro ovest)."""
    for t in (a0 + 0.35, a1 - 0.35):
        if lato == 'n':
            c.scatola((t - 0.06, muro - 1.6, z - 0.3), (t + 0.06, muro, z - 0.2), 'gioco_giallo')
            c.cilindro((t, muro - 1.4, z - 0.25), (t, muro, z - 1.5), 0.05, 'gioco_giallo', seg=10)
        else:
            c.scatola((muro, t - 0.06, z - 0.3), (muro + 1.9, t + 0.06, z - 0.2), 'gioco_giallo')
            c.cilindro((muro + 1.7, t, z - 0.25), (muro, t, z - 1.5), 0.05, 'gioco_giallo', seg=10)


def porta_murata(c, base, lato):
    """Vano di una porta di servizio chiuso con i blocchi, telaio di metallo e la striscia di pericolo."""
    b = Vector(base)
    if lato == 'n':
        c.scatola((b.x - 0.6, b.y - 0.05, b.z), (b.x + 0.6, b.y, b.z + 2.1), 'cemento')
        c.scatola((b.x - 0.7, b.y - 0.1, b.z + 2.1), (b.x + 0.7, b.y, b.z + 2.22), 'metallo')
        c.scatola((b.x - 0.6, b.y - 0.07, b.z + 0.9), (b.x + 0.6, b.y - 0.05, b.z + 1.05), 'strisce')
    else:
        c.scatola((b.x, b.y - 0.6, b.z), (b.x + 0.05, b.y + 0.6, b.z + 2.1), 'cemento')
        c.scatola((b.x, b.y - 0.7, b.z + 2.1), (b.x + 0.1, b.y + 0.7, b.z + 2.22), 'metallo')
        c.scatola((b.x + 0.05, b.y - 0.6, b.z + 0.9), (b.x + 0.07, b.y + 0.6, b.z + 1.05), 'strisce')


# --- versione A: il groviglio attorno al vuoto ----------------------------------------------------------

A = dict(centro=(31.0, 15.0))


def versione_A(mats):
    """Si entra in cima dal portone, su una passerella; la discesa gira attorno al vuoto centrale stringendosi:
    scivolo, salto, scivolo fino alla pedana est con la vasca intermedia; poi un pezzo spezzato dove serve la
    spinta del getto, fino alla pedana ovest (la Polaroid 10, sotto la passerella da cui sei entrato); l'ultimo
    scivolo stringe la spirale fino alla vasca del fondo, accanto al pozzo da cui sale la luce di lei.
    Gli altri scivoli del groviglio (tubi chiusi, interrotti) attraversano il vuoto: non si usano."""
    C = A['centro']
    c = K.Costruttore(mats)
    s1 = elica(C, 6.2, 7.2, 172.0, 112.0, 0.05, -2.4)
    s2 = elica(C, 7.2, 7.2, 102.0, 18.0, -3.0, -5.9)
    s3 = elica(C, 6.8, 6.4, -6.0, -78.0, -6.35, -9.6)
    s4 = elica(C, 5.6, 5.0, -102.0, -168.0, -10.7, -13.0)
    s5 = elica(C, 4.6, 3.6, 172.0, 28.0, -13.35, -18.9)
    CANALI[:] = [s1, s2, s3, s4, s5]
    DECO.clear()
    OSTACOLI.clear()
    PALI_PEDANE.clear()
    GRATE[0] = K.Costruttore(mats)
    # il groviglio: gli altri scivoli del parco, che qui dentro si incrociano a tutte le altezze. Tubi chiusi che
    # entrano ed escono dai muri, canali aperti tra le pedane di un vecchio percorso, uno spezzato con il
    # pezzo caduto sul fondo, uno che finisce nella vasca sud-ovest del fondo. Nessuno toglie spazio alla discesa.
    # (va per primo: i sostegni della discesa devono già sapere dove passano questi tubi)
    grov, sostegni_grov = groviglio_A(c, mats)
    guscio_profondo(c)
    percorso = []
    acque = []
    # passerella dal portone alla partenza (quota della sala grande)
    piattaforma(c, XI0, 13.4, 24.2, 16.6, 0.0, lati=('n', 's'), pali=True)
    piattaforma(c, 24.2, 12.6, 26.6, 17.4, 0.0, lati=('n', 's', 'o'), aperture=(('o', 0.17, 0.83),),
                pali=True)
    percorso.append(('portone', Vector((XI0 + 0.5, 15.0, 0.0))))
    # 1: la prima discesa, dalla partenza verso nord (r 7,2), poi un salto corto
    a0 = 180.0
    cancello_partenza(c, polare(C, 6.25, 174.0, 0.0), polare(C, 1.0, 84.0) - Vector((C[0], C[1], 0)))
    scivolo(c, s1, 'scivolo')
    percorso += [('scivolo', p) for p in s1[::4]]
    scivolo(c, s2, 'scivolo_b')
    percorso.append(('salto', s1[-1]))
    percorso += [('scivolo', p) for p in s2[::4]]
    # pedana est con la vasca intermedia (lo scivolo ci finisce dentro)
    px = polare(C, 7.2, 8.0)
    piattaforma(c, px.x - 1.9, px.y - 2.6, XI1 - 0.05, px.y + 2.2, -6.3, lati=('s', 'e', 'n'),
                aperture=(('n', 0.0, 0.45),))
    acque.append(vasca(c, px.x - 1.5, px.y - 0.4, XI1 - 0.4, px.y + 2.0, -6.3, nome_acqua='acqua_vasca_est'))
    percorso.append(('vasca intermedia', Vector((px.x, px.y + 0.8, -6.3))))
    # 2: dalla pedana est verso sud, si spezza sopra il vuoto: la spinta del getto porta al pezzo dopo
    scivolo(c, s3, 'scivolo_c')
    scivolo(c, s4, 'scivolo_d')
    percorso += [('scivolo', p) for p in s3[::4]]
    percorso.append(('getto', s3[-1]))
    percorso += [('scivolo', p) for p in s4[::4]]
    # pedana ovest (sotto la passerella del portone): la Polaroid 10 sul lettino
    q = polare(C, 5.0, 180.0)
    piattaforma(c, q.x - 2.4, q.y - 2.2, q.x + 0.9, q.y + 1.6, -13.3, lati=('o', 's', 'n'),
                aperture=(('s', 0.55, 1.0),))
    percorso.append(('pedana ovest', Vector((q.x - 0.6, q.y, -13.3))))
    # 3: l'ultimo scivolo stringe la spirale attorno al pozzo fino alla vasca del fondo
    scivolo(c, s5, 'scivolo')
    percorso += [('scivolo', p) for p in s5[::4]]
    # il fondo: pozzo di lei al centro, vasca d'arrivo a nord-est, la bocca del tubo grande dell'inseguimento
    pozzo_lei(c, C)
    acque.append(vasca(c, 32.6, 15.8, 38.0, 21.6, FONDO, alto=0.6, nome_acqua='acqua_vasca_fondo'))
    percorso.append(('fondo', Vector((35.0, 18.5, FONDO))))
    # la bocca del tubo dell'inseguimento (tappa 10), sulla parete est, accanto alla vasca
    bocca = [(XI1 - 3.0, 9.0, FONDO + 1.2), (XI1 - 1.2, 9.0, FONDO + 1.2), (XI1 + 1.0, 9.0, FONDO + 1.0)]
    K.tubo_scivolo(mats, bocca, nome='torre_tubo_inseguimento', materiali=['scivolo_d'], r=0.8, spessore=0.06)
    # i sostegni per ultimi, quando pedane, vasche e tubi sono tutti al loro posto
    for pts, fu in ((s1, 0.9), (s2, 0.9), (s3, 0.9), (s4, 0.0), (s5, 0.0)):
        sostegni(c, pts, fuori=fu, centro=C)
    sostegni_grov()
    pali_pedane(c)
    # la balconata dei bambini: parete nord, di fronte alla prima discesa
    balconata(c, 26.5, 33.5, YI1, -2.0)
    # tubi di servizio sui muri
    tubo_muro(c, [(XI0 + 0.3, YI0 + 0.4, -18.5), (XI1 - 0.4, YI0 + 0.4, -18.5)])
    tubo_muro(c, [(XI1 - 0.4, YI0 + 0.4, -12.0), (XI1 - 0.4, YI1 - 0.4, -12.0)], r=0.2)
    tubo_muro(c, [(XI0 + 0.4, YI1 - 0.4, 6.0), (XI1 - 0.4, YI1 - 0.4, 6.0)])
    gr = GRATE[0].crea('torre_A_grigliati')
    ob = c.crea('torre_A', sporco=lambda co: 0.55 + 0.45 * min(1.0, max(0.0, (co.z - FONDO) / 8.0)))
    # prop: sulle pedane e sul fondo, appoggiati, mai davanti alle bocche degli scivoli
    props = [
        prop('cartello_pavimento_bagnato', (25.9, 12.95, 0.0), 210),
        prop('salvagente_nave', (XI1 - 0.75, px.y - 1.9, -6.3), 15),
        prop('paperella_gigante', (XI1 - 0.9, px.y + 1.4, -6.3 + 0.45 - 0.12 - 0.15), 200),
        prop('ciambella_gonfiabile', (XI1 - 1.05, px.y + 0.35, -6.3 + 0.45 - 0.12 - 0.08), 40),
        prop('lettino_plastica', (q.x - 1.35, q.y + 0.6, -13.3), 90),
        prop('orsacchiotto_grande', (q.x - 1.7, q.y - 1.3, -13.3), 60),
        prop('tubi_galleggianti', (27.5, 23.6, FONDO), 15),
        prop('sedia_bagnino', (38.9, 13.2, FONDO), 200),
        prop('balena_gonfiabile_sgonfia', (31.0, 23.6, FONDO), 10),
        prop('delfino_gonfiabile_sgonfio', (35.2, 18.0, FONDO + 0.6 - 0.12 - 0.1), 120),
        prop('pallone_spiaggia', (27.2, 8.3, FONDO), 0),
        prop('pallone_spiaggia', (22.4, 6.1, FONDO), 70),
        prop('cartello_pavimento_bagnato', (31.0, 11.6, FONDO), 180),
        prop('salvagente_nave', (23.0, 24.8, FONDO), 80),
        prop('lettino_plastica', (21.6, 13.6, FONDO), 90),
        prop('lettino_plastica', (21.6, 15.4, FONDO), 96),
        prop('cestino_pesce', (39.3, 24.9, FONDO), 220),
        prop('secchio_gigante', (22.3, 23.6, FONDO), 30),
        prop('cannoncino_acqua', (37.0, 22.5, FONDO), 200),
        prop('ciambella_gonfiabile', (36.4, 20.4, FONDO + 0.6 - 0.12 - 0.08), 120),
        prop('cartello_pavimento_bagnato', (26.4, 12.2, FONDO), 100),
    ]
    # due cartelloni dipinti del parco sui muri (tra le costole)
    for i, (pos, rot, graf) in enumerate((((24.0, YI1 - 0.005, -9.5), 0, 'p1'), ((36.0, YI0 + 0.005, -11.5), 180, 'p2'))):
        cart = K.cartellone(mats, 3.2, 1.8, nome=f'torre_cartellone_{i}')
        cart.location = Vector(pos)
        cart.rotation_euler = (0, 0, math.radians(rot))
        for j, m in enumerate(cart.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                cart.data.materials[j] = mats.get('cartellone_' + graf)
        props.append(cart)
    polaroid(c2 := K.Costruttore(mats), Vector((q.x - 1.35, q.y + 0.6, -13.3 + 0.36)), Vector((1, 0, 0)))
    pol = c2.crea('torre_polaroid_10')
    # la Polaroid 10 è sulla pedana ovest: nel percorso subito dopo la pedana
    i_ped = [k for k, _ in percorso].index('pedana ovest')
    percorso.insert(i_ped + 1, ('polaroid 10', Vector((q.x - 1.35, q.y + 0.6, -13.3))))
    scivoli = [o for o in bpy.data.objects if o.name.startswith('torre_tubo')]
    return [ob, gr, pol] + scivoli + acque + grov + props, percorso


VERSIONI = {'A': versione_A}


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    nome = argv[0] if argv else 'A'
    K.svuota()
    S._MODELLI.clear()
    mats = K.Materiali(S.PALETTE_SALA, per_render=False)
    S.materiali_nuovi(mats)
    materiali_torre(mats)
    oggetti, percorso = VERSIONI[nome](mats)
    os.makedirs(USCITA, exist_ok=True)
    out = os.path.join(USCITA, f'torre_{nome}.glb')
    K.esporta(oggetti, out)
    tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in oggetti if o.type == 'MESH')
    print(f'GLB {out}: {len(oggetti)} oggetti, {tri} triangoli, {os.path.getsize(out) / 1e6:.1f} MB')
    with open(os.path.join(USCITA, f'torre_{nome}_percorso.json'), 'w') as f:
        json.dump([dict(cosa=k, x=round(p.x, 2), y=round(p.y, 2), z=round(p.z, 2)) for k, p in percorso], f, indent=1)
    if '--blend' in argv:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(argv[argv.index('--blend') + 1]))


if __name__ == '__main__':
    main()
