"""Posa "affacciata" (sala centrale, docs/concept/medusa_sbircia.jpg): la medusa vera dentro la vasca sollevata,
che sbircia chi entra. Immersa fino alla vita: la campana (schiacciata e allargata dalla shape key
"campana_schiaccia") brilla appena sotto il pelo dell'acqua; il busto esce dall'acqua inclinato in avanti, con le
spalle alzate e in avanti, la testa sporta sopra lo spigolo interno del bordo e appena inclinata, l'occhio
all'altezza di quello del giocatore. Mani larghe aggrappate al coping, palmo sopra e dita piegate oltre lo
spigolo esterno, gomiti in fuori. Otto tentacoli escono dall'acqua e scavalcano il bordo davanti, tra le mani e
accanto (le zampe fino al pavimento, i medi lungo il muro); gli altri restano sott'acqua intorno alla campana.
Unico movimento: un respiro quasi impercettibile (ciclo di 4 s).

Stesso scheletro e stessa scala vera (4,5 m) del modello eroe. I tentacoli approvati non cambiano: si piegano
solo con le loro catene di ossa. La vasca e' quella dell'agente ambiente (sala_vasca_centrale.glb):
  - origine del GLB 2,1 m dietro il filo esterno del muro davanti, al livello del pavimento della sala, nessuna
    rotazione; la medusa guarda verso +Z (in Blender -Y). Nella sala (filo esterno a z 12,25, interno a 11,95)
    il marker "medusa_affacciata" va in (0, 0, 10,15) Godot, rotazione 0;
  - bordo anteriore: faccia esterna a +2,1 m dal centro, coping largo 0,30 m (faccia interna a +1,8 m), cima a
    1,0 m; muro esterno verticale alto 1,0 m; pelo dell'acqua a 0,88 m; fondo della vasca a 0.
Uso come modulo dal passo 7: schiaccia_campana(arm) dopo la posa di riposo, poi azione_affacciata(arm, k, zp)
prima della scala vera.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_pose as POSE  # noqa: E402
from mathutils import Quaternion  # noqa: E402

# vasca, coordinate di Blender in metri (y = -Z di Godot), origine 2,1 m dietro il filo esterno, sul pavimento
VASCA = dict(fuori=-2.1, dentro=-1.8, cima=1.0, acqua=0.88, fondo=0.0, mezza_larghezza=1.8)
SPIGOLO_FUORI = -2.09             # spigolo esterno del coping (le piastrelle del muro sporgono fino a -2,09)
# corpo (metri, mondo): la vita (testa dell'osso colonna_1, cioe' la cima della campana) in fondo all'acqua, cosi'
# il pelo dell'acqua arriva appena sopra il seno (regola del GDD: il seno resta sempre coperto) e l'occhio e' a
# circa 1,65 m, all'altezza degli occhi di chi entra: lei sbircia dal basso, come nel concept
VITA = (0.0, -1.04, 0.43)
INCLINA = (13.0, 13.0, 12.0)      # busto in avanti (gradi): colonna_1, colonna_2, petto
GOBBA = (0.12, 0.07)              # spalle alzate e portate avanti (m): su, avanti
COLLO = -5.0                      # collo (gradi): appena indietro, la testa resta alta sopra il bordo
TESTA = (-40.0, 10.0)             # testa: indietro per guardare avanti (viso un po' in su), inclinata di lato
SGUARDO = (0.3, -11.0, 1.7)       # chi entra: a circa 9 m, occhi a 1,7 m
# mani: polso sopra lo spigolo interno, palmo sul coping, dita oltre lo spigolo esterno; gomiti in fuori
MANI_X = 0.6
POLSO = (-1.80, 1.036)            # y, z del polso: polso sullo spigolo interno, palmo appoggiato al coping
POLO_GOMITI = (1.3, -1.55, 1.05)  # verso dove si piegano i gomiti (x per il lato): in fuori e un po' in basso
# campana schiacciata sott'acqua: altezza x0,38 (il bordo resta sopra il fondo), +12% di larghezza al bordo
SCHIACCIA = (0.38, 0.12)
# Tentacoli che ricadono fuori dal bordo: le 4 zampe davanti (lunghe 3,2-3,6 m: arrivano al pavimento e ci si
# allargano) e i 4 medi davanti (2,3-2,4 m: pendono lungo il muro); le 2 zampe di dietro, gli altri medi e i
# sottili restano in acqua intorno alla campana.
# Dove passano il bordo (x sul coping, da sinistra) e verso dove si allargano sul pavimento: zampe ai lati, medi
# tra le mani e accanto, come nel concept; liberi il pulsante dei bambini (x -0,2..0,2, alto 0,44-0,8 m) e i
# disegni appesi al muro davanti (x -1,25..-1,04 e 1,14..1,36, alti 0,45-0,75 m).
POSTI_ZAMPE = [(-1.62, (-0.8, -0.6)), (-1.42, (-0.2, -1.0)), (1.48, (0.2, -1.0)), (1.68, (0.8, -0.6))]
POSTI_MEDI = [(-0.9, (0.0, -1.0)), (-0.34, (0.0, -1.0)), (0.34, (0.0, -1.0)), (0.9, (0.0, -1.0))]


def _mod(w, k, zp):
    """Mondo (m, origine al centro della vasca) -> spazio dello scheletro prima della scala vera."""
    w = np.asarray(w, float)
    return np.array([w[0] / k, w[1] / k, w[2] / k + zp])


def _mondo(m, k, zp):
    m = np.asarray(m, float)
    return np.array([m[0] * k, m[1] * k, (m[2] - zp) * k])


def _fitta(punti, passo=0.003):
    P = [np.asarray(punti[0], float)]
    for a, b in zip(punti[:-1], punti[1:]):
        a, b = np.asarray(a, float), np.asarray(b, float)
        n = max(int(np.linalg.norm(b - a) / passo), 1)
        for i in range(1, n + 1):
            P.append(a + (b - a) * i / n)
    return np.array(P)


def giunti_catena(punti, lunghezze):
    """Giunti di una catena di ossa lungo la polilinea: ognuno alla distanza dell'osso dal precedente."""
    P = _fitta(punti)
    pos = P[0].copy()
    j = 0
    giunti = [pos]
    for L in lunghezze:
        while j < len(P) and np.linalg.norm(P[j] - pos) < L:
            j += 1
        if j >= len(P):
            d = P[-1] - P[-2]
            d /= np.linalg.norm(d) + 1e-12
            q = pos + d * L
        else:
            a, b = P[max(j - 1, 0)], P[j]
            da, db = np.linalg.norm(a - pos), np.linalg.norm(b - pos)
            t = (L - da) / max(db - da, 1e-9)
            q = a + (b - a) * np.clip(t, 0, 1)
        giunti.append(q)
        pos = q
    return giunti


