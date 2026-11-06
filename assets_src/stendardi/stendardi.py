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
            # la cima è dritta, attaccata al bordo della piega (il lenzuolo continua dalla piega, che le mollette
            # stringono sul bastone); fra le mollette (n-1 campate) nascono le pieghe
            campata = u * (mollette - 1)
            abbassa = 0.0
            # le pieghe: in profondità (verso), le creste a metà campata. Profonde solo in alto, fra una molletta e
            # l'altra; scendendo si smorzano (entro un terzo dell'altezza sono onde di 1-2 cm) e in basso il lenzuolo è
            # quasi piatto, tirato dal suo peso: un lenzuolo appeso, non una tenda plissettata
            d = v * alto                                   # (metri dalla cima)
            amp = (0.11 * (1 - math.exp(-d / 0.25)) * math.exp(-d / (alto * 0.1))
                   + 0.015 * (1 - math.exp(-d / 0.5)) * (1 - v) ** 2)
            piega = amp * math.cos(math.pi * 2 * campata) * -1.0
            # e una piega larga e lenta che fa ondeggiare appena il telo a metà (in cima e in fondo è dritto)
            larga = (0.025 * math.sin(u * math.pi * 1.6 + fasi[0]) * math.sin(math.pi * v)
                     + 0.015 * (math.sin(v * 5.0 + fasi[1]) - math.sin(fasi[1])) * (1 - v))
            # l'orlo in basso dritto (il peso lo tira giù)
            fondo = 0.0
            # le pieghe stringono un po' il telo in larghezza (il tessuto va in profondità)
            x = (u - 0.5) * largo * (1.0 - 0.025 * min(1.0, amp / 0.05))
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


