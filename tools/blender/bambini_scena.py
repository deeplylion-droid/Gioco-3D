"""I bambini dentro l'acquapark: render in Cycles nell'"angolo di prova" dell'ambiente.

La stanza (piscina, ponte piastrellato, parete-scafo con gli oblò, galleria, scivolo, luci
d'emergenza rosse, neon, nebbia bassa) la costruisce il kit dell'ambiente,
tools/blender/ambiente_anteprima.py + ambiente_kit.py, usato in sola lettura. Se nel repo non
c'è ancora, lo cerca in /home/user/wt/ambiente/tools/blender (worktree del ramo lavoro/ambiente).
La stanza costruita si può salvare in un .blend di cache (--cache), così i render successivi
partono subito e non dipendono da modifiche in corso al kit.

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_scena.py \
        <modello> <uscita.png> [--vista davanti|tre_quarti|dietro] [--inquadratura ponte|vicino]
        [--res 1600x900] [--campioni 40] [--bagliore 0] [--occhi-rosa] [--cache stanza.blend]
        [--nebbia 1.0] [--fili 4]

<modello> è una chiave di MODELLI in bambini_comune.py (cubo_calmo, cubo_rivelato, ...).
<uscita> è un prefisso: escono <uscita>_eroe.png (RX x RY, inquadratura scelta) e, con la
ripresa 'giro', <uscita>_giro.png (davanti, tre quarti e dietro affiancati, RX x RY).
"""
import argparse, math, os, sys, time
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bambini_comune as B  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('modello'); ap.add_argument('uscita')
ap.add_argument('--vista', default='davanti', choices=['davanti', 'tre_quarti', 'dietro'])
ap.add_argument('--inquadratura', default='ponte', choices=['ponte', 'vicino'])
ap.add_argument('--res', default='1600x900')
ap.add_argument('--campioni', type=int, default=40)
ap.add_argument('--bagliore', type=float, default=0.0)
ap.add_argument('--occhi-rosa', action='store_true')
ap.add_argument('--bagnato', type=float, default=0.75)
ap.add_argument('--cache', default='')
ap.add_argument('--nebbia', type=float, default=0.55)
ap.add_argument('--palette', default='p1_bianco_turchese')
ap.add_argument('--fili', type=int, default=4)
ap.add_argument('--salva-blend', default='')
ap.add_argument('--riprese', default='eroe,giro')
ap.add_argument('--suffisso', default='')
ap.add_argument('--esposizione', type=float, default=-0.5)
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
RX, RY = (int(v) for v in A.res.split('x'))

# posizione del bambino sul ponte, a destra della piscina, davanti alla parete con gli oblò
POS = Vector((1.15, 3.55, 0.0))
INQ = {
    # camera, punto guardato, lente (mm)
    'ponte': ((2.1, 0.45, 0.98), (0.82, 3.55, 0.64), 35.0),
    'vicino': ((1.75, 1.15, 0.72), (1.1, 3.55, 0.70), 32.0),
}
GIRO = {'davanti': 0.0, 'tre_quarti': 35.0, 'dietro': 180.0}


def trova_kit():
    for d in (B.QUI, '/home/user/wt/ambiente/tools/blender'):
        if os.path.exists(os.path.join(d, 'ambiente_anteprima.py')):
            return d
    raise SystemExit('kit dell\'ambiente non trovato (ambiente_anteprima.py)')


def stanza():
    if A.cache and os.path.exists(A.cache):
        bpy.ops.wm.open_mainfile(filepath=A.cache)
        B.log('stanza dalla cache', A.cache)
        return
    kit = trova_kit()
    sys.path.insert(0, kit)
    import ambiente_anteprima as AA  # noqa: E402
    AA.K.svuota()
    mats = AA.K.Materiali(A.palette, per_render=True)
    AA.costruisci_angolo(mats)
    AA.acqua()
    AA.esterno()
    AA.luci()
    AA.decal_colature(mats)
    if A.nebbia > 0:
        AA.nebbia(A.nebbia)
    AA.impostazioni(A.campioni, RX, RY, A.fili, False)
    B.log('stanza costruita con il kit in', kit)
    if A.cache:
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=A.cache, compress=True)
        B.log('cache salvata', A.cache)