def adatta_catena(arm, nomi, punti):
    """Mette la catena lungo la polilinea (spazio dello scheletro): giunti alla distanza delle ossa."""
    giunti = giunti_catena(punti, [arm.data.bones[n].length for n in nomi])
    for i, n in enumerate(nomi):
        POSE.orienta(arm, n, Vector(giunti[i]), Vector(giunti[i + 1] - giunti[i]))
    return giunti


def _catene(arm):
    cat = {}
    for b in arm.data.bones:
        if b.name.startswith('tentacolo_'):
            _, i, kk = b.name.split('_')
            cat.setdefault(int(i), []).append((int(kk), b.name))
    return {i: [n for _, n in sorted(v)] for i, v in sorted(cat.items())}


def spigolo_bordo(x_t, g=1.0):
    """Dove il tentacolo passa lo spigolo interno del bordo (sopra il coping): qui ci va un giunto."""
    return (x_t, VASCA['dentro'] + 0.02 * g, VASCA['cima'] + 0.07 * g)


def percorso_bordo(R, x_t, verso, curva, z_fondo, g=1.0, vita=VITA):
    """Tentacolo che esce dall'acqua: scende sotto il bordo della campana, va in avanti fino al muro, giu' fino a
    z_fondo e su lungo il muro interno, sopra il coping e giu' lungo il muro esterno fino al pavimento, poi sul
    pavimento verso 'verso' con una curva morbida (coordinate del mondo). I tentacoli corti finiscono prima, appesi
    al muro. Le distanze dai muri e dal coping sono per le zampe (nastri larghi 21 cm e spessi 8 cm,
    attorcigliati): g le scala per i tentacoli piu' sottili, che cosi' si appoggiano al bordo."""
    V = VASCA
    d = np.array(verso, float)
    d /= np.linalg.norm(d)
    lato = np.array([-d[1], d[0]])
    piede = np.array([x_t, V['fuori'] - 0.13])
    pav = [piede + d * t + lato * curva * math.sin(math.pi * t / 1.0) for t in (0.22, 0.4, 0.6, 0.8, 1.0, 1.2)]
    return [R,
            (0.6 * R[0] + 0.4 * x_t, max(vita[1] - 0.45, V['dentro'] + 0.22), 0.075),
            (x_t, V['dentro'] + 0.16 * g, z_fondo),
            (x_t, V['dentro'] + 0.14 * g, V['acqua'] - 0.02),
            spigolo_bordo(x_t, g),
            (x_t, V['fuori'] - 0.01 * g, V['cima'] + 0.07 * g),
            (x_t, V['fuori'] - 0.11 * g, V['cima'] - 0.03),
            (x_t, V['fuori'] - 0.13 * g, 0.4),
            (x_t, V['fuori'] - 0.14, 0.16),
            (x_t + d[0] * 0.08, V['fuori'] - 0.17 + d[1] * 0.04, 0.085)] + [(p[0], p[1], 0.075) for p in pav]


