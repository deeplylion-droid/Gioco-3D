"""Posa "affacciata" (sala centrale, docs/concept/medusa_sbircia.jpg): la medusa vera dentro la vasca sollevata,
affacciata e immobile. Mani sul bordo piastrellato con le dita aggrappate, busto e testa fuori dall'acqua,
campana a pelo d'acqua, tentacoli che escono dall'acqua, passano sul bordo e ricadono lungo il muro (le zampe fino
al pavimento, i medi a mezzo muro), gli altri sotto l'acqua intorno alla campana; testa appena inclinata, occhio
fisso su chi entra.
Unico movimento: un respiro quasi impercettibile (ciclo di 4 s).

Stesso scheletro e stessa scala vera (4,5 m) del modello eroe. I tentacoli approvati non cambiano: si piegano
solo con le loro catene di ossa. La vasca e' quella dell'agente ambiente (misure del coordinatore):
  - origine del GLB 2,1 m dietro il filo esterno del muro davanti, al livello del pavimento della sala, nessuna
    rotazione; la medusa guarda verso +Z (in Blender -Y). Nella vasca della sala (sala_dati.json: filo esterno a
    z 12,25, interno a 11,95) il marker "medusa_affacciata" va in (0, 0, 10,15) Godot, rotazione 0;
  - bordo anteriore: faccia esterna a +2,1 m dal centro, coping largo 0,30 m (faccia interna a +1,8 m), cima a
    1,0 m; muro esterno verticale alto 1,0 m; pelo dell'acqua a 0,88 m; fondo della vasca a 0 (o piu' in basso).
Uso come modulo dal passo 7: azione_affacciata(arm, k, zp) prima della scala vera.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_pose as POSE  # noqa: E402

# vasca, coordinate di Blender in metri (y = -Z di Godot), origine al centro della vasca sul pavimento
VASCA = dict(fuori=-2.1, dentro=-1.8, cima=1.0, acqua=0.88, fondo=0.0, mezza_larghezza=1.8)
VITA = (0.0, -0.85, 1.2)          # dove sta la vita (cima della campana): campana a pelo d'acqua, 17 cm dal muro
MANI_X = 0.45                     # mani sul bordo anteriore
SGUARDO = (0.3, -11.0, 1.7)       # chi entra: a circa 9 m, occhi a 1,7 m
# Tentacoli che ricadono fuori dal bordo: le 4 zampe davanti (lunghe 3,2-3,6 m: arrivano al pavimento e ci si
# allargano) e i 4 medi davanti (2,3-2,4 m: pendono lungo il muro); le 2 zampe di dietro, gli altri medi e i
# sottili restano in acqua intorno alla campana.
# Dove passano il bordo (x sul coping, da sinistra) e verso dove si allargano sul pavimento: zampe ai lati, medi
# vicino alle mani, come nel concept; liberi il pulsante dei bambini (x -0,2..0,2) e i disegni appesi al muro
# davanti (x -1,25..-1,04 e 1,14..1,36, alti 0,45-0,75 m) della vasca dell'agente ambiente.
POSTI_ZAMPE = [(-1.62, (-0.8, -0.6)), (-1.42, (-0.2, -1.0)), (1.48, (0.2, -1.0)), (1.68, (0.8, -0.6))]
POSTI_MEDI = [(-0.88, (0.0, -1.0)), (-0.68, (0.0, -1.0)), (0.66, (0.0, -1.0)), (0.86, (0.0, -1.0))]


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


def percorso_bordo(R, x_t, verso, curva, z_fondo, g=1.0):
    """Tentacolo che esce dall'acqua: sotto la campana (sotto il suo bordo), in avanti fino al muro, giu' fino a
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
            (0.6 * R[0] + 0.4 * x_t, VITA[1] - 0.45, 0.2),
            (x_t, V['dentro'] + 0.16 * g, z_fondo),
            (x_t, V['dentro'] + 0.14 * g, V['acqua'] - 0.02),
            spigolo_bordo(x_t, g),
            (x_t, V['fuori'] - 0.01 * g, V['cima'] + 0.07 * g),
            (x_t, V['fuori'] - 0.11 * g, V['cima'] - 0.03),
            (x_t, V['fuori'] - 0.13 * g, 0.4),
            (x_t, V['fuori'] - 0.14, 0.16),
            (x_t + d[0] * 0.08, V['fuori'] - 0.17 + d[1] * 0.04, 0.07)] + [(p[0], p[1], 0.06) for p in pav]


def percorso_acqua(R, az, lunghezza, rng):
    """Tentacolo sott'acqua: scende sotto il bordo della campana e gira intorno, dietro, a mezz'acqua."""
    V = VASCA
    c = np.array([VITA[0], VITA[1]])
    pts = [R, (R[0] + 0.25 * math.cos(az), R[1] + 0.25 * math.sin(az), 0.22)]
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
        z = 0.16 + 0.42 * t + 0.08 * math.sin(2 * math.pi * 2 * t + fase)
        pts.append((x, y, min(z, V['acqua'] - 0.1)))
    return pts


