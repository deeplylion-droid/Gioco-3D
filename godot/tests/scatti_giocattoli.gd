extends Node
## Scatti dei modelli dell'enigma "I giocattoli al loro posto" (accordo con enigmi del 28 ottobre) sul modello vero
## della piscina a onde (solo sala_piscina.glb: la sala intera con llvmpipe non ci sta in memoria), piscina vuota, con
## le posizioni della scena di enigmi:
## - il disegno a pastello (decal di 1,2 x 0,9 m) sul muro ovest della parte profonda, x -6,97, centro z -0,2, y -0,8,
##   guarda a est;
## - i cerchi a mosaico da 1 m sul fondo a quota -2,05 (giallo -3,9/3,3, rosso 3,9/3,3, blu -3,9/-0,1), col bordo
##   spento (giallo), a metà (rosso) e acceso (blu), e su ognuno il suo giocattolo. Qui dischi e giocattoli si
##   appoggiano sul fondo vero, trovato con un raggio (a x ±3,9 è a circa -2,02, non -2,05).
## Luce: ambiente scuro della sala e una torcia sulla camera (solo negli scatti).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_giocattoli.gd <cartella>

const DIR := "res://assets/models/enigma_giocattoli/"
const FONDO := -2.05
## [colore, giocattolo, bordo_acceso, x, z, giro del giocattolo in gradi]
const CERCHI := [["giallo", "paperella", 0.0, -3.9, 3.3, 200.0], ["rosso", "pallone", 0.5, 3.9, 3.3, 0.0],
	["blu", "balena", 1.0, -3.9, -0.1, 230.0]]
## [occhio, guardato, fov]
const SCATTI := {
	"disegno_muro": [Vector3(-3.2, -0.5, -0.2), Vector3(-6.97, -0.8, -0.2), 60.0],
	"disegno_vicino": [Vector3(-5.6, -0.75, -0.2), Vector3(-6.97, -0.8, -0.2), 55.0],
	"disegno_e_cerchi": [Vector3(1.0, -0.3, -2.4), Vector3(-3.0, -1.8, 1.6), 70.0],
	"pallone_vicino": [Vector3(2.6, -1.0, 1.8), Vector3(3.9, -1.85, 3.3), 60.0],
	"giocattoli_vicino": [Vector3(-2.2, -0.9, 1.2), Vector3(-3.9, -1.85, 2.2), 60.0],
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
	# il fondo vero (è curvo: -2,00 ai lati, -2,17 al centro), per appoggiare dischi e giocattoli
	for mi in piscina.find_children("*", "MeshInstance3D", true, false):
		var sb := StaticBody3D.new()
		mi.add_child(sb)
		var cs := CollisionShape3D.new()
		cs.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		sb.add_child(cs)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spazio := get_viewport().world_3d.direct_space_state
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
	# il decal: guarda a est (il suo +Y verso +X), la destra del disegno a nord (-Z), l'alto del disegno in su
	var dec := Decal.new()
	dec.texture_albedo = load(DIR + "disegno_piscina.png")
	dec.size = Vector3(1.2, 0.1, 0.9)
	dec.cull_mask = 1
	add_child(dec)
	dec.global_transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), Vector3(-6.97, -0.8, -0.2))
	for c in CERCHI:
		var disco := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1, 1)
		disco.mesh = pm
		var mat := (load(DIR + "cerchio_" + c[0] + ".tres") as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"bordo_acceso", c[2])
		disco.material_override = mat
		disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disco)
		var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c[3], 0, c[4]), Vector3(c[3], -5, c[4])))
		var y: float = hit.get("position", Vector3(0, FONDO, 0)).y
		var n: Vector3 = hit.get("normal", Vector3.UP)
		var alti := []
		for d in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
			alti.append(snappedf(spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c[3] + d.x, 0, c[4] + d.y), Vector3(c[3] + d.x, -5, c[4] + d.y))).get("position", Vector3.ZERO).y, 0.001))
		print("fondo in ", c[0], ": %.3f, normale %s, ai bordi (x+, x-, z+, z-) %s" % [y, n, alti])
		# il fondo lì è inclinato: il disco segue il fondo
		disco.basis = Basis(Quaternion(Vector3.UP, n))
		disco.position = Vector3(c[3], y + 0.003, c[4])
		var g := (load(DIR + c[1] + ".glb") as PackedScene).instantiate() as Node3D
		add_child(g)
		g.position = Vector3(c[3], y + 0.004, c[4])
		g.rotation.y = deg_to_rad(c[5])
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var torcia := SpotLight3D.new()
	torcia.spot_range = 20.0
	torcia.spot_angle = 32.0
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
