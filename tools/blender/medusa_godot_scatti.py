"""Screenshot in Godot 4.7.2 delle mani della medusa (statua e affacciata), per vederle come nel gioco.

Prepara il progetto di prova build/godot_prova (lo stesso del controllo del passo 6): il GLB, i materiali della
cartella godot/ applicati come nel gioco (override delle superfici) e, per la posa affacciata, la vasca della
sala dell'agente ambiente al suo posto rispetto al marker. Luce semplice (sole, riempimento, ambiente grigio),
camera a circa 60 cm dalla mano sinistra. Le immagini vanno in docs/proposte/medusa/mani/godot_*.jpg.

Uso: flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python
     tools/blender/medusa_godot_scatti.py
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

PRJ = os.path.join(BUILD, 'godot_prova')
OUT = os.path.join(PROPOSTE, 'mani')
VASCA = os.path.join(BUILD, 'rif', 'sala_vasca_centrale.glb')

GD = r'''extends SceneTree
# Screenshot delle mani: carica il GLB, applica i materiali come nel gioco, posa, camera, foto.
var radice
var cam
var anim
var scatti = []
var i := -1
var attesa := 0

func _mat(nodo: Node, nome: String, superficie: int, percorso: String) -> void:
	var mi = nodo.find_child(nome, true, false)
	if mi and mi is MeshInstance3D and ResourceLoader.exists(percorso):
		if superficie < mi.mesh.get_surface_count():
			mi.set_surface_override_material(superficie, load(percorso))

func _initialize() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.22, 0.22, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-42, -35, 0)
	sole.light_energy = 1.7
	sole.shadow_enabled = true
	root.add_child(sole)
	var riemp := DirectionalLight3D.new()
	riemp.rotation_degrees = Vector3(-15, 150, 0)
	riemp.light_energy = 0.6
	root.add_child(riemp)
	radice = (load("res://medusa.glb") as PackedScene).instantiate()
	root.add_child(radice)
	var m := "res://assets/models/medusa/"
	_mat(radice, "Medusa", 0, m + "medusa_pelle.tres")
	_mat(radice, "Medusa", 2, m + "medusa_campana.tres")
	_mat(radice, "Medusa", 3, m + "medusa_orbita.tres")
	_mat(radice, "Medusa_Mani", 0, m + "medusa_mani.tres")
	_mat(radice, "Medusa_Ciocche", 0, m + "medusa_ciocche.tres")
	_mat(radice, "Medusa_Tentacoli", 0, m + "medusa_tentacoli.tres")
	_mat(radice, "Medusa_Bordo", 0, m + "medusa_tentacoli.tres")
	_mat(radice, "Medusa_Occhio", 0, m + "medusa_occhio.tres")
	if ResourceLoader.exists("res://vasca.glb"):
		var v = (load("res://vasca.glb") as PackedScene).instantiate()
		v.position = Vector3(0, 0, -10.15)
		v.name = "vasca"
		v.visible = false
		root.add_child(v)
	anim = radice.find_child("AnimationPlayer", true, false)
	cam = Camera3D.new()
	cam.fov = 42
	cam.near = 0.02
	root.add_child(cam)
	cam.current = true
	# [animazione, direzione della camera dalla mano (x, y, z di Godot), nome, vasca visibile]
	scatti = [
		["statua", Vector3(0.15, 0.25, 1.0), "statua_davanti", false],
		["statua", Vector3(1.0, 0.2, 0.25), "statua_lato", false],
		["affacciata", Vector3(0.1, 0.3, 1.0), "affacciata_davanti", true],
		["affacciata", Vector3(0.7, 0.6, 0.7), "affacciata_tre_quarti", true],
	]

func _centro_mano() -> Vector3:
	var sk: Skeleton3D = radice.find_child("Skeleton3D", true, false)
	var a := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mano.L"))
	var b := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("medio_2.L"))
	return (a.origin + b.origin) * 0.5

func _process(_delta: float) -> bool:
	if attesa > 0:
		attesa -= 1
		if attesa == 8:
			_metti_camera()
		if attesa == 0 and i >= 0:
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(OS.get_environment("SCATTI") + "/godot_" + scatti[i][2] + ".png")
			print("SCATTO ", scatti[i][2])
		return false
	i += 1
	if i >= scatti.size():
		return true
	var s = scatti[i]
	anim.play(s[0])
	anim.seek(0.0, true)
	anim.pause()
	var v = root.get_node_or_null("vasca")
	if v:
		v.visible = s[3]
	await_pose()
	return false

func await_pose() -> void:
	# la posa si applica nei frame dopo: la camera si mette qualche frame piu' tardi, la foto alla fine
	attesa = 14

func _metti_camera() -> void:
	var c := _centro_mano()
	var d: Vector3 = scatti[i][1].normalized()
	cam.global_position = c + d * 0.62
	cam.look_at(c, Vector3.UP)
'''


def main():
    if not shutil.which('godot'):
        log('godot non trovato')
        return
    os.makedirs(OUT, exist_ok=True)
    glb = os.path.join(ASSET, 'medusa.glb')
    shutil.copy(glb, os.path.join(PRJ, 'medusa.glb'))
    if os.path.exists(VASCA):
        shutil.copy(VASCA, os.path.join(PRJ, 'vasca.glb'))
    dest = os.path.join(PRJ, 'assets', 'models', 'medusa')
    os.makedirs(dest, exist_ok=True)
    gd = os.path.join(ASSET, 'godot')
    for f in os.listdir(gd):
        if not f.endswith('.md'):
            shutil.copy(os.path.join(gd, f), os.path.join(dest, f))
    with open(os.path.join(PRJ, 'scatta.gd'), 'w') as f:
        f.write(GD)
    tmp = os.path.join(BUILD, 'render', 'godot')
    os.makedirs(tmp, exist_ok=True)
    env = dict(os.environ, SCATTI=tmp)
    subprocess.run(['godot', '--headless', '--path', PRJ, '--import'], capture_output=True, text=True, timeout=1200)
    r = subprocess.run(['xvfb-run', '-a', '-s', '-screen 0 960x960x24', 'godot', '--path', PRJ,
                        '--rendering-driver', 'vulkan', '--resolution', '960x960', '--script', 'res://scatta.gd'],
                       capture_output=True, text=True, timeout=1200, env=env)
    for x in (r.stdout + r.stderr).splitlines():
        if x.startswith(('SCATTO', 'SCRIPT ERROR', 'ERROR')) and 'leaked' not in x and 'resources still' not in x:
            print('   ', x)
    from PIL import Image
    celle = []
    for nome, etichetta in (('statua_davanti', 'Godot: statua'), ('statua_lato', 'Godot: statua, lato'),
                            ('affacciata_davanti', 'Godot: affacciata'),
                            ('affacciata_tre_quarti', 'Godot: affacciata, 3/4')):
        p = os.path.join(tmp, f'godot_{nome}.png')
        if os.path.exists(p):
            Image.open(p).convert('RGB').save(os.path.join(OUT, f'godot_{nome}.jpg'), quality=90)
            celle.append((p, etichetta))
    if celle:
        tavola(celle, os.path.join(OUT, 'mani_godot.jpg'), colonne=len(celle), larghezza=2400)


if __name__ == '__main__':
    main()
