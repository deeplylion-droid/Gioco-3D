"""Le due pile negli angoli dalla parte dell'entrata della sala principale (punto 8 della prova v0.3.2):
"due pile che toccano quasi il soffitto, attaccate agli angoli, una di palloni da spiaggia gonfi e sgonfi, l'altra di
scatoloni di diversi colori". Il soffitto è a 11,5 m: le pile arrivano a circa 10 m.
  - scatoloni: catasta a gradini contro i due muri, colonna per colonna (ogni scatolone sta su quello sotto, più
    piccolo o uguale: niente sospesi, niente compenetrazioni), qualcuno caduto alla base;
  - palloni: una pila di palloni grandi tenuta da una rete da carico fissata ai due muri (da soli a 10 m non
    starebbero su): i palloni gonfi si sistemano con la simulazione fisica di Blender dentro la rete, gli sgonfi sono
    schiacciati tra quelli in cima e sparsi alla base.
Ogni pila è fatta con l'angolo nell'origine, contro i muri x = 0 e y = 0, e si allarga verso +x e +y (base massima
3,4 m: nell'angolo sud-ovest non copre la serranda, che comincia a 4,1 m). Collisione semplice: una scatola per pila.
Modelli Meshy in assets_src/sala_angoli/ (genera_angoli.py).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/sala_angoli.py [palloni|scatoloni ...]
Uscita: godot/assets/ambiente/proposte_angoli/angolo_<palloni|scatoloni>.gltf"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import ambienti2_comune as C
import ambienti1_hq as HQ

HQ.LINK[0] = C._link
HQ.CARTELLE.append(os.path.join(C.RADICE, 'assets_src', 'sala_angoli'))
# Con 'gioco' tra gli argomenti scrive la versione del gioco (disposizione 2, scelta il 17 ottobre) in angoli_sala/.
GIOCO = 'gioco' in C.argomenti()
USCITA = os.path.join(C.RADICE, 'godot', 'assets', 'ambiente', 'angoli_sala' if GIOCO else 'proposte_angoli')
LATO = 3.4      # quanto si allarga la pila lungo ciascun muro
ALTEZZA = 10.0  # il soffitto è a 11,5


def reset():
    C.reset()
    HQ._base.clear(); HQ._dim.clear()


def posa(nome, file, centro_base, k, rz, obs, rot=(0, 0, 0)):
    d = HQ.dimensioni(file)
    o = HQ.metti(nome, file, tuple(centro_base), (d.x * k, d.y * k, d.z * k), rot_z=rz, rot=rot)
    obs.append(o)
    return o


def catasta_scatoloni():
    reset()
    rnd = random.Random(7)
    obs = []
    tipi = ['scatolone_marrone', 'scatolone_blu', 'scatolone_rosso', 'scatolone_giallo', 'scatolone_verde']
    cella = 0.85
    n = int(LATO / cella)
    for i in range(n):
        for j in range(n):
            # quanti piani: tanti vicino all'angolo, pochi lontano (catasta a gradini contro i due muri)
            dist = math.hypot(i + 0.5, j + 0.5) * cella
            h_obj = ALTEZZA * max(0.0, 1.0 - (dist / (LATO * 1.08)) ** 1.6) + rnd.uniform(-0.6, 0.6)
            cx, cy = (i + 0.5) * cella, (j + 0.5) * cella
            z = 0.0
            lato_sotto = cella - 0.06
            k_obj = 0
            while z < h_obj:
                f = rnd.choice(tipi)
                d = HQ.dimensioni(f)
                lato = min(lato_sotto, rnd.uniform(0.62, 0.8) * cella)
                k = lato / max(d.x, d.y)
                hz = d.z * k
                if z + hz > ALTEZZA + 0.3:
                    break
                # un po' storti e spostati, ma sempre dentro la cella e sopra lo scatolone di sotto
                gioco = (lato_sotto - lato) / 2
                posa(f'scat_{i}_{j}_{k_obj}', f, (cx + rnd.uniform(-gioco, gioco), cy + rnd.uniform(-gioco, gioco), z + 0.003),
                     k, rnd.uniform(-0.08, 0.08) + rnd.choice((0, math.pi / 2)), obs)
                z += hz + 0.003
                lato_sotto = lato
                k_obj += 1
    # qualche scatolone caduto alla base, girato e schiacciato contro la catasta
    for k_obj in range(7):
        a = rnd.uniform(0.15, 1.42)
        r = LATO + rnd.uniform(0.2, 0.9)
        f = rnd.choice(tipi)
        d = HQ.dimensioni(f)
        k = 0.55 / max(d.x, d.y)
        rz = rnd.uniform(0, math.pi)
        # nel gioco la catasta sta nell'angolo sud-ovest, accanto alla serranda del magazzino (lungo +X): lì non
        # cade niente, la serranda resta libera
        if GIOCO and r * math.cos(a) > LATO - 0.3:
            continue
        posa(f'scat_caduto_{k_obj}', f, (r * math.cos(a), r * math.sin(a), 0.0), k, rz, obs)
    C.collisione_box('angolo_scatoloni', (0, 0, 0), (LATO, LATO, ALTEZZA))
    return obs


def pila_palloni():
    reset()
    rnd = random.Random(3)
    obs = []
    gonfi = ['pallone_gonfio_a', 'pallone_gonfio_b']
    R = LATO - 0.15   # raggio della rete (un quarto di cilindro nell'angolo)
    # palloni gonfi fatti cadere nella rete: rigid body, poi si applica la posa finale
    scene = bpy.context.scene
    bpy.ops.rigidbody.world_add()
    scene.rigidbody_world.substeps_per_frame = 10
    scene.rigidbody_world.solver_iterations = 20
    def contenitore(nome, ob):
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.rigidbody.object_add(type='PASSIVE')
        ob.rigid_body.collision_shape = 'MESH'
        ob.hide_render = True
        return ob
    pav = C.box('cont_pav', (LATO, LATO, -0.25), (LATO * 3, LATO * 3, 0.5), None, uv=None)
    mx = C.box('cont_mx', (-0.25, LATO, ALTEZZA), (0.5, LATO * 3, ALTEZZA * 2.2), None, uv=None)
    my = C.box('cont_my', (LATO, -0.25, ALTEZZA), (LATO * 3, 0.5, ALTEZZA * 2.2), None, uv=None)
    cont = [pav, mx, my]
    # la rete: tante assi verticali sottili lungo l'arco (solo per la simulazione)
    for k in range(24):
        a = (k + 0.5) / 24 * math.pi / 2
        cont.append(C.box(f'cont_rete{k}', (R * math.cos(a), R * math.sin(a), ALTEZZA), (0.25, R * math.pi / 2 / 24 * 1.3, ALTEZZA * 2.2),
                          None, uv=None, rot=(0, 0, a)))
    for o in cont:
        bpy.ops.object.select_all(action='DESELECT')
        contenitore(o.name, o)
    palle = []
    n = 0
    z = 0.8
    while z < ALTEZZA * 1.75:   # si fanno cadere da più in alto: assestandosi la pila scende
        for _ in range(9):
            diam = rnd.uniform(0.75, 1.15)
            a = rnd.uniform(0.1, math.pi / 2 - 0.1); r = rnd.uniform(0.5, R - diam / 2 - 0.1) * math.sqrt(rnd.random() * 0.6 + 0.4)
            f = rnd.choice(gonfi)
            d = HQ.dimensioni(f)
            k = diam / max(d.x, d.y, d.z)
            o = posa(f'pallone_{n}', f, (r * math.cos(a), r * math.sin(a), z), k, rnd.uniform(0, math.tau), obs,
                     rot=(rnd.uniform(0, math.tau), rnd.uniform(0, math.tau), 0))
            bpy.ops.object.select_all(action='DESELECT')
            bpy.context.view_layer.objects.active = o; o.select_set(True)
            bpy.ops.rigidbody.object_add(type='ACTIVE')
            o.rigid_body.collision_shape = 'SPHERE'
            o.rigid_body.mass = 0.3
            o.rigid_body.friction = 0.9
            o.rigid_body.restitution = 0.15
            o.rigid_body.linear_damping = 0.4; o.rigid_body.angular_damping = 0.6
            palle.append(o)
            n += 1
        z += 1.05
    scene.frame_start, scene.frame_end = 1, 260
    scene.rigidbody_world.point_cache.frame_end = 260
    for f in range(1, 261):
        scene.frame_set(f)
    # posa finale: si tengono solo i palloni dentro la pila (sotto ALTEZZA) e si fissa la trasformazione
    finali = []
    for o in palle:
        mw = o.matrix_world.copy()
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        bpy.ops.rigidbody.object_remove()
        o.matrix_world = mw
        if mw.translation.z > ALTEZZA - 0.3 or mw.translation.z < -0.5:
            obs.remove(o); bpy.data.objects.remove(o)
            continue
        finali.append(o)
    for o in cont:
        bpy.data.objects.remove(o)
    bpy.ops.rigidbody.world_remove()
    alto = max((o.matrix_world.translation.z for o in finali), default=ALTEZZA)
    print('palloni nella pila:', len(finali), 'quota del più alto:', round(alto, 2), flush=True)
    # sgonfi: schiacciati sopra la pila e sparsi alla base, fuori dalla rete
    for k_obj in range(6):
        a = rnd.uniform(0.2, 1.37); r = rnd.uniform(0.3, R * 0.8)
        f = rnd.choice(['pallone_sgonfio', 'pallone_mezzo'])
        d = HQ.dimensioni(f); k = 0.9 / max(d.x, d.y)
        posa(f'pallone_sopra_{k_obj}', f, (r * math.cos(a), r * math.sin(a), alto + 0.3), k, rnd.uniform(0, math.tau), obs)
    for k_obj in range(9):
        a = rnd.uniform(0.05, 1.52); r = R + rnd.uniform(0.35, 1.4)
        f = rnd.choice(['pallone_sgonfio', 'pallone_sgonfio', 'pallone_mezzo', 'pallone_gonfio_a', 'pallone_gonfio_b'])
        tondo = f.startswith('pallone_gonfio')
        d = HQ.dimensioni(f); k = (0.85 if tondo else 0.8) / max(d.x, d.y, d.z if tondo else 0)
        posa(f'pallone_terra_{k_obj}', f, (r * math.cos(a), r * math.sin(a), 0.0), k, rnd.uniform(0, math.tau), obs)
    # la rete da carico: maglie di corda grosse su un quarto di cilindro, fissata ai muri con barre e ganci
    corda = C.mat_pbr('corda_rete', base=(0.45, 0.38, 0.28), roughness=0.9)
    ferro = C.mat_pbr('ferro_rete', base=(0.25, 0.25, 0.25), roughness=0.5, metallic=0.8)
    h_rete = min(ALTEZZA, alto + 0.6)
    for k in range(13):   # corde verticali
        a = k / 12 * math.pi / 2
        p = Vector((R * math.cos(a), R * math.sin(a), 0))
        obs.append(C.tubo(f'rete_v{k}', [p + Vector((0, 0, 0.05)), p + Vector((0, 0, h_rete))], 0.018, corda, seg=6, uv=None))
    for j in range(int(h_rete / 0.55) + 1):   # corde orizzontali
        zz = min(0.1 + j * 0.55, h_rete)
        pts = [Vector((R * math.cos(t / 16 * math.pi / 2), R * math.sin(t / 16 * math.pi / 2), zz)) for t in range(17)]
        obs.append(C.tubo(f'rete_o{j}', pts, 0.016, corda, rc=0.05, seg=6, uv=None))
    for (x, y) in ((R + 0.05, 0.06), (0.06, R + 0.05)):   # barre ai muri
        obs.append(C.tubo(f'rete_barra_{x:.0f}', [(x, y, 0.1), (x, y, h_rete)], 0.03, ferro, seg=10, uv=None))
    C.collisione_box('angolo_palloni', (0, 0, 0), (R, R, h_rete))
    return obs


# Prova della v0.3.4: "L'angolo dei palloni io lo volevo senza grata a reggere i palloni, e deve essere più grande la
# base, tipo una piramide." Un mucchio a piramide appoggiato nell'angolo, senza rete: la base si allarga lungo il muro
# sud (asse +y, fino a 7,5 m) e meno lungo il muro est (asse +x, 4,4 m: lì dopo c'è la panca), alto circa 6 m. I
# palloni (gonfi, mezzi sgonfi e sgonfi) si posano con la fisica su un nucleo nascosto a cono (i palloni di dentro,
# che non si vedono), poi si fissano. Collisione: un quarto di cono convesso.
PIR_X, PIR_Y, PIR_H = 4.4, 7.5, 6.5
# cose della sala lì vicino (coordinate della pila): la panca, un pallone e una paperella a terra
PIR_OSTACOLI = [((4.85, 0.0, 0.0), (6.9, 0.6, 0.45)), ((4.9, 5.8, 0.0), (5.6, 6.5, 0.55)), ((5.4, 9.4, 0.0), (5.9, 9.8, 0.25))]


def posa_centro(nome, file, centro, k, rz, obs, rot=(0, 0, 0)):
    """Come posa, ma con l'origine (e la rotazione) nel centro del modello, non alla base: un pallone girato a caso
    resta dov'è invece di ruotare intorno al punto in basso (e finire nel pavimento o nel muro)."""
    d = HQ.dimensioni(file)
    o = HQ.metti(nome, file, tuple(centro), (d.x * k, d.y * k, d.z * k), rot_z=rz, perno=(0, 0, d.z * k / 2), rot=rot)
    obs.append(o)
    return o


