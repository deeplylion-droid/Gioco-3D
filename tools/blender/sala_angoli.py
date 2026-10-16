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
USCITA = os.path.join(C.RADICE, 'godot', 'assets', 'ambiente', 'proposte_angoli')
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
        posa(f'scat_caduto_{k_obj}', f, (r * math.cos(a), r * math.sin(a), 0.0), k, rnd.uniform(0, math.pi), obs)
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
        esporta(s, pila_palloni() if s == 'palloni' else catasta_scatoloni())
