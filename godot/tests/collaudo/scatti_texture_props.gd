extends Node
## Scatti dal motore degli oggetti piccoli le cui texture passano da 2048 a 1024 (scelta A dell'utente del 4 novembre,
## "peso": tools/godot_vram_textures.py, PROPS_1024 e la torre): ogni oggetto da solo, trovato dalla texture che usa,
## da molto vicino (0,6 m dalla superficie, il caso peggiore) e alla distanza di gioco (1,5 m dal centro), con la stessa
## luce. Si lancia prima e dopo l'import con le texture ridotte, e si confrontano i fogli.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_texture_props.gd <cartella>

## [gltf, parte del nome della texture, nome dello scatto]
const OGGETTI := [
	["res://assets/ambienti_interni/stanzino.gltf", "hq_estintore_staffa", "estintore"],
	["res://assets/ambienti_tecnici/sala_pompe.gltf", "hq_leva_maniglia", "leva"],
	["res://assets/ambienti_tecnici/arredo_risalita/arredo_risalita.gltf", "hq_fusti_cloro", "fusti_cloro"],
	["res://assets/ambienti_tecnici/sala_pompe.gltf", "hq_manometro", "manometro"],
	["res://assets/ambienti_interni/corridoio.gltf", "hq_valvola_volantino", "valvola"],
	["res://assets/ambienti_interni/spogliatoi.gltf", "hq_quadro_pulsante", "quadro_pulsante"],
	["res://assets/ambienti_tecnici/arredo_risalita/arredo_risalita.gltf", "hq_carrello_attrezzi", "carrello_attrezzi"],
	# (la torre: lì cambiano solo normal e ORM, il colore resta; gli scivoli si guardano da vicino scendendo)
	["res://assets/ambiente/torre/torre_scivoli.glb", "torre_scivoli_vetroresina", "torre_scivolo"],
	["res://assets/ambiente/torre/torre_struttura.glb", "torre_struttura_metallo_verniciato", "torre_metallo"],
]

var _cartella := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_texture_props"
	DirAccess.make_dir_recursive_absolute(_cartella)
	var mondo := Node3D.new()
	add_child(mondo)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.38)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	mondo.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-40, 35, 0)
	sole.light_energy = 0.7
	sole.shadow_enabled = true
	mondo.add_child(sole)
	var cam := Camera3D.new()
	cam.fov = 60.0
	mondo.add_child(cam)
	cam.current = true
	var caricati := {}
	for o in OGGETTI:
		var g: String = o[0]
		if not caricati.has(g):
			var ps := load(g) as PackedScene
			if ps == null:
				print("SCATTI: non trovo ", g)
				continue
			var n := ps.instantiate() as Node3D
			mondo.add_child(n)
			caricati[g] = n
		for k in caricati:
			(caricati[k] as Node3D).visible = k == g
		var radice: Node3D = caricati[g]
		var trovati: Array[MeshInstance3D] = []
		for m in radice.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			mi.visible = _usa(mi, o[1])
			if mi.visible:
				trovati.append(mi)
		if trovati.is_empty():
			print("SCATTI: nessuna mesh con ", o[1])
			continue
		# (il primo pezzo trovato e quelli vicini a lui: in una stanza lo stesso oggetto può stare in più posti)
		var box := trovati[0].global_transform * trovati[0].get_aabb()
		for mi in trovati.slice(1):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if b.intersects(box.grow(0.05)):
				box = box.merge(b)
			else:
				(mi as MeshInstance3D).visible = false
		var c := box.get_center()
		var raggio := box.size.length() * 0.5
		var dir := Vector3(0.7, 0.35, 1.0).normalized()
		# (vicino: l'oggetto riempie l'inquadratura, come col naso sopra; gioco: a 1,5 m)
		var riempie := raggio / tan(deg_to_rad(cam.fov * 0.5)) * 1.15
		var viste := [["vicino", maxf(riempie, raggio + 0.15)], ["gioco", maxf(1.5, raggio + 0.8)]]
		if raggio > 2.0:
			# (un pezzo grande, come gli scivoli: un punto della superficie vicino al centro, guardato lungo la sua normale)
			var pv := _punto_superficie(trovati[0], c)
			c = pv[0]
			dir = pv[1]
			raggio = 0.0
			viste = [["vicino", 0.6], ["gioco", 1.5]]
		for vista in viste:
			cam.look_at_from_position(c + dir * float(vista[1]), c, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
			sole.look_at_from_position(c + Vector3(1.0, 1.5, 1.2), c, Vector3.UP)
			for i in 8:
				await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var file := "%s/%s_%s.png" % [_cartella, o[2], vista[0]]
			img.save_png(file)
			print("SCATTI: ", file)
	print("SCATTI FINITI")
	get_tree().quit()


## [punto, normale] (nel mondo) del vertice della prima superficie di [param mi] più vicino a [param verso].
func _punto_superficie(mi: MeshInstance3D, verso: Vector3) -> Array:
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var loc := mi.global_transform.affine_inverse() * verso
	var best := 0
	var bd := INF
	for i in v.size():
		var dd := v[i].distance_squared_to(loc)
		if dd < bd:
			bd = dd
			best = i
	return [mi.global_transform * v[best], (mi.global_basis * nr[best]).normalized()]


func _usa(mi: MeshInstance3D, parte: String) -> bool:
	if mi.mesh == null:
		return false
	for s in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s) as BaseMaterial3D
		if mat == null:
			continue
		for t in [mat.albedo_texture, mat.normal_texture, mat.orm_texture if mat is ORMMaterial3D else null]:
			if t and parte in (t as Texture2D).resource_path:
				return true
	return false
