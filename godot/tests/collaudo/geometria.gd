extends Node
## Collaudo del posizionamento (squadra collaudo): scrive la geometria visibile di una scena in uno stato del
## capitolo, per misurare fuori da Godot le distanze vere fra le mesh (tools/collaudo/distanze.py), e le celle
## dove si cammina (per il giro dagli occhi del giocatore, giro.gd).
## A differenza di tests/controllo_posizionamento.gd conta anche le istanze dei MultiMesh (i dettagli della
## sala, DettagliSala, con 6 o più copie diventano MultiMesh), gli oggetti grandi e quelli che compaiono dopo
## (vedi stati.gd).
## Con --headless i MultiMesh non tengono le trasformazioni delle istanze (il renderer finto le butta): quelle dei
## dettagli della sala si rifanno da posizionamento.json come fa DettagliSala, gli altri MultiMesh (lampadine del
## portone, lamelle della serranda, medusine) si saltano e si guardano negli scatti.
## Uso (sotto il render.lock):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/geometria.gd \
##       <scena.tscn> <stato> <file di uscita senza estensione> [nodi di primo livello da togliere, separati da virgola]
## Scrive <uscita>.bin (triangoli nel mondo, float32 x 9 per triangolo), <uscita>.json (le mesh: nodo, box,
## dove stanno i loro triangoli, visibile o no) e <uscita>_celle.json (le celle da 50 cm raggiungibili a piedi
## dai checkpoint, con l'ordine del checkpoint più vicino).

const STATI := preload("res://tests/collaudo/stati.gd")
const PASSO := 0.5

