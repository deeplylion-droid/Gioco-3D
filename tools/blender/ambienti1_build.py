"""Costruisce gli ambienti interni dell'inizio del capitolo 1 e li esporta in GLB per Godot.
  1. corridoio di servizio del ponte inferiore (risveglio, cartellone, porta sala pompe, porta tagliafuoco)
  2. spogliatoi (armadietti, panche, docce, corridoio con vasca lava-piedi, tornello, saracinesca con turbina)
  3. stanzino dei bagnini (fischietti, salvagenti, pronto soccorso, bacheca, sedia, radio, rastrelliera dello zaino)
Uso: /home/user/tools/blender-venv/bin/python tools/blender/ambienti1_build.py [--no-export]
Uscita: assets_src/ambienti_interni/ambienti1.blend e assets_src/ambienti_interni/glb/*.glb
Misure in metri, Z in alto (in Godot diventa Y), pavimento a quota 0. Pianta e nomi in assets_src/ambienti_interni/README.md."""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Euler
import ambienti1_lib as L
import ambienti1_hq as HQ

AI = L.AI
MESHY = os.path.join(AI, 'meshy')
POSTER = os.path.join(AI, 'poster')
R = math.radians
# turbina della saracinesca rifatta con Meshy (TURBINA_CANCELLO=vecchia per la vecchia, solo per i confronti)
TURBINA_NUOVA = os.environ.get('TURBINA_CANCELLO', 'nuova') == 'nuova'   # approvata il 16 ottobre
# finestra del gabbiotto nella parete est del corridoio lava-piedi (y0, y1, z0, z1)
FINESTRA = (15.45, 16.55, 0.85, 2.25)


def materiali():
    M = {n: L.mat_tex(n) for n in L.SCALA_UV}
    M.update(L.materiali_base())
    M['salvagente'] = L.mat_tex('salvagente')
    M['cartellone'] = L.mat_immagine('cartellone_medusa', os.path.join(POSTER, 'cartellone_medusa_vecchio.jpg'), rough=0.55)
    M['cartello_regole'] = L.mat_immagine('cartello_regole', os.path.join(POSTER, 'cartello_regole_vecchio.jpg'), rough=0.5)
    M['poster_bagnino'] = L.mat_immagine('poster_bagnino', os.path.join(POSTER, 'poster_bagnino_vecchio.jpg'), rough=0.7)
    M['pulsante'] = L.mat_colore('pulsante_rosso', (0.7, 0.03, 0.02), rough=0.35, emiss=(1, 0.05, 0.02), forza=4.0)
    M['pulsante_verde'] = L.mat_colore('pulsante_verde', (0.05, 0.5, 0.1), rough=0.35, emiss=(0.1, 1, 0.2), forza=8.0)
    M['impronte'] = L.mat_colore('impronte_bagnate', (0.02, 0.02, 0.02), rough=0.05)
    M['polaroid'] = L.mat_colore('polaroid_retro', (0.82, 0.8, 0.74), rough=0.6)
    M['battiscopa'] = L.mat_colore('battiscopa', (0.06, 0.07, 0.07), rough=0.45, metal=0.3)
    M['battiscopa_piastrelle'] = L.mat_colore('battiscopa_piastrelle', (0.08, 0.2, 0.15), rough=0.25)
    return M


def prop(nome, file, loc, rot_z=0.0, dim=None, asse='max', rot=(0, 0, 0)):
    return L.importa_prop(nome, os.path.join(MESHY, file + '.glb'), loc, R(rot_z), dim, asse, rot)


def col_ob(ob, sopra=0.0):
    """Collisione a scatola grande come l'oggetto e orientata come lui: si urta come un oggetto vero. Da chiamare
    nella zona dell'oggetto (la scatola va nella collisione della collezione attiva). La scatola sta nello spazio
    dell'oggetto: allineata agli assi del mondo, intorno a un oggetto ruotato (la porta aperta dello stanzino)
    copriva il vano e non si passava più (v0.3.9, segnalazione dell'utente del 23 ottobre)."""
    bpy.context.view_layer.update()
    mw = ob.matrix_world
    ls = [v.co for v in ob.data.vertices]
    lo = [min(p[i] for p in ls) for i in range(3)]
    hi = [max(p[i] for p in ls) for i in range(3)]
    if sopra:
        # "sopra" è in metri nel mondo, verso l'alto: lungo l'asse locale più verticale, alla sua scala
        asse = max(range(3), key=lambda i: abs(mw.col[i][2]))
        sc = Vector(mw.col[asse][:3]).length
        if mw.col[asse][2] >= 0:
            hi[asse] += sopra / sc
        else:
            lo[asse] -= sopra / sc
    L.col_scatola(tuple(lo), tuple(hi), matrice=mw)
    return ob


