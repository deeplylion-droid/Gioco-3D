"""Gli stendardi dei bambini nella sala delle condotte (inseguimento): lenzuoli grandi colorati dal club dei bambini
della nave, appesi nel vuoto dietro le vasche, lontani (nota dell'utente del 6 novembre: «Lascia le vasche uguali ma
aggiungi degli stendardi giganti appesi nel vuoto dietro, nella distanza ... come s'è fossero lenzuoli appesi e colorati
dai bambini»).

Come starebbero davvero:
- ogni lenzuolo è fermato con le mollette a un bastone (un tubo di plastica arancio, come quelli delle reti dei giochi
  d'acqua), e il bastone pende da due corde legate alle travi del soffitto (le travi ogni 4 m, sotto a z -6,6): niente
  galleggia, le corde arrivano su una trave e ci girano attorno;
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
from mathutils import Vector
from mathutils.bvhtree import BVHTree

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
DIR = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'inseguimento')
USCITA = os.path.join(DIR, 'stendardi')

SOTTO_TRAVE = -6.6          # il fondo delle travi del soffitto
DISTANZA_MINIMA = 0.25

# Gli stendardi: [nome (la texture), trave (x), y del centro, quota della cima del lenzuolo, largo, alto, girato (gradi
# attorno alla verticale: 0 = il lenzuolo guarda verso -x, cioè verso ovest), mollette]
STENDARDI = [
    ['stendardo_1', 60.0, 21.0, -11.0, 3.0, 4.5, 0.0, 5],
    ['stendardo_2', 72.0, 11.5, -12.5, 3.0, 4.5, 90.0, 5],
    ['stendardo_3', 56.0, 7.0, -11.5, 3.0, 4.5, 0.0, 5],
    ['stendardo_4', 64.0, 31.0, -12.0, 3.0, 4.5, 180.0, 4],
]


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
    nx, ny = 24, 36
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
        pezzi.append(cilindro('%s_%d' % (nome, k), pts[k], pts[k + 1], 0.012, mat, seg=6))
    return pezzi


def nodo_alla_trave(nome, x, y, mat):
    """La corda che gira due volte attorno alla trave (larga 40 cm, alta 60) e scende: un anello schiacciato."""
    pezzi = []
    for k, dy in enumerate((-0.03, 0.03)):
        pts = [Vector((x - 0.215, y + dy, SOTTO_TRAVE - 0.015)), Vector((x + 0.215, y + dy, SOTTO_TRAVE - 0.015)),
               Vector((x + 0.215, y + dy, SOTTO_TRAVE + 0.5)), Vector((x - 0.215, y + dy, SOTTO_TRAVE + 0.5))]
        for i in range(4):
            pezzi.append(cilindro('%s_giro%d_%d' % (nome, k, i), pts[i], pts[(i + 1) % 4], 0.012, mat, seg=6))
    return pezzi


def costruisci():
    pulisci()
    m_corda = materiale('M_corda', (0.55, 0.5, 0.4, 1))
    m_bastone = materiale('M_bastone', (0.85, 0.45, 0.15, 1))
    m_molletta = materiale('M_molletta', (0.3, 0.55, 0.85, 1))
    dati = []
    oggetti = []
    for k, (nome, xt, yc, zc, largo, alto, giro, mollette) in enumerate(STENDARDI):
        a = math.radians(giro)
        verso = Vector((-math.cos(a), -math.sin(a), 0))
        lato = Vector((-verso.y, verso.x, 0)) * -1.0
        centro = Vector((xt, yc, zc))
        # il lenzuolo pende 4 cm sotto il bastone (le mollette lo stringono sul davanti)
        telo, punti = lenzuolo(nome, centro - Vector((0, 0, 0.04)), verso, lato, largo, alto, mollette, 7 + k)
        oggetti.append(telo)
        # il bastone (tubo di plastica Ø 4 cm), 20 cm più largo del lenzuolo
        ba = centro - lato * (largo / 2 + 0.1)
        bb = centro + lato * (largo / 2 + 0.1)
        oggetti.append(cilindro(nome + '_bastone', ba, bb, 0.022, m_bastone, seg=10))
        # le mollette: due ganasce sul davanti e sul dietro della cima, che stringono stoffa e bastone
        for i, p in enumerate(punti):
            for s in (-1, 1):
                oggetti.append(scatola('%s_molletta%d_%d' % (nome, i, s), p + verso * s * 0.03 - Vector((0, 0, 0.02)),
                                       [lato, verso, Vector((0, 0, 1))], (0.008, 0.006, 0.035), m_molletta))
        # le due corde: dagli estremi del bastone su fino alla trave (la trave è a x = xt, lungo y): se il lenzuolo è
        # girato lungo y le corde salgono dritte; se è girato lungo x salgono alla trave dalla stessa x, al punto di y
        # sopra ogni capo
        for s, capo in (('a', ba), ('b', bb)):
            sopra = Vector((xt, capo.y, SOTTO_TRAVE - 0.015))
            if abs(lato.x) > 0.5:
                # (il lenzuolo è di traverso alla trave: le corde vanno a due travi vicine, ai capi del bastone)
                sopra = Vector((round((capo.x - 44.0) / 4.0) * 4.0 + 44.0, capo.y, SOTTO_TRAVE - 0.015))
            oggetti += corda('%s_corda_%s' % (nome, s), capo + Vector((0, 0, 0.02)), sopra, m_corda)
            oggetti += nodo_alla_trave('%s_nodo_%s' % (nome, s), sopra.x, sopra.y, m_corda)
        dati.append({'nome': nome, 'centro_cima': list(centro), 'verso': list(verso), 'lato': list(lato), 'largo': largo,
                     'alto': alto, 'trave_x': xt})
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
    sala = BVHTree.FromBMesh(bm)
    problemi = []
    for o in oggetti:
        legato = '_nodo_' in o.name or '_corda_' in o.name
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
        if '_corda_' in o.name or '_nodo_' in o.name or '_molletta' in o.name or '_bastone' in o.name:
            continue
        fondo = min((o.matrix_world @ v.co).z for v in o.data.vertices)
        xs = [(o.matrix_world @ v.co) for v in o.data.vertices]
        x0, x1 = min(p.x for p in xs) - 0.5, max(p.x for p in xs) + 0.5
        y0, y1 = min(p.y for p in xs) - 0.5, max(p.y for p in xs) + 0.5
        sotto = []
        for nome, linea in gioco['tubi'].items():
            for q in linea:
                if x0 <= q[0] <= x1 and y0 <= q[1] <= y1:
                    sotto.append(q[2] + 0.8)
        for vv in gioco['vasche']:
            r = vv['rett']
            if r[0] <= x1 and x0 <= r[2] and r[1] <= y1 and y0 <= r[3]:
                sotto.append(vv['acqua'] + 1.8)
        alto_sopra = fondo - max(sotto) if sotto else 99.0
        print('CONTROLLO %s: fondo a %.2f, %.1f m sopra tubi e vasche sotto' % (o.name, fondo, alto_sopra))
        if alto_sopra < 2.0:
            problemi.append('%s: solo %.2f m sopra un tubo o una vasca' % (o.name, alto_sopra))
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