def posa_affacciata(arm, k, zp, respiro=0.0):
    """Tutta la posa nello spazio dello scheletro (prima della scala vera)."""
    rng = np.random.default_rng(31)
    POSE.azzera(arm)
    # 1. corpo: la vita va al suo posto nella vasca
    vita_riposo = np.array(arm.data.bones['colonna_1'].head_local)
    d = _mod(VITA, k, zp) - vita_riposo
    pr = arm.pose.bones['radice']
    pr.matrix = Matrix.Translation(Vector(d)) @ arm.data.bones['radice'].matrix_local
    POSE.aggiorna()
    # 2. busto in avanti sul bordo, testa che torna dritta e si inclina un poco, respiro sul petto
    for nome, gradi in (('colonna_1', 13), ('colonna_2', 12), ('petto', 10 + respiro)):
        pb = arm.pose.bones[nome]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi), 0, 0)
    for nome, gradi, rollio in (('collo', -12, 0), ('testa', -15, 9)):
        pb = arm.pose.bones[nome]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi), 0, math.radians(rollio))
    for suf in ('.L', '.R'):
        pb = arm.pose.bones['clavicola' + suf]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(-0.4 * respiro), 0, 0)
    POSE.aggiorna()
    # 3. braccia: mani sul coping, dita in avanti che si aggrappano oltre il bordo, gomiti un po' in fuori
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = Vector(_mod((s * MANI_X, VASCA['dentro'] - 0.06, VASCA['cima'] + 0.05), k, zp))
        polo = Vector(_mod((s * 1.1, -1.0, 1.6), k, zp))
        POSE.posa_braccio(arm, suf, polso, polo, Vector((-s * 0.05, -1.0, -0.12)), Vector((s * 0.1, 0.05, 1.0)))
        for dito in POSE.DITA:
            extra = (4, 12, 10) if dito == 'pollice' else (2, 46, 28)
            for f in (1, 2, 3):
                pb = arm.pose.bones[f'{dito}_{f}{suf}']
                pb.rotation_mode = 'XYZ'
                pb.rotation_euler = (-math.radians(extra[f - 1]), 0, 0)
    POSE.aggiorna()
    # 4. occhio fisso su chi entra (al massimo 15 gradi dal riposo)
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
    # 5. tentacoli: quelli davanti escono dall'acqua e ricadono fuori dal bordo, gli altri restano sott'acqua
    cat = _catene(arm)
    vita_w = np.array(VITA)
    tutte = []
    for i, nomi in cat.items():
        R = _mondo(np.array(arm.pose.bones[nomi[0]].head), k, zp)
        az = math.atan2(R[1] - vita_w[1], R[0] - vita_w[0])
        tutte.append((i, nomi, R, az))
    # escono dall'acqua le zampe e i medi piu' vicini al davanti (azimut -90 gradi, verso chi entra)
    tutte.sort(key=lambda c: abs(math.remainder(c[3] + math.pi / 2, 2 * math.pi)))
    zampe = sorted([c for c in tutte if len(c[1]) >= 10][:len(POSTI_ZAMPE)], key=lambda c: c[2][0])
    medi = sorted([c for c in tutte if 5 <= len(c[1]) < 10][:len(POSTI_MEDI)], key=lambda c: c[2][0])
    davanti = list(zip(zampe, POSTI_ZAMPE)) + list(zip(medi, POSTI_MEDI))
    fuori = {c[0] for c, _ in davanti}
    dietro = [c for c in tutte if c[0] not in fuori]
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
            pts = [_mod(p, k, zp) for p in percorso_bordo(R, x_t, verso, curva, z_fondo, g)]
            e = min(np.linalg.norm(q - A) for q in giunti_catena(pts, lunghezze))
            if migliore is None or e < migliore[0]:
                migliore = (e, pts)
        adatta_catena(arm, nomi, migliore[1])
    for i, nomi, R, az in dietro:
        L = sum(arm.data.bones[n].length for n in nomi) * k
        pts = [_mod(p, k, zp) for p in percorso_acqua(R, az, L, rng)]
        adatta_catena(arm, nomi, pts)
    return len(davanti), len(dietro)


def azione_affacciata(arm, k, zp, chiave, nla):
    """Azione 'affacciata' (96 fotogrammi, 4 s, in ciclo): posa immobile con un respiro appena visibile."""
    act = bpy.data.actions.new('affacciata')
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    for f, r in ((1, 0.0), (49, 0.8), (97, 0.0)):
        n_d, n_a = posa_affacciata(arm, k, zp, respiro=r)
        chiave(arm, f)
    nla(arm, 'affacciata', act)
    POSE.azzera(arm)
    log(f'posa affacciata: {n_d} tentacoli fuori dal bordo, {n_a} sott\'acqua; vita a {VITA}, mani a x +-{MANI_X}')
