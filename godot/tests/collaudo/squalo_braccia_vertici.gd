extends Node3D
## Lo spazio fra le braccia e il muso dello squalo misurato sui vertici della pelle, non sulle ossa: il GLB caricato a
## runtime (così si confrontano due versioni), a ogni fotogramma dell'animazione (1/30 s) dal richiamo alla fine, la
## pelle nella posa di adesso, deformata qui come nello shader (pesi × posa dell'osso × posa di riposo nella pelle:
## bake_mesh_from_current_skeleton_pose restituiva la pelle di riposo). Ogni vertice va all'osso col peso più grande: le braccia sono quelli di avambraccio e mano (con pinna e
## artigli), il muso quelli di bocca, mascella e mento (con denti, gengive e l'interno della bocca). Scrive per ogni
## fotogramma la distanza più piccola fra un vertice delle braccia e uno del muso (oltre [constant OLTRE] non conta) e
## quale braccio.
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
	# per ogni mesh con la pelle e ogni superficie, i vertici delle braccia e del muso: posizione di riposo, ossa e pesi
	# (la pelle si deforma qui come nello shader: somma dei pesi per osso × posa di riposo dell'osso nella pelle)
	var punti: Array = []    # [vertice, [ossa dello scheletro], [pesi], parte (1 sinistro, 2 destro, 3 muso)]
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		var bind_osso := PackedInt32Array()
		var bind_posa: Array[Transform3D] = []
		for b in m.skin.get_bind_count():
			var nome_b := String(m.skin.get_bind_name(b))
			bind_osso.append(sk.find_bone(nome_b) if nome_b != "" else m.skin.get_bind_bone(b))
			bind_posa.append(m.skin.get_bind_pose(b))
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossa: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesi: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nv := vv.size()
			var k := ossa.size() / maxi(nv, 1)
			for v in nv:
				var meglio := 0
				for j in k:
					if pesi[v * k + j] > pesi[v * k + meglio]:
						meglio = j
				var nome := sk.get_bone_name(bind_osso[ossa[v * k + meglio]])
				var p := 0
				if nome.begins_with("avambraccio") or nome.begins_with("mano"):
					p = 1 if nome.ends_with(".L") else 2
				elif nome in MUSO:
					p = 3
				if p == 0:
					continue
				var o := []
				var w := []
				for j in k:
					if pesi[v * k + j] > 0.0:
						o.append(ossa[v * k + j])
						w.append(pesi[v * k + j])
				punti.append([vv[v], o, w, p])
		# (tutte le mesh hanno la stessa pelle)
		punti.append(["bind", bind_osso, bind_posa])
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
		var bind_osso := PackedInt32Array()
		var bind_posa: Array = []
		for pu in punti:
			if pu[0] is String:
				bind_osso = pu[1]
				bind_posa = pu[2]
		var mat: Array[Transform3D] = []
		for b in bind_osso.size():
			mat.append(sk.get_bone_global_pose(bind_osso[b]) * (bind_posa[b] as Transform3D))
		for pu in punti:
			if pu[0] is String:
				continue
			var v0: Vector3 = pu[0]
			var w := Vector3.ZERO
			var o: Array = pu[1]
			var pe: Array = pu[2]
			for j in o.size():
				w += (mat[o[j]] * v0) * float(pe[j])
			w = sk.global_transform * w
			if int(pu[3]) == 3:
				var c := Vector3i((w / CELLA).floor())
				if not griglia.has(c):
					griglia[c] = []
				(griglia[c] as Array).append(w)    # (un Array: un PackedVector3Array si copierebbe e l'aggiunta andrebbe persa)
				n_muso += 1
			else:
				braccia.append([w, pu[3]])
		if OS.get_environment("SONDA_VERTICI") != "" and absf(t - 9.2) < 0.01:
			var cb := Vector3.ZERO
			var nb := 0
			var cm := Vector3.ZERO
			for b in braccia:
				if int(b[1]) == 2:
					cb += b[0]
					nb += 1
			for c in griglia:
				for q in griglia[c] as Array:
					cm += q
			print("SONDA t %.2f: braccio destro, centro dei vertici %s (%d), osso mano.R %s, avambraccio.R %s; muso, centro dei vertici %s (%d), osso bocca %s" % [
					t, cb / maxi(nb, 1), nb, sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mano.R")).origin,
					sk.global_transform * sk.get_bone_global_pose(sk.find_bone("avambraccio.R")).origin, cm / maxi(n_muso, 1), n_muso,
					sk.global_transform * sk.get_bone_global_pose(sk.find_bone("bocca")).origin])
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
						for q in cella as Array:
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