def risvolto(nome, cima, verso, lato, largo, mat, buchi=()):
    """Il lenzuolo ripiegato sopra il bastone: dalla cima del telo (6 cm sotto il bastone) sale davanti, gira sopra il
    bastone e riscende dietro fino alla stessa quota. [cima]: il centro del bastone. Stessa stoffa del telo (la fascia
    più alta della texture)."""
    rb = R_BASTONE + 0.0015
    # (davanti: dalla cima del telo sale e si appoggia al bastone; poi lo avvolge, e dietro riscende fino alla stessa
    # quota, 3 mm dietro il telo; le falde restano dentro la larghezza del bastone, dove le mollette non arrivano)
    giro = [(rb * math.cos(math.radians(g)), rb * math.sin(math.radians(g))) for g in range(-30, 211, 15)]
    sez = ([(0.0, -R_BASTONE - RISVOLTO), (rb * 0.4, -rb * 3.0), (rb * 0.85, -rb * 1.2)] + giro +
           [(-rb * 0.85, -rb * 1.2), (-rb * 0.4, -rb * 3.0), (-0.003, -R_BASTONE - RISVOLTO)])
    # [buchi]: dove una corda gira attorno al bastone in mezzo al lenzuolo (distanza dal centro, lungo il bastone):
    # lì, sotto il bastone, la piega ha un taglio largo 6 cm da cui passa la corda (sopra e ai lati la corda stringe la
    # piega, sotto la stoffa non può girarle attorno senza un buco)
    nx = max(12, int(largo * 4))
    xs = set((i / nx - 0.5) * largo for i in range(nx + 1))
    for b in buchi:
        xs |= {b - 0.03, b + 0.03}
    xs = sorted(x for x in xs if -largo / 2 - 1e-6 <= x <= largo / 2 + 1e-6)
    nx = len(xs) - 1
    taglio = {1, 2, len(sez) - 4, len(sez) - 3}       # (le strisce sotto il bastone, fra 1,5 e 3,75 cm sotto l'asse)
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    uv_l = bm.loops.layers.uv.new('UVMap')
    up = Vector((0, 0, 1))
    righe = []
    for (dv, dz) in sez:
        righe.append([bm.verts.new(cima + lato * x + verso * dv + up * dz) for x in xs])
    for j in range(len(sez) - 1):
        for i in range(nx):
            xm = (xs[i] + xs[i + 1]) / 2
            if j in taglio and any(abs(xm - b) < 0.03 for b in buchi):
                continue
            f = bm.faces.new((righe[j][i], righe[j + 1][i], righe[j + 1][i + 1], righe[j][i + 1]))
            for l, (a, b) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                l[uv_l].uv = (xs[a] / largo + 0.5, 1.0 - 0.012 * b / (len(sez) - 1))
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def molletta(nome, p, verso, lato, mat):
    """Una molletta da bucato vera, a cavallo del bastone come su un filo: le due ganasce (la bocca) scendono ai due lati
    del bastone e stringono le due falde della piega contro di lui (la faccia interna a 0,3 mm dalla stoffa, che lì gira
    attorno al bastone); sopra il bastone le due metà si toccano al perno, con la molla di metallo che sporge di lato, e
    sopra ancora i manici, un po' aperti. Alta 8 cm, larga 1,1. [p]: il punto sull'asse del bastone."""
    up = Vector((0, 0, 1))
    rb = R_BASTONE + 0.0015                  # (il raggio della stoffa attorno al bastone, come nel risvolto)
    pezzi = []
    giu, perno0, perno1, cima = -0.018, rb + 0.003, rb + 0.020, rb + 0.052
    dentro = rb + 0.0003
    for s_ in (-1, 1):
        # la ganascia: dalla punta, 1,8 cm sotto l'asse, fino al perno; la faccia interna tocca la stoffa al fianco
        c = p + up * ((giu + perno0) / 2) + verso * s_ * (dentro + 0.0025)
        pezzi.append(scatola('%s_bocca%d' % (nome, s_), c, [lato, verso, up], (0.0055, 0.0025, (perno0 - giu) / 2), mat))
        # il perno: sopra la stoffa le due metà si toccano in mezzo
        c = p + up * ((perno0 + perno1) / 2) + verso * s_ * (dentro + 0.005) / 2
        pezzi.append(scatola('%s_perno%d' % (nome, s_), c, [lato, verso, up], (0.0055, (dentro + 0.005) / 2, (perno1 - perno0) / 2), mat))
        # il manico, un po' aperto in cima
        asse_z = (up + verso * s_ * 0.08).normalized()
        c = p + up * ((perno1 + cima) / 2) + verso * s_ * 0.0045
        pezzi.append(scatola('%s_manico%d' % (nome, s_), c, [lato, asse_z.cross(lato).normalized() * -1.0, asse_z], (0.0055, 0.0035, (cima - perno1) / 2 + 0.001), mat))
    molla_c = p + up * ((perno0 + perno1) / 2)
    pezzi.append(cilindro(nome + '_molla', molla_c - lato * 0.008, molla_c + lato * 0.008, 0.0045, materiale('M_molla', (0.6, 0.6, 0.62, 1)), seg=8))
    return unisci(nome, pezzi)