def attacca(ob, d, gioco=0.001, massimo=0.2):
    """Sposta ob lungo la direzione d finché tocca quello che c'è (muro, pavimento, rastrelliera): raggi dai suoi
    punti più avanti in quella direzione; si ferma a 'gioco' dal sostegno. Come posa.gd in Godot (controllo di
    posizionamento severo del 22 ottobre: niente oggetti staccati di pochi centimetri)."""
    bpy.context.view_layer.update()
    d = Vector(d).normalized()
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    fronte = max(p.dot(d) for p in ws)
    punti = [p for p in ws if p.dot(d) > fronte - 0.003]
    dg = bpy.context.evaluated_depsgraph_get()
    vicino = None
    for p in punti[::max(1, len(punti) // 200)]:
        ok, loc, _n, _i, colpito, _m = bpy.context.scene.ray_cast(dg, p + d * 0.0005, d, distance=massimo)
        if ok and colpito.name != ob.name:
            t = (loc - p).dot(d)
            vicino = t if vicino is None else min(vicino, t)
    if vicino is None:
        print(f'ATTENZIONE: {ob.name}: niente entro {massimo} m verso {tuple(d)}')
        return ob
    ob.location += d * (vicino - gioco)
    print(f'attacca {ob.name}: spostato di {(vicino - gioco) * 100:.1f} cm')
    return ob


def lampada(nome, p, n, M, watt):
    """Luce d'emergenza a muro, a contatto con la parete (prima stavano 2 cm staccate, collaudo del 22 ottobre)."""
    c, v, l = L.lampada_emergenza(nome, p, n, M, watt=watt)
    prima = c.location.copy()
    attacca(c, tuple(-k for k in n))
    d = c.location - prima
    for o in (v, l):
        if o is not None:
            o.location += d
    return c, v, l


def copia(ob, nome, loc, rot_z=None, rot=None):
    o = ob.copy(); o.name = nome
    L._link(o); o.location = loc
    if rot_z is not None:
        o.rotation_euler = (0, 0, R(rot_z))
    if rot is not None:
        o.rotation_euler = rot
    return o


def pozza(nome, centro, rx, ry, M, seme=0, z=0.004):
    """Pozza d'acqua: poligono irregolare appena sopra il pavimento (oggetto separato, il livello si puo' animare)."""
    import bmesh
    rnd = random.Random(seme)
    bm = bmesh.new(); n = 28
    fase = [rnd.uniform(0, 6.28) for _ in range(3)]
    vs = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + 0.18 * math.sin(3 * a + fase[0]) + 0.12 * math.sin(5 * a + fase[1]) + 0.08 * math.sin(7 * a + fase[2])
        vs.append(bm.verts.new((centro[0] + rx * k * math.cos(a), centro[1] + ry * k * math.sin(a), z)))
    bm.faces.new(vs)
    ob = L._ob_da_bm(nome, bm, M['acqua'])
    L.uv_scatola(ob, 1.0)
    ob.visible_shadow = False   # nei render Cycles l'acqua non deve fare ombra sul pavimento
    return ob


def cornice_porta(nome, lato, a, b, za, piano_muro, M, mat=None, s=0.08, sporge=0.04, entrambi=True):
    """Telaio attorno a un'apertura nella parete. lato N/S: a,b lungo x; E/W lungo y. piano_muro: coord della faccia interna."""
    mat = mat or M['porta_lamiera']
    parti = []
    facce = [(piano_muro, 1 if lato in ('S', 'W') else -1)]
    if entrambi:
        spess = 0.2
        facce.append((piano_muro - spess if lato in ('S', 'W') else piano_muro + spess, -1 if lato in ('S', 'W') else 1))
    for p, verso in facce:
        p0, p1 = (p, p + verso * sporge) if verso > 0 else (p + verso * sporge, p)
        pezzi = [((a - s, za), (a, 0)), ((b, za), (b + s, 0)), ((a - s, za + s), (b + s, za))]
        for (u0, z1), (u1, z0) in pezzi:
            if lato in ('N', 'S'):
                parti.append(L.scatola(nome, (u0, p0, z0), (u1, p1, z1), mat, smussa=0.012))
            else:
                parti.append(L.scatola(nome, (p0, u0, z0), (p1, u1, z1), mat, smussa=0.012))
    return L.unisci(nome, parti)


def porta_hq(vecchia, file, cerniera, w, h, rot_z, lato):
    """Sostituisce la porta procedurale con il modello Meshy: stesso nome, origine sul cardine.
    lato: -1 = cardine sul bordo sinistro del modello (visto dal fronte), +1 = destro."""
    if not HQ.disponibile(file):
        return vecchia
    nome = vecchia.name
    for c in list(vecchia.children):
        bpy.data.objects.remove(c)
    bpy.data.objects.remove(vecchia)
    return HQ.metti(nome, file, cerniera, (w, None, h), rot_z=rot_z, perno=(lato * w / 2, 0, 0))


def soffitto_nave(nome, x0, x1, y0, y1, h, M, lungo='x', passo=1.25, mancanti=(), pende=None, travi=True, seme=0):
    """Soffitto da nave: pannelli di lamiera smussati tra le ordinate, con i giunti aperti di 1 cm.
    lungo = asse lungo cui si susseguono i pannelli. mancanti = indici dei pannelli tolti (si vede il buio
    sopra); pende = indice del pannello staccato da un lato. travi = ordinate tra i pannelli."""
    parti = []
    a0, a1 = (x0, x1) if lungo == 'x' else (y0, y1)
    b0, b1 = (y0, y1) if lungo == 'x' else (x0, x1)
    n = max(1, round((a1 - a0) / passo)); pa = (a1 - a0) / n
    rnd = random.Random(seme)
    for i in range(n):
        u0, u1 = a0 + i * pa + 0.006, a0 + (i + 1) * pa - 0.006
        z0 = h - 0.07 + rnd.uniform(-0.004, 0.004)
        lo, hi = ((u0, b0 + 0.01, z0), (u1, b1 - 0.01, z0 + 0.02)) if lungo == 'x' else ((b0 + 0.01, u0, z0), (b1 - 0.01, u1, z0 + 0.02))
        if i in mancanti:
            continue
        p = L.scatola(f'{nome}_pannello', lo, hi, M['soffitto_lamiera'], smussa=0.008)
        if pende is not None and i == pende:
            # staccato dal lato u0: ruota attorno al bordo opposto
            perno = Vector((u1, (b0 + b1) / 2, z0 + 0.01)) if lungo == 'x' else Vector(((b0 + b1) / 2, u1, z0 + 0.01))
            asse = 'Y' if lungo == 'x' else 'X'
            ang = math.radians(-24 if lungo == 'x' else 24)
            p.data.transform(Matrix.Translation(perno) @ Matrix.Rotation(ang, 4, asse) @ Matrix.Translation(-perno))
            L.uv_scatola(p)
        parti.append(p)
        if travi and i > 0:
            c = a0 + i * pa
            lo, hi = ((c - 0.05, b0, h - 0.16), (c + 0.05, b1, h)) if lungo == 'x' else ((b0, c - 0.05, h - 0.16), (b1, c + 0.05, h))
            parti.append(L.scatola(f'{nome}_trave', lo, hi, M['soffitto_lamiera'], smussa=0.015))
    return L.unisci(nome, parti)


def condotto_aria(nome, p0, p1, w, hh, M, passo=1.5):
    """Condotto rettangolare smussato lungo x (da p0 a p1, centro della sezione) con flange e bocchette."""
    x0, y, z = p0; x1 = p1[0]
    parti = [L.scatola(nome, (x0, y - w / 2, z - hh / 2), (x1, y + w / 2, z + hh / 2), M['metallo_grezzo'], smussa=0.02)]
    x = x0 + passo
    k = 0
    while x < x1 - 0.2:
        parti.append(L.scatola(nome + '_flangia', (x - 0.025, y - w / 2 - 0.015, z - hh / 2 - 0.015), (x + 0.025, y + w / 2 + 0.015, z + hh / 2 + 0.015), M['metallo_grezzo'], smussa=0.008))
        if k % 2 == 0:
            for j in range(5):
                xx = x + 0.25 + j * 0.06
                parti.append(L.scatola(nome + '_bocchetta', (xx, y - w / 2 + 0.05, z - hh / 2 - 0.004), (xx + 0.03, y + w / 2 - 0.05, z - hh / 2 + 0.002), M['nero'], uv=False))
        x += passo; k += 1
    return L.unisci(nome, parti)


def canalina_cavi(nome, x0, x1, y, z, M):
    parti = [L.scatola(nome, (x0, y - 0.11, z - 0.01), (x1, y + 0.11, z), M['lamiera_grata'], smussa=0.004),
             L.scatola(nome, (x0, y - 0.115, z - 0.01), (x1, y - 0.105, z + 0.05), M['metallo_grezzo']),
             L.scatola(nome, (x0, y + 0.105, z - 0.01), (x1, y + 0.115, z + 0.05), M['metallo_grezzo'])]
    rnd = random.Random(int(x0 * 10 + y * 100))
    for k, (dy, r, mat) in enumerate([(-0.06, 0.016, 'gomma'), (-0.02, 0.012, 'gomma'), (0.02, 0.018, 'gomma'), (0.065, 0.01, 'vernice_rossa')]):
        pts = [(x0, y + dy, z + r)]
        x = x0
        while x < x1:
            x = min(x1, x + rnd.uniform(1.5, 3.0))
            pts.append((x, y + dy + rnd.uniform(-0.01, 0.01), z + r + rnd.uniform(0, 0.01)))
        parti.append(L.tubo_percorso(nome + '_cavo', pts, r, M[mat], flange=False))
    # un cavo che pende fuori dalla canalina
    xm = (x0 + x1) / 2 + rnd.uniform(-2, 2)
    parti.append(L.tubo_percorso(nome + '_cavo_pende', [(xm - 0.6, y + 0.1, z + 0.02), (xm - 0.2, y + 0.18, z - 0.35), (xm + 0.3, y + 0.15, z - 0.42), (xm + 0.7, y + 0.1, z + 0.02)], 0.011, M['gomma'], flange=False))
    return L.unisci(nome, parti)


def sprinkler(nome, x, y, z_tubo, z_testa, M):
    """Stacco verticale dal tubo antincendio e testina Meshy (o una testina semplice)."""
    parti = [L.cilindro(nome + '_stacco', (x, y, z_tubo), (x, y, z_testa + 0.04), 0.012, M['vernice_rossa'], seg=16)]
    if HQ.disponibile('sprinkler'):
        HQ.metti(nome, 'sprinkler', (x, y, z_testa - 0.06), (None, None, 0.1))
    else:
        parti.append(L.cilindro(nome, (x, y, z_testa + 0.04), (x, y, z_testa), 0.015, M['cromo'], seg=16))
    return L.unisci(nome + '_stacco', parti)


def pannello_ammaccato(nome, lo, hi, M, seme, mat='lamiera_crema'):
    """Lamiera ammaccata riportata sulla parete (sporge 1 cm), dello stesso colore della fascia su cui sta."""
    p = L.scatola(nome, lo, hi, M[mat], smussa=0.006)
    L.ammacca(p, 0.02, 2.2, seme, 10)
    L.uv_scatola(p)
    return p


def costole(nome, x0, x1, y0, y1, h, passo, M, salta_s=(), salta_n=()):
    """Costole della nave (rinforzi verticali sulle pareti lunghe e travi sul soffitto).
    salta_s / salta_n: intervalli di x liberi (porte, cartelloni) sulla parete sud / nord."""
    parti = []
    libero = lambda x, salta: all(not (a - 0.1 < x < b + 0.1) for a, b in salta)
    if True:
        x = x0 + passo
        while x < x1 - 0.3:
            if libero(x, salta_s):
                parti.append(L.scatola(nome, (x - 0.06, y0 - 0.02, 0), (x + 0.06, y0 + 0.07, h), M['lamiera_crema'], smussa=0.018))
            if libero(x, salta_n):
                parti.append(L.scatola(nome, (x - 0.06, y1 - 0.07, 0), (x + 0.06, y1 + 0.02, h), M['lamiera_crema'], smussa=0.018))
            parti.append(L.scatola(nome, (x - 0.07, y0, h - 0.17), (x + 0.07, y1, h + 0.02), M['soffitto_lamiera'], smussa=0.02))
            x += passo
    return L.unisci(nome, parti)


def grata_parete(nome, centro, w, h, normale, M):
    """Griglia di ventilazione a lamelle sulla parete."""
    n = Vector(normale); parti = []
    parti.append(L.scatola(nome, (-w / 2, -h / 2, 0), (w / 2, h / 2, 0.02), M['metallo_grezzo'], uv=False))
    k = int(h / 0.04)
    for i in range(k):
        z = -h / 2 + 0.02 + i * 0.04
        parti.append(L.scatola(nome, (-w / 2 + 0.02, z, 0.02), (w / 2 - 0.02, z + 0.012, 0.035), M['nero'], uv=False))
    ob = L.unisci(nome, parti)
    q = n.to_track_quat('Z', 'Y')
    ob.matrix_world = Matrix.Translation(centro) @ q.to_matrix().to_4x4()
    L.uv_scatola(ob, 0.5)
    return ob


# =====================================================================================
# 1. CORRIDOIO DEL PONTE INFERIORE   x 0..22, y 0..2.6, h 2.7
# =====================================================================================
def corridoio(M):
    L.usa_collezione('corridoio')
    X0, X1, Y0, Y1, H = 0.0, 22.0, 0.0, 2.6, 2.7
    mats = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'], battiscopa=M['battiscopa'])
    ap = {
        'E': [(0.7, 1.9, 0, 2.1)],          # porta tagliafuoco (alle spalle del giocatore)
        'S': [(17.0, 18.0, 0, 2.05)],       # porta della sala pompe
        'N': [(6.0, 7.6, 0, 2.2)],          # passaggio verso gli spogliatoi
        'W': [(0.8, 1.8, 0, 2.05)],         # porta di servizio chiusa in fondo
    }
    statico = L.stanza('corridoio', X0, Y0, X1, Y1, H, mats, ap)
    statico.append(costole('corridoio_costole', X0, X1, Y0, Y1, H, 2.5, M, salta_s=[(13.6, 15.6), (16.9, 18.1)], salta_n=[(5.9, 7.7)]))
    # telai delle porte
    statico.append(cornice_porta('telaio_tagliafuoco', 'E', 0.7, 1.9, 2.1, X1, M, M['vernice_rossa']))
    statico.append(cornice_porta('telaio_pompe', 'S', 17.0, 18.0, 2.05, Y0, M, M['vernice_gialla']))
    statico.append(cornice_porta('telaio_spogliatoi', 'N', 6.0, 7.6, 2.2, Y1, M, entrambi=False))
    statico.append(cornice_porta('telaio_servizio', 'W', 0.8, 1.8, 2.05, X0, M))
    # strisce gialle e nere sulla soglia della sala pompe
    statico.append(L.scatola('soglia_pompe', (17.0, -0.2, 0), (18.0, 0.04, 0.03), M['vernice_gialla']))

    # tubi sul soffitto, lato nord, per tutta la lunghezza; uno scende vicino al passaggio
    tubi = [
        *tubo_grande_con_valvola(M),
        L.tubo_percorso('tubo_rosso', [(0, 2.12, 2.48), (22, 2.12, 2.48)], 0.05, M['vernice_rossa'], passo_flange=3.0),
        L.tubo_percorso('tubo_piccolo', [(0, 2.48, 2.12), (8.2, 2.48, 2.12), (8.2, 2.48, 0.25), (8.2, 2.2, 0.25), (8.2, 2.2, -0.05)], 0.035, M['metallo_grezzo'], passo_flange=1.5),
        L.tubo_percorso('tubo_sud', [(0, 0.22, 2.45), (16.4, 0.22, 2.45), (16.4, 0.22, 2.3), (22, 0.22, 2.3)], 0.06, M['metallo_grezzo'], passo_flange=2.5),
    ]
    staffe = []
    for x in [1.2 + 2.5 * i for i in range(9)]:
        staffe.append(L.scatola('staffa', (x - 0.03, 2.0, 2.3), (x + 0.03, 2.6, 2.56), M['metallo_grezzo']))
        staffe.append(L.scatola('staffa', (x - 0.03, 0.0, 2.36), (x + 0.03, 0.32, 2.4), M['metallo_grezzo']))
    statico += tubi + [L.unisci('staffe_tubi', staffe)]
    # canalina dei cavi sul lato sud
    statico.append(L.scatola('canalina_cavi', (0, 0.0, 2.05), (22, 0.12, 2.1), M['metallo_grezzo']))
    # griglie di ventilazione
    statico.append(grata_parete('grata_vent_1', (4.0, 2.595, 2.0), 0.5, 0.35, (0, -1, 0), M))
    statico.append(grata_parete('grata_vent_2', (11.5, 0.005, 1.95), 0.5, 0.35, (0, 1, 0), M))
    statico.append(grata_parete('grata_vent_3', (20.0, 2.595, 0.35), 0.6, 0.3, (0, -1, 0), M))

    # ---- porta tagliafuoco (cardine sul lato y=0.7; in Godot parte aperta e si chiude da sola)
    pt = [L.scatola('porta_tagliafuoco', (21.93, 0.72, 0.01), (22.0, 1.88, 2.08), M['vernice_rossa'])]
    pt.append(L.scatola('pt_vetro_cornice', (21.91, 1.15, 1.35), (21.93, 1.45, 1.75), M['metallo_grezzo']))
    pt.append(L.cilindro('pt_maniglia', (21.85, 1.72, 1.05), (21.93, 1.72, 1.05), 0.02, M['cromo']))
    pt.append(L.cilindro('pt_leva', (21.85, 1.72, 1.05), (21.85, 1.55, 1.02), 0.015, M['cromo']))
    pt.append(L.scatola('pt_chiudiporta', (21.85, 0.8, 1.98), (21.93, 1.3, 2.05), M['metallo_grezzo']))
    porta_tf = L.unisci('porta_tagliafuoco', pt)
    L.ammacca(porta_tf, 0.004, 2.0, 3.0, 3)
    L.origine(porta_tf, (21.965, 0.72, 0))
    vtf = L.scatola('porta_tagliafuoco_vetro', (21.915, 1.17, 1.37), (21.925, 1.43, 1.73), M['vetro_sporco'], uv=False)
    L.figlio(vtf, porta_tf)
    porta_tf = porta_hq(porta_tf, 'porta_tagliafuoco', (21.965, 0.72, 0.01), 1.16, 2.07, R(-90), +1)
    attacca(porta_tf, (0, 0, -1))   # poggia sul pavimento (stava 1 cm sopra, controllo del 22 ottobre)
    # oltre la porta: un tratto di corridoio buio da cui si e' arrivati
    statico += L.stanza('corridoio_oltre', 22.2, 0.4, 25.0, 2.2, 2.4, mats, {'W': [(0.4, 2.2, 0, 2.4)]})

    # ---- porta della sala pompe (cardine x=17; maniglione antipanico sul lato della sala pompe, y<0)
    pp = [L.scatola('porta_sala_pompe', (17.02, -0.13, 0.01), (17.98, -0.07, 2.03), M['porta_lamiera'])]
    pp.append(L.scatola('pp_piastra', (17.75, -0.07, 0.95), (17.9, -0.06, 1.25), M['cromo']))           # lato corridoio: solo una piastra
    pp.append(L.scatola('pp_oblo_cornice', (17.3, -0.06, 1.35), (17.7, -0.05, 1.8), M['metallo_grezzo']))
    pp.append(L.scatola('pp_maniglione', (17.15, -0.24, 0.98), (17.85, -0.2, 1.04), M['vernice_rossa']))   # lato sala pompe
    for x in (17.12, 17.88):
        pp.append(L.scatola('pp_supporto', (x - 0.025, -0.2, 0.97), (x + 0.025, -0.13, 1.05), M['metallo_grezzo']))
    porta_pp = L.unisci('porta_sala_pompe', pp)
    L.ammacca(porta_pp, 0.004, 2.5, 5.0, 3)
    L.origine(porta_pp, (17.02, -0.1, 0))
    vpp = L.scatola('porta_sala_pompe_vetro', (17.33, -0.075, 1.38), (17.67, -0.065, 1.77), M['vetro_sporco'], uv=False)
    L.figlio(vpp, porta_pp)
    porta_pp = porta_hq(porta_pp, 'porta_servizio', (17.02, -0.1, 0.01), 0.96, 2.02, R(180), +1)
    if HQ.disponibile('porta_servizio'):
        # maniglione antipanico sul lato della sala pompe
        mb = [L.cilindro('maniglione', (17.15, -0.25, 1.0), (17.85, -0.25, 1.0), 0.022, M['vernice_rossa'], seg=24)]
        for x in (17.15, 17.85):
            mb.append(L.cilindro('maniglione', (x, -0.25, 1.0), (x, -0.16, 1.0), 0.018, M['cromo'], seg=16))
        L.figlio(L.unisci('maniglione_antipanico', mb), porta_pp)
    # pianerottolo e scala che scende verso la sala pompe (si collega al piano sotto)
    pian = L.stanza('scala_pompe', 16.2, -3.9, 18.8, -0.2, 2.7, dict(pav=M['cemento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'], battiscopa=M['battiscopa']),
                    {'N': [(17.0, 18.0, 0, 2.05)], 'S': [(16.4, 18.6, 0, 0.5)]}, pavimento=False)
    L.raccogli(True)
    pian.append(L.scatola('scala_pompe_pian', (16.0, -1.4, -0.2), (19.0, 0.0, 0), M['cemento']))
    L.raccogli(False)
    # collisione della scala: una rampa (36 gradi) invece dei gradini, sulla retta dei nasi: dal bordo del
    # pianerottolo (y -1,4, z 0) al piano di sotto (y -3,9, z -1,8), lunga 3,08 m
    rampa = L.scatola('scala_pompe_rampa-colonly', (16.4, -1.54, -0.1), (18.6, 1.54, 0.0), None, uv=False)
    rampa.data.transform(Matrix.Rotation(math.atan2(1.8, 2.5), 4, 'X'))
    rampa.location = (0, -2.65, -0.9); rampa.hide_render = True; rampa.display_type = 'WIRE'
    for i in range(10):
        y = -1.4 - i * 0.25; z = -0.18 * (i + 1)
        pian.append(L.scatola('gradino', (16.4, y - 0.25, z - 0.2), (18.6, y, z), M['lamiera_grata']))
    # corrimano fissato al muro est del vano (x 18,8): a 8 cm dal muro con tre staffe (prima stava a 25 cm, senza
    # sostegni, in mezzo a chi scende: controllo di posizionamento del 23 ottobre, stato tappa7)
    CX, CA, CB = 18.72, (-1.3, 0.95), (-3.9, -0.95)
    pian.append(L.tubo_percorso('corrimano_scala', [(CX, CA[0], CA[1]), (CX, CB[0], CB[1])], 0.025, M['vernice_gialla'], flange=False))
    for t in (0.1, 0.5, 0.9):
        yy, zz = CA[0] + (CB[0] - CA[0]) * t, CA[1] + (CB[1] - CA[1]) * t
        pian.append(L.cilindro('corrimano_staffa', (CX, yy, zz - 0.02), (CX, yy, zz - 0.07), 0.012, M['vernice_gialla'], seg=10))
        pian.append(L.cilindro('corrimano_staffa', (CX, yy, zz - 0.07), (18.8, yy, zz - 0.07), 0.012, M['vernice_gialla'], seg=10))
        pian.append(L.cilindro('corrimano_rosetta', (18.79, yy, zz - 0.07), (18.8, yy, zz - 0.07), 0.035, M['vernice_gialla'], seg=16))
    statico += pian
    # porta di servizio in fondo, chiusa a chiave
    ps = [L.scatola('porta_servizio', (0.0, 0.82, 0.01), (0.06, 1.78, 2.03), M['porta_lamiera'])]
    ps.append(L.scatola('ps_oblo', (0.06, 1.1, 1.35), (0.075, 1.5, 1.8), M['metallo_grezzo']))
    ps.append(L.cilindro('ps_maniglia', (0.06, 1.65, 1.0), (0.13, 1.65, 1.0), 0.02, M['cromo']))
    porta_s = L.unisci('porta_servizio', ps); L.ammacca(porta_s, 0.005, 2.0, 9.0, 3)
    porta_s = porta_hq(porta_s, 'porta_servizio', (0.04, 0.82, 0.01), 0.96, 2.02, R(90), -1)
    attacca(porta_s, (0, 0, -1))   # chiusa, poggia sulla soglia (stava 1 cm sopra)
    L.col_scatola((0.0, 0.8, 0.0), (0.08, 1.8, 2.05))
    if not HQ.disponibile('porta_servizio'):
        statico.append(L.scatola('porta_servizio_vetro', (0.074, 1.13, 1.38), (0.078, 1.47, 1.77), M['vetro_sporco'], uv=False))

    # ---- cartellone della mascotte (accanto alla porta della sala pompe, lato sud)
    cx, cz, cw, ch = 14.6, 1.3, 1.5, 2.0
    statico.append(L.piano('cartellone_medusa', (cx, 0.016, cz), cw, ch, M['cartellone'], rot=(R(90), 0, 0)))
    cor = [L.scatola('cornice', (cx - cw / 2 - 0.05, 0, cz - ch / 2 - 0.05), (cx + cw / 2 + 0.05, 0.03, cz - ch / 2), M['vernice_gialla']),
           L.scatola('cornice', (cx - cw / 2 - 0.05, 0, cz + ch / 2), (cx + cw / 2 + 0.05, 0.03, cz + ch / 2 + 0.05), M['vernice_gialla']),
           L.scatola('cornice', (cx - cw / 2 - 0.05, 0, cz - ch / 2), (cx - cw / 2, 0.03, cz + ch / 2), M['vernice_gialla']),
           L.scatola('cornice', (cx + cw / 2, 0, cz - ch / 2), (cx + cw / 2 + 0.05, 0.03, cz + ch / 2), M['vernice_gialla'])]
    statico.append(L.unisci('cornice_cartellone', cor))
    # le costole passano davanti al cartellone? no: il cartellone sta tra x=12.5 e 15 (costole a 12.5 e 15)

    # ---- luci: rosse d'emergenza e neon quasi tutti spenti
    luci = []
    # (collaudo del 22 ottobre) a muro, a contatto; quelle a nord sotto il tubo grande (bordo basso 2,30 m) e sopra i
    # 2 m; la 01 sul muro sud (a nord, fino a x 8,2, c'è anche il tubo piccolo a 2,12 m), sopra la canalina dei cavi
    # (2,10 m) come la 07; la 04, sopra la porta della sala pompe, più in alto del tubo sud (lì scende a 2,30 m)
    for i, (p, n) in enumerate([((3.0, 0.02, 2.21), (0, 1, 0)), ((10.8, 2.58, 2.11), (0, -1, 0)), ((19.2, 2.58, 2.11), (0, -1, 0)),
                                ((17.5, 0.02, 2.48), (0, 1, 0)), ((21.98, 1.3, 2.4), (-1, 0, 0)), ((0.02, 1.3, 2.35), (1, 0, 0)),
                                ((7.5, 0.02, 2.21), (0, 1, 0)), ((17.5, 2.58, 2.11), (0, -1, 0))]):
        c, v, l = lampada(f'luce_emergenza_{i + 1:02d}', p, n, M, watt=32 if i != 4 else 22)
        luci += [c, v]
    for i, (x, stato, app) in enumerate([(4.2, 'spento', 0), (10.0, 'sfarfalla', 0), (15.5, 'spento', 0.35), (20.0, 'spento', 0)]):
        c, t, l = L.neon_soffitto(f'neon_corridoio_{i + 1}', (x, 1.3, 0), 1.2, M, H, stato, watt=90, appeso=app, rot_z=0)
        luci += [c, t]

    # ---- acqua sul pavimento (pozze separate: in Godot possono avere lo shader dell'acqua)
    pz = [pozza('pozza_corridoio_1', (13.5, 1.0, 0), 2.2, 0.75, M, 1), pozza('pozza_corridoio_2', (9.0, 1.6, 0), 1.3, 0.6, M, 2),
          pozza('pozza_corridoio_3', (19.6, 1.5, 0), 1.0, 0.55, M, 3), pozza('pozza_corridoio_4', (4.0, 1.2, 0), 1.5, 0.7, M, 4),
          pozza('pozza_corridoio_5', (17.4, 0.5, 0), 0.6, 0.4, M, 5)]
    L.unisci('acqua_pozze_corridoio', pz)
    L.vuoto('emit_goccia_corridoio_1', (13.2, 2.32, 2.29))     # gocciolio dal tubo sopra la pozza
    L.vuoto('emit_goccia_corridoio_2', (19.4, 2.32, 2.29))

    # ---- oggetti
    # estintore appeso con la staffa (16 ottobre): il modello di prima aveva una tavola di legno dietro, che nel
    # gioco stava davanti. Questo non ha tavole: la staffa (lato +x del modello) va contro il muro, il tubo di lato.
    # gli oggetti dove si passa hanno la collisione (controllo di posizionamento del 22 ottobre: si attraversavano)
    col_ob(attacca(HQ.metti('estintore', 'estintore_staffa', (9.6, 0.21, 0.84), (None, None, 0.62), rot_z=R(-90)), (0, -1, 0)))
    col_ob(prop('cestino', 'cestino', (5.3, 2.3, 0), 30, 0.55, 'z'))
    prop('paperella', 'paperella', (13.9, 1.2, 0.0), 140, 0.09)
    col_ob(prop('pallone', 'pallone', (2.2, 0.6, 0), 0, 0.42))
    # le due valvole del corridoio sono in linea sul tubo grande del soffitto: tubo_grande_con_valvola
    if HQ.disponibile('cartello_pericolo'):
        col_ob(HQ.metti('cartello_corridoio', 'cartello_pericolo', (16.2, 1.95, 0), (None, None, 0.62), rot_z=R(-60)))
    # l'asciugamano per terra, più vicino al muro sud (stava in mezzo alla strada)
    # mucchio alto 52 cm contro il muro sud: si urta (scatola orientata), il corridoio resta libero per 1,3 m
    col_ob(prop('asciugamano_corridoio', 'asciugamano', (8.4, 0.45, 0), 75, 0.8))

    # ---- punti per il gioco
    L.vuoto('marker_risveglio', (20.4, 1.25, 0.0), (0, 0, R(90)), 'ARROWS', 0.5)    # sdraiato, guarda verso ovest (-X)
    L.vuoto('marker_polaroid_P1', (20.9, 0.55, 0.005), (0, 0, R(20)), 'CUBE', 0.05)
    L.vuoto('marker_porta_tagliafuoco_cardine', (21.965, 0.72, 0), dim=0.3)
    # soffitto da nave: pannelli tra le ordinate (due mancano), condotto dell'aria,
    # canalina con i cavi, sprinkler sul tubo rosso. Il pannello 10 pendeva (pende=10): nella prova
    # della v0.3.2 l'utente l'ha visto come un pezzo di soffitto "buggato in obliquo", ora è dritto.
    statico.append(soffitto_nave('soffitto_pannelli', X0, X1, Y0, Y1, H, M, 'x', 1.25, mancanti=(5, 13), pende=None, travi=False, seme=3))
    statico.append(condotto_aria('condotto_aria', (0.0, 0.62, 2.5), (X1, 0.62, 2.5), 0.38, 0.2, M))
    statico.append(canalina_cavi('canalina_soffitto', 0.0, X1, 1.86, 2.56, M))
    for k, x in enumerate([1.8, 5.2, 8.6, 12.1, 15.6, 19.0]):
        statico.append(sprinkler(f'sprinkler_corridoio_{k + 1}', x, 2.12, 2.43, 2.3, M))
    # due lamiere ammaccate (lontano dal cartellone, che sta tra x 13,85 e 15,35 sul lato sud)
    # sta nello zoccolo (fino a 1,1 m): color petrolio come lui. Crema sembrava una tavola di legno
    statico.append(pannello_ammaccato('lamiera_ammaccata_1', (1.1, 2.58, 0.25), (2.1, 2.6, 1.05), M, 21.0, 'lamiera_petrolio'))   # su muro libero
    # (la seconda lamiera ammaccata stava vicino all'estintore: tolta del tutto, questionario del 16 ottobre)
    L.unisci('corridoio_statico', statico)
    L.crea_collisione('corridoio', 'corridoio')


# =====================================================================================
# 2. SPOGLIATOI   x 3..11, y 3..11, h 2.9  + docce, corridoio lava-piedi, gabbiotto
# =====================================================================================
def armadietto(nome, x, y, faccia, M, stato='chiuso', ang=0, mat_anta=None, seme=0, w=0.4, d=0.5, h=1.8):
    """Un armadietto. faccia: +1 se l'anta guarda verso +x, -1 verso -x. Ritorna (corpo, anta)."""
    zb = 0.12
    # corpo costruito con l'anta verso +x, poi specchiato
    parti = [
        L.scatola(nome, (0, 0, zb), (0.02, w, zb + h), M['armadietto_verde']),               # fondo
        L.scatola(nome, (0, 0, zb), (d, 0.015, zb + h), M['armadietto_verde']),              # fianco
        L.scatola(nome, (0, w - 0.015, zb), (d, w, zb + h), M['armadietto_verde']),
        L.scatola(nome, (0, 0, zb + h - 0.02), (d, w, zb + h), M['armadietto_verde']),       # cielo
        L.scatola(nome, (0, 0, zb), (d, w, zb + 0.02), M['armadietto_verde']),
        L.scatola(nome, (0, 0.015, zb + 1.45), (d - 0.03, w - 0.015, zb + 1.47), M['armadietto_verde']),  # ripiano
        L.cilindro(nome, (0.25, 0.03, zb + 1.38), (0.25, w - 0.03, zb + 1.38), 0.008, M['cromo'], seg=6),   # asta appendiabiti
    ]
    corpo = L.unisci(nome + '_corpo', parti)
    ma = mat_anta or M['armadietto_verde']
    ap = [L.scatola(nome, (d - 0.02, 0.01, zb + 0.02), (d, w - 0.01, zb + h - 0.02), ma)]
    for zz in (zb + 1.55, zb + 1.6, zb + 1.65, zb + 0.15, zb + 0.2, zb + 0.25):
        ap.append(L.scatola(nome, (d - 0.001, 0.09, zz), (d + 0.004, w - 0.09, zz + 0.018), M['nero'], uv=False))
    ap.append(L.scatola(nome, (d, w - 0.07, zb + 0.95), (d + 0.03, w - 0.045, zb + 1.1), M['cromo'], uv=False))  # maniglia
    ap.append(L.scatola(nome, (d, 0.12, zb + 1.3), (d + 0.003, w - 0.12, zb + 1.36), M['plastica_bianca'], uv=False))  # targhetta vuota
    anta = L.unisci(nome + '_anta', ap)
    L.ammacca(anta, 0.006, 4.0, seme, 4)
    L.origine(anta, (d, 0.01, 0))
    anta.rotation_euler = (0, 0, R(-ang))
    zoc = L.scatola(nome + '_zoccolo', (0.03, 0, 0), (d - 0.03, w, zb), M['lamiera_petrolio'])
    for o in (corpo, anta, zoc):
        if faccia < 0:
            o.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(R(180), 4, 'Z') @ Matrix.Translation((0, -w, 0)) @ o.matrix_world
        else:
            o.matrix_world = Matrix.Translation((x, y, 0)) @ o.matrix_world
    corpo = L.unisci(nome + '_corpo', [corpo, zoc])
    for o in (corpo,):
        L.uv_scatola(o)
    if stato == 'mancante':
        bpy.data.objects.remove(anta); anta = None
    return corpo, anta


def fila_armadietti(prefisso, x, y0, n, faccia, M, stati, seme=0):
    if HQ.disponibile('armadietto_anta') and HQ.disponibile('armadietto_corpo'):
        return fila_armadietti_hq(prefisso, x, y0, n, faccia, M, stati, seme)
    corpi, ante, speciali = [], [], {}
    colori = {3: M['vernice_gialla'], 9: M['vernice_rossa'], 14: M['vernice_gialla']}
    for i in range(n):
        st, ang = stati.get(i, ('chiuso', random.uniform(0, 3)))
        c, a = armadietto(f'{prefisso}_{i:02d}', x, y0 + i * 0.4, faccia, M, st, ang, colori.get((i + seme) % 17), seme + i)
        corpi.append(c)
        if a is not None:
            if st == 'speciale':
                speciali[i] = a
            else:
                ante.append(a)
    return L.unisci(prefisso + '_corpi', corpi), (L.unisci(prefisso + '_ante', ante) if ante else None), speciali


CERNIERE = []   # le cerniere delle ante aperte, nella parte fissa degli spogliatoi


def cerniere(nome, cern, faccia, yy):
    """La cerniera tra il telaio dell'armadietto e l'anta aperta: due piastrine sul fronte del telaio e il perno
    continuo sull'asse dell'anta (è sull'asse, quindi resta giusto anche per l'anta che sbatte). Prima l'anta
    girava nel vuoto, 1-3 cm davanti al telaio (controllo di posizionamento severo del 22 ottobre)."""
    fx, py = cern[0], cern[1]
    telaio = yy + 0.01 if faccia > 0 else yy + 0.39
    parti = []
    for z in (0.32, 1.42):
        y0, y1 = sorted((telaio, py + 0.006 * (1 if faccia > 0 else -1)))
        x0, x1 = sorted((fx, fx - 0.012 * faccia))
        parti.append(L.scatola(nome + '_cerniera', (x0, y0, z), (x1, y1, z + 0.1), MAT_CERNIERA[0]))
    # cerniera continua (a pianoforte) lungo tutta l'anta: lo spigolo dell'anta, smussato, passa a 1,8 cm
    # dall'asse, a ogni apertura
    parti.append(L.cilindro(nome + '_perno', (fx, py, 0.2), (fx, py, 1.72), 0.016, MAT_CERNIERA[0], seg=12))
    return parti


MAT_CERNIERA = [None]


def fila_armadietti_hq(prefisso, x, y0, n, faccia, M, stati, seme=0):
    """Armadietti Meshy: quelli chiusi sono il modello intero, quelli aperti sono il corpo vuoto
    più l'anta (ricavata dal modello chiuso) con l'origine sul cardine. Alcune ante sono colorate
    (suffisso _giallo / _rosso: la tinta la dà Godot)."""
    HQ.sportello_da_chiuso('armadietto_anta', 'armadietto_sportello')
    colori = {3: '_giallo', 9: '_rosso', 14: '_giallo'}
    rz = R(90) if faccia > 0 else R(-90)
    speciali = {}
    for i in range(n):
        st, ang = stati.get(i, ('chiuso', 0.0))
        yy = y0 + i * 0.4
        c = (x + 0.25 * faccia, yy + 0.2, 0)
        nome = f'{prefisso}_{i:02d}' + colori.get((i + seme) % 17, '')
        if st == 'chiuso':
            HQ.metti(nome, 'armadietto_anta', c, (0.4, 0.5, 1.92), rot_z=rz + R(random.uniform(-0.6, 0.6)))
            continue
        HQ.metti(nome + '_corpo', 'armadietto_corpo', c, (0.4, 0.5, 1.92), rot_z=rz)
        if st == 'mancante':
            continue
        # cardine sul bordo dell'anta (5 cm dentro lo spigolo del corpo, sul telaio): prima girava intorno allo
        # spigolo e da aperta stava 5 cm staccata dal corpo (controllo di posizionamento, 22 ottobre)
        cern = (x + 0.5, yy + 0.05, 0) if faccia > 0 else (x - 0.5, yy + 0.35, 0)
        anta = HQ.metti(nome + '_anta', 'armadietto_anta', cern, (0.4, 0.5, 1.92), rot_z=rz - R(ang),
                        perno=(-0.15, -0.25, 0), parte='armadietto_sportello')
        if st != 'speciale':
            col_ob(anta)   # l'anta aperta si urta (prima si attraversava)
        CERNIERE.extend(cerniere(nome, cern, faccia, yy))
        if st == 'speciale':
            speciali[i] = anta
    return None, None, speciali


def panca(nome, x0, y0, x1, y1, M, rotta=False):
    if HQ.disponibile('panca'):
        # panche Meshy da circa 1,9 m in fila lungo y
        lung = y1 - y0
        k = max(1, round(lung / 1.9))
        l = lung / k
        for j in range(k):
            HQ.metti(f'{nome}_{j + 1}', 'panca', ((x0 + x1) / 2, y0 + l * (j + 0.5), 0), (l - 0.05, x1 - x0 + 0.02, 0.46), rot_z=R(90))
        return None
    """Panca di legno a tre doghe su gambe di metallo, lungo l'asse y."""
    parti = []; cx = (x0 + x1) / 2
    for k in range(3):
        xa = x0 + k * (x1 - x0) / 3 + 0.01; xb = x0 + (k + 1) * (x1 - x0) / 3 - 0.01
        if rotta and k == 2:
            ym = (y0 + y1) / 2
            parti.append(L.scatola(nome, (xa, y0, 0.42), (xb, ym - 0.1, 0.45), M['legno_panca']))
            d = L.scatola(nome, (xa, ym + 0.1, 0.42), (xb, y1, 0.45), M['legno_panca'])
            d.rotation_euler = (R(-6), 0, 0); parti.append(d)
        else:
            parti.append(L.scatola(nome, (xa, y0, 0.42), (xb, y1, 0.45), M['legno_panca']))
    yy = y0 + 0.15
    while yy < y1:
        parti.append(L.scatola(nome, (x0 + 0.02, yy - 0.025, 0), (x0 + 0.06, yy + 0.025, 0.42), M['metallo_grezzo']))
        parti.append(L.scatola(nome, (x1 - 0.06, yy - 0.025, 0), (x1 - 0.02, yy + 0.025, 0.42), M['metallo_grezzo']))
        parti.append(L.scatola(nome, (x0 + 0.02, yy - 0.025, 0.38), (x1 - 0.02, yy + 0.025, 0.42), M['metallo_grezzo']))
        yy += 1.3
    return L.unisci(nome, parti)


def doccia(i, x, yparete, M):
    """Doccia sulla parete nord: tubo, braccio, soffione (separato), rubinetto (separato), punto d'emissione."""
    pref = f'doccia_{i:02d}'
    y = yparete - 0.05
    tubo = L.tubo_percorso(pref + '_tubo', [(x, y, 1.05), (x, y, 2.15), (x, y - 0.3, 2.15)], 0.016, M['cromo'], flange=False)
    sof = [L.cilindro(pref, (x, y - 0.33, 2.17), (x, y - 0.33, 2.11), 0.075, M['cromo'], seg=20),
           L.cilindro(pref, (x, y - 0.33, 2.112), (x, y - 0.33, 2.105), 0.068, M['nero'], seg=20)]
    soffione = L.unisci(pref + '_soffione', sof); L.origine(soffione, (x, y - 0.33, 2.15))
    rub = [L.cilindro(pref, (x, y, 1.1), (x, y - 0.07, 1.1), 0.03, M['cromo'], seg=12),
           L.scatola(pref, (x - 0.06, y - 0.08, 1.09), (x + 0.06, y - 0.06, 1.11), M['cromo'], uv=False)]
    rubinetto = L.unisci(pref + '_rubinetto', rub); L.origine(rubinetto, (x, y - 0.05, 1.1))
    L.vuoto('emit_' + pref, (x, y - 0.33, 2.1), (0, 0, 0), 'SINGLE_ARROW', 0.3)
    return tubo


def spogliatoi(M):
    L.usa_collezione('spogliatoi')
    X0, X1, Y0, Y1, H = 3.0, 11.0, 3.0, 11.0, 2.9
    mats = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'], battiscopa=M['battiscopa'])
    statico = L.stanza('spogliatoi', X0, Y0, X1, Y1, H, mats, {
        'S': [(6.0, 7.6, 0, 2.2)],
        'N': [(3.6, 7.8, 0, 2.4), (8.6, 10.8, 0, 2.4)],
        'E': [(8.0, 8.9, 0, 2.05)],
    }, zoccolo=1.2)
    statico.append(cornice_porta('telaio_stanzino', 'E', 8.0, 8.9, 2.05, X1, M))
    statico.append(cornice_porta('telaio_spogliatoi_S', 'S', 6.0, 7.6, 2.2, Y0, M, entrambi=False))

    # ---- armadietti: fila ovest (18) ed est (11 + 3), ante ammaccate, qualcuna aperta
    MAT_CERNIERA[0] = M['metallo_grezzo']
    random.seed(11)
    cw, aw, sw = fila_armadietti('armadietti_ovest', X0, 3.3, 18, +1, M,
                                 {2: ('aperto', 95), 5: ('aperto', 25), 8: ('mancante', 0), 11: ('aperto', 110), 15: ('aperto', 12)}, seme=0)
    ce, ae, se = fila_armadietti('armadietti_est', X1, 3.3, 11, -1, M,
                                 {1: ('aperto', 70), 4: ('speciale', 4), 7: ('aperto', 30), 9: ('aperto', 100)}, seme=5)
    ce2, ae2, _ = fila_armadietti('armadietti_est2', X1, 9.3, 4, -1, M, {2: ('aperto', 45)}, seme=21)
    # collisione solo nella parte posteriore: gli armadietti aperti restano raggiungibili (Polaroid P2)
    L.col_scatola((X0, 3.3, 0), (X0 + 0.3, 3.3 + 18 * 0.4, 1.94))
    L.col_scatola((X1 - 0.3, 3.3, 0), (X1, 3.3 + 11 * 0.4, 1.94))
    L.col_scatola((X1 - 0.3, 9.3, 0), (X1, 9.3 + 4 * 0.4, 1.94))
    statico.extend(CERNIERE)
    # l'armadietto che sbatte (anta separata, cardine come origine; dentro un salvagente colorato)
    anta_sb = se[4]; anta_sb.name = 'armadietto_sbatte_anta'
    if not HQ.disponibile('armadietto_corpo'):
        anta_sb.rotation_euler = (0, 0, R(180 + 4))
    L.vuoto('marker_armadietto_sbatte', (X1 - 0.25, 3.3 + 4 * 0.4 + 0.2, 1.0), dim=0.2)
    sg = prop('salvagente_giocattolo', 'salvagente_giocattolo', (X1 - 0.26, 3.3 + 4 * 0.4 + 0.2, 0.15), 90, 0.36)
    sg.rotation_euler = (R(75), 0, R(90))
    L.vuoto('marker_polaroid_P2', (X0 + 0.38, 3.3 + 11 * 0.4 + 0.2, 1.595), dim=0.05)   # sul ripiano dell'armadietto aperto

    # ---- panche
    statico.append(panca('panca_ovest', 4.45, 4.0, 4.85, 9.8, M))
    statico.append(panca('panca_est', 9.15, 4.0, 9.55, 7.4, M, rotta=True))
    L.col_scatola((4.45, 4.0, 0), (4.85, 9.8, 0.45)); L.col_scatola((9.15, 4.0, 0), (9.55, 7.4, 0.45))
    # cartello con i pittogrammi vicino all'ingresso
    statico.append(L.piano('cartello_regole_spogliatoi', (8.6, 3.012, 1.65), 0.45, 0.6, M['cartello_regole'], rot=(R(90), 0, 0)))
    statico.append(L.tubo_percorso('tubi_spogliatoi', [(3.0, 10.75, 2.6), (11.0, 10.75, 2.6)], 0.07, M['ruggine']))
    statico.append(L.tubo_percorso('tubi_spogliatoi_2', [(6.2, 3.0, 2.72), (6.2, 11.0, 2.72)], 0.045, M['metallo_grezzo']))
    statico.append(grata_parete('grata_vent_spogliatoi', (7.0, 10.995, 2.5), 0.6, 0.3, (0, -1, 0), M))

    # ---- docce   x 3..8.2, y 11.2..14.6
    DX0, DX1, DY0, DY1 = 3.0, 8.2, 11.2, 14.6
    md = dict(pav=M['piastrelle_doccia'], sof=M['soffitto_lamiera'], muro=M['piastrelle_doccia'], muro_basso=M['piastrelle_verdi'], battiscopa=M['battiscopa_piastrelle'])
    statico += L.stanza('docce', DX0, DY0, DX1, DY1, H, md, {'S': [(DX0 - 0.2, DX1 + 0.2, 0, H)], 'W': [(12.0, 12.6, 0, 0.5)]}, zoccolo=1.2)
    tubi_d = []
    for i, x in enumerate([3.7, 4.65, 5.6, 6.55, 7.5]):
        tubi_d.append(doccia(i + 1, x, DY1, M))
        statico.append(L.scatola('scarico_doccia', (x - 0.1, DY1 - 0.7, 0.0), (x + 0.1, DY1 - 0.5, 0.004), M['lamiera_grata']))
    for x in [4.175, 5.125, 6.075, 7.025]:
        L.col_scatola((x - 0.04, DY1 - 0.95, 0.0), (x + 0.04, DY1, 2.0))
        statico.append(L.scatola('divisorio_doccia', (x - 0.04, DY1 - 0.95, 0.15), (x + 0.04, DY1, 2.0), M['piastrelle_verdi']))
    statico.append(L.tubo_percorso('tubo_docce', [(3.0, DY1 - 0.05, 2.15), (8.2, DY1 - 0.05, 2.15)], 0.022, M['cromo'], flange=False))
    statico += tubi_d
    statico.append(L.scatola('canaletta_docce', (3.0, DY0 + 0.4, 0), (8.2, DY0 + 0.55, 0.004), M['lamiera_grata']))
    L.vuoto('emit_vapore_docce', (5.6, 13.6, 1.5), dim=0.6)
    # grata d'aerazione bassa (si apre: cardine in alto) e condotto dietro
    gr = [L.scatola('grata_aerazione', (DX0 - 0.02, 12.0, 0.04), (DX0, 12.6, 0.5), M['metallo_grezzo'])]
    for k in range(9):
        z = 0.08 + k * 0.045
        gr.append(L.scatola('grata_aerazione', (DX0 - 0.015, 12.04, z), (DX0 + 0.012, 12.56, z + 0.015), M['metallo_grezzo']))
    grata = L.unisci('grata_aerazione', gr)
    L.origine(grata, (DX0, 12.3, 0.5)); grata.rotation_euler = (0, R(-8), 0)   # un po' socchiusa
    L.vuoto('marker_grata_aerazione_cardine', (DX0, 12.3, 0.5), dim=0.2)
    statico += L.stanza('condotto_aerazione', 0.6, 12.0, 2.8, 12.6, 0.5, dict(pav=M['ruggine'], sof=M['ruggine'], muro=M['ruggine']), {'E': [(12.0, 12.6, 0, 0.5)]}, t=0.05)
    # impronte bagnate verso la grata (B1)
    imp = []
    for k in range(7):
        px = 5.2 - k * 0.32; py = 12.9 - k * 0.09 + (0.08 if k % 2 else -0.08)
        o = L.piano('impronta', (px, py, 0.003), 0.11, 0.25, M['impronte'], rot=(0, 0, R(80)))
        imp.append(o)
    L.unisci('impronte_bagnate_B1', imp)

    # ---- corridoio con la vasca lava-piedi   x 8.6..10.8, y 11.2..20.5, h 2.7
    CX0, CX1, CY0, CY1, CH = 8.6, 10.8, 11.2, 20.5, 2.7
    UX0, UX1, UH = 9.1, 10.3, 2.2    # uscita verso la sala principale: 1,2 x 2,2 m
    mc = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['piastrelle_doccia'], muro_basso=M['piastrelle_verdi'], battiscopa=M['battiscopa_piastrelle'])
    statico += L.stanza('corridoio_lavapiedi', CX0, CY0, CX1, CY1, CH, mc,
                        {'S': [(CX0 - 0.2, CX1 + 0.2, 0, CH)], 'E': [(FINESTRA[0], FINESTRA[1], FINESTRA[2], FINESTRA[3])], 'N': [(UX0, UX1, 0, UH)]}, pavimento=False, zoccolo=1.2)
    VY0, VY1, VZ = 12.4, 14.4, -0.2
    L.raccogli(True)
    statico.append(L.scatola('pav_lavapiedi_a', (CX0 - 0.2, CY0, -0.2), (CX1 + 0.2, VY0, 0), M['piastrelle_pavimento']))
    statico.append(L.scatola('pav_lavapiedi_b', (CX0 - 0.2, VY1, -0.2), (CX1 + 0.2, CY1 + 0.2, 0), M['piastrelle_pavimento']))
    statico.append(L.scatola('vasca_lavapiedi_fondo', (CX0, VY0, VZ - 0.2), (CX1, VY1, VZ), M['piastrelle_verdi']))
    # bordi della vasca a toro (piastrelle "bullnose") e cartello del pavimento bagnato
    for yb in (VY0, VY1):
        statico.append(L.cilindro('vasca_lavapiedi_bordo', (CX0, yb, -0.01), (CX1, yb, -0.01), 0.035, M['piastrelle_doccia'], seg=24))
    if HQ.disponibile('cartello_pericolo'):
        col_ob(HQ.metti('cartello_bagnato', 'cartello_pericolo', (10.3, 11.75, 0), (None, None, 0.62), rot_z=R(160)))
    L.raccogli(False)
    acqua_lp = L.scatola('acqua_lavapiedi', (CX0, VY0, VZ), (CX1, VY1, -0.05), M['acqua'], uv=False)
    L.uv_scatola(acqua_lp, 1.0); acqua_lp.visible_shadow = False
    L.vuoto('marker_acqua_lavapiedi_livello', (9.7, 13.4, -0.05), dim=0.3)
    # docce lava-piedi sopra la vasca e corrimano
    statico.append(L.tubo_percorso('tubo_lavapiedi', [(CX0, 13.4, 2.3), (CX1, 13.4, 2.3)], 0.025, M['cromo'], flange=False))
    for k, x in enumerate((9.2, 10.2)):
        statico.append(L.cilindro('ugello_lavapiedi', (x, 13.4, 2.28), (x, 13.4, 2.2), 0.02, M['cromo']))
        L.vuoto(f'emit_lavapiedi_{k + 1}', (x, 13.4, 2.2), dim=0.2)
    for xx in (CX0 + 0.06, CX1 - 0.06):
        statico.append(L.tubo_percorso('corrimano_lavapiedi', [(xx, 11.8, 0.95), (xx, 15.0, 0.95)], 0.02, M['cromo'], flange=False))

    # tornello a tutta altezza (Meshy): telaio fisso e rotore separato con l'origine sul perno
    TY = 16.4; TX = 9.5
    L.col_scatola((CX0, TY - 0.05, 0), (CX0 + 0.3, TY + 0.05, 2.7)); L.col_scatola((CX1 - 0.68, TY - 0.05, 0), (CX1, TY + 0.05, 2.7))
    L.col_scatola((CX0, TY - 0.05, 2.25), (CX1, TY + 0.05, 2.7))
    HQ.metti('tornello_telaio', 'tornello_telaio', (TX, TY, 0), (1.76, 1.3, 2.32))
    dr = HQ.dimensioni('tornello_rotore'); kxy = 1.2 / dr.x; kz = 2.2 / dr.z
    asse = HQ.asse_rotore('tornello_rotore')
    HQ.metti('tornello_rotore', 'tornello_rotore', (TX, TY, 0.04), (dr.x * kxy, dr.y * kxy, 2.2), perno=(asse.x * kxy, asse.y * kxy, 0))
    # i due cuscinetti sull'asse del rotore: sotto sul pavimento, sopra nel tetto del telaio (prima il rotore girava
    # a 1 cm dal telaio senza toccarlo, collaudo del 22 ottobre); sull'asse, quindi il rotore che gira resta giusto
    statico.append(L.cilindro('tornello_cuscinetto', (TX, TY, 0.0), (TX, TY, 0.07), 0.035, M['cromo'], seg=16))
    statico.append(L.cilindro('tornello_cuscinetto', (TX, TY, 2.21), (TX, TY, 2.32), 0.035, M['cromo'], seg=16))
    # grata fissa tra il telaio e la parete est
    fisso = []
    for x in [10.42 + 0.095 * j for j in range(4)]:
        fisso.append(L.cilindro('grata_tornello', (x, TY, 0.0), (x, TY, 2.32), 0.016, M['cromo'], seg=20))
    fisso.append(L.cilindro('grata_tornello', (10.38, TY, 2.3), (CX1, TY, 2.3), 0.025, M['cromo'], seg=20))
    fisso.append(L.cilindro('grata_tornello', (10.38, TY, 1.05), (CX1, TY, 1.05), 0.02, M['cromo'], seg=20))
    statico.append(L.unisci('grata_tornello', fisso))
    L.vuoto('marker_tornello_perno', (TX, TY, 0), dim=0.3)

    # gabbiotto con il vetro rotto (finestra Meshy) e il pulsante del tornello (fuori portata)
    GX0, GX1, GY0, GY1 = 11.0, 13.2, 14.6, 17.4
    statico += L.stanza('gabbiotto', GX0, GY0, GX1, GY1, CH, dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'], battiscopa=M['battiscopa']),
                        {'W': [(GY0 - 0.2, GY1 + 0.2, 0, CH)]})
    WY0, WY1, WZ0, WZ1 = FINESTRA
    dfin = HQ.dimensioni('finestra_gabbiotto'); kf = 1.62 / dfin.z
    # il modello è profondo (davanzale): lo schiacciamo a 28 cm e lo appoggiamo al muro (faccia a x = 10,8)
    HQ.metti('finestra_gabbiotto', 'finestra_gabbiotto', (10.8 - 0.14 + 0.08, (WY0 + WY1) / 2, WZ0 - 0.1), (1.32, 0.28, 1.62), rot_z=R(-90))
    # vetro con un buco frastagliato al centro (anello tra il telaio e il bordo del buco); il getto passa
    import bmesh
    bm = bmesh.new(); xg = 10.9
    rnd = random.Random(4)
    cy, cz = (WY0 + WY1) / 2, (WZ0 + WZ1) / 2
    hy, hz = (WY1 - WY0) / 2, (WZ1 - WZ0) / 2
    cen = (cy + 0.03, cz - 0.05); NB = 56
    def bordo_telaio(t):
        dy, dz = math.cos(t), math.sin(t)
        k = min(hy / abs(dy) if abs(dy) > 1e-6 else 9, hz / abs(dz) if abs(dz) > 1e-6 else 9)
        return (cy + dy * k, cz + dz * k)
    est, inn = [], []
    for i in range(NB):
        t = 2 * math.pi * i / NB
        est.append(bm.verts.new((xg, *bordo_telaio(t))))
        r = (0.3 if i % 2 else 0.2) * rnd.uniform(0.6, 1.4)
        inn.append(bm.verts.new((xg, cen[0] + math.cos(t) * r * 1.1, cen[1] + math.sin(t) * r * 1.3)))
    for i in range(NB):
        j = (i + 1) % NB
        bm.faces.new((est[i], est[j], inn[j], inn[i]))
    pi_ = [v.co.copy() for v in inn]   # bordo del buco (prima che la bmesh diventi un oggetto)
    vetro = L._ob_da_bm('vetro_rotto', bm, M['vetro_sporco']); L.uv_scatola(vetro, 1.0)
    # bordo chiaro e frastagliato del buco e qualche crepa che parte da lì: senza, il vetro quasi
    # trasparente non si vedeva e la finestra sembrava vuota (questionario del 15 ottobre)
    mb = L.mat_colore('vetro_bordo', (0.86, 0.92, 0.9), rough=0.18)
    bm = bmesh.new()
    xb = xg - 0.002
    for i in range(NB):
        j = (i + 1) % NB
        a, b = pi_[i], pi_[j]
        da = Vector((0, a.y - cen[0], a.z - cen[1])).normalized() * 0.014
        db = Vector((0, b.y - cen[0], b.z - cen[1])).normalized() * 0.014
        q = [bm.verts.new((xb, a.y, a.z)), bm.verts.new((xb, b.y, b.z)), bm.verts.new((xb, b.y + db.y, b.z + db.z)), bm.verts.new((xb, a.y + da.y, a.z + da.z))]
        bm.faces.new(q)
    for k in range(9):
        i = rnd.randrange(NB)
        a = pi_[i]
        d = Vector((0, a.y - cen[0], a.z - cen[1])).normalized()
        lung = rnd.uniform(0.12, 0.34)
        pts = [Vector((xb, a.y, a.z))]
        for t in range(3):   # crepa a zig-zag
            d = (d + Vector((0, rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35)))).normalized()
            pts.append(pts[-1] + d * lung / 3)
        for p0, p1 in zip(pts, pts[1:]):
            n = Vector((0, -(p1 - p0).z, (p1 - p0).y)).normalized() * 0.0025
            if not (cy - hy + 0.02 < p1.y < cy + hy - 0.02 and cz - hz + 0.02 < p1.z < cz + hz - 0.02):
                break   # la crepa si ferma al telaio
            bm.faces.new([bm.verts.new(p0 - n), bm.verts.new(p1 - n), bm.verts.new(p1 + n), bm.verts.new(p0 + n)])
    L._ob_da_bm('vetro_rotto_bordo', bm, mb)
    sch = []
    for k in range(18):
        x = rnd.uniform(9.9, 10.6) if k < 10 else rnd.uniform(11.1, 12.2); y = rnd.uniform(15.2, 16.8)
        o = L.piano('schegge_vetro', (x, y, 0.003), rnd.uniform(0.03, 0.1), rnd.uniform(0.02, 0.07), M['vetro_sporco'], rot=(0, 0, rnd.uniform(0, 3)))
        sch.append(o)
    L.unisci('schegge_vetro', sch)
    if HQ.disponibile('scrivania'):
        HQ.metti('banco_gabbiotto', 'scrivania', (12.8, 16.0, 0), (1.2, 0.6, 0.78), rot_z=R(-90))
        L.col_scatola((12.5, 15.4, 0), (13.1, 16.6, 0.8))
    dq = HQ.dimensioni('quadro_pulsante'); kq = 0.55 / dq.z
    HQ.metti('quadro_pulsante', 'quadro_pulsante', (13.2 - dq.y * kq / 2, 16.0, 0.95), (None, None, 0.55), rot_z=R(-90))
    L.luce_punto('luce_pulsante_tornello', (12.95, 16.0, 1.35), (1.0, 0.15, 0.08), 6, 0.03)
    prop('radio_gabbiotto', 'radio', (12.6, 16.35, 0.78), 100, 0.3)

    # saracinesca (si alza) nell'uscita verso la sala principale, con la turbina sulla parete ovest
    SY = CY1 + 0.1
    sar = []
    z = 0.0
    while z < UH - 0.01:
        sar.append(L.scatola('saracinesca', (UX0, SY - 0.03, z), (UX1, SY + 0.03, min(z + 0.075, UH)), M['porta_lamiera']))
        sar.append(L.scatola('saracinesca', (UX0, SY - 0.04, z + 0.03), (UX1, SY - 0.03, z + 0.045), M['nero'], uv=False))
        z += 0.08
    sar.append(L.scatola('saracinesca', (UX0, SY - 0.05, 0), (UX1, SY + 0.05, 0.08), M['vernice_gialla']))
    saracinesca = L.unisci('saracinesca', sar); L.ammacca(saracinesca, 0.008, 1.5, 2.0, 2)
    L.origine(saracinesca, ((UX0 + UX1) / 2, SY, 0))     # come PoweredDoor: in basso al centro del vano
    statico.append(L.scatola('cassonetto_saracinesca', (UX0 - 0.1, SY - 0.35, UH), (UX1 + 0.1, SY + 0.05, UH + 0.4), M['metallo_grezzo']))
    for x in (UX0 - 0.06, UX1):
        statico.append(L.scatola('guida_saracinesca', (x, SY - 0.06, 0), (x + 0.06, SY + 0.06, UH), M['metallo_grezzo']))
    statico.append(cornice_porta('telaio_uscita', 'N', UX0, UX1, UH, CY1, M, M['vernice_gialla'], entrambi=True))
    L.vuoto('marker_uscita_sala_principale', ((UX0 + UX1) / 2, CY1 + 0.2, 0), (0, 0, 0), 'SINGLE_ARROW', 0.5)
    # turbina: carcassa sulla parete, ruota a pale separata (asse lungo x), ingranaggio e catena verso il cassonetto
    # alzata (scelta dell'utente del 22 ottobre, opzione A): col centro a 2,05 m il bordo della ruota scendeva a
    # 1,75, all'altezza della testa di chi cammina; ora il bordo basso è a 2,02 e la cima a 2,62, sotto i pannelli
    # del soffitto (2,63). 20 cm più verso la saracinesca, così sta tra le travi del soffitto (una è a y 19,17 e
    # scende a 2,54: con y 19,4 la ruota ci entrava). Il centro deve restare uguale a quello di PernoTurbina in
    # godot/scenes/interni/interni.tscn.
    TBy, TBz = 19.6, 2.32
    statico.append(L.cilindro('turbina_carcassa', (CX0, TBy, TBz), (CX0 + 0.08, TBy, TBz), 0.3, M['metallo_grezzo'], seg=28))
    statico.append(L.cilindro('turbina_mozzo', (CX0, TBy, TBz), (CX0 + 0.2, TBy, TBz), 0.05, M['ruggine']))
    pale = [L.cilindro('turbina', (CX0 + 0.12, TBy, TBz), (CX0 + 0.26, TBy, TBz), 0.07, M['vernice_gialla'], seg=16)]
    for k in range(8):
        a = R(45 * k)
        c = Vector((0, math.cos(a), math.sin(a)))
        p = L.scatola('turbina', (CX0 + 0.12, -0.02, 0.05), (CX0 + 0.26, 0.02, 0.24), M['vernice_rossa'] if k % 2 else M['vernice_gialla'], uv=False)
        p.matrix_world = Matrix.Translation((0, TBy, TBz)) @ Matrix.Rotation(a, 4, 'X')
        pale.append(p)
    turb = L.unisci('turbina_saracinesca', pale); L.uv_scatola(turb, 0.5)
    L.origine(turb, (CX0 + 0.19, TBy, TBz))
    if TURBINA_NUOVA and HQ.disponibile('turbina_cancello'):
        # ruota Meshy (questionario del 15 ottobre: "la turbina è orribile"): stesso nome, stesso perno, asse X
        bpy.data.objects.remove(turb)
        dt = HQ.dimensioni('turbina_cancello'); kt = 0.6 / max(dt.x, dt.z)
        turb = HQ.metti('turbina_saracinesca', 'turbina_cancello', (CX0 + 0.19, TBy, TBz), tuple(dt * kt), rot_z=R(90),
                        perno=(0, 0, dt.z * kt / 2))
    # la catena parte dal bordo della carcassa verso la saracinesca e va dritta, alla quota del mozzo, fino al
    # fianco del cassonetto (z da UH a UH + 0,4): con la turbina alzata è più corta e non sale più
    statico.append(L.tubo_percorso('catena_turbina', [(CX0 + 0.05, TBy + 0.3, TBz), (CX0 + 0.05, SY - 0.2, TBz), (UX0 - 0.1, SY - 0.2, TBz)], 0.03, M['metallo_grezzo'], flange=False))

    # ---- luci
    for i, (p, n) in enumerate([((6.8, 3.02, 2.45), (0, 1, 0)), ((3.02, 7.0, 2.4), (1, 0, 0)), ((5.6, 14.58, 2.55), (0, -1, 0)),
                                ((10.78, 18.2, 2.3), (-1, 0, 0)), ((9.7, 11.22, 2.5), (0, 1, 0)), ((13.18, 16.0, 2.3), (-1, 0, 0))]):
        lampada(f'luce_emergenza_spogliatoi_{i + 1:02d}', p, n, M, watt=40)
    for i, (x, y, stato, rz) in enumerate([(7.0, 5.0, 'sfarfalla', 90), (7.0, 8.8, 'spento', 90), (5.6, 12.6, 'spento', 0), (9.7, 17.5, 'spento', 90)]):
        L.neon_soffitto(f'neon_spogliatoi_{i + 1}', (x, y, 0), 1.2, M, H if y < 15 else CH, stato, watt=90, rot_z=R(rz))

    # ---- oggetti dimenticati (ciabatte, braccioli, asciugamani) e acqua
    random.seed(3)
    cia = prop('ciabatta', 'ciabatta', (6.1, 6.2, 0), 30, 0.27)
    for k, (x, y, rz) in enumerate([(6.35, 6.0, 10), (8.1, 8.9, 200), (5.2, 12.2, 130), (8.3, 9.2, 170), (9.9, 15.3, 60)]):
        copia(cia, f'ciabatta_{k + 2}', (x, y, 0), rz)
    br = prop('braccioli', 'braccioli', (4.65, 7.2, 0.45), 20, 0.3)
    copia(br, 'braccioli_2', (7.6, 9.9, 0), 110)
    prop('asciugamano', 'asciugamano', (9.35, 5.2, 0.45), 90, 0.9)
    # mucchio alto 52 cm contro il muro sud, a ovest dell'ingresso dal corridoio (x 6..7,6): davanti all'ingresso
    # bloccava il passaggio (prova coi passaggi del 23 ottobre); si urta (scatola orientata)
    col_ob(prop('asciugamano_2', 'asciugamano', (5.0, 3.45, 0), 20, 0.8))
    prop('paperella_spogliatoi', 'paperella', (7.9, 13.3, 0), 200, 0.09)
    col_ob(prop('secchio_mocio', 'secchio_mocio', (7.6, 11.6, 0), 210, 0.95, 'z'))
    col_ob(prop('pallone_spogliatoi', 'pallone', (10.2, 10.2, 0), 0, 0.4))
    col_ob(prop('cestino_spogliatoi', 'cestino', (3.5, 10.6, 0), 0, 0.5, 'z'))
    pz = [pozza('pozza_spogliatoi_1', (6.8, 9.2, 0), 1.2, 0.8, M, 11), pozza('pozza_spogliatoi_2', (5.5, 13.0, 0), 1.8, 1.0, M, 12),
          pozza('pozza_spogliatoi_3', (7.4, 5.4, 0), 0.6, 0.4, M, 13), pozza('pozza_spogliatoi_4', (9.7, 15.8, 0), 0.8, 0.6, M, 14)]
    L.unisci('acqua_pozze_spogliatoi', pz)
    # soffitti da nave nel corridoio lava-piedi e nel gabbiotto
    statico.append(soffitto_nave('soffitto_lavapiedi', CX0, CX1, CY0, CY1, CH, M, 'y', 1.3, mancanti=(4,), pende=None, travi=True, seme=7))
    statico.append(soffitto_nave('soffitto_gabbiotto', 11.0, 13.2, 14.6, 17.4, CH, M, 'y', 0.95, mancanti=(), pende=None, travi=True, seme=9))
    for k, y in enumerate((12.0, 16.8, 19.0)):
        statico.append(sprinkler(f'sprinkler_lavapiedi_{k + 1}', 10.4, y, CH, CH - 0.2, M))
    L.unisci('spogliatoi_statico', statico)
    L.crea_collisione('spogliatoi', 'spogliatoi')


