extends Node
## Collaudo della girata dello squalo all'inizio verso la porta (lavoro/bambini-squalo-0317, riscontro della 0.3.16:
## "quando si gira mette male una pinna attaccata al braccio, anche il braccio stesso; animalo un po' di più"). Nella
## scena vera (interni), con la camera del giocatore guidata dalla scena: ogni fotogramma dal richiamo di Jilly a dopo la
## porta in <cartella>/fotogrammi, e per ogni fotogramma in <cartella>/misure.csv:
## - le ossa delle braccia nel mondo (per gli scatti: velocità e accelerazione si fanno dopo, da qui);
## - quanto entra nei muri la pelle vera (la mesh con la posa di adesso, MeshInstance3D.bake_mesh_from_current_skeleton_pose):
##   un raggio della fisica (solo il mondo) dal petto a ogni vertice più su di 25 cm dal pavimento; se trova qualcosa
##   prima, il vertice è oltre un muro, di tanto quanto resta del raggio.
## Con "lato" la camera non è quella del giocatore ma una ferma nel corridoio, a 1,6 m d'altezza, che guarda il petto
## dello squalo da sud-ovest (per vedere il braccio e la pinna di fianco): gli stessi fotogrammi.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/collaudo_squalo_girata.gd <cartella> [lato]

const LEVEL := "res://scenes/interni/interni.tscn"
const OSSA := ["spina", "petto", "testa", "braccio.L", "avambraccio.L", "mano.L", "braccio.R", "avambraccio.R", "mano.R"]

var cartella := ""
var lato := false


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	lato = a.size() > 2 and a[2] == "lato"
	DirAccess.make_dir_recursive_absolute(cartella.path_join("fotogrammi"))
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 30:
		await get_tree().process_frame
	var level := get_tree().current_scene as Node3D
	var p := GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var s := level.get_node("Gioco/RisveglioSqualo") as RisveglioSqualo
	var R: float = s.tempi.get("richiamo", 5.4)
	var G: float = s.tempi.get("giro", 8.57)
	var porta_t: float = s.tempi.get("porta", 10.9)
	print("tempi: richiamo %.2f, giro %.2f, esita %.2f, porta %.2f" % [R, G, float(s.tempi.get("esita", 0.0)), porta_t])
	level.call(&"fai_risveglio", p, true)
	var cam_lato: Camera3D
	var csv := FileAccess.open(cartella.path_join("misure.csv"), FileAccess.WRITE)
	var testa := "n,t"
	for o in OSSA:
		testa += ",%s_x,%s_y,%s_z" % [o, o, o]
	csv.store_line(testa + ",dentro_muro_m,dentro_muro_dove,vertici_provati")
	var spazio: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var t := 0.0
	var n := 0
	var peggio := 0.0
	var peggio_quando := ""
	var pavimento := -INF
	while t < porta_t + 0.9:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t < R - 0.2 or s.squalo == null:
			continue
		if pavimento == -INF:
			var sp: Vector3 = s.call(&"_bone_mondo", "spina")
			var q := PhysicsRayQueryParameters3D.create(sp, sp + Vector3.DOWN * 4.0, Layers.WORLD)
			var h: Dictionary = spazio.intersect_ray(q)
			pavimento = (h.position as Vector3).y if not h.is_empty() else -99.0
			print("pavimento a y %.2f" % pavimento)
		if lato and cam_lato == null:
			cam_lato = Camera3D.new()
			level.add_child(cam_lato)
			cam_lato.fov = 60.0
			cam_lato.make_current()
		if cam_lato:
			var petto: Vector3 = s.call(&"_bone_mondo", "petto")
			var dove := Vector3(petto.x - 2.2, pavimento + 1.6, -0.35)
			cam_lato.global_transform = Transform3D(Basis.looking_at(petto - dove, Vector3.UP), dove)
		# la pelle nella posa di adesso, e i raggi dal petto
		var da: Vector3 = s.call(&"_bone_mondo", "petto")
		var dentro := 0.0
		var dentro_dove := ""
		var provati := 0
		for mi in s.squalo.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.skin == null or not m.visible:
				continue
			var cotta := m.bake_mesh_from_current_skeleton_pose()
			for sup in cotta.get_surface_count():
				var v: PackedVector3Array = cotta.surface_get_arrays(sup)[Mesh.ARRAY_VERTEX]
				for k in range(0, v.size(), 3):
					var w := m.global_transform * v[k]
					if w.y < pavimento + 0.25:
						continue
					provati += 1
					var q := PhysicsRayQueryParameters3D.create(da, w, Layers.WORLD)
					var h: Dictionary = spazio.intersect_ray(q)
					if h.is_empty():
						continue
					var d := (h.position as Vector3).distance_to(w)
					if d > dentro:
						dentro = d
						dentro_dove = "%s (%.2f, %.2f, %.2f) in %s" % [m.name, w.x, w.y, w.z, (h.collider as Node).name]
		if dentro > peggio:
			peggio = dentro
			peggio_quando = "%.2f s: %s" % [t, dentro_dove]
		var riga := "%d,%.4f" % [n, t]
		for o in OSSA:
			var b: Vector3 = s.call(&"_bone_mondo", o)
			riga += ",%.4f,%.4f,%.4f" % [b.x, b.y, b.z]
		csv.store_line(riga + ",%.4f,%s,%d" % [dentro, dentro_dove.replace(",", ";"), provati])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("fotogrammi/%05d.jpg" % n), 0.88)
		n += 1
	csv.close()
	print("PEGGIO DENTRO I MURI: %.3f m a %s" % [peggio, peggio_quando])
	print("FINE squalo, %d fotogrammi" % n)
	get_tree().quit()
