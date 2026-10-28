extends Node
## Scatti dei modelli dell'enigma "I giocattoli al loro posto" (28 ottobre) sul modello vero della piscina a onde
## (solo sala_piscina.glb: la sala intera con llvmpipe non ci sta in memoria), piscina vuota:
## - il disegno dei bambini sul muro della parte fonda (z = 5, guarda verso la spiaggia), sopra le bocchette delle
##   onde e lontano dal pulsante del portello: dal fondo a 2,5 m e da vicino (1,1 m);
## - i tre cerchi a mosaico col loro giocattolo sul fondo piano vicino al muro ovest, col bordo fosforescente spento
##   (giallo), a metà (rosso) e appena acceso (blu). La disposizione qui è solo per lo scatto: i cerchi li mette enigmi.
## Luce: ambiente scuro della sala e la torcia sulla camera (solo negli scatti).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_giocattoli.gd <cartella>

const DIR := "res://assets/enigma_giocattoli/"
const DISEGNO := Vector3(-2.5, -0.42, 4.997)
## [occhio, guardato, fov]
const SCATTI := {
	"disegno_dal_fondo": [Vector3(-2.2, -0.45, 2.5), Vector3(-2.5, -0.5, 5.0), 60.0],
	"disegno_da_vicino": [Vector3(-2.35, -0.5, 3.9), Vector3(-2.5, -0.42, 5.0), 60.0],
	"cerchi_e_giocattoli": [Vector3(-3.0, -0.3, -0.6), Vector3(-5.5, -2.0, 2.3), 60.0],
}

var cartella := "user://scatti_giocattoli"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	var piscina := (load("res://assets/ambiente/sala/sala_piscina.glb") as PackedScene).instantiate()
	add_child(piscina)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.025, 0.03)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.32, 0.36, 0.42)
	env.environment.ambient_light_energy = 0.35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment.glow_enabled = true
	add_child(env)
	var disegno := (load(DIR + "disegno_giocattoli.tscn") as PackedScene).instantiate() as Node3D
	add_child(disegno)
	disegno.position = DISEGNO
	disegno.rotation.y = PI
	var cerchi := [["giallo", "paperella", 0.0, 1.0], ["rosso", "palla_rossa", 0.5, 2.3], ["blu", "balena_blu", 1.0, 3.6]]
	for c in cerchi:
		var cm := (load(DIR + "cerchio_mosaico.tscn") as PackedScene).instantiate() as MeshInstance3D
		var mat := (load(DIR + "cerchio_" + c[0] + ".tres") as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"luce_bordo", c[2])
		cm.material_override = mat
		add_child(cm)
		cm.position = Vector3(-5.5, -2.0, c[3])
		var g := (load(DIR + c[1] + ".tscn") as PackedScene).instantiate() as RigidBody3D
		g.freeze = true
		add_child(g)
		g.position = Vector3(-5.5, -2.0, c[3])
		g.rotation.y = deg_to_rad(-120.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var torcia := SpotLight3D.new()
	torcia.spot_range = 20.0
	torcia.spot_angle = 30.0
	torcia.light_energy = 6.0
	torcia.shadow_enabled = true
	cam.add_child(torcia)
	torcia.position = Vector3(0.25, -0.15, 0)
	for nome in SCATTI:
		var s: Array = SCATTI[nome]
		cam.fov = s[2]
		cam.look_at_from_position(s[0], s[1])
		for i in 40:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()
