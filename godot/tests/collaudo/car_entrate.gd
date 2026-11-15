extends Node
## Collaudo 0.3.22: la schermata di caricamento con Jilly in tutte le entrate vere, una dopo l'altra nello stesso
## processo: Nuova partita (dopo lo spot), morte e ripartenza, ritorno al titolo e Continua, le partenze F9, di nuovo il
## titolo e Nuova partita (con la domanda). Per ogni caricamento: se la schermata c'è, se il video va e gira in ciclo
## senza salti, se la percentuale e la barra avanzano senza tornare indietro, se arrivati il video è liberato; dopo ogni
## arrivo la memoria (RSS e statica), i nodi orfani e i VideoStreamPlayer vivi (CAR:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/car_entrate.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"
var _rec := {}
var _nome := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _rss() -> int:
	# (/proc dice lunghezza 0: get_as_text torna vuoto, si legge riga per riga)
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var r := f.get_line()
		if r.begins_with("VmRSS:"):
			return r.split(" ", false)[1].to_int() / 1024
	return -1


func _process(_d: float) -> void:
	var s := get_tree().current_scene
	if s == null or String(s.name) != "Caricamento" or _nome == "":
		return
	var r: Dictionary = _rec
	r["visto"] = true
	r["fotogrammi"] = r.get("fotogrammi", 0) + 1
	var v := s.find_child("VideoJilly", true, false) as VideoStreamPlayer
	if v:
		r["video"] = true
		var p := v.stream_position
		var prima: float = r.get("pos", -1.0)
		if prima >= 0.0:
			if p < prima - 1.0:
				r["cicli"] = r.get("cicli", 0) + 1
			elif p - prima > 0.5:
				r["salti"] = r.get("salti", 0) + 1
		r["pos"] = p
		r["pos_max"] = maxf(r.get("pos_max", 0.0), p)
		if not v.is_playing():
			r["fermo"] = r.get("fermo", 0) + 1
	var a: float = s.get(&"avanzamento")
	if a < r.get("av", 0.0) - 0.001:
		r["indietro"] = r.get("indietro", 0) + 1
	r["av"] = a
	r["av_max"] = maxf(r.get("av_max", 0.0), a)
	var t0: int = r.get("t0", 0)
	if t0 == 0:
		r["t0"] = Time.get_ticks_msec()
	r["durata"] = (Time.get_ticks_msec() - r["t0"]) / 1000.0


func _arrivati(entro_s: float) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		if sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" \
				and get_tree().get_first_node_in_group(&"player") != null and not GameState.is_dying:
			return true
		await _frames(5)
	return false


func _al_titolo(entro_s: float) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		if sc and String(sc.name) == "MenuPrincipale":
			return true
		await _frames(5)
	return false


func _inizia(nome: String) -> void:
	_rec = {}
	_nome = nome


func _chiudi(arrivato: bool) -> void:
	await _frames(30)
	var r := _rec
	var vivi := get_tree().root.find_children("*", "VideoStreamPlayer", true, false).size()
	var jilly := get_tree().root.find_children("VideoJilly", "", true, false).size()
	print("CAR: %s: arrivato %s, schermata %s (%.1f s, %d fotogrammi), video %s, posizione max %.2f s, cicli %d, salti %d, fermo %d; avanzamento max %.0f%%, indietro %d; poi VideoJilly vivi %d, VideoStreamPlayer vivi %d, orfani %d, RSS %d MB, statica %d MB" % [
		_nome, arrivato, r.get("visto", false), r.get("durata", 0.0), r.get("fotogrammi", 0), r.get("video", false),
		r.get("pos_max", 0.0), r.get("cicli", 0), r.get("salti", 0), r.get("fermo", 0), r.get("av_max", 0.0) * 100.0,
		r.get("indietro", 0), jilly, vivi, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), _rss(),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	_nome = ""


func _titolo() -> void:
	Game.return_to_title()
	var ok := await _al_titolo(300.0)
	await _frames(60)
	print("CAR: al titolo %s, RSS %d MB, orfani %d" % [ok, _rss(), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(60)
	print("CAR: titolo, RSS %d MB" % _rss())
	# 1. Nuova partita: lo spot, poi la schermata
	_inizia("nuova partita")
	get_tree().current_scene.call(&"nuova_partita")
	await _frames(120)
	for n in get_tree().root.get_children():
		if n is LettoreSpot:
			n.call(&"_fine")
	await _chiudi(await _arrivati(600.0))
	# 2. morte e ripartenza (la sala si ricarica in due tempi: la schermata c'è?)
	await _frames(120)
	_inizia("ripartenza dopo la morte")
	GameState.kill_player(&"prova")
	await _frames(30)
	await _chiudi(await _arrivati(300.0))
	# 3. al titolo e Continua
	for giro in 2:
		await _titolo()
		_inizia("Continua %d" % (giro + 1))
		print("CAR: c'è il salvataggio %s" % GameState.has_save())
		get_tree().current_scene.call(&"continua")
		await _chiudi(await _arrivati(600.0))
	# 4. le partenze F9
	for id in ["torre", "fiume", "tunnel", "inizio"]:
		await _titolo()
		_inizia("F9 %s" % id)
		var ok := false
		if id == "inizio":
			ok = true
			get_tree().current_scene.call(&"_avvia_nuova_partita")
			await _frames(60)
			for n in get_tree().root.get_children():
				if n is LettoreSpot:
					n.call(&"_fine")
		else:
			ok = MenuProva.parti(get_tree(), id)
		print("CAR: partenza %s: %s" % [id, ok])
		await _chiudi(await _arrivati(600.0))
	# 5. di nuovo morte, poi titolo e Nuova partita con la domanda
	_inizia("ripartenza 2")
	GameState.kill_player(&"prova")
	await _frames(30)
	await _chiudi(await _arrivati(300.0))
	await _titolo()
	print("CAR: finito")
	Game.esci(0)