# =====================================================================================
# 3. STANZINO DEI BAGNINI   x 11.2..15.2, y 6.2..10.6, h 2.6
# =====================================================================================
def stanzino(M):
    L.usa_collezione('stanzino')
    X0, X1, Y0, Y1, H = 11.2, 15.2, 6.2, 10.6, 2.6
    mats = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'], battiscopa=M['battiscopa'])
    # a ovest è addossato alla parete est degli spogliatoi (x 11,0-11,2): niente pareti, pavimento e soffitto oltre
    statico = L.stanza('stanzino', X0, Y0, X1, Y1, H, mats, {}, zoccolo=1.0, attaccata='W')
    # porta (aperta verso l'interno, cardine sul lato nord del vano)
    pt = [L.scatola('porta_stanzino', (11.02, 8.02, 0.01), (11.07, 8.88, 2.03), M['porta_lamiera'])]
    pt.append(L.cilindro('porta_stanzino', (11.07, 8.1, 1.0), (11.14, 8.1, 1.0), 0.02, M['cromo']))
    pt.append(L.scatola('porta_stanzino', (11.0, 8.3, 1.35), (11.09, 8.6, 1.75), M['metallo_grezzo']))
    porta = L.unisci('porta_stanzino', pt); L.ammacca(porta, 0.004, 2.0, 12.0, 3)
    L.origine(porta, (11.05, 8.88, 0)); porta.rotation_euler = (0, 0, R(-75))
    porta = porta_hq(porta, 'porta_servizio', (11.05, 8.88, 0.01), 0.86, 2.02, R(-90 - 75), -1)
    col_ob(porta)   # la porta aperta si urta (prima si attraversava)
    # costole
    for y in (7.4, 9.4):
        statico.append(L.scatola('costola', (X1 - 0.07, y - 0.06, 0), (X1, y + 0.06, H), M['lamiera_crema']))
    statico.append(L.tubo_percorso('tubo_stanzino', [(X0, 10.35, 2.35), (13.4, 10.35, 2.35), (13.4, 10.35, 2.6)], 0.06, M['ruggine']))
    statico.append(L.tubo_percorso('tubo_stanzino_2', [(X0, 6.45, 2.4), (X1, 6.45, 2.4)], 0.04, M['vernice_rossa'], flange=False))

    # ---- parete nord: rastrelliera di ganci con i fischietti, radiatore, pronto soccorso
    statico.append(L.scatola('portaganci', (11.6, Y1 - 0.04, 1.62), (13.1, Y1, 1.74), M['legno_panca']))
    fis = None
    for k, x in enumerate([11.8, 12.1, 12.4, 12.7, 13.0]):
        statico.append(L.tubo_percorso('gancio', [(x, Y1 - 0.04, 1.68), (x, Y1 - 0.11, 1.68), (x, Y1 - 0.11, 1.72)], 0.008, M['metallo_grezzo'], flange=False))
        if k in (0, 1, 3, 4):
            statico.append(L.cilindro('cordino', (x, Y1 - 0.1, 1.67), (x, Y1 - 0.1, 1.35 - 0.04 * k), 0.003, M['vernice_rossa'] if k % 2 else M['gomma'], seg=5))
            if fis is None:
                f = fis = prop('fischietto_1', 'fischietto', (x, Y1 - 0.1, 1.3 - 0.04 * k - 0.05), 0, 0.07)
            else:
                f = copia(fis, f'fischietto_{k + 1}', (x, Y1 - 0.1, 1.3 - 0.04 * k - 0.05), random.uniform(-30, 30))
            # appeso al capo del cordino (prima stava 5-10 cm più in basso, staccato)
            bpy.context.view_layer.update()
            f.location.z += (1.35 - 0.04 * k) - max((f.matrix_world @ v.co).z for v in f.data.vertices)
    rad = [L.scatola('radiatore', (11.7, Y1 - 0.12, 0.15), (13.1, Y1 - 0.1, 0.17), M['metallo_grezzo'])]
    x = 11.72
    while x < 13.1:
        rad.append(L.scatola('radiatore', (x, Y1 - 0.14, 0.12), (x + 0.04, Y1 - 0.05, 0.75), M['metallo_grezzo']))
        x += 0.07
    statico.append(L.unisci('radiatore', rad))
    # cassetta del pronto soccorso a muro: alta 42 cm, così sporge 24 cm (con 60 cm sporgeva 34 cm, oltre i 25 della
    # regola per le cose a muro: controllo del 23 ottobre), appoggiata al muro e con la sua collisione
    cps = prop('cassetta_pronto_soccorso', 'cassetta_pronto_soccorso', (14.25, Y1 - 0.15, 1.15), 180, 0.42, 'z')   # accanto al salvagente, non contro
    attacca(cps, (0, 1, 0))
    col_ob(cps)
    L.toro('salvagente_parete', Vector((13.6, Y1 - 0.08, 1.75)), 0.27, 0.075, M['salvagente'], rot=(R(90), 0, 0))

    # ---- parete est: rastrelliera dello zaino-pompa (posto libero al centro) e salvagenti
    RX = X1 - 0.04
    drs = HQ.dimensioni('rastrelliera'); krs = 2.0 / drs.z
    HQ.metti('rastrelliera_zaino', 'rastrelliera', (X1 - drs.y * krs / 2, 8.42, 0), (None, None, 2.0), rot_z=R(-90))
    ras = []
    statico.append(L.unisci('rastrelliera_zaino_extra', ras))
    L.col_scatola((RX - 0.45, 6.95, 0), (RX, 9.85, 2.0))
    # posto dello zaino: due ganci centrali (y 8.1 e 8.75) liberi; lo zaino va appeso qui, schiena verso il muro
    FR = X1 - drs.y * krs          # fronte della rastrelliera (i ganci sporgono qui)
    L.vuoto('marker_zaino_pompa', (FR - 0.12, 8.425, 1.25), (0, 0, R(90)), 'ARROWS', 0.4)
    for k, y in enumerate((7.55, 9.3)):
        s = L.toro(f'salvagente_rastrelliera_{k + 1}', Vector((FR - 0.1, y, 1.0)), 0.28, 0.08, M['salvagente'], rot=(R(90), R(8 * (k * 2 - 1)), R(90)))
        attacca(s, (1, 0, 0))   # appoggiato alla rastrelliera
    sal_ripiano = L.toro('salvagente_ripiano', Vector((X1 - 0.3, 7.9, 2.06)), 0.27, 0.075, M['salvagente'], rot=(0, R(4), 0))
    attacca(prop('braccioli_stanzino', 'braccioli', (X1 - 0.3, 9.0, 2.02), 70, 0.3), (0, 0, -1))   # sul ripiano

    # ---- parete sud: bacheca di sughero con cartello, poster e foglietti; scrivania con radio; sedia
    BY = Y0 + 0.03
    dbc = HQ.dimensioni('bacheca'); kb = 1.6 / dbc.x
    HQ.metti('bacheca', 'bacheca', (12.7, Y0 + dbc.y * kb / 2, 1.1), (1.6, None, None), rot_z=R(180))
    BY = Y0 + dbc.y * kb * 0.75
    statico.append(L.piano('bacheca_cartello_regole', (12.25, BY + 0.003, 1.62), 0.42, 0.56, M['cartello_regole'], rot=(R(90), 0, 0)))
    statico.append(L.piano('bacheca_poster_bagnino', (13.05, BY + 0.003, 1.6), 0.5, 0.67, M['poster_bagnino'], rot=(R(90), 0, R(2))))
    fog = []
    rnd = random.Random(8)
    for k in range(7):
        x = rnd.uniform(11.98, 13.45); z = rnd.uniform(1.2, 2.0)
        if 12.0 < x < 12.5 and 1.3 < z < 1.95:
            continue
        fog.append(L.piano('foglietti', (x, BY + 0.005 + k * 0.0004, z), rnd.choice([0.1, 0.09, 0.15]), rnd.choice([0.11, 0.14, 0.2]), M['carta'] if k % 3 else M['polaroid'], rot=(R(90), R(rnd.uniform(-8, 8)), 0)))
    if fog:
        statico.append(L.unisci('bacheca_foglietti', fog))
    L.vuoto('marker_polaroid_P3', (12.65, BY + 0.01, 1.3), (R(90), 0, 0), 'CUBE', 0.05)
    HQ.metti('scrivania', 'scrivania', (12.5, Y0 + 0.32, 0), (1.4, 0.62, 0.78), rot_z=R(180))
    L.col_scatola((11.8, Y0, 0), (13.2, Y0 + 0.6, 0.78))
    prop('radio', 'radio', (12.95, Y0 + 0.3, 0.78), 190, 0.32)
    prop('ricetrasmittente', 'radio_ricetrasmittente', (12.35, Y0 + 0.35, 0.78), 0, 0.2, rot=(R(90), 0, 0))
    col_ob(prop('sedia', 'sedia', (12.4, Y0 + 1.05, 0), 160, 0.88, 'z'))
    col_ob(attacca(HQ.metti('estintore_stanzino', 'estintore_staffa', (14.6, Y0 + 0.21, 0.82), (None, None, 0.62), rot_z=R(-90)), (0, -1, 0)))
    prop('ciabatta_stanzino', 'ciabatta', (14.2, 9.5, 0), 250, 0.27)

    # ---- luci
    lampada('luce_emergenza_stanzino_01', (11.22, 9.6, 2.3), (1, 0, 0), M, watt=30)
    lampada('luce_emergenza_stanzino_02', (15.18, 7.6, 2.3), (-1, 0, 0), M, watt=22)
    L.neon_soffitto('neon_stanzino', (13.2, 8.4, 0), 1.2, M, H, 'sfarfalla', watt=60, rot_z=R(90))
    pozza('acqua_pozza_stanzino', (12.0, 8.6, 0), 0.6, 0.45, M, 21)
    # soffitto da nave: un pannello manca, uno pende vicino alla rastrelliera
    statico.append(soffitto_nave('soffitto_stanzino', X0, X1, Y0, Y1, H, M, 'x', 1.0, mancanti=(1,), pende=3, travi=True, seme=11))
    for k, x in enumerate((11.9, 14.4)):
        statico.append(sprinkler(f'sprinkler_stanzino_{k + 1}', x, 6.45, 2.4, 2.25, M))
    statico.append(canalina_cavi('canalina_stanzino', X0, X1, 9.9, 2.46, M))
    L.unisci('stanzino_statico', statico)
    L.crea_collisione('stanzino', 'stanzino')