def percorso_acqua(R, az, lunghezza, rng, vita=VITA):
    """Tentacolo sott'acqua: scende sotto il bordo della campana e le gira intorno, dietro, a mezz'acqua."""
    V = VASCA
    c = np.array([vita[0], vita[1]])
    pts = [R, (R[0] + 0.25 * math.cos(az), R[1] + 0.25 * math.sin(az), 0.075)]
    # verso dell'arco: verso il dietro (+y in Blender = lontano da chi entra)
    verso = 1.0 if math.cos(az) >= 0 else -1.0
    r0 = rng.uniform(1.15, 1.5)
    giro = min(lunghezza / r0, math.radians(150))
    fase = rng.uniform(0, 2 * math.pi)
    n = 24
    for i in range(1, n + 1):
        t = i / n
        a = az + verso * giro * t
        r = r0 + 0.12 * math.sin(2 * math.pi * 1.5 * t + fase)
        x, y = c[0] + r * math.cos(a), c[1] + r * math.sin(a)
        x = float(np.clip(x, -V['mezza_larghezza'] + 0.12, V['mezza_larghezza'] - 0.12))
        y = float(np.clip(y, V['dentro'] + 0.15, V['mezza_larghezza'] - 0.12))
        z = 0.1 + 0.42 * t + 0.08 * math.sin(2 * math.pi * 2 * t + fase)
        pts.append((x, y, min(z, V['acqua'] - 0.1)))
    return pts


# ---------------------------------------------------------------- campana schiacciata (shape key)

