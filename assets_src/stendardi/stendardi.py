"""Gli stendardi dei bambini nella sala delle condotte (inseguimento): lenzuoli grandi colorati dal club dei bambini
della nave, appesi nel vuoto dietro le vasche, lontani (nota dell'utente del 6 novembre: «Lascia le vasche uguali ma
aggiungi degli stendardi giganti appesi nel vuoto dietro, nella distanza ... come s'è fossero lenzuoli appesi e colorati
dai bambini»).

Come starebbero davvero:
- ogni lenzuolo è ripiegato sopra un bastone (un tubo di plastica arancio, Ø 2,2 cm) e fermato sotto il bastone con le
  mollette da bucato, che stringono le due falde; il bastone pende da corde che gli fanno due giri attorno 5-8 cm prima
  del capo, col nodo sopra, e salgono a un golfare avvitato sotto una trave del soffitto (le travi ogni 4 m, sotto a
  z -6,6, attaccate al soffitto: la corda non ci può girare sopra), annodate all'occhiello: niente galleggia;
- la grandezza (e le cuciture, se è fatto di più lenzuoli) è in misure.py, che legge anche teli.py;
- il tessuto cade con le pieghe vere: fra una molletta e l'altra la cima si affloscia e da lì scendono le pieghe, che si
  allargano e si smorzano verso il fondo; il fondo è un po' ondulato e un angolo è più basso;
- lontano da tubi, tiranti e catene (controllato qui: almeno [DISTANZA_MINIMA] da ogni altra geometria della sala),
  e almeno 2 m sopra i tubi in cui si scivola e le vasche.
Le coordinate sono di Blender (z in su), come le altre GLB della sala (assets/ambiente/inseguimento/). Scrive
godot/assets/ambiente/inseguimento/stendardi/stendardi.glb e stendardi.json (dove sono, per il gioco e per i controlli).
Le texture le fa teli.py. Uso: /home/user/tools/blender-venv/bin/python assets_src/stendardi/stendardi.py
"""
import json
import math
import os
import sys

import bpy
import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from misure import STENDARDI  # noqa: E402
from mathutils import Vector
from mathutils.bvhtree import BVHTree

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
DIR = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'inseguimento')
USCITA = os.path.join(DIR, 'stendardi')

SOTTO_TRAVE = -6.6          # il fondo delle travi del soffitto
DISTANZA_MINIMA = 0.25

# il bastone: raggio; il risvolto del lenzuolo sopra il bastone (quanto scende dietro e davanti prima delle mollette)
R_BASTONE = 0.011
R_CORDA = 0.006
RISVOLTO = 0.06


def pulisci():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def materiale(nome, colore=(0.8, 0.8, 0.8, 1.0)):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.diffuse_color = colore
    return m


def lenzuolo(nome, centro, verso, lato, largo, alto, mollette, seme):
    """La mesh del lenzuolo: una griglia 24 x 36, la cima sulle mollette, le pieghe che scendono dalle mollette.
    centro: il punto in mezzo alla cima; verso: dove guarda la faccia disegnata; lato: lungo la cima (da sinistra a destra
    di chi guarda la faccia)."""
    import random
    rnd = random.Random(seme)
    nx, ny = max(24, int(largo * 8)), max(36, int(alto * 8))
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    uv_l = bm.loops.layers.uv.new('UVMap')
    up = Vector((0, 0, 1))
    vert = []
    fasi = [rnd.uniform(0, math.tau) for _ in range(3)]
    for j in range(ny + 1):
        v = j / ny                      # 0 in cima, 1 in fondo
        riga = []
        for i in range(nx + 1):
            u = i / nx
            # fra le mollette (n-1 campate) la cima si affloscia (8 cm) e lì nascono le pieghe
            campata = u * (mollette - 1)
            t = campata - math.floor(campata)
            fra = math.sin(math.pi * t)            # 0 sulle mollette, 1 a metà campata
            abbassa = 0.08 * fra * math.exp(-v * 6.0)
            # le pieghe: in profondità (verso), le creste a metà campata; crescono scendendo e poi si smorzano un po'
            amp = 0.11 * (1 - math.exp(-v * 5.0)) * (1.0 - 0.35 * v)
            piega = amp * math.cos(math.pi * 2 * campata) * -1.0
            # e una piega larga, lenta, che fa ondeggiare tutto il telo (il lenzuolo non è una tavola)
            larga = 0.07 * v * math.sin(u * math.pi * 1.6 + fasi[0]) + 0.03 * math.sin(v * 5.0 + fasi[1])
            # il fondo ondulato e l'angolo destro più basso (il peso dell'orlo bagnato)
            fondo = 0.0
            if v > 0.85:
                fondo = (v - 0.85) / 0.15 * (0.06 * math.sin(u * 9.0 + fasi[2]) + 0.12 * u)
            # le pieghe stringono un po' il telo in larghezza (il tessuto va in profondità)
            x = (u - 0.5) * largo * (1.0 - 0.025 * (1 - math.exp(-v * 4.0)))
            p = centro + lato * x + verso * (piega + larga) - up * (v * alto + abbassa + fondo)
            riga.append(bm.verts.new(p))
        vert.append(riga)
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((vert[j][i], vert[j + 1][i], vert[j + 1][i + 1], vert[j][i + 1]))
            for l, (a, b) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                l[uv_l].uv = (a / nx, 1.0 - b / ny)
    # (la faccia disegnata guarda verso [verso])
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(verso) < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(materiale('M_' + nome))
    return o, [centro + lato * ((k / (mollette - 1)) - 0.5) * largo for k in range(mollette)]