def atmosfera():
    """Più buio e più rosso, come lo stile A: neon e cupola smorzati, emergenze più forti,
    pozzanghere lucide sul ponte intorno al bambino."""
    ob = sc.objects
    for nome, f in (('neon_a_luce', 0.35), ('neon_b_luce', 0.5), ('cupola', 0.3),
                    ('faro_cartellone', 0.4), ('emerg_a_luce', 2.5), ('emerg_b_luce', 1.8),
                    ('emerg_e_luce', 1.5)):
        if nome in ob and ob[nome].type == 'LIGHT':
            ob[nome].data.energy *= f
    if 'nebbia' in ob:
        ob['nebbia'].hide_render = A.nebbia <= 0
        for m in ob['nebbia'].data.materials:
            for n in m.node_tree.nodes:
                if n.type == 'MATH' and n.operation == 'MULTIPLY_ADD':
                    n.inputs[1].default_value *= A.nebbia
                    n.inputs[2].default_value *= A.nebbia
    sc.cycles.volume_step_rate = 4.0
    # pozzanghere: piano appena sopra il pavimento, lucido, con alfa a macchie
    m = bpy.data.materials.new('M_pozzanghere'); m.use_nodes = True
    nt, ln = m.node_tree.nodes, m.node_tree.links
    b = nt['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.012, 0.014, 0.016, 1)
    b.inputs['Roughness'].default_value = 0.015
    tc = nt.new('ShaderNodeTexCoord')
    no = nt.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 0.9
    no.inputs['Detail'].default_value = 4.0; no.inputs['Roughness'].default_value = 0.55
    ln.new(tc.outputs['Object'], no.inputs['Vector'])
    mr = nt.new('ShaderNodeMapRange'); mr.interpolation_type = 'SMOOTHSTEP'
    mr.inputs['From Min'].default_value = 0.47; mr.inputs['From Max'].default_value = 0.53
    ln.new(no.outputs['Fac'], mr.inputs['Value'])
    ln.new(mr.outputs[0], b.inputs['Alpha'])
    bpy.ops.mesh.primitive_plane_add(size=1, location=(1.6, 2.4, 0.003))
    p = bpy.context.active_object; p.name = 'pozzanghere'; p.scale = (4.4, 4.6, 1)
    p.data.materials.append(m)


t0 = time.time()
stanza()
sc = bpy.context.scene
atmosfera()
glb, altezza = B.MODELLI[A.modello]
perno = B.importa(os.path.join(B.ASSET, glb), None, nome=A.modello)  # i GLB del repo sono già a misura
perno.location = POS
B.ritocca_materiali(B.materiali_di(perno), A.bagnato, A.bagliore, A.occhi_rosa)


def luce(nome, tipo, pos, energia, colore, **kw):
    d = bpy.data.lights.new(nome, tipo); d.energy = energia; d.color = colore
    for k, v in kw.items():
        setattr(d, k, v)
    ob = bpy.data.objects.new(nome, d); sc.collection.objects.link(ob); ob.location = pos
    return ob


# luci in più per il bambino: controluce rosso (una luce d'emergenza alle sue spalle),
# controluce freddo dall'altra parte e una luce debole dal punto di vista del giocatore
r = luce('b_rosso_dietro', 'POINT', POS + Vector((-0.6, 0.7, 1.25)), 110, (1.0, 0.05, 0.03),
         shadow_soft_size=0.08)
cam_eroe = Vector(INQ['ponte'][0])
f = luce('b_giocatore', 'SPOT', cam_eroe + Vector((0.25, 0.1, 0.35)), 180, (0.75, 0.85, 1.0),
         spot_size=math.radians(30), spot_blend=0.9, shadow_soft_size=0.15)
f.rotation_euler = (POS + Vector((0, 0, 0.7)) - f.location).to_track_quat('-Z', 'Y').to_euler()
c = luce('b_freddo_dietro', 'POINT', POS + Vector((0.85, 0.8, 1.7)), 60, (0.6, 0.85, 1.0),
         shadow_soft_size=0.1)
for o in (r, f, c):
    o.visible_camera = False

cd = bpy.data.cameras.new('cam_bambini'); cd.sensor_width = 36; cd.sensor_height = 20.25
cam = bpy.data.objects.new('cam_bambini', cd); sc.collection.objects.link(cam)
sc.camera = cam
cd.dof.use_dof = True
cd.dof.aperture_fstop = 2.8

sc.cycles.samples = A.campioni
sc.cycles.adaptive_threshold = 0.04
sc.cycles.diffuse_bounces = 2
sc.cycles.glossy_bounces = 2
sc.view_settings.exposure = A.esposizione
sc.render.threads_mode = 'FIXED'; sc.render.threads = A.fili
sc.render.image_settings.file_format = 'PNG'
sc.render.use_persistent_data = True


def ripresa(nome, vista, pos_cam, bersaglio, lente, rx, ry, verticale=False):
    B.guarda_verso(perno, pos_cam, GIRO[vista])
    cam.location = pos_cam
    cam.rotation_euler = (Vector(bersaglio) - Vector(pos_cam)).to_track_quat('-Z', 'Y').to_euler()
    cd.lens = lente
    cd.sensor_fit = 'VERTICAL' if verticale else 'HORIZONTAL'
    cd.dof.focus_distance = (POS + Vector((0, 0, 0.6)) - Vector(pos_cam)).length
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    out = f'{A.uscita}_{nome}.png'
    sc.render.filepath = os.path.abspath(out)
    t1 = time.time()
    bpy.ops.render.render(write_still=True)
    B.log(A.modello, nome, f'{time.time() - t1:.0f}s ->', out)
    return out


if A.salva_blend:
    bpy.ops.wm.save_as_mainfile(filepath=A.salva_blend, compress=True)
for rip in A.riprese.split(','):
    if rip == 'eroe':
        pc, bers, lente = INQ[A.inquadratura]
        ripresa('eroe' + A.suffisso, A.vista, pc, bers, lente, RX, RY)
    elif rip == 'giro':
        # tre strisce verticali (davanti, tre quarti, dietro), poi unite in un'immagine RX x RY
        pc = POS + Vector((0.45, -2.75, 0.95))
        bers = POS + Vector((0, 0, 0.6))
        w = int(round(RX / 3))
        fatte = [ripresa(f'giro_{v}', v, pc, bers, 35.0, w, RY, verticale=True)
                 for v in ('davanti', 'tre_quarti', 'dietro')]
        try:
            from PIL import Image
            tela = Image.new('RGB', (w * 3, RY))
            for i, fp in enumerate(fatte):
                tela.paste(Image.open(fp).convert('RGB'), (i * w, 0))
            tela.save(f'{A.uscita}_giro.png')
        except ImportError:
            pass
B.log(A.modello, f'totale {time.time() - t0:.0f}s')