def _fuori(o, tolleranza=0.02):
    """Il modello entra nel pavimento o in uno dei due muri (x = 0, y = 0) più della tolleranza."""
    import numpy as np
    me = o.data
    v = np.zeros(len(me.vertices) * 3); me.vertices.foreach_get('co', v); v = v.reshape(-1, 3)
    M = np.array(o.matrix_world); w = v @ M[:3, :3].T + M[:3, 3]
    return w.min(axis=0).min() < -tolleranza


def _quarto_di_cono(nome, ax, ay, h, seg=24):
    import bmesh
    bm = bmesh.new()
    vs = [bm.verts.new((0, 0, 0)), bm.verts.new((0, 0, h))]
    for k in range(seg + 1):
        t = k / seg * math.pi / 2
        vs.append(bm.verts.new((ax * math.cos(t), ay * math.sin(t), 0)))
    bmesh.ops.convex_hull(bm, input=vs)
    return C._ob_da_bm(nome, bm, None)


def pila_piramide():
    reset()
    rnd = random.Random(5)
    obs = []
    scene = bpy.context.scene
    bpy.ops.rigidbody.world_add()
    scene.rigidbody_world.substeps_per_frame = 10
    scene.rigidbody_world.solver_iterations = 20
    ax, ay, hc = PIR_X - 0.75, PIR_Y - 0.75, PIR_H - 0.7   # il nucleo: i palloni di dentro
    nucleo = _quarto_di_cono('pir_nucleo', ax, ay, hc)
    cont = [nucleo,
            C.box('pir_pav', (6, 6, -0.25), (24, 24, 0.5), None, uv=None),
            C.box('pir_mx', (-0.25, 6, 6), (0.5, 24, 14), None, uv=None),
            C.box('pir_my', (6, -0.25, 6), (24, 0.5, 14), None, uv=None)]
    for k, (lo, hi) in enumerate(PIR_OSTACOLI):
        lo, hi = Vector(lo), Vector(hi)
        cont.append(C.box(f'pir_ost{k}', (lo + hi) / 2, hi - lo, None, uv=None))
    for o in cont:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        bpy.ops.rigidbody.object_add(type='PASSIVE')
        o.rigid_body.collision_shape = 'MESH' if o is nucleo else 'BOX'
        o.rigid_body.friction = 0.6 if o is nucleo else 0.2   # sui muri i palloni scivolano: niente colonne contro i muri
        o.hide_render = True

    tipi = ['pallone_gonfio_a'] * 6 + ['pallone_gonfio_b'] * 6 + ['pallone_mezzo'] * 3 + ['pallone_sgonfio'] * 4

    def quota(x, y):
        return hc * max(0.0, 1.0 - math.sqrt((x / ax) ** 2 + (y / ay) ** 2))

    # i palloni di dentro: un reticolo fitto (fermi) che riempie il nucleo; quelli di fuori ci si posano sopra
    nucleo.scale = (0.8, 0.8, 0.8)   # resta un sostegno più piccolo, tutto coperto dal reticolo
    passo = 0.78
    dentro = []
    zi = 0.4
    riga = 0
    while zi < hc:
        off = (passo / 2) * (riga % 2)
        xi = 0.4 + off
        while xi < ax:
            yi = 0.4 + off
            while yi < ay:
                if quota(xi, yi) > zi + 0.15:
                    f = rnd.choice(tipi[:12] + ['pallone_mezzo'])
                    d = HQ.dimensioni(f)
                    k = rnd.uniform(0.74, 0.86) / max(d.x, d.y, d.z)
                    o = posa_centro(f'pallone_dentro_{len(dentro)}', f, (xi + rnd.uniform(-0.04, 0.04), yi + rnd.uniform(-0.04, 0.04), zi), k,
                                    rnd.uniform(0, math.tau), obs, rot=(rnd.uniform(0, math.tau), rnd.uniform(0, math.tau), 0))
                    if _fuori(o):
                        obs.remove(o); bpy.data.objects.remove(o)
                        yi += passo
                        continue
                    bpy.ops.object.select_all(action='DESELECT')
                    bpy.context.view_layer.objects.active = o; o.select_set(True)
                    bpy.ops.rigidbody.object_add(type='PASSIVE')
                    o.rigid_body.collision_shape = 'CONVEX_HULL'   # la sfera di Blender sta sull'origine, cioè alla base
                    o.rigid_body.friction = 0.6
                    dentro.append(o)
                yi += passo
            xi += passo
        zi += passo * 0.82
        riga += 1
    print('palloni di dentro:', len(dentro), flush=True)

    palle = []
    for onda in range(3):   # a ondate, da più in alto ogni volta: niente palloni che nascono uno dentro l'altro
        for _ in range(40):
            while True:
                u, v = rnd.random(), rnd.random()
                if u * u + v * v <= 1.1:
                    break
            f = rnd.choice(tipi)
            tondo = f != 'pallone_sgonfio'
            diam = rnd.uniform(0.6, 1.05) if f.startswith('pallone_gonfio') else rnd.uniform(0.75, 1.0)
            x, y = diam / 2 + 0.05 + u * (ax + 0.6), diam / 2 + 0.05 + v * (ay + 0.6)
            d = HQ.dimensioni(f)
            k = diam / max(d.x, d.y, d.z)
            z = quota(x, y) + 0.6 + diam / 2 + onda * 1.2 + rnd.uniform(0, 0.8)
            o = posa_centro(f'pallone_{len(palle)}', f, (x, y, z), k, rnd.uniform(0, math.tau), obs,
                     rot=(rnd.uniform(0, math.tau), rnd.uniform(0, math.tau), 0) if tondo else (rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))
            bpy.ops.object.select_all(action='DESELECT')
            bpy.context.view_layer.objects.active = o; o.select_set(True)
            bpy.ops.rigidbody.object_add(type='ACTIVE')
            o.rigid_body.collision_shape = 'CONVEX_HULL'   # la sfera di Blender sta sull'origine del modello, cioè alla base
            o.rigid_body.mass = 0.3 if tondo else 0.2
            o.rigid_body.friction = 0.7
            o.rigid_body.restitution = 0.1
            o.rigid_body.linear_damping = 0.3; o.rigid_body.angular_damping = 0.5   # rotolano giù e si fermano nelle conche
            palle.append(o)
    fine = 420
    scene.frame_start, scene.frame_end = 1, fine
    scene.rigidbody_world.point_cache.frame_end = fine
    for f in range(1, fine + 1):
        scene.frame_set(f)
    # la posa della simulazione si applica alla trasformazione (togliendo il corpo rigido Blender rimetterebbe
    # ogni pallone dov'era nato)
    bpy.ops.object.select_all(action='DESELECT')
    for o in palle:
        o.select_set(True)
    bpy.context.view_layer.objects.active = palle[0]
    bpy.ops.object.visual_transform_apply()
    bpy.ops.rigidbody.objects_remove()
    finali = []
    for o in palle:
        t = o.matrix_world.translation
        lontano = (t.x / (PIR_X + 1.6)) ** 2 + (t.y / (PIR_Y + 2.0)) ** 2 > 1.0
        sulla_panca = t.x > PIR_X + 0.2 and t.y < 1.2
        troppo_alto = t.z > PIR_H + 0.6   # quelli rimasti in bilico sopra la cima (sopra non hanno niente)
        if t.z < -0.3 or lontano or sulla_panca or troppo_alto or _fuori(o):
            obs.remove(o); bpy.data.objects.remove(o)
            continue
        finali.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in dentro:
        o.select_set(True)
    if dentro:
        bpy.context.view_layer.objects.active = dentro[0]
        bpy.ops.rigidbody.objects_remove()   # fermi: la posa è quella di partenza
    for o in cont:
        bpy.data.objects.remove(o)
    bpy.ops.rigidbody.world_remove()
    alto = max((o.matrix_world.translation.z for o in finali + dentro), default=PIR_H)
    print('palloni nella pila:', len(finali), 'quota del più alto:', round(alto, 2), flush=True)
    col = _quarto_di_cono('angolo_palloni-convcolonly', PIR_X - 0.2, PIR_Y - 0.2, alto + 0.5)
    C._segna_collisione(col)
    # i palloni rotolati fuori dal cono: una scatola ciascuno (niente da attraversare)
    for o in finali:
        t = o.matrix_world.translation
        if (t.x / (PIR_X - 0.2)) ** 2 + (t.y / (PIR_Y - 0.2)) ** 2 > 0.9:
            vs = [o.matrix_world @ Vector(c) for c in o.bound_box]
            lo = Vector([min(v[i] for v in vs) for i in range(3)]); hi = Vector([max(v[i] for v in vs) for i in range(3)])
            lo.z = max(lo.z, 0.0)
            C.collisione_box(o.name + '_col', lo, hi)
    return obs


def esporta(nome, obs):
    os.makedirs(USCITA, exist_ok=True)
    for im in bpy.data.images:
        lim = 1024
        if im.size[0] > lim:
            im.scale(lim, lim)
    bpy.ops.object.select_all(action='DESELECT')
    cols = [o for o in bpy.context.scene.objects if o.name.endswith('colonly')]
    for o in obs + cols:
        o.select_set(True)
    p = os.path.join(USCITA, f'angolo_{nome}.gltf')
    bpy.ops.export_scene.gltf(filepath=p, export_format='GLTF_SEPARATE', export_texture_dir='texture', use_selection=True,
                              export_apply=True, export_lights=False, export_cameras=False, export_yup=True,
                              export_image_format='JPEG', export_jpeg_quality=88)
    print('esportato', p, len(obs), 'oggetti', flush=True)


if __name__ == '__main__':
    scelte = [a for a in C.argomenti() if a in ('palloni', 'scatoloni')] or ['palloni', 'scatoloni']
    for s in scelte:
        esporta(s, (pila_piramide() if GIOCO else pila_palloni()) if s == 'palloni' else catasta_scatoloni())