def cilindro(nome, a, b, r, mat, seg=8):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    d = (b - a)
    lung = d.length
    asse = d.normalized()
    t1 = asse.orthogonal().normalized()
    t2 = asse.cross(t1)
    anelli = []
    for p in (a, b):
        anelli.append([bm.verts.new(p + (t1 * math.cos(k * math.tau / seg) + t2 * math.sin(k * math.tau / seg)) * r) for k in range(seg)])
    for k in range(seg):
        bm.faces.new((anelli[0][k], anelli[0][(k + 1) % seg], anelli[1][(k + 1) % seg], anelli[1][k]))
    bm.faces.new(anelli[0][::-1])
    bm.faces.new(anelli[1])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def scatola(nome, c, assi, mezzi, mat):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    vs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                vs.append(bm.verts.new(c + assi[0] * sx * mezzi[0] + assi[1] * sy * mezzi[1] + assi[2] * sz * mezzi[2]))
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[k] for k in q])
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def corda(nome, a, b, mat, cedere=0.0, seg=10):
    """Una corda da a a b (tesa, o che cede di [cedere] metri a metà), fatta di cilindri corti."""
    pezzi = []
    pts = []
    for k in range(seg + 1):
        t = k / seg
        pts.append(a.lerp(b, t) - Vector((0, 0, cedere * math.sin(math.pi * t))))
    for k in range(seg):
        pezzi.append(cilindro('%s_%d' % (nome, k), pts[k], pts[k + 1], R_CORDA, mat, seg=6))
    return pezzi


