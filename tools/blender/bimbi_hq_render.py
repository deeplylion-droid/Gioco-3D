"""Render Cycles dei modelli nuovi dell'area bimbi in alta definizione (proposta, 16 ottobre): struttura di
gioco con il secchio al suo posto sul telaio, fungo-fontana, secchio da vicino. Luce da studio, pavimento
grigio chiaro, texture 4K dei GLB scaricati da Meshy se ci sono (BIMBI_HQ_GREZZI), altrimenti quelle 2K.

Uso: flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python \\
       tools/blender/bimbi_hq_render.py --uscita <cartella> [--viste a,b,...] [--campioni 96]"""
import argparse, math, os, sys
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import bpy  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402
import bimbi_hq as H  # noqa: E402

# vista: (cosa, posizione camera, punto guardato, lente mm)
VISTE = {
    'struttura_tre_quarti': ('struttura', (9.5, -12.5, 3.2), (-0.6, 0.3, 3.4), 30),
    'struttura_scala': ('struttura', (-6.0, -8.2, 1.7), (-2.4, -1.6, 1.6), 30),
    'struttura_secchio': ('struttura', (3.6, -3.4, 5.3), (-1.2, 2.2, 6.4), 32),
    'fungo_tre_quarti': ('fungo', (3.2, -4.4, 1.9), (0.0, 0.0, 1.0), 40),
    'fungo_sotto': ('fungo', (1.7, -2.0, 0.9), (0.0, 0.0, 1.55), 30),
    'secchio_vicino': ('secchio', (2.2, -2.6, 0.9), (0.0, 0.0, 0.0), 45),
}


def scena(cosa):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    if cosa == 'struttura':
        H.struttura_locale(grezzo=True)
        s = H.secchio_locale(grezzo=True)
        A = H.ASSE_SECCHIO
        s.location = (A['x'], A['y'], A['z'])
        s.rotation_euler = Euler((math.radians(-14), 0, 0))
    elif cosa == 'fungo':
        f = H.importa_unito(H.file_hq(H.FUNGO_HD, grezzo=True), 'fungo')
        lo, hi = H.limiti(f.data)
        f.data.transform(__import__('mathutils').Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
        f.data.transform(__import__('mathutils').Matrix.Scale(2.0 / (hi.z - lo.z), 4))
    else:
        H.secchio_locale(grezzo=True)
    # pavimento grigio chiaro, appena lucido
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -0.75 if cosa == 'secchio' else 0.0))
    pav = bpy.context.active_object
    m = bpy.data.materials.new('pavimento')
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.42, 0.42, 0.43, 1)
    b.inputs['Roughness'].default_value = 0.55
    pav.data.materials.append(m)
    # mondo: studio di Blender, più tre luci ad area
    w = bpy.data.worlds.new('studio')
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    env = nt.nodes.new('ShaderNodeTexEnvironment')
    env.image = bpy.data.images.load(os.path.join(os.path.dirname(bpy.__file__), '5.2', 'datafiles', 'studiolights',
                                                  'world', 'studio.exr'))
    nt.links.new(env.outputs['Color'], nt.nodes['Background'].inputs['Color'])
    nt.nodes['Background'].inputs['Strength'].default_value = 0.55
    H_ = 8.2 if cosa == 'struttura' else 2.0
    for nome, pos, en, col in (('chiave', (-1.0, -1.4, 1.2), 900, (1.0, 0.96, 0.9)),
                               ('riempimento', (1.5, -0.8, 0.5), 300, (0.85, 0.9, 1.0)),
                               ('controluce', (0.4, 1.5, 1.3), 500, (1.0, 0.92, 0.85))):
        l = bpy.data.lights.new(nome, 'AREA')
        l.energy = en * H_ * H_ / 4
        l.color = col
        l.size = 0.9 * H_
        o = bpy.data.objects.new(nome, l)
        sc.collection.objects.link(o)
        o.location = Vector(pos) * H_ * 1.3 + Vector((0, 0, H_ * 0.4))
        o.rotation_euler = (Vector((0, 0, H_ * 0.4)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    return sc


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--uscita', required=True)
    ap.add_argument('--viste', default=','.join(VISTE))
    ap.add_argument('--campioni', type=int, default=96)
    ap.add_argument('--larghezza', type=int, default=1600)
    ap.add_argument('--altezza', type=int, default=1000)
    a = ap.parse_args(argv)
    os.makedirs(a.uscita, exist_ok=True)
    fatta = None
    for v in a.viste.split(','):
        cosa, pos, mira, lente = VISTE[v]
        if cosa != fatta:
            sc = scena(cosa)
            fatta = cosa
        cam_d = bpy.data.cameras.new('cam_' + v)
        cam_d.lens = lente
        cam = bpy.data.objects.new('cam_' + v, cam_d)
        sc.collection.objects.link(cam)
        cam.location = pos
        cam.rotation_euler = (Vector(mira) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
        sc.camera = cam
        sc.render.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = a.campioni
        sc.cycles.use_denoising = True
        sc.render.threads_mode = 'FIXED'
        sc.render.threads = 3
        sc.render.resolution_x, sc.render.resolution_y = a.larghezza, a.altezza
        sc.view_settings.view_transform = 'AgX'
        sc.render.image_settings.file_format = 'PNG'
        sc.render.filepath = os.path.join(os.path.abspath(a.uscita), f'{v}.png')
        bpy.ops.render.render(write_still=True)
        print('render ->', sc.render.filepath, flush=True)


if __name__ == '__main__':
    main()
