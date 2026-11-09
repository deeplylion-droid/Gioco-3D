extends Node
## Collaudo dei passi lunghi della sala (#147, ambienti-1): le 7 lampade d'emergenza della torre (SalaTorre._emergenza,
## coi 9 raggi sulle sole mesh vicine). La sala della torre da sola, con l'ambiente della sala grande (come
## scatti_torre.gd). Per ogni lampada:
## - dagli occhi: 1,6 m sopra il pavimento sotto un punto 2,5 m davanti alla lampada, guardandola;
## - da vicino, a 45 cm, di taglio lungo il muro da sinistra, da destra e da sopra (campo visivo 40°);
## - il distacco: 25 raggi dal retro della scatola verso il muro (tutte le mesh): il più vicino è il contatto (0 mm
##   = appoggiata), e se il muro entra nella scatola.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##   --script res://tests/run.gd -- res://tests/collaudo/scatti_lampade_emergenza.gd <cartella>

const SCENA := "res://scenes/sala/torre/sala_torre.tscn"

var cartella := "/tmp/scatti_lampade"
## "portone": le lampade nelle posizioni che prendono giocando dal portone (la torre si costruisce nascosta e Posa salta le
## mesh invisibili: posa_prima_dopo.gd), al posto di quelle della torre costruita visibile (F9, morte, Continua)
var portone := false
const POSIZIONI_PORTONE := [Vector3(20.3050, 6.0, -20.5), Vector3(39.92, 1.5, -15.0), Vector3(31.0, -2.5, -4.08),
		Vector3(31.0, -8.0, -25.92), Vector3(20.28, -12.0, -10.0), Vector3(39.92, -16.5, -15.0), Vector3(27.0, 9.0, -25.92)]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	portone = a.has("portone")
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
	add_child(sala)
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
		if portone:
			var luce_vicina: Node3D = null
			for l in luci.get_children():
				if l is OmniLight3D and (l as Node3D).global_position.distance_to(corpo.global_position) < 0.6:
					luce_vicina = l
			var spost: Vector3 = POSIZIONI_PORTONE[k] - corpo.global_position
			corpo.global_position += spost
			if luce_vicina:
				luce_vicina.global_position += spost
			await get_tree().process_frame
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