def toro(nome, c, asse, R, r, mat, seg=16, seg_r=6):
    """Un anello (toro) di centro [c], asse [asse], raggio [R] e sezione [r]."""
    asse = asse.normalized()
    t1 = asse.orthogonal().normalized()
    t2 = asse.cross(t1)
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    anelli = []
    for i in range(seg):
        a = math.tau * i / seg
        d = t1 * math.cos(a) + t2 * math.sin(a)
        anelli.append([bm.verts.new(c + d * (R + r * math.cos(math.tau * k / seg_r)) + asse * r * math.sin(math.tau * k / seg_r))
                       for k in range(seg_r)])
    for i in range(seg):
        for k in range(seg_r):
            bm.faces.new((anelli[i][k], anelli[(i + 1) % seg][k], anelli[(i + 1) % seg][(k + 1) % seg_r], anelli[i][(k + 1) % seg_r]))
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def palla(nome, c, r, mat):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=r)
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def risvolto(nome, cima, verso, lato, largo, mat):
    """Il lenzuolo ripiegato sopra il bastone: dalla cima del telo (6 cm sotto il bastone) sale davanti, gira sopra il
    bastone e riscende dietro fino alla stessa quota. [cima]: il centro del bastone. Stessa stoffa del telo (la fascia
    più alta della texture)."""
    rb = R_BASTONE + 0.0015
    sez = [(0.0, -R_BASTONE - RISVOLTO), (rb * 0.55, -rb * 1.6), (rb, -rb * 0.3), (rb * 0.7, rb * 0.72),
           (0.0, rb), (-rb * 0.7, rb * 0.72), (-rb, -rb * 0.3), (-rb * 0.55, -rb * 1.6), (-0.003, -R_BASTONE - RISVOLTO)]
    nx = max(12, int(largo * 4))
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    uv_l = bm.loops.layers.uv.new('UVMap')
    up = Vector((0, 0, 1))
    righe = []
    for (dv, dz) in sez:
        righe.append([bm.verts.new(cima + lato * ((i / nx) - 0.5) * largo + verso * dv + up * dz) for i in range(nx + 1)])
    for j in range(len(sez) - 1):
        for i in range(nx):
            f = bm.faces.new((righe[j][i], righe[j + 1][i], righe[j + 1][i + 1], righe[j][i + 1]))
            for l, (a, b) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                l[uv_l].uv = (a / nx, 1.0 - 0.012 * b / (len(sez) - 1))
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def molletta(nome, p, verso, lato, mat):
    """Una molletta da bucato vera, sotto il bastone: due bracci di legno lunghi 7,5 cm e larghi 1,1 cm, ognuno con la
    bocca sottile in cima (stringe le due falde del risvolto) e il manico più spesso in basso, che si allarga appena
    verso fuori, e la molla di metallo a metà, che sporge di lato. [p]: dove il telo esce dal risvolto (6 cm sotto il
    bastone), sul piano del telo."""
    up = Vector((0, 0, 1))
    pezzi = []
    centro_z = p.z + RISVOLTO - 0.045        # (le punte arrivano 1,5 cm sotto il bastone)
    molla_z = centro_z + 0.004
    for s_ in (-1, 1):
        # la bocca: 3,4 cm sopra la molla, spessa 5 mm, appoggiata alla stoffa (faccia interna a 2,5 mm dal telo)
        c = Vector((p.x, p.y, molla_z + 0.017)) + verso * s_ * 0.005
        pezzi.append(scatola('%s_bocca%d' % (nome, s_), c, [lato, verso, up], (0.0055, 0.0025, 0.017), mat))
        # il manico: 4,1 cm sotto la molla, spesso 7 mm, un po' aperto in basso
        asse_z = (up - verso * s_ * 0.08).normalized()
        c = Vector((p.x, p.y, molla_z - 0.0185)) + verso * s_ * (0.0065 + 0.0015)
        pezzi.append(scatola('%s_manico%d' % (nome, s_), c, [lato, asse_z.cross(lato).normalized(), asse_z], (0.0055, 0.0035, 0.0225), mat))
    molla_c = Vector((p.x, p.y, molla_z))
    pezzi.append(cilindro(nome + '_molla', molla_c - lato * 0.008, molla_c + lato * 0.008, 0.0045, materiale('M_molla', (0.6, 0.6, 0.62, 1)), seg=8))
    return unisci(nome, pezzi)


def corda_al_bastone(nome, capo, lato, mat):
    """I due giri della corda attorno al bastone in [capo] (sul suo asse), larghi 3 cm lungo il bastone, e il nodo sopra.
    Torna i pezzi e il punto sopra il bastone da cui la corda sale."""
    pezzi = []
    rr = R_BASTONE + R_CORDA * 0.9
    up = Vector((0, 0, 1))
    giro_v = lato.cross(up).normalized()
    pts = []
    n = 56
    for k in range(n + 1):
        t = k / n
        a = math.pi / 2 + t * 2 * math.tau          # due giri, dall'alto
        pts.append(capo + lato * (-0.015 + 0.03 * t) + (up * math.sin(a) + giro_v * math.cos(a)) * rr)
    for k in range(n):
        pezzi.append(cilindro('%s_giro%d' % (nome, k), pts[k] - (pts[k + 1] - pts[k]) * 0.15, pts[k + 1] + (pts[k + 1] - pts[k]) * 0.15, R_CORDA, mat, seg=6))
    # il nodo sopra il bastone, accanto ai giri, e il capo corto che pende
    nodo = capo + up * (R_BASTONE + R_CORDA * 1.6) + lato * 0.022
    pezzi.append(palla(nome + '_nodo', nodo, R_CORDA * 2.2, mat))
    pezzi.append(cilindro(nome + '_capo', nodo, nodo + lato * 0.02 - up * 0.05, R_CORDA * 0.9, mat, seg=6))
    return pezzi, pts[0]