def schiaccia_campana(arm):
    """Shape key 'campana_schiaccia' (corpo, struttura interna, bordo): la campana si abbassa verso la vita e si
    allarga al bordo. Serve solo sott'acqua nella posa affacciata (la vita e' a pelo d'acqua e la vasca e' fonda
    0,88 m). Va fatta sulla posa di riposo, prima della scala vera."""
    sz, allarga = SCHIACCIA
    zv_arm = arm.data.bones['colonna_1'].head_local
    for nome in ('Medusa', 'Medusa_Interno', 'Medusa_Bordo'):
        ob = bpy.data.objects.get(nome)
        if ob is None:
            continue
        me = ob.data
        vita = ob.matrix_world.inverted() @ (arm.matrix_world @ zv_arm)
        co = coords(me)
        if nome == 'Medusa':
            mi = np.empty(len(me.polygons), dtype=np.int32)
            me.polygons.foreach_get('material_index', mi)
            idx = [i for i, m in enumerate(me.materials) if m and m.name.startswith('M_campana')]
            sel = np.zeros(len(me.vertices), bool)
            for p in me.polygons:
                if mi[p.index] in idx:
                    sel[list(p.vertices)] = True
            sel &= co[:, 2] < vita.z
        else:
            sel = np.ones(len(me.vertices), bool)
        z0 = co[sel, 2].min() if sel.any() else vita.z - 1.0
        t = np.clip((vita.z - co[:, 2]) / max(vita.z - z0, 1e-6), 0, 1)
        nuovo = co.copy()
        nuovo[:, 2] = np.where(sel, vita.z - (vita.z - co[:, 2]) * sz, co[:, 2])
        f = 1.0 + allarga * t ** 1.5
        nuovo[:, 0] = np.where(sel, vita.x + (co[:, 0] - vita.x) * f, co[:, 0])
        nuovo[:, 1] = np.where(sel, vita.y + (co[:, 1] - vita.y) * f, co[:, 1])
        if me.shape_keys is None:
            ob.shape_key_add(name='Basis', from_mix=False)
        sk = ob.shape_key_add(name='campana_schiaccia', from_mix=False)
        sk.data.foreach_set('co', nuovo.ravel())
        sk.value = 0.0
    log(f'shape key campana_schiaccia: altezza x{sz}, bordo +{allarga * 100:.0f}%')


# ---------------------------------------------------------------- posa

def _fuori_dal_bordo(P):
    """Distanza (con segno, positiva fuori) dei punti P dal blocco del bordo: coping (cima a 1,0, spigolo esterno
    a SPIGOLO_FUORI) e muro sotto, un po' rientrato."""
    V = VASCA
    y, z = P[:, 1], P[:, 2]
    fronte = np.where(z > V['cima'] - 0.08, SPIGOLO_FUORI, -2.05)
    dy = fronte - y                       # > 0 davanti al fronte
    dz = z - V['cima']                    # > 0 sopra la cima
    fuori = np.where((dy > 0) & (dz > 0), np.hypot(dy, dz), np.maximum(dy, dz))
    return fuori


