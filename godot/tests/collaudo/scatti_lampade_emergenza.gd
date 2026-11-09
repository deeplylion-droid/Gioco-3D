extends Node
## Collaudo dei passi lunghi della sala (#147, ambienti-1): le 7 lampade d'emergenza della torre (SalaTorre._emergenza,
## coi 9 raggi sulle sole mesh vicine). La sala della torre da sola, con l'ambiente della sala grande (come
## scatti_torre.gd). Per ogni lampada:
## - dagli occhi: 1,6 m sopra il pavimento sotto un punto 2,5 m davanti alla lampada, guardandola;
## - da vicino, a 45 cm, di taglio lungo il muro da sinistra, da destra e da sopra (campo visivo 40°);
## - il distacco: 25 raggi dal retro della scatola verso il muro (tutte le mesh): il più vicino è il contatto (0 mm
##   = appoggiata), e se il muro entra nella scatola.
## Con "nascosta" la torre si costruisce come dal portone. Per ogni lampada anche le cose sopra e sotto la scatola.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##   --script res://tests/run.gd -- res://tests/collaudo/scatti_lampade_emergenza.gd <cartella> [nascosta]

const SCENA := "res://scenes/sala/torre/sala_torre.tscn"

var cartella := "/tmp/scatti_lampade"
## "nascosta": la torre si costruisce a pezzi nascosta e ferma (visible = false, process_mode DISABLED), come dal portone
## (SalaPrincipale._prepara_torre), e poi si mostra; senza, si costruisce a pezzi visibile, come da F9, morte e Continua.
var nascosta := false


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	nascosta = a.has("nascosta")
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _scatto(nome: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	print("SCATTO ", nome)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := (load(SCENA) as PackedScene).instantiate()
	sala.set(&"costruzione_a_pezzi", true)
	if nascosta:
		sala.visible = false
		sala.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(sala)
	await sala.call(&"costruisci_a_pezzi", 8.0)
	sala.visible = true
	sala.process_mode = Node.PROCESS_MODE_INHERIT
	print("TORRE costruita a pezzi, ", "nascosta" if nascosta else "visibile")
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.near = 0.02
	for i in 40:
		await get_tree().process_frame
	var luci := sala.get_node_or_null(^"Luci")
	var k := 0
	for c in (luci.get_children() if luci else []):
		var corpo := c as MeshInstance3D
		if corpo == null or not corpo.mesh is BoxMesh:
			continue
		var bx := corpo.mesh as BoxMesh
		# il verso verso fuori dal muro: il lato sottile della scatola (16 cm), dalla parte libera
		var asse := Vector3.RIGHT if bx.size.x < 0.2 else Vector3.BACK
		var p := corpo.global_position
		var st := get_tree().root.get_world_3d().direct_space_state
		var v := asse
		var d1 := Posa._raggio(corpo, p, p + asse * 2.0, [])
		var d2 := Posa._raggio(corpo, p, p - asse * 2.0, [])
		var dist1: float = p.distance_to(d1.position) if not d1.is_empty() else INF
		var dist2: float = p.distance_to(d2.position) if not d2.is_empty() else INF
		v = -asse if dist1 < dist2 else asse   # il muro sta dalla parte più vicina: fuori è l'altra
		var a1 := v.cross(Vector3.UP).normalized()
		var a2 := v.cross(a1).normalized()
		# distacco: 25 raggi dal retro (8 cm dietro il centro) verso il muro
		var contatto := INF
		var dentro := 0
		for i in range(-2, 3):
			for j in range(-2, 3):
				var o: Vector3 = a1 * (i * 0.07) + a2 * (j * 0.07)
				var retro := p + o - v * 0.08
				var h := Posa._raggio(corpo, p + o, p + o - v * 0.6, [])
				if h.is_empty():
					continue
				var gap: float = (retro - (h.position as Vector3)).dot(v)
				contatto = minf(contatto, gap)
				if gap < -0.001:
					dentro += 1
		# sopra e sotto la scatola (alta 30 cm): 9 raggi verso il basso dal fondo e verso l'alto dal coperchio, fino a 60 cm
		for su_giu: Vector3 in [Vector3.DOWN, Vector3.UP]:
			var minimo := INF
			var cosa := ""
			for i in [-1, 0, 1]:
				for j in [-1, 0, 1]:
					var o2: Vector3 = a1 * (i * 0.07) + v * (j * 0.07)
					var faccia: Vector3 = p + o2 + su_giu * 0.15
					var h2 := Posa._raggio(corpo, p + o2, faccia + su_giu * 0.6, [])
					if h2.is_empty():
						continue
					var g: float = ((h2.position as Vector3) - faccia).dot(su_giu)
					if g < minimo:
						minimo = g
						var col: Object = h2.get("collider")
						cosa = str(sala.get_path_to(col)) if col is Node and sala.is_ancestor_of(col) else str(col)
			print("LAMPADA %d %s: la cosa più vicina a %s mm (%s)" % [k, "sotto" if su_giu == Vector3.DOWN else "sopra",
					"%.1f" % (minimo * 1000.0) if minimo < INF else "oltre 600", cosa])
		var pav := st.intersect_ray(PhysicsRayQueryParameters3D.create(p + v * 0.3, p + v * 0.3 + Vector3.DOWN * 40.0))
		if not pav.is_empty():
			print("LAMPADA %d: fondo della scatola %.2f m sopra la superficie sotto, 30 cm davanti (%s)" % [k,
					p.y - 0.15 - (pav.position as Vector3).y, pav.collider])
		print("LAMPADA %d a (%.2f, %.2f, %.2f), fuori %s: contatto %.1f mm, raggi col muro dentro la scatola %d" % [k, p.x,
				p.y, p.z, v, contatto * 1000.0, dentro])
		# dagli occhi
		var davanti := p + v * 2.5
		var giu := st.intersect_ray(PhysicsRayQueryParameters3D.create(davanti + Vector3.UP * 1.0, davanti + Vector3.DOWN * 30.0))
		var occhio := davanti + Vector3.UP * 1.6
		if not giu.is_empty():
			occhio = (giu.position as Vector3) + Vector3.UP * 1.6
		cam.fov = 75.0
		cam.look_at_from_position(occhio, p)
		await _scatto("lampada%d_occhi" % k)
		cam.fov = 40.0
		for vista in [["sinistra", a1 * 0.45 + v * 0.06], ["destra", -a1 * 0.45 + v * 0.06], ["sopra", Vector3.UP * 0.45 + v * 0.08]]:
			var su := Vector3.UP if vista[0] != "sopra" else v
			cam.look_at_from_position(p + (vista[1] as Vector3), p - v * 0.08, su)
			await _scatto("lampada%d_%s" % [k, vista[0]])
		k += 1
	print("FINE")
	get_tree().quit()