def golfare(nome, x, y, verso_corda, mat_corda):
    """Il golfare avvitato sotto la trave (il gambo entra 1,2 cm nel legno-ferro della trave), l'occhiello sotto, e la
    corda annodata all'occhiello. Torna i pezzi e il punto dove la corda arriva (il fondo dell'occhiello)."""
    m_ferro = materiale('M_golfare', (0.45, 0.45, 0.47, 1))
    up = Vector((0, 0, 1))
    pezzi = [cilindro(nome + '_gambo', Vector((x, y, SOTTO_TRAVE + 0.012)), Vector((x, y, SOTTO_TRAVE - 0.03)), 0.006, m_ferro, seg=8)]
    occhio_c = Vector((x, y, SOTTO_TRAVE - 0.03 - 0.02))
    # (l'occhiello nel piano verticale della corda)
    asse = verso_corda.cross(up)
    if asse.length < 0.1:
        asse = Vector((1, 0, 0))
    pezzi.append(toro(nome + '_occhiello', occhio_c, asse, 0.02, 0.005, m_ferro))
    fondo = occhio_c - up * 0.02
    # il nodo della corda attorno al fondo dell'occhiello
    pezzi.append(toro(nome + '_nodo', fondo, up.cross(asse).normalized(), 0.01, 0.0065, mat_corda, seg=12))
    return pezzi, fondo - up * 0.012


def trave_vicina(x):
    return round((x - 44.0) / 4.0) * 4.0 + 44.0


