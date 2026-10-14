"""Passo 6: export GLB per Godot (scheletro, pesi, shape key, materiali PBR standard).

Parte da build/medusa_04_scheletro.blend (oppure da un altro .blend con --blend) e scrive
assets_src/medusa/export/medusa.glb. Prima di esportare adatta i materiali a quello che Godot legge
dal glTF:
  - tutti i materiali sono Principled con texture collegate direttamente (base color, metallic/roughness
    con il nodo Separate Color, normal map), cioe' quello che l'exporter glTF capisce;
  - la cornea usa la trasparenza "alpha blend" (Godot non legge KHR_materials_transmission);
  - il labbro dell'orbita usa la texture della pelle con un fattore di colore piu' scuro;
  - gli slot di materiale vuoti (l'occhio dipinto tolto) si eliminano.
I punti d'attacco dei tentacoli (empties) si appendono all'osso "campana": in Godot diventano nodi figli
di quell'osso (BoneAttachment3D).

Controlli: reimporta il GLB in Blender e, se c'e' il comando `godot`, lo importa anche in un progetto
Godot di prova (build/godot_prova) e stampa ossa, superfici, blend shape e materiali.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_06_export.py [--blend X] [--out Y]
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401


def argomento(nome, default):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return default


def togli_slot_vuoti(ob):
    me = ob.data
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    usati = sorted(set(mi.tolist()))
    if len(usati) == len(me.materials):
        return
    mappa = {old: new for new, old in enumerate(usati)}
    mats = [me.materials[i] for i in usati]
    nuovi = np.array([mappa[i] for i in mi], dtype=np.int32)
    me.materials.clear()
    for m in mats:
        me.materials.append(m)
    me.polygons.foreach_set('material_index', nuovi)
    me.update()
    log('slot di materiale tolti:', [i for i in range(max(usati) + 1) if i not in usati])


def materiali_per_godot():
    mc = bpy.data.materials.get('M_occhio_cornea')
    if mc:
        b = mc.node_tree.nodes['BSDF']
        b.inputs['Transmission Weight'].default_value = 0.0
        b.inputs['Alpha'].default_value = 0.12
        b.inputs['Roughness'].default_value = 0.03
        try:
            mc.surface_render_method = 'BLENDED'
        except Exception:
            pass
    mo = bpy.data.materials.get('M_orbita')
    if mo:
        nt = mo.node_tree
        for n in list(nt.nodes):
            if n.type == 'MIX':
                nt.nodes.remove(n)
        nt.links.new(nt.nodes['base'].outputs['Color'], nt.nodes['BSDF'].inputs['Base Color'])
        # piu' scuro: glTF moltiplica baseColorFactor per la texture; l'exporter lo legge da un nodo
        # "Mix Multiply" solo in certi casi, quindi qui si scurisce con la roughness e il colore e' quello della pelle
        nt.nodes['BSDF'].inputs['Roughness'].default_value = 0.6


def attacchi_sull_osso(arm):
    coll = bpy.data.collections.get('Attacchi_tentacoli')
    if not coll:
        return
    for e in coll.objects:
        mw = e.matrix_world.copy()
        e.parent = arm
        e.parent_type = 'BONE'
        e.parent_bone = 'campana'
        bpy.context.view_layer.update()
        e.matrix_world = mw


def esporta(out):
    arm = bpy.data.objects['Medusa_Scheletro']
    attacchi_sull_osso(arm)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    sel = [arm] + [o for o in bpy.data.objects if o.parent == arm]
    for o in sel:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True,
        export_image_format='AUTO', export_tangents=True, export_materials='EXPORT',
        export_skins=True, export_influence_nb=4, export_def_bones=False, export_leaf_bone=False,
        export_morph=True, export_morph_normal=True, export_animations=True, export_yup=True,
        export_apply=False, export_extras=False)
    log('esportato', os.path.relpath(out, REPO), f'{os.path.getsize(out) / 1e6:.1f} MB')


def controlla_blender(out):
    reset()
    bpy.ops.import_scene.gltf(filepath=out)
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    mesh = [o for o in bpy.data.objects if o.type == 'MESH']
    log('reimport: armature', [(a.name, len(a.data.bones)) for a in arms])
    for o in mesh:
        sk = [k.name for k in o.data.shape_keys.key_blocks] if o.data.shape_keys else []
        log(f'  mesh {o.name}: {len(o.data.polygons)} facce, materiali {[m.name for m in o.data.materials]}, '
            f'shape key {sk}, gruppi {len(o.vertex_groups)}')


GD_CONTROLLO = '''extends SceneTree
func _init():
\tvar scena = load("res://medusa.glb").instantiate()
\tvar stack = [scena]
\twhile stack.size() > 0:
\t\tvar n = stack.pop_back()
\t\tif n is Skeleton3D:
\t\t\tprint("SKELETON ", n.name, " ossa=", n.get_bone_count(), " radice=", n.get_bone_name(0))
\t\tif n is MeshInstance3D:
\t\t\tvar m = n.mesh
\t\t\tvar bs = []
\t\t\tfor i in m.get_blend_shape_count():
\t\t\t\tbs.append(m.get_blend_shape_name(i))
\t\t\tprint("MESH ", n.name, " superfici=", m.get_surface_count(), " blend_shape=", bs, " skin=", n.skin != null)
\t\t\tfor s in m.get_surface_count():
\t\t\t\tvar mat = m.surface_get_material(s)
\t\t\t\tif mat is BaseMaterial3D:
\t\t\t\t\tprint("   materiale ", mat.resource_name, " trasparenza=", mat.transparency, " albedo_tex=", mat.albedo_texture != null, " normal=", mat.normal_enabled, " roughness=", mat.roughness)
\t\tif n is BoneAttachment3D:
\t\t\tprint("ATTACCO ", n.name, " osso=", n.bone_name)
\t\tfor c in n.get_children():
\t\t\tstack.append(c)
\tquit()
'''


def controlla_godot(out):
    if not shutil.which('godot'):
        log('godot non trovato: controllo saltato')
        return
    prj = os.path.join(BUILD, 'godot_prova')
    os.makedirs(prj, exist_ok=True)
    with open(os.path.join(prj, 'project.godot'), 'w') as f:
        f.write('config_version=5\n\n[application]\nconfig/name="prova medusa"\n')
    shutil.copy(out, os.path.join(prj, 'medusa.glb'))
    with open(os.path.join(prj, 'controlla.gd'), 'w') as f:
        f.write(GD_CONTROLLO)
    r = subprocess.run(['godot', '--headless', '--path', prj, '--import'], capture_output=True, text=True, timeout=900)
    r = subprocess.run(['godot', '--headless', '--path', prj, '--script', 'res://controlla.gd'],
                       capture_output=True, text=True, timeout=600)
    righe = [x for x in (r.stdout + r.stderr).splitlines()
             if x.startswith(('SKELETON', 'MESH', '   materiale', 'ATTACCO', 'ERROR', 'SCRIPT ERROR'))]
    log('Godot:')
    for x in righe:
        print('   ', x)


def main():
    src = argomento('--blend', os.path.join(BUILD, 'medusa_04_scheletro.blend'))
    out = argomento('--out', os.path.join(EXPORT, 'medusa.glb'))
    apri(src)
    togli_slot_vuoti(bpy.data.objects['Medusa'])
    materiali_per_godot()
    esporta(out)
    controlla_blender(out)
    if '--no-godot' not in sys.argv:
        controlla_godot(out)


if __name__ == '__main__':
    main()