def _orienta_dita(arm, suf, d_mano, k, zp, piega_min=20):
    """Dita aggrappate allo spigolo del coping: la prima falange sul coping, la seconda piegata giu' oltre lo
    spigolo (circa 90 gradi, nocca in alto), la punta premuta sul fronte. Per ogni dito si cercano le due pieghe
    che tengono le falangi fuori dal bordo (al loro spessore) con il polpastrello appoggiato al fronte.
    Il pollice resta sul coping, verso l'interno. Con piega_min piu' bassa le dita possono anche distendersi sul
    coping (mani che scivolano indietro, quando lo spigolo non si raggiunge piu')."""
    import medusa_mani as MANI
    V = VASCA
    s = 1.0 if suf == '.L' else -1.0
    H = MANI.OSSA_MANO['lunghezza'] * k                 # lunghezza della mano (m)
    r0 = MANI.MANI['raggio'] * H
    tap = MANI.MANI['rastremazione']
    su = np.array([0.0, 0.0, 1.0])
    for dito in POSE.DITA:
        nomi = [f'{dito}_{f}{suf}' for f in (1, 2, 3)]
        L = [arm.data.bones[n].length * k for n in nomi]
        r = r0 * MANI.MANI['spessore'][dito]
        K = _mondo(np.array(arm.pose.bones[nomi[0]].head), k, zp)
        if dito == 'pollice':
            avanti = np.array([-s * 0.45, -0.9, 0.0])
            avanti /= np.linalg.norm(avanti)
            dirs = []
            z_t = V['cima'] + r * tap[1]
            p = K.copy()
            for i in range(3):
                pend = math.asin(np.clip((p[2] - z_t) / L[i], -0.5, 0.5)) if i == 0 else 0.0
                dk = avanti * math.cos(pend) - su * math.sin(pend)
                dirs.append(dk)
                p = p + dk * L[i]
        else:
            # avanti lungo il dito (il ventaglio della mano resta), in piano
            dx = _mondo(np.array(arm.pose.bones[nomi[0]].tail), k, zp) - K
            avanti = np.array([dx[0], dx[1], 0.0])
            avanti /= np.linalg.norm(avanti)
            z_pip = V['cima'] + r * tap[1]
            pend = math.asin(np.clip((K[2] - z_pip) / L[0], -0.6, 0.6))
            d1 = avanti * math.cos(pend) - su * math.sin(pend)
            P1 = K + d1 * L[0]
            migliore = None
            for a2 in np.radians(np.arange(piega_min, 121, 4)):
                d2 = avanti * math.cos(a2) - su * math.sin(a2)
                P2 = P1 + d2 * L[1]
                for a3 in np.radians(np.arange(0, 71, 5)):
                    d3 = avanti * math.cos(a2 + a3) - su * math.sin(a2 + a3)
                    P3 = P2 + d3 * L[2]
                    pen = 0.0
                    for (A, B, ra, rb) in ((K, P1, r, r * tap[1]), (P1, P2, r * tap[1], r * tap[2]),
                                           (P2, P3, r * tap[2], r * tap[3])):
                        t = np.linspace(0, 1, 7)[:, None]
                        Q = A + (B - A) * t
                        rq = (ra + (rb - ra) * t[:, 0]) * 0.92
                        pen += np.clip(rq - _fuori_dal_bordo(Q), 0, None).sum()
                    tip = P2 + d3 * max(L[2] - 0.5 * r * tap[3], 0.0)
                    contatto = abs(float(_fuori_dal_bordo(tip[None])[0]) - r * tap[3])
                    costo = 50.0 * pen + 4.0 * contatto + 0.02 * abs(math.degrees(a2) - 90) / 90
                    if migliore is None or costo < migliore[0]:
                        migliore = (costo, d2, d3)
            _, d2, d3 = migliore
            dirs = [d1, d2, d3]
        lat = np.cross(avanti, su)
        lat /= np.linalg.norm(lat)
        p = K.copy()
        for nome, dk, Lk in zip(nomi, dirs, L):
            dk = dk / np.linalg.norm(dk)
            dorso = np.cross(lat, dk)                 # dalla parte delle unghie: fuori dalla piega
            POSE.orienta(arm, nome, Vector(_mod(p, k, zp)), Vector(dk), Vector(dorso))
            p = p + dk * Lk