def corda_al_bastone(nome, capo, lato, mat, sotto=R_BASTONE):
    """I due giri della corda attorno al bastone in [capo] (sul suo asse), larghi 3 cm lungo il bastone, e il nodo sopra.
    Torna i pezzi e il punto sopra il bastone da cui la corda sale."""
    pezzi = []
    # [sotto]: il raggio di quello che la corda stringe: il bastone nudo ai capi, la piega della stoffa dove il lenzuolo
    # c'è (allora i giri vanno attorno alla piega, non dentro)
    nudo = sotto <= R_BASTONE
    rr = sotto + R_CORDA * (0.9 if nudo else 1.05)       # (sul legno stringe, sulla stoffa la sfiora)
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
    nodo = capo + up * (sotto + R_CORDA * (1.6 if nudo else 2.4)) + lato * 0.022
    pezzi.append(palla(nome + '_nodo', nodo, R_CORDA * 2.2, mat))
    # il codino: dal nodo scende di fianco, davanti al bastone (fuori dalla stoffa), e pende per 4 cm
    fuori = sotto + R_CORDA * 1.3
    spalla = capo + lato * 0.027 + (giro_v + up).normalized() * fuori
    fianco = capo + lato * 0.03 + giro_v * fuori
    pezzi.append(cilindro(nome + '_capo', nodo, spalla, R_CORDA * 0.9, mat, seg=6))
    pezzi.append(cilindro(nome + '_capo1', spalla, fianco, R_CORDA * 0.9, mat, seg=6))
    pezzi.append(cilindro(nome + '_capo2', fianco, fianco - up * 0.04, R_CORDA * 0.9, mat, seg=6))
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
        # il bastone, 20 cm più largo del lenzuolo
        ba = centro - lato * (largo / 2 + 0.1)
        bb = centro + lato * (largo / 2 + 0.1)
        oggetti.append(cilindro(nome + '_bastone', ba, bb, R_BASTONE, m_bastone, seg=10))
        # le corde: a 6,5 cm dai capi del bastone (e una in mezzo se è più largo di 4,5 m), su fino al golfare sotto la
        # trave: la stessa trave se il bastone le corre sotto (girato lungo y), se no la trave più vicina sopra ogni corda
        capi = [('a', ba + lato * 0.065), ('b', bb - lato * 0.065)]
        if largo > 4.5:
            capi.append(('m', centro.copy()))
        if abs(lato.x) > 0.5 and largo > 4.5:
            # un bastone lungo che attraversa le travi: le corde scendono dritte dalle travi che ha sopra (ogni 4 m),
            # e i capi sporgono oltre come su uno stendibiancheria
            x0, x1 = sorted((ba.x, bb.x))
            sopra = [t for t in range(44, 80, 4) if x0 + 0.3 <= t <= x1 - 0.3]
            if len(sopra) >= 2:
                capi = [('abcdefgh'[i], centro + lato * ((t - centro.x) / lato.x)) for i, t in enumerate(sopra)]
        for s, capo in capi:
            # (dentro la larghezza del lenzuolo il bastone è avvolto dalla piega: i giri le vanno attorno)
            sotto = R_BASTONE + 0.0015 + 0.0005 if abs((capo - centro).dot(lato)) < largo / 2 + 0.03 else R_BASTONE
            pezzi, da = corda_al_bastone('%s_corda_%s_bastone' % (nome, s), capo, lato, m_corda, sotto)
            tx = xt if abs(lato.x) < 0.5 else trave_vicina(capo.x)
            dir_corda = Vector((tx, capo.y, SOTTO_TRAVE)) - da
            dir_corda.z = 0.0
            pg, a_ = golfare('%s_corda_%s_golfare' % (nome, s), tx, capo.y, dir_corda, m_corda)
            pezzi += pg
            pezzi += corda('%s_corda_%s_su' % (nome, s), da, a_, m_corda)
            # (tutto un pezzo: dal bastone, a cui gira attorno, al golfare avvitato nella trave)
            oggetti.append(unisci('%s_corda_%s' % (nome, s), pezzi))
        buchi = [(c - centro).dot(lato) for _s, c in capi if abs((c - centro).dot(lato)) < largo / 2 + 0.03]
        oggetti.append(risvolto(nome + '_risvolto', centro, verso, lato, largo, telo.data.materials[0], buchi))
        # le mollette sul bastone: la prima e l'ultima 8 cm dentro gli orli, le altre in mezzo, e nessuna a meno di
        # 12 cm da una corda (i giri, il nodo e il codino stanno entro 5 cm)
        corde = [(c - centro).dot(lato) for _s, c in capi]
        for i in range(mollette):
            x = -largo / 2 + 0.08 + (largo - 0.16) * i / (mollette - 1)
            for cx in corde:
                if abs(x - cx) < 0.12:
                    x = cx + (0.12 if x >= cx else -0.12)
            oggetti.append(molletta('%s_molletta%d' % (nome, i), centro + lato * x, verso, lato, m_molletta))

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
    # le mollette: niente dentro la piega o nelle corde (ogni molletta contro la piega e le corde del suo stendardo)
    def albero(o):
        t = bmesh.new()
        t.from_mesh(o.data)
        t.transform(o.matrix_world)
        a = BVHTree.FromBMesh(t)
        t.free()
        return a
    for o in oggetti:
        if '_molletta' not in o.name and '_corda_' not in o.name:
            continue
        st = o.name.split('_molletta')[0].split('_corda_')[0]
        am = albero(o)
        for q in oggetti:
            if q is o or ('_corda_' in o.name and '_corda_' in q.name):
                continue
            if q.name.startswith(st + '_risvolto') or q.name.startswith(st + '_corda_') or q.name == st:
                if am.overlap(albero(q)):
                    problemi.append('%s entra in %s' % (o.name, q.name))
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