var scena := ""
var stato := "inizio"
var uscita := ""
var togli := PackedStringArray()
var livello: Node
var _spazio: PhysicsDirectSpaceState3D


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var a := OS.get_cmdline_user_args()
	scena = a[1]
	stato = a[2]
	uscita = a[3]
	if a.size() > 4 and a[4] != "":
		togli = a[4].split(",")
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	seed(20261022)
	livello = (load(scena) as PackedScene).instantiate()
	for percorso in togli:
		var n := livello.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	# le stanze della Risalita (fiume e infermeria) subito, come in giro.gd: senza, si caricano solo col giocatore
	# vicino alla sala pompe
	if OS.get_environment("COLLAUDO_RISALITA") == "1":
		Engine.set_meta(&"risalita_subito", true)
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().physics_frame
	get_tree().paused = false
	var p = GameState.player
	for i in 900:
		if p == null or not is_instance_valid(p) or p.input_enabled:
			break
		await get_tree().physics_frame
	# i checkpoint prima di cambiare stato (le porte aperte non spostano i punti di ripartenza)
	var cps := []
	for cp in livello.find_children("*", "Checkpoint", true, false):
		var sp = cp.get(&"spawn_point")
		var t: Transform3D = cp.call(&"get_spawn_transform") if cp.has_method(&"get_spawn_transform") else (cp as Node3D).global_transform
		cps.append({"nodo": String(livello.get_path_to(cp)), "ordine": int(cp.get(&"order")), "buio": bool(cp.get(&"solo_al_buio")),
				"pos": _v(t.origin), "verso": _v(-t.basis.z), "area": _v((cp as Node3D).global_position), "spawn": sp != null})
	STATI.applica(livello, stato)
	for i in 240:
		await get_tree().physics_frame
	livello.process_mode = Node.PROCESS_MODE_DISABLED
	for c in livello.find_children("*", "CollisionObject3D", true, false):
		(c as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		await get_tree().physics_frame
	_spazio = (livello as Node3D).get_world_3d().direct_space_state
	_scrivi_mesh()
	var celle := _celle(cps)
	var f := FileAccess.open(uscita + "_celle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"scena": scena, "stato": stato, "checkpoint": cps, "celle": celle}))
	f.close()
	print("COLLAUDO: %d celle raggiungibili" % celle.size())
	get_tree().quit()


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _visibile(n: Node) -> bool:
	while n and n != livello.get_parent():
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


## Le mesh da non contare: il giocatore, le creature e i corpi che si muovono, le gocce in volo.
func _esclusi() -> Array:
	var esclusi := []
	for n in livello.find_children("*", "CharacterBody3D", true, false) + livello.find_children("*", "RigidBody3D", true, false):
		esclusi.append(n)
	for n in get_tree().get_nodes_in_group(&"bambini"):
		esclusi.append(n)
	# le gocce in volo: quelle dal soffitto (Gocce) e quelle dalle dita della medusa (WaterDripEmitter), come nel
	# controllo della CI
	for classe in ["Gocce", "WaterDripEmitter"]:
		for n in livello.find_children("*", classe, true, false):
			esclusi.append(n)
	return esclusi


func _scrivi_mesh() -> void:
	var esclusi := _esclusi()
	var bin := FileAccess.open(uscita + ".bin", FileAccess.WRITE)
	var voci := []
	var tri := 0
	for n in livello.find_children("*", "GeometryInstance3D", true, false):
		if not (n is MeshInstance3D or n is MultiMeshInstance3D):
			continue
		if esclusi.any(func(e): return (e as Node).is_ancestor_of(n)):
			continue
		var g := n as GeometryInstance3D
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var percorso := String(livello.get_path_to(g))
		# le superfici dell'acqua: un pezzo del percorso che comincia con "acqua", ma non gli acquari dell'enigma
		# (nel controllo della CI "/acqua" prende anche "/AcquarioGiallo": gli acquari restano fuori)
		var acqua := String(g.name).to_lower() in ["superficie", "surface"]
		for pezzo in percorso.to_lower().split("/"):
			if pezzo.begins_with("acqua") and not pezzo.begins_with("acquari"):
				acqua = true
		var vis := _visibile(g)
		var trasformazioni := []
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			trasformazioni.append(g.global_transform)
		else:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null:
				continue
			mesh = mm.mesh
			# chi crea il MultiMesh può lasciare le trasformazioni nel meta "trasformazioni", del nodo o della risorsa
			var locali: Array = g.get_meta(&"trasformazioni", mm.get_meta(&"trasformazioni", []))
			if locali.size() != mm.instance_count:
				locali = _istanze_dettagli(g as MultiMeshInstance3D)
			if locali.is_empty():
				print("COLLAUDO: MultiMesh saltato (istanze non leggibili senza renderer): ", percorso)
				continue
			for t in locali:
				trasformazioni.append(g.global_transform * (t as Transform3D))
		if mesh == null:
			continue
		var facce := mesh.get_faces()
		if facce.is_empty():
			continue
		for i in trasformazioni.size():
			var t: Transform3D = trasformazioni[i]
			var w: PackedVector3Array = t * facce
			var box := t * mesh.get_aabb()
			var buf := PackedFloat32Array()
			buf.resize(w.size() * 3)
			for k in w.size():
				buf[k * 3] = w[k].x
				buf[k * 3 + 1] = w[k].y
				buf[k * 3 + 2] = w[k].z
			bin.store_buffer(buf.to_byte_array())
			voci.append({"nodo": percorso, "istanza": i if g is MultiMeshInstance3D else -1, "visibile": vis, "acqua": acqua,
					"box": _v(box.position) + _v(box.size), "da": tri, "n": w.size() / 3, "classe": g.get_class(),
					"pos": _v(t.origin)})
			tri += w.size() / 3
	bin.close()
	var f := FileAccess.open(uscita + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"scena": scena, "stato": stato, "mesh": voci}))
	f.close()
	print("COLLAUDO: %d mesh, %d triangoli" % [voci.size(), tri])


var _posti_dettagli := {}


## Le istanze di un MultiMesh di DettagliSala, rifatte da posizionamento.json nello stesso ordine.
func _istanze_dettagli(mmi: MultiMeshInstance3D) -> Array:
	var padre := mmi.get_parent()
	if padre == null or not padre is DettagliSala:
		return []
	var cartella: String = padre.get(&"cartella")
	if not _posti_dettagli.has(cartella):
		var dati = JSON.parse_string(FileAccess.get_file_as_string(cartella.path_join("posizionamento.json")))
		_posti_dettagli[cartella] = dati.posti if dati is Dictionary else []
	var out := []
	for p in _posti_dettagli[cartella]:
		if p.nodo == String(mmi.name):
			out.append(padre.call(&"_trasformazione", p))
	if out.size() != mmi.multimesh.instance_count:
		print("COLLAUDO: istanze diverse per ", mmi.name, ": ", out.size(), " invece di ", mmi.multimesh.instance_count)
		return []
	return out