def posa_affacciata(arm, k, zp, respiro=0.0):
    """Tutta la posa nello spazio dello scheletro (prima della scala vera)."""
    POSE.azzera(arm)
    # 1. corpo: la vita va al suo posto nella vasca
    vita_riposo = np.array(arm.data.bones['colonna_1'].head_local)
    d = _mod(VITA, k, zp) - vita_riposo
    pr = arm.pose.bones['radice']
    pr.matrix = Matrix.Translation(Vector(d)) @ arm.data.bones['radice'].matrix_local
    POSE.aggiorna()
    # 2. busto inclinato in avanti, collo in avanti, testa che torna a guardare avanti e si inclina di lato
    for nome, gradi in zip(('colonna_1', 'colonna_2', 'petto'), INCLINA):
        pb = arm.pose.bones[nome]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi + (respiro if nome == 'petto' else 0.0)), 0, 0)
    for nome, gradi, rollio in (('collo', COLLO, 0.0), ('testa', TESTA[0], TESTA[1])):
        pb = arm.pose.bones[nome]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi), 0, math.radians(rollio))
    POSE.aggiorna()
    # 3. spalle alzate e in avanti (ingobbita); col respiro si alzano appena
    for suf in ('.L', '.R'):
        pb = arm.pose.bones['clavicola' + suf]
        testa_c, coda = np.array(pb.head), np.array(pb.tail)
        su = (GOBBA[0] + 0.004 * respiro) / k
        nuova = coda + np.array([0.0, -GOBBA[1] / k, su])
        POSE.orienta(arm, 'clavicola' + suf, Vector(testa_c), Vector(nuova - testa_c))
    # 4. braccia: polso sopra lo spigolo interno, palmo sul coping, gomiti in fuori; dita aggrappate
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = Vector(_mod((s * MANI_X, POLSO[0], POLSO[1]), k, zp))
        polo = Vector(_mod((s * POLO_GOMITI[0], POLO_GOMITI[1], POLO_GOMITI[2]), k, zp))
        d_mano = np.array([s * 0.1, -1.0, 0.0])
        d_mano /= np.linalg.norm(d_mano)
        POSE.posa_braccio(arm, suf, polso, polo, Vector(d_mano), Vector((0.0, 0.0, 1.0)))
        _orienta_dita(arm, suf, d_mano, k, zp)
    POSE.aggiorna()
    # 5. occhio fisso su chi entra (al massimo 15 gradi dal riposo)
    pe = arm.pose.bones['occhio']
    testa_occ = np.array(pe.head)
    bersaglio = _mod(SGUARDO, k, zp)
    dirz = bersaglio - testa_occ
    dirz /= np.linalg.norm(dirz)
    attuale = np.array(pe.matrix.col[1][:3])
    attuale /= np.linalg.norm(attuale)
    ang = math.acos(np.clip(attuale @ dirz, -1, 1))
    if ang > math.radians(15):
        q = Vector(attuale).rotation_difference(Vector(dirz))
        q = Quaternion().slerp(q, math.radians(15) / ang)
        dirz = np.array(q @ Vector(attuale))
    POSE.orienta(arm, 'occhio', Vector(testa_occ), Vector(dirz))
    # 6. tentacoli: quelli davanti escono dall'acqua e ricadono fuori dal bordo, gli altri restano sott'acqua
    perc = percorsi_tentacoli(arm, k, zp)
    for c in perc:
        adatta_catena(arm, c['nomi'], c['pts'])
    n_d = sum(1 for c in perc if c['ruolo'] == 'bordo')
    return n_d, len(perc) - n_d


