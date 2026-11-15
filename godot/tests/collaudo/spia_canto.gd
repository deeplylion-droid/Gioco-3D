extends Node
## Collaudo 0.4.0 (il canto di lei): ogni fotogramma guarda i lettori dell'addon audio (riserve 2D e 3D) che suonano
## un canto di lei (lei_canto_prima_*, lei_tunnel_canto*). Per ogni frase: quando parte, il file, dove è il giocatore;
## quando finisce: se è arrivata alla fine del file (naturale) o è stata fermata prima, e allora com'era il volume
## (dB del lettore, e per il 3D anche quello che arriva al giocatore, con la distanza) 1 s, 0,5 s, 0,25 s e
## un fotogramma prima. Fermata prima con il volume che arriva al giocatore sopra -30 dB nell'ultimo fotogramma:
## TRONCATA (la regola: il canto non si tronca mai, solo alla presa). Stampa SC:. Con forza_riproduzione i lettori
## suonano davvero anche col driver Dummy (la posizione avanza).
## Uso: var spia := preload("res://tests/collaudo/spia_canto.gd").new(); add_child(spia); ...; spia.riassunto()

var voci := {}          # id lettore -> {file, partito, t0, storia: [[t, db, db_eff, tono, pos]], len}
var finite: Array = []
var troncate := 0
var t := 0.0
var _t0 := Time.get_ticks_msec()
var etichetta := ""
var stampa := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	AudioLoop.forza_riproduzione(true)


static func _canto(p: Node) -> bool:
	var s = p.get(&"stream")
	return s is AudioStream and (s.resource_path.contains("canto_prima") or s.resource_path.contains("tunnel_canto"))


static func _nome(p: Node) -> String:
	var s = p.get(&"stream") as AudioStream
	if s and s.resource_path != "":
		return s.resource_path.get_file()
	return "canto_tunnel(senza percorso)" if p.has_meta(&"_spia_tunnel") else "senza percorso"


func _ascoltatore() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.global_position
	var g := GameState.player
	return g.global_position if g and is_instance_valid(g) else Vector3.ZERO


func _db_eff(p: Node) -> float:
	var db := float(p.get(&"volume_db"))
	if p is AudioStreamPlayer3D:
		var p3 := p as AudioStreamPlayer3D
		var d := maxf(p3.global_position.distance_to(_ascoltatore()), 0.01)
		if d > p3.max_distance:
			return -80.0
		db += linear_to_db(minf(p3.unit_size / d, 1.0)) if p3.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE else 0.0
	return db


func _process(delta: float) -> void:
	t = (Time.get_ticks_msec() - _t0) / 1000.0
	var a := get_node_or_null(^"/root/Audio")
	if a == null:
		return
	var lettori: Array = []
	for nome in [&"_pool_3d", &"_pool_2d"]:
		var pool = a.get(nome)
		if pool is Array:
			for x in pool:
				if is_instance_valid(x) and _canto(x):
					lettori.append(x)
	# i canti che l'addon tiene per nome (le frasi del tunnel hanno lo stream senza percorso)
	var cp = a.get(&"canto_prima")
	if cp:
		for k in [&"lon", &"vic"]:
			var x = cp.get(k)
			# (solo se suona ancora la frase partita da lì: i lettori della riserva si riprendono per altri suoni)
			if x is Node and is_instance_valid(x) and not lettori.has(x) and float(x.get_meta(&"partito", -2.0)) == float(cp.get(&"partito")):
				lettori.append(x)
	for at in a.get(&"_attivi"):
		if at is Object and &"canto" in at:
			var x = at.get(&"canto")
			if x is Node and is_instance_valid(x) and not lettori.has(x) and float(x.get_meta(&"partito", -2.0)) == float(at.get(&"canto_partito")):
				x.set_meta(&"_spia_tunnel", true)
				lettori.append(x)
	# i lettori già seguiti restano seguiti finché suona la stessa frase (dopo lo spegnimento chi la comanda li lascia)
	for id in voci.keys():
		var o := instance_from_id(id)
		if o is Node and is_instance_valid(o) and not lettori.has(o):
			lettori.append(o)
	var visti := {}
	for p in lettori:
		if not is_instance_valid(p):
			continue
		var id: int = p.get_instance_id()
		var suona: bool = p.get(&"playing")
		var partito := float(p.get_meta(&"partito", -1.0))
		if voci.has(id):
			var v: Dictionary = voci[id]
			if not suona or v["partito"] != partito or v["file"] != _nome(p):
				_fine(id, v)
		if suona and not voci.has(id):
			voci[id] = {"file": _nome(p), "partito": partito, "t0": t,
				"storia": [], "len": (p.get(&"stream") as AudioStream).get_length(), "3d": p is AudioStreamPlayer3D}
			if stampa:
				print("SC: %s %.2f s parte %s (%s), giocatore %s" % [etichetta, t, voci[id]["file"], "3D" if p is AudioStreamPlayer3D else "2D", _gpos()])
		if suona:
			visti[id] = true
			var st: Array = voci[id]["storia"]
			st.append([t, float(p.get(&"volume_db")), _db_eff(p), float(p.get(&"pitch_scale")), float(p.call(&"get_playback_position"))])
			if st.size() > 200:
				st.pop_front()
	for id in voci.keys():
		if not visti.has(id) and voci.has(id):
			_fine(id, voci[id])


func _gpos() -> String:
	var g := GameState.player
	return str(g.global_position.snappedf(0.1)) if g and is_instance_valid(g) else "-"


func _a(st: Array, quanto: float) -> String:
	if st.is_empty():
		return "-"
	var fine: float = st[-1][0]
	for i in range(st.size() - 1, -1, -1):
		if fine - float(st[i][0]) >= quanto:
			return "%.0f/%.0f" % [st[i][1], st[i][2]]
	return "%.0f/%.0f" % [st[0][1], st[0][2]]


func _fine(id: int, v: Dictionary) -> void:
	voci.erase(id)
	var st: Array = v["storia"]
	if st.is_empty():
		return
	var ultimo: Array = st[-1]
	var naturale: bool = float(ultimo[4]) >= float(v["len"]) - 0.12
	var forte := float(ultimo[2]) > -30.0
	var esito := "naturale" if naturale else ("TRONCATA" if forte else "spenta")
	if esito == "TRONCATA":
		troncate += 1
	var r := {"file": v["file"], "t0": v["t0"], "t1": t, "esito": esito, "tono_fine": ultimo[3]}
	finite.append(r)
	if stampa:
		print("SC: %s %.2f s finisce %s dopo %.2f s di %.2f: %s; dB lettore/al giocatore a -1 s %s, -0,5 s %s, -0,25 s %s, ultimo %.0f/%.0f, tono %.2f, giocatore %s" % [
			etichetta, t, v["file"], float(ultimo[4]), float(v["len"]), esito, _a(st, 1.0), _a(st, 0.5), _a(st, 0.25),
			ultimo[1], ultimo[2], ultimo[3], _gpos()])


## Il volume più alto che arriva adesso al giocatore da un canto (dB, -80 se niente), e il file.
func adesso() -> Array:
	var meglio := -80.0
	var file := ""
	for id in voci:
		var st: Array = voci[id]["storia"]
		if not st.is_empty() and float(st[-1][2]) > meglio:
			meglio = float(st[-1][2])
			file = voci[id]["file"]
	return [meglio, file]


func riassunto() -> void:
	var n := {}
	for r in finite:
		n[r["esito"]] = int(n.get(r["esito"], 0)) + 1
	print("SC: %s riassunto: frasi finite %d %s, troncate %d" % [etichetta, finite.size(), n, troncate])