def neon_sotto_il_soffitto(margine=0.004):
    """Le plafoniere stanno appoggiate sotto il soffitto vero (pannelli, travi, condotti), non sotto la quota
    della stanza: misura il soffitto sopra ogni plafoniera e la abbassa, con tubi, luce e cavo."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    sc = bpy.context.scene
    plafoniere = [o for o in sc.objects if o.type == 'MESH' and o.name.startswith('neon_')
                  and not any(o.name.endswith(s) for s in ('_tubi', '_tubi_accesi', '_tubo_sfarfalla', '_cavo'))]
    for corpo in plafoniere:
        nome = corpo.name
        if nome + '_cavo' in sc.objects:
            continue   # appesa a un cavo: è già più in basso
        bb = [corpo.matrix_world @ Vector(c) for c in corpo.bound_box]
        x0, x1 = min(v.x for v in bb), max(v.x for v in bb)
        y0, y1 = min(v.y for v in bb), max(v.y for v in bb)
        z0, z1 = min(v.z for v in bb), max(v.z for v in bb)
        cielo = None
        # griglia fitta: una trave larga 10 cm non deve passare fra due campioni
        lungo_x = (x1 - x0) > (y1 - y0)
        fitti, radi = [k / 24 for k in range(1, 24)], (0.1, 0.5, 0.9)
        for fx in (fitti if lungo_x else radi):
            for fy in (radi if lungo_x else fitti):
                o = Vector((x0 + (x1 - x0) * fx, y0 + (y1 - y0) * fy, z0 - 0.3))   # da sotto: anche le travi che la attraversano
                for _ in range(8):
                    hit, loc, _n, _i, ob, _m = sc.ray_cast(dg, o, Vector((0, 0, 1)), distance=1.0)
                    if not hit:
                        break
                    if ob.name.startswith(nome) or ob.hide_render or 'colonly' in ob.name:
                        o = loc + Vector((0, 0, 0.001))
                        continue
                    if cielo is None or loc.z < cielo:
                        cosa = (ob.name, round(o.x, 2), round(o.y, 2))
                    cielo = loc.z if cielo is None else min(cielo, loc.z)
                    break
        if cielo is None or z1 <= cielo - margine:
            continue
        giu = z1 - (cielo - margine)
        for o in sc.objects:
            if o.name == nome or o.name.startswith(nome + '_'):
                o.location.z -= giu
        print(f'{nome}: abbassata di {giu * 100:.1f} cm (soffitto a {cielo:.3f}: {cosa})')


# tubo grande del soffitto del corridoio: asse a y 2,32, z 2,38, raggio 8,5 cm, flange ogni 2,2 m
TUBO_GRANDE = (2.32, 2.38, 0.085)
VALVOLE_X = (4.9, 15.9)   # dov'erano; la prima non sopra il passaggio degli spogliatoi (x 6..7,6)


def tubo_grande_con_valvola(M):
    """Il tubo grande del soffitto del corridoio con le due valvole in linea (scelta dell'utente del 22 ottobre,
    opzione A): prima stavano su un bypass che scendeva a 1,58 m, all'altezza della testa di chi cammina. Ora
    il tubo passa dalle loro flange (foro grande come il tubo), con le controflange e i bulloni; il volantino
    guarda in basso verso il corridoio (45 gradi), tutto sopra i 2 m. Ritorna le parti statiche."""
    y, z, r = TUBO_GRANDE
    fine = 22.0
    tagli = []
    parti = []
    if HQ.disponibile('valvola_volantino'):
        # misure del modello (alto 1 m, asse del foro lungo x): metà lunghezza, centro e raggio del foro, flangia
        prova = HQ.metti('valvola_prova', 'valvola_volantino', (0, 0, 0), (None, None, 1.0), rot_z=R(180))
        bpy.context.view_layer.update()
        ws = [prova.matrix_world @ p.co for p in prova.data.vertices]
        bpy.data.objects.remove(prova)
        x1 = max(p.x for p in ws)
        faccia = [p for p in ws if p.x > x1 - 0.0095]
        zf = (min(p.z for p in faccia) + max(p.z for p in faccia)) / 2
        r_foro = (max(p.y for p in faccia) - min(p.y for p in faccia)) / 2
        corona = [p for p in ws if p.x > x1 - 0.0286]
        r_fl = (max(p.y for p in corona) - min(p.y for p in corona)) / 2
        alt = r / r_foro                     # foro grande come il tubo
        for n, vx in enumerate(VALVOLE_X):
            HQ.metti(f'valvola_corridoio_{n + 1}', 'valvola_volantino', (vx, y, z), (None, None, alt), rot_z=R(180),
                     perno=(0, 0, zf * alt), rot=(R(-135), 0, 0))
            tagli.append((vx - x1 * alt, vx + x1 * alt))
    for n, (xa, xb) in enumerate(tagli):
        for lato, xf in ((-1, xa), (1, xb)):
            # controflangia del tubo appoggiata a quella della valvola, con i bulloni
            fl = [L.cilindro('valvola_controflangia', (xf, y, z), (xf + lato * 0.025, y, z), r_fl * alt, M['metallo_grezzo'], seg=32)]
            for j in range(8):
                t = 2 * math.pi * j / 8
                py, pz = y + math.cos(t) * r_fl * alt * 0.8, z + math.sin(t) * r_fl * alt * 0.8
                fl.append(L.cilindro('valvola_bullone', (xf - lato * 0.01, py, pz), (xf + lato * 0.04, py, pz), 0.008, M['ruggine'], seg=8))
            parti.append(L.unisci(f'flangia_valvola_{n + 1}_{lato + 1}', fl))
    # il tubo, interrotto dove c'è la valvola; le flange del tubo restano dov'erano (ogni 2,2 m)
    estremi = [0.0] + [v for t in tagli for v in t] + [fine]
    pezzi = [L.cilindro(f'tubo_grande_{i}', (estremi[2 * i], y, z), (estremi[2 * i + 1], y, z), r, M['ruggine'], seg=28, tappi=False)
             for i in range(len(estremi) // 2)]
    k = 1
    while k * 2.2 < fine - 0.2:
        c = k * 2.2
        if not any(a - 0.1 < c < b + 0.1 for a, b in tagli):
            pezzi.append(L.cilindro('tubo_grande_fl', (c - 0.03, y, z), (c + 0.03, y, z), r * 1.35, M['ruggine'], seg=28))
        k += 1
    tubo = L.unisci('tubo_grande', pezzi)
    for p in tubo.data.polygons:
        p.use_smooth = True
    return [tubo] + parti


def costruisci():
    L.reset()
    M = materiali()
    corridoio(M)
    spogliatoi(M)
    stanzino(M)
    neon_sotto_il_soffitto()
    return M


if __name__ == '__main__':
    costruisci()
    out = os.path.join(AI, 'ambienti1.blend')
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print('salvato', out)
    if '--no-export' not in sys.argv:
        os.makedirs(os.path.join(AI, 'gltf'), exist_ok=True)
        for c in ('corridoio', 'spogliatoi', 'stanzino'):
            L.esporta_glb(os.path.join(AI, 'gltf', f'{c}.gltf'), [c])
