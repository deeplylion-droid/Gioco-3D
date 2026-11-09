extends Node
## Test: i due lavori lunghi della torre spezzati su più fotogrammi danno lo stesso risultato di prima (fotogrammi
## lunghi di test_attesa_zone, 0.3.23).
## 1. I varchi delle scalette dell'inseguimento (SalaInseguimento._varco_scalette): costruita tutta insieme o a pezzi
##    (_passi_varco_scalette, al più VARCO_FACCE_PER_PASSO facce per passo), le forme di collisione della struttura
##    hanno le stesse facce, nello stesso ordine; e qualche faccia è stata tolta (i pioli e i montanti ci sono).
## 2. Le coordinate di texture del pavimento per la soglia della torre (SALA_GD._uv_pavimento): calcolate tutte
##    insieme o a pezzi (prepara_uv_pavimento, con pochissimi ms per fotogramma, quindi in più fotogrammi) sono uguali.
## 3. Alla ripartenza (tutta insieme) i varchi vengono dalla cache (SalaInseguimento._varco_cache) e sono gli stessi.
## 4. I raggi delle lampade d'emergenza della torre con le sole mesh vicine (Posa.mesh_vicine, una volta per lampada)
##    colpiscono lo stesso punto che guardando tutte le mesh dell'albero (passi da 40-70 ms, ora 4-8 ms).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_torre_pezzi_uguali.gd

const INSEGUIMENTO := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const SALA := "res://scenes/sala_principale.tscn"
const SALA_GD := preload("res://scripts/game/sala_principale.gd")

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", cosa)
	else:
		_ko += 1
		print("  KO    ", cosa)