func _raggio(da: Vector3, a: Vector3, maschera: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(da, a, maschera)
	q.hit_back_faces = true
	return _spazio.intersect_ray(q)


## Le celle dove si cammina, raggiungibili dai punti di ripartenza dei checkpoint (gradini fino a 40 cm, un
## cilindro di 30 cm di raggio fra 0,3 e 1 m che non tocca il mondo né i muri invisibili).
func _celle(cps: Array) -> Array:
	var limiti := AABB()
	var primo := true
	for c in livello.find_children("*", "CollisionShape3D", true, false):
		var co := (c as Node).get_parent() as CollisionObject3D
		if co == null or co is Area3D or (co.collision_layer & Layers.WORLD) == 0:
			continue
		var s := (c as CollisionShape3D).shape
		if s == null:
			continue
		var b: AABB = (c as Node3D).global_transform * s.get_debug_mesh().get_aabb()
		if b.size.length() > 400.0:
			continue
		limiti = b if primo else limiti.merge(b)
		primo = false
	var cil := CylinderShape3D.new()
	cil.radius = 0.3
	cil.height = 0.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cil
	q.collision_mask = Layers.WORLD | Layers.BARRIERS
	var x0 := floorf(limiti.position.x / PASSO) * PASSO
	var z0 := floorf(limiti.position.z / PASSO) * PASSO
	var nx := int((limiti.end.x - x0) / PASSO) + 1
	var nz := int((limiti.end.z - z0) / PASSO) + 1
	var colonne := {}
	for ix in nx:
		for iz in nz:
			var x := x0 + ix * PASSO
			var zz := z0 + iz * PASSO
			var y := limiti.end.y + 1.0
			var piani := []
			for k in 10:
				var h := _raggio(Vector3(x, y, zz), Vector3(x, limiti.position.y - 1.0, zz), Layers.WORLD)
				if h.is_empty():
					break
				if (h.normal as Vector3).y >= 0.7:
					piani.append((h.position as Vector3).y)
				y = (h.position as Vector3).y - 0.05
			if not piani.is_empty():
				colonne[Vector2i(ix, iz)] = piani
	# libera: le gambe non toccano niente e sopra c'è spazio per la testa (1,8 m); il raggio verso l'alto vede anche
	# le collisioni a trimesh da dentro (un muro spesso, dove il cilindro non tocca nessuna superficie)
	var libero := func(c: Vector2i, yy: float) -> bool:
		var centro := Vector3(x0 + c.x * PASSO, yy, z0 + c.y * PASSO)
		q.transform = Transform3D(Basis(), centro + Vector3(0, 0.65, 0))
		if not _spazio.intersect_shape(q, 1).is_empty():
			return false
		return _raggio(centro + Vector3(0, 0.1, 0), centro + Vector3(0, 1.8, 0), Layers.WORLD).is_empty()
	var raggiunte := {}
	var coda := []
	for cp in cps:
		var s := Vector3(cp.pos[0], cp.pos[1], cp.pos[2])
		var c := Vector2i(roundi((s.x - x0) / PASSO), roundi((s.z - z0) / PASSO))
		if not colonne.has(c):
			continue
		var piani: Array = colonne[c]
		for i in piani.size():
			if absf(float(piani[i]) - s.y) < 0.6 and libero.call(c, float(piani[i])):
				var k := Vector3i(c.x, i, c.y)
				if not raggiunte.has(k):
					raggiunte[k] = int(cp.ordine)
					coda.append(k)
	while not coda.is_empty():
		var k: Vector3i = coda.pop_front()
		var y: float = colonne[Vector2i(k.x, k.z)][k.y]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := Vector2i(k.x + d.x, k.z + d.y)
			if not colonne.has(c):
				continue
			var piani: Array = colonne[c]
			for i in piani.size():
				var y2 := float(piani[i])
				if absf(y2 - y) > 0.4:
					continue
				var k2 := Vector3i(c.x, i, c.y)
				if raggiunte.has(k2) or not libero.call(c, y2):
					continue
				raggiunte[k2] = raggiunte[k]
				coda.append(k2)
	var out := []
	for k in raggiunte:
		out.append([snappedf(x0 + k.x * PASSO, 0.01), snappedf(float(colonne[Vector2i(k.x, k.z)][k.y]), 0.01), snappedf(z0 + k.z * PASSO, 0.01), raggiunte[k]])
	return out