def unisci(nome, pezzi):
    """Un oggetto solo dai [pezzi]."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in pezzi:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pezzi[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nome
    o.data.name = nome
    return o


def costruisci():
    pulisci()
    m_corda = materiale('M_corda', (0.55, 0.5, 0.4, 1))
    m_bastone = materiale('M_bastone', (0.85, 0.45, 0.15, 1))
    m_molletta = materiale('M_molletta', (0.3, 0.55, 0.85, 1))
    dati = []
    oggetti = []
    for k, st in enumerate(STENDARDI):
        nome, xt, yc, zc = st['nome'], st['x'], st['y'], st['cima']
        largo, alto, giro = st['largo'], st['alto'], st['giro']
        mollette = max(3, int(round(largo / 0.6)) + 1)
        a = math.radians(giro)
        verso = Vector((-math.cos(a), -math.sin(a), 0))
        lato = Vector((-verso.y, verso.x, 0)) * -1.0
        # [zc] è la quota del centro del bastone; il telo comincia sotto il risvolto
        centro = Vector((xt, yc, zc))
        telo, punti = lenzuolo(nome, centro - Vector((0, 0, R_BASTONE + RISVOLTO)), verso, lato, largo, alto - RISVOLTO,
                               mollette, 7 + k)
        oggetti.append(telo)
        oggetti.append(risvolto(nome + '_risvolto', centro, verso, lato, largo, telo.data.materials[0]))
        # il bastone, 20 cm più largo del lenzuolo
        ba = centro - lato * (largo / 2 + 0.1)
        bb = centro + lato * (largo / 2 + 0.1)
        oggetti.append(cilindro(nome + '_bastone', ba, bb, R_BASTONE, m_bastone, seg=10))
        for i, p in enumerate(punti):
            oggetti.append(molletta('%s_molletta%d' % (nome, i), p, verso, lato, m_molletta))
        # le corde: a 6,5 cm dai capi del bastone (e una in mezzo se è più largo di 4,5 m), su fino al golfare sotto la
        # trave: la stessa trave se il bastone le corre sotto (girato lungo y), se no la trave più vicina sopra ogni corda
        capi = [('a', ba + lato * 0.065), ('b', bb - lato * 0.065)]
        if largo > 4.5:
            capi.append(('m', centro.copy()))
        for s, capo in capi:
            pezzi, da = corda_al_bastone('%s_corda_%s_bastone' % (nome, s), capo, lato, m_corda)
            tx = xt if abs(lato.x) < 0.5 else trave_vicina(capo.x)
            dir_corda = Vector((tx, capo.y, SOTTO_TRAVE)) - da
            dir_corda.z = 0.0
            pg, a_ = golfare('%s_corda_%s_golfare' % (nome, s), tx, capo.y, dir_corda, m_corda)
            pezzi += pg
            pezzi += corda('%s_corda_%s_su' % (nome, s), da, a_, m_corda)
            # (tutto un pezzo: dal bastone, a cui gira attorno, al golfare avvitato nella trave)
            oggetti.append(unisci('%s_corda_%s' % (nome, s), pezzi))
        dati.append({'nome': nome, 'centro_bastone': list(centro), 'verso': list(verso), 'lato': list(lato), 'largo': largo,
                     'alto': alto, 'trave_x': xt, 'mollette': mollette})
    return oggetti, dati


def controlla(oggetti):
    """Ogni pezzo degli stendardi ad almeno DISTANZA_MINIMA da tutto il resto della sala (tranne le travi dove si legano
    le corde); e il fondo dei lenzuoli almeno 2 m sopra tubi e vasche (le linee dei tubi in inseguimento_gioco.json)."""
    nostri = set(o.name for o in oggetti)
    for f in ('inseguimento_struttura.glb', 'inseguimento_tubi.glb', 'inseguimento_prop.glb', 'inseguimento_mobili.glb'):
        bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, f))
    bm = bmesh.new()
    for o in bpy.data.objects:
        if o.type != 'MESH' or o.name in nostri or o.name.startswith('acqua') or o.name.endswith('-col'):
            continue
        t = bmesh.new()
        t.from_mesh(o.data)
        t.transform(o.matrix_world)
        tm = bpy.data.meshes.new('tmp')
        t.to_mesh(tm)
        bm.from_mesh(tm)
        t.free()
    # le lampade appese che fa il gioco (non sono nelle GLB): il cavo dal soffitto e il paralume
    luci = json.load(open(os.path.join(DIR, 'inseguimento_luci.json')))
    for (lx, ly, lz, _calda) in luci['appese']:
        for k in range(24):
            z = -6.0 + (lz + 0.3 + 6.0) * k / 23.0
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.05, matrix=__import__('mathutils').Matrix.Translation((lx, ly, z)))
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.4, matrix=__import__('mathutils').Matrix.Translation((lx, ly, lz)))
    sala = BVHTree.FromBMesh(bm)
    problemi = []
    for o in oggetti:
        legato = '_corda_' in o.name
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if legato and p.z > SOTTO_TRAVE - 0.8:
                continue                  # la corda arriva alla trave: lì la tocca apposta
            hit = sala.find_nearest(p, DISTANZA_MINIMA)
            if hit[0] is not None:
                problemi.append('%s a %.2f m da %s' % (o.name, hit[3], tuple(round(c, 2) for c in p)))
                break
    gioco = json.load(open(os.path.join(DIR, 'inseguimento_gioco.json')))
    for o in oggetti:
        if '_corda_' in o.name or '_molletta' in o.name or '_bastone' in o.name or '_risvolto' in o.name:
            continue
        fondo = min((o.matrix_world @ v.co).z for v in o.data.vertices)
        xs = [(o.matrix_world @ v.co) for v in o.data.vertices]
        x0, x1 = min(p.x for p in xs) - 0.5, max(p.x for p in xs) + 0.5
        y0, y1 = min(p.y for p in xs) - 0.5, max(p.y for p in xs) + 0.5
        sotto = []
        for nome, linea in gioco['tubi'].items():
            for q in linea:
                if x0 <= q[0] <= x1 and y0 <= q[1] <= y1:
                    sotto.append(q[2] + 0.8 + 2.0)     # (il cielo del tubo, più 2 m)
        for vv in gioco['vasche'] + gioco['scolo']:
            r = vv['rett']
            if r[0] <= x1 and x0 <= r[2] and r[1] <= y1 and y0 <= r[3]:
                sotto.append(vv['fondo'] + 2.0)    # (dove si sta in piedi, più 2 m)
        margine = fondo - max(sotto) if sotto else 99.0
        print('CONTROLLO %s: fondo a %.2f, %.1f m oltre i 2 m liberi sopra tubi, vasche e scoli sotto' % (o.name, fondo, margine))
        if margine < 0.0:
            problemi.append('%s: %.2f m dentro i 2 m liberi sopra un tubo, una vasca o uno scolo' % (o.name, -margine))
    return problemi


def esporta(oggetti):
    for o in bpy.data.objects:
        o.select_set(o in oggetti)
    bpy.ops.export_scene.gltf(filepath=os.path.join(USCITA, 'stendardi.glb'), use_selection=True, export_format='GLB',
                              export_apply=True, export_materials='PLACEHOLDER')


if __name__ == '__main__':
    os.makedirs(USCITA, exist_ok=True)
    oggetti, dati = costruisci()
    esporta(oggetti)
    with open(os.path.join(USCITA, 'stendardi.json'), 'w') as f:
        json.dump(dati, f, indent=1)
    if '--senza-controllo' not in sys.argv:
        prob = controlla(oggetti)
        print('PROBLEMI:', len(prob))
        for p in prob:
            print('  ', p)