def percorsi_tentacoli(arm, k, zp, vita=VITA, schiaccia=1.0):
    """Percorsi dei tentacoli nella posa affacciata (spazio dello scheletro), dalle radici nella posa attuale.
    Ritorna per ogni catena un dizionario: nomi, radice R (mondo), ruolo ('bordo': esce dall'acqua e scavalca il
    bordo; 'acqua': resta sott'acqua), i parametri del percorso e i punti 'pts'. Con vita e schiaccia diversi
    (campana spostata o meno schiacciata) le radici e i percorsi seguono la campana; i tentacoli che escono
    scavalcano sempre lo stesso punto del bordo."""
    rng = np.random.default_rng(31)
    cat = _catene(arm)
    vita_w = np.array(vita, float)
    tutte = []
    for i, nomi in cat.items():
        R = _mondo(np.array(arm.pose.bones[nomi[0]].head), k, zp)
        # le radici seguono la campana schiacciata (restano dentro, sopra il fondo della vasca)
        R[2] = vita_w[2] - (vita_w[2] - R[2]) * (1.0 - schiaccia * (1.0 - SCHIACCIA[0]))
        az = math.atan2(R[1] - vita_w[1], R[0] - vita_w[0])
        tutte.append((i, nomi, R, az))
    # escono dall'acqua le zampe e i medi piu' vicini al davanti (azimut -90 gradi, verso chi entra)
    tutte.sort(key=lambda c: abs(math.remainder(c[3] + math.pi / 2, 2 * math.pi)))
    zampe = sorted([c for c in tutte if len(c[1]) >= 10][:len(POSTI_ZAMPE)], key=lambda c: c[2][0])
    medi = sorted([c for c in tutte if 5 <= len(c[1]) < 10][:len(POSTI_MEDI)], key=lambda c: c[2][0])
    davanti = list(zip(zampe, POSTI_ZAMPE)) + list(zip(medi, POSTI_MEDI))
    fuori = {c[0] for c, _ in davanti}
    dietro = [c for c in tutte if c[0] not in fuori]
    out = []
    for (i, nomi, R, az), (x_t, verso) in davanti:
        g = 1.0 if len(nomi) >= 10 else 0.5            # i medi sono larghi e spessi la meta' delle zampe
        curva = rng.uniform(0.12, 0.2) * rng.choice([-1, 1])
        # le ossa sono dritte e lunghe piu' o meno quanto il coping e' largo: se un giunto cade sullo spigolo
        # interno, l'osso dopo attraversa il coping e quello dopo ancora scende lungo il muro, senza tagliare gli
        # spigoli. Il giunto ce lo porta la profondita' del tratto sott'acqua vicino al muro.
        lunghezze = [arm.data.bones[n].length for n in nomi]
        A = _mod(spigolo_bordo(x_t, g), k, zp)
        migliore = None
        for z_fondo in np.linspace(0.1, 0.55, 46):
            pts = [_mod(p, k, zp) for p in percorso_bordo(R, x_t, verso, curva, z_fondo, g, vita_w)]
            e = min(np.linalg.norm(q - A) for q in giunti_catena(pts, lunghezze))
            if migliore is None or e < migliore[0]:
                migliore = (e, pts, z_fondo)
        out.append(dict(i=i, nomi=nomi, R=R, az=az, ruolo='bordo', x_t=x_t, verso=verso, curva=curva, g=g,
                        z_fondo=migliore[2], pts=migliore[1]))
    for i, nomi, R, az in dietro:
        L = sum(arm.data.bones[n].length for n in nomi) * k
        pts = [_mod(p, k, zp) for p in percorso_acqua(R, az, L, rng, vita_w)]
        out.append(dict(i=i, nomi=nomi, R=R, az=az, ruolo='acqua', pts=pts))
    return out


def azione_affacciata(arm, k, zp, chiave, nla):
    """Azione 'affacciata' (96 fotogrammi, 4 s, in ciclo): posa immobile con un respiro appena visibile."""
    act = bpy.data.actions.new('affacciata')
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    for f, r in ((1, 0.0), (49, 0.8), (97, 0.0)):
        n_d, n_a = posa_affacciata(arm, k, zp, respiro=r)
        chiave(arm, f)
    nla(arm, 'affacciata', act)
    # campana schiacciata sott'acqua per tutta l'azione (shape key a 1)
    for nome in ('Medusa', 'Medusa_Interno', 'Medusa_Bordo'):
        ob = bpy.data.objects.get(nome)
        if ob is None or not ob.data.shape_keys or 'campana_schiaccia' not in ob.data.shape_keys.key_blocks:
            continue
        key = ob.data.shape_keys
        kb = key.key_blocks['campana_schiaccia']
        ka = bpy.data.actions.new(f'affacciata_campana_{nome}')
        (key.animation_data or key.animation_data_create()).action = ka
        for f in (1, 97):
            kb.value = 1.0
            kb.keyframe_insert('value', frame=f)
        nla(key, 'affacciata', ka)
        kb.value = 0.0
    POSE.azzera(arm)
    log(f'posa affacciata: {n_d} tentacoli fuori dal bordo, {n_a} sott\'acqua; vita a {VITA}, mani a x +-{MANI_X}')