## Le facce delle forme di collisione della struttura (in ordine di albero).
static func _facce_struttura(ins: Node) -> Array:
	var out: Array = []
	var glb := ins.get_node_or_null(^"InseguimentoStruttura")
	if glb == null:
		return out
	for sb in glb.find_children("*", "StaticBody3D", true, false):
		for cs in sb.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
				out.append([str(glb.get_path_to(cs)), ((cs as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()])
	return out


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("1. Varchi delle scalette")
	var scena := load(INSEGUIMENTO) as PackedScene
	SalaInseguimento._varco_cache.clear()
	var tutta := scena.instantiate()
	tutta.set(&"crea_luci", false)
	add_child(tutta)
	await get_tree().process_frame
	var a := _facce_struttura(tutta)
	# (senza la cache dei varchi: a pezzi si rifanno davvero)
	SalaInseguimento._varco_cache.clear()
	var pezzi := scena.instantiate()
	pezzi.set(&"crea_luci", false)
	pezzi.set(&"costruzione_a_pezzi", true)
	add_child(pezzi)
	await pezzi.call(&"costruisci_a_pezzi", 4.0)
	var b := _facce_struttura(pezzi)
	var uguali := a.size() == b.size() and a.size() > 0
	var facce_tot := 0
	for i in mini(a.size(), b.size()):
		uguali = uguali and a[i][0] == b[i][0] and a[i][1] == b[i][1]
		facce_tot += (a[i][1] as PackedVector3Array).size() / 3
	check(uguali, "a pezzi le %d forme della struttura hanno le stesse facce di quando si costruisce tutta insieme (%d facce)" % [a.size(), facce_tot])
	var originali := 0
	var glb := load(SalaInseguimento.DIR + "inseguimento_struttura.glb") as PackedScene
	if glb:
		var g := glb.instantiate()
		for sb in g.find_children("*", "StaticBody3D", true, false):
			for cs in sb.get_children():
				if cs is CollisionShape3D and (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
					originali += ((cs as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size() / 3
		g.free()
		check(originali > facce_tot, "i varchi tolgono qualche faccia (le scalette): %d -> %d" % [originali, facce_tot])
	# una ripartenza: la torre tutta insieme, coi varchi presi dalla cache
	var t_r := Time.get_ticks_usec()
	var terza := scena.instantiate()
	terza.set(&"crea_luci", false)
	add_child(terza)
	var ms_r := (Time.get_ticks_usec() - t_r) / 1000.0
	var c := _facce_struttura(terza)
	var uguali_c := c.size() == a.size()
	for i in mini(a.size(), c.size()):
		uguali_c = uguali_c and a[i][1] == c[i][1]
	check(uguali_c, "alla ripartenza i varchi presi dalla cache sono gli stessi (inseguimento costruito in %.0f ms)" % ms_r)
	terza.queue_free()
	var passi_lunghi: Array = pezzi.get(&"passi_lunghi")
	check(passi_lunghi.is_empty(), "a pezzi nessun passo oltre 50 ms (%s)" % [passi_lunghi])
	tutta.queue_free()
	pezzi.queue_free()
	await get_tree().process_frame

	print("2. Coordinate di texture della soglia della torre")
	var sala := (load(SALA) as PackedScene).instantiate()
	sala.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(sala)
	var pav := sala.find_child("sala_pavimento", true, false) as MeshInstance3D
	check(pav != null, "il pavimento della sala c'è")
	if pav:
		var punto: Vector2 = SALA_GD.PUNTO_UV_SOGLIA
		SALA_GD._uv_cache.clear()
		var t0 := Time.get_ticks_usec()
		var subito := SALA_GD._uv_pavimento(pav, punto)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		SALA_GD._uv_cache.clear()
		var fotogrammi := [0]
		var conta := func(): fotogrammi[0] += 1
		get_tree().process_frame.connect(conta)
		await SALA_GD.prepara_uv_pavimento(pav, punto, 0.5)
		get_tree().process_frame.disconnect(conta)
		var a_pezzi: Array = SALA_GD._uv_pavimento(pav, punto)
		# (il materiale si legge al momento: la sala intanto ha messo il pavimento bagnato)
		subito[3] = pav.get_active_material(0) if subito.size() > 3 else null
		if str(subito) != str(a_pezzi):
			print("    tutta insieme: %s\n    a pezzi:       %s" % [str(subito), str(a_pezzi)])
		check(subito.size() == 5 and str(subito) == str(a_pezzi),
				"a pezzi (%d fotogrammi) la mappa è la stessa di tutta insieme (%.1f ms): %s" % [fotogrammi[0], ms, str(a_pezzi.slice(0, 3))])
		check(fotogrammi[0] > 1, "a pezzi il calcolo si divide davvero su più fotogrammi (%d)" % fotogrammi[0])
		var t1 := Time.get_ticks_usec()
		SALA_GD._uv_pavimento(pav, punto)
		var ms_cache := (Time.get_ticks_usec() - t1) / 1000.0
		check(ms_cache < 1.0, "dopo, presa dalla cache costa poco (%.2f ms)" % ms_cache)
	sala.queue_free()
	await get_tree().process_frame

	print("4. Le lampade d'emergenza della torre: i raggi con le mesh vicine")
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	torre.set(&"costruzione_a_pezzi", true)
	add_child(torre)
	await torre.call(&"costruisci_a_pezzi", 50.0)
	var raggi := 0
	var diversi := 0
	var luci := torre.get_node_or_null(^"Luci")
	for figlio in (luci.get_children() if luci else []):
		var corpo := figlio as MeshInstance3D
		if corpo == null or not corpo.mesh is BoxMesh:
			continue
		# (gli stessi 9 raggi di SalaTorre._emergenza, nei quattro versi)
		for v: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var a1 := v.cross(Vector3.UP).normalized()
			var a2 := v.cross(a1).normalized()
			var p0 := corpo.global_position
			var zona := AABB(p0, Vector3.ZERO)
			for i in [-1, 1]:
				for j in [-1, 1]:
					var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
					zona = zona.expand(p0 + o + v * 0.3).expand(p0 + o - v * Posa.PORTATA)
			var vicine := Posa.mesh_vicine(corpo, zona)
			for i in [-1, 0, 1]:
				for j in [-1, 0, 1]:
					var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
					var tutte := Posa._raggio(corpo, p0 + o + v * 0.3, p0 + o - v * Posa.PORTATA, [])
					var poche := Posa._raggio(corpo, p0 + o + v * 0.3, p0 + o - v * Posa.PORTATA, [], vicine)
					raggi += 1
					if str(tutte) != str(poche):
						diversi += 1
	check(raggi > 100 and diversi == 0, "i raggi delle lampade con le sole mesh vicine (Posa.mesh_vicine) colpiscono lo stesso punto (%d raggi, %d diversi)" % [raggi, diversi])
	check(float(torre.get(&"fotogramma_piu_carico_ms")) >= 0.0, "la torre si costruisce a pezzi")
	torre.queue_free()
	await get_tree().process_frame
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
