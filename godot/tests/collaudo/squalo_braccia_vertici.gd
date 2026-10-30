extends Node3D
## Lo spazio fra le braccia e il muso dello squalo misurato sui vertici della pelle, non sulle ossa: il GLB caricato a
## runtime (così si confrontano due versioni), a ogni fotogramma dell'animazione (1/30 s) dal richiamo alla fine, la
## pelle nella posa di adesso (MeshInstance3D.bake_mesh_from_current_skeleton_pose, dopo che lo scheletro si è
## aggiornato). Ogni vertice va all'osso col peso più grande: le braccia sono quelli di avambraccio e mano (con pinna e
## artigli), il muso quelli di bocca, mascella e mento (con denti, gengive e l'interno della bocca). Scrive per ogni
## fotogramma la distanza più piccola fra un vertice delle braccia e uno del muso (oltre [constant OLTRE] non conta) e
## quale braccio. Col renderer vero: senza schermo la pelle non si cuoce.
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/collaudo/squalo_braccia_vertici.gd <glb> <uscita.csv>

const DA := 5.4
const A := 11.8
const CELLA := 0.06
## Le distanze oltre questa si scrivono così (la ricerca guarda solo le celle vicine).
const OLTRE := 0.12
const MUSO := ["bocca", "mascella", "mento_punta"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var stato := GLTFState.new()
	if doc.append_from_file(a[1], stato) != OK:
		printerr("non carico ", a[1])
		get_tree().quit(1)
		return
	var radice := doc.generate_scene(stato) as Node3D
	add_child(radice)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1, 6)
	for i in 3:
		await get_tree().process_frame
	var ap := radice.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := radice.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anim: StringName = ap.get_animation_list()[0]
	for n in ap.get_animation_list():
		if String(n).contains("risveglio"):
			anim = n
	ap.play(anim)
	ap.pause()
	# per ogni mesh con la pelle e ogni superficie: di ogni vertice la parte (0 niente, 1 braccio sinistro, 2 destro, 3 muso)
	var mesh_pelle: Array[MeshInstance3D] = []
	var parte := {}
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		mesh_pelle.append(m)
		var per_sup := []
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var ossa: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesi: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var k := ossa.size() / maxi(nv, 1)
			var pv := PackedByteArray()
			pv.resize(nv)
			for v in nv:
				var meglio := 0
				for j in k:
					if pesi[v * k + j] > pesi[v * k + meglio]:
						meglio = j
				var bind := ossa[v * k + meglio]
				var nome := String(m.skin.get_bind_name(bind))
				if nome == "":
					nome = sk.get_bone_name(m.skin.get_bind_bone(bind))
				var p := 0
				if nome.begins_with("avambraccio") or nome.begins_with("mano"):
					p = 1 if nome.ends_with(".L") else 2
				elif nome in MUSO:
					p = 3
				pv[v] = p
			per_sup.append(pv)
		parte[m] = per_sup
	var csv := FileAccess.open(a[2], FileAccess.WRITE)
	csv.store_line("t,distanza_m,braccio,vertici_braccia,vertici_muso")
	var peggio := INF
	var peggio_quando := ""
	var k := int(DA * 30.0)
	while k <= int(A * 30.0):
		var t := k / 30.0
		ap.seek(t, true)
		for i in 2:
			await get_tree().process_frame
		var griglia := {}
		var braccia: Array = []
		var n_muso := 0
		for m in mesh_pelle:
			var cotta := m.bake_mesh_from_current_skeleton_pose()
			if cotta == null:
				continue
			for s in cotta.get_surface_count():
				var v: PackedVector3Array = cotta.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				var pv: PackedByteArray = parte[m][s]
				for i in v.size():
					if pv[i] == 0:
						continue
					var w := m.transform * v[i]
					if pv[i] == 3:
						var c := Vector3i((w / CELLA).floor())
						if not griglia.has(c):
							griglia[c] = PackedVector3Array()
						(griglia[c] as PackedVector3Array).append(w)
						n_muso += 1
					else:
						braccia.append([w, pv[i]])
		var d_min := OLTRE
		var quale := "-"
		for b in braccia:
			var w: Vector3 = b[0]
			var c0 := Vector3i((w / CELLA).floor())
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					for dz in range(-2, 3):
						var cella: Variant = griglia.get(c0 + Vector3i(dx, dy, dz))
						if cella == null:
							continue
						for q in cella as PackedVector3Array:
							var d := w.distance_to(q)
							if d < d_min:
								d_min = d
								quale = "sinistro" if int(b[1]) == 1 else "destro"
		csv.store_line("%.3f,%.4f,%s,%d,%d" % [t, d_min, quale, braccia.size(), n_muso])
		if d_min < peggio:
			peggio = d_min
			peggio_quando = "%.2f s, braccio %s" % [t, quale]
		k += 1
	csv.close()
	print("PIÙ VICINO: %.3f m a %s" % [peggio, peggio_quando])
	print("FINE vertici ", a[2])
	get_tree().quit()
