extends Node
## Collaudo del caricamento della Risalita (fiume e infermeria caricati nel thread dalla sala pompe e scaricati oltre
## la serranda, grafica 23 ottobre). Prova i rischi da fuori, come un giocatore: lo stesso copione gira anche su un
## commit di prima (le stanze sempre caricate), e i risultati si confrontano riga per riga (righe "RIGA").
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://tests/collaudo/risalita_caricamento.gd <scenario> [cartella di uscita]
## Scenari: impronta, corsa, fermo, serranda, morte, costruzione, ripartenze, polaroid, uscita.

const SCENA := "res://scenes/sala_principale.tscn"
const CORSA := 5.8   # m/s, la corsa del giocatore
## Dalla sala pompe (checkpoint 6) alla porta di servizio di C2, giù per la scala e lungo il corridoio fino
## all'ingresso del capannone (celle raggiungibili del collaudo, i pezzi fra le porte a mano).
const ANDATA := [Vector3(0.00, -9.05, 32.00), Vector3(-0.50, -9.05, 33.50), Vector3(-2.00, -9.05, 35.00),
	Vector3(-2.50, -9.05, 36.50), Vector3(-2.50, -9.05, 39.50), Vector3(-3.00, -9.05, 41.00), Vector3(-2.00, -9.05, 42.50),
	Vector3(-1.50, -9.05, 44.00), Vector3(-1.50, -9.05, 51.50), Vector3(0.00, -8.58, 52.50), Vector3(1.50, -7.50, 52.50),
	Vector3(3.00, -6.42, 53.00), Vector3(4.00, -5.70, 53.00), Vector3(7.80, -5.40, 53.00), Vector3(7.80, -1.80, 47.50),
	Vector3(7.80, -1.80, 45.40), Vector3(5.10, -1.80, 46.36), Vector3(5.10, -1.80, 49.20), Vector3(4.00, -1.86, 49.25),
	Vector3(-1.50, -5.40, 49.00), Vector3(-3.00, -5.40, 49.00), Vector3(-4.50, -5.40, 50.00), Vector3(-4.50, -5.40, 63.50),
	Vector3(-5.00, -5.40, 65.00), Vector3(-6.50, -5.40, 66.00), Vector3(-7.50, -5.40, 66.00)]
## Dalla serranda (16) al magazzino, per C3 e la scala di servizio fino alla porta nord dell'infermeria.
const RITORNO := [Vector3(-15.00, 0.00, 19.50), Vector3(-15.00, 0.00, 36.00), Vector3(-15.50, 0.00, 37.50),
	Vector3(-17.00, 0.00, 38.50), Vector3(-27.50, 0.00, 38.50), Vector3(-29.00, -0.71, 38.50), Vector3(-30.50, -1.67, 38.50),
	Vector3(-32.00, -2.64, 38.50), Vector3(-33.50, -2.70, 38.50), Vector3(-35.00, -3.60, 38.50), Vector3(-36.50, -4.56, 38.50),
	Vector3(-38.00, -5.40, 39.00), Vector3(-38.50, -5.40, 40.50), Vector3(-39.00, -5.40, 41.50)]
const PORTA_CAPANNONE := Vector3(-4.9, -4.0, 66.0)
const DENTRO_FIUME := Vector3(-7.6, -5.4, 66.0)
const DENTRO_INFERMERIA := Vector3(-36.0, -5.4, 45.4)
const MAGAZZINO_LONTANO := Vector3(-15.0, 0.0, 12.0)

var level: Node
var ris: Node
var p: Player
var uscita := ""
var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	# a tempo vero, 60 fotogrammi al secondo come nel gioco (il thread lavora a tempo vero: con --fixed-fps
	# il gioco correrebbe più del caricamento)
	Engine.max_fps = 60
	var a := OS.get_cmdline_user_args()
	var scenario := a[1] if a.size() > 1 else "corsa"
	uscita = a[2] if a.size() > 2 else "user://"
	print("COMMIT ", _commit())
	GameState.reset_progress()
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	match scenario:
		"impronta": await _impronta_scenario()
		"corsa": await _corsa()
		"fermo": await _fermo()
		"serranda": await _serranda()
		"morte": await _morte()
		"costruzione": await _costruzione()
		"ripartenze": await _ripartenze()
		"polaroid": await _polaroid()
		"uscita": await _uscita()
		"uscita2": await _uscita(true)
	_fine()


# --- gli scenari ------------------------------------------------------------------------------------------

## Quello che si vede delle stanze dopo il flash e il blackout, col giocatore dentro: in un file, da confrontare
## fra i due commit.
func _impronta_scenario() -> void:
	await _risveglio()
	await _cp(6)
	await _fino_alle_stanze(60.0)
	_tp(DENTRO_FIUME)
	await _secondi(2.0)
	var imp := _impronta()
	var f := FileAccess.open(uscita.path_join("impronta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(imp, "\t", true))
	riga("impronta_nodi", imp.size())


## Rischio 1 e 6: dal checkpoint 6 di corsa fino all'ingresso del capannone, fotogramma per fotogramma.
func _corsa() -> void:
	await _risveglio()
	await _cp(6)
	var punti: Array = ANDATA
	var csv := FileAccess.open(uscita.path_join("corsa.csv"), FileAccess.WRITE)
	csv.store_line("t;x;y;z;vicino;caricate;visibili;in_costruzione;in_caricamento;porta_in_vista;ms;vero_s")
	var t_vero := Time.get_ticks_msec()
	var t := 0.0
	var dt := 1.0 / 60.0
	var tratto := 0
	var pos: Vector3 = punti[0]
	var prima := Time.get_ticks_usec()
	var mancanti := 0
	var peggiore := 0.0
	var visto_da := -1.0
	var arrivate := -1.0
	var lente := PackedFloat32Array()
	_tp(pos)
	while tratto < punti.size() - 1:
		var resto := CORSA * dt
		while resto > 0.0 and tratto < punti.size() - 1:
			var dove: Vector3 = punti[tratto + 1]
			var d := pos.distance_to(dove)
			if d <= resto:
				pos = dove
				resto -= d
				tratto += 1
			else:
				pos = pos.move_toward(dove, resto)
				resto = 0.0
		var avanti: Vector3 = (punti[mini(tratto + 1, punti.size() - 1)] as Vector3) - pos
		var yaw := atan2(-avanti.x, -avanti.z) if Vector2(avanti.x, avanti.z).length() > 0.01 else p.yaw
		p.teleport(pos, yaw, 0.0)
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		var ms := (ora - prima) / 1000.0
		prima = ora
		t += dt
		var vicino: bool = ris.call(&"_vicino", pos) if ris.has_method(&"_vicino") else true
		var caricate := _caricate()
		var visibili := caricate and (ris.get(&"fiume") as Node3D).visible
		var costr: bool = ris.get(&"_fiume_nuovo") != null
		var in_car: bool = ris.get(&"_in_caricamento") == true
		var porta := _porta_in_vista()
		if porta and not visibili:
			mancanti += 1
		if caricate and arrivate < 0.0:
			arrivate = t
		if porta and visto_da < 0.0:
			visto_da = t
		peggiore = maxf(peggiore, ms)
		lente.append(ms)
		csv.store_line("%.3f;%.2f;%.2f;%.2f;%s;%s;%s;%s;%s;%s;%.1f;%.2f" % [t, pos.x, pos.y, pos.z, vicino, caricate, visibili, costr, in_car, porta, ms, (Time.get_ticks_msec() - t_vero) / 1000.0])
	lente.sort()
	riga("corsa_durata_s", "%.1f" % t)
	riga("corsa_stanze_arrivate_s", "%.2f" % arrivate)
	riga("corsa_porta_vista_da_s", "%.2f" % visto_da)
	riga("corsa_fotogrammi_porta_in_vista_senza_stanze", mancanti)
	riga("corsa_fotogramma_peggiore_ms", "%.0f" % peggiore)
	riga("corsa_fotogramma_mediano_ms", "%.1f" % lente[lente.size() / 2])
	check(mancanti == 0, "di corsa dal 6, la porta del capannone non manca mai mentre è in vista (%d fotogrammi)" % mancanti)


## Rischio 6: fermi nella sala pompe dopo il checkpoint 6, i primi 8 s fotogramma per fotogramma.
func _fermo() -> void:
	await _risveglio()
	_tp(Vector3(0.0, -9.05, 33.0))
	await _secondi(1.0)
	var base: Array = await _tempi(2.0)
	await _cp(6)
	var t_cp := Time.get_ticks_msec()
	var dopo: Array = await _tempi(8.0, true)
	var f := 0
	while not _caricate() and f < 60 * 60:
		await get_tree().process_frame
		f += 1
	riga("fermo_stanze_pronte_tempo_vero_s", "%.1f" % ((Time.get_ticks_msec() - t_cp) / 1000.0) if _caricate() else "mai in 68 s")
	riga("fermo_prima_peggiore_ms", "%.0f" % base[0])
	riga("fermo_prima_mediano_ms", "%.1f" % base[1])
	riga("fermo_dopo_peggiore_ms", "%.0f" % dopo[0])
	riga("fermo_dopo_mediano_ms", "%.1f" % dopo[1])
	riga("fermo_dopo_sopra_50ms", dopo[2])
	riga("fermo_dopo_sopra_100ms", dopo[3])
	riga("fermo_stanze_pronte_s", "%.2f" % dopo[4])


## Rischio 2: stato cambiato nelle stanze, poi oltre la serranda (si scaricano), poi di nuovo dentro per C3 e la
## scala di servizio.
func _serranda() -> void:
	await _risveglio()
	await _cp(6)
	await _fino_alle_stanze(60.0)
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.0)
	var voluto := _cambia_stanze()
	await _secondi(0.5)
	riga("serranda_stato_messo", _stato_stanze())
	await _cp(15)
	await _cp(16)
	_tp(MAGAZZINO_LONTANO)
	await _secondi(1.0)
	riga("serranda_lontano_caricate", _caricate())
	await _percorri(RITORNO, CORSA)
	await _secondi(1.0)
	var adesso := _stato_stanze()
	riga("serranda_stato_al_ritorno", adesso)
	check(adesso == voluto, "tornando per C3 e la scala di servizio le stanze sono come le avevo lasciate")
	riga("serranda_keycard_ricomparsa", level.has_node(^"Risalita/Infermeria/Keycard"))
	riga("serranda_radiografia_ricomparsa", level.has_node(^"Risalita/Infermeria/Cassetto14/Frontale/Radiografia"))


## Rischio 3: si muore nel fiume o nell'infermeria dopo aver cambiato qualcosa: si riparte col checkpoint.
func _morte() -> void:
	await _risveglio()
	await _cp(6)
	await _fino_alle_stanze(60.0)
	_tp(DENTRO_FIUME)
	await _secondi(1.0)
	await _cp(10)
	var par := ris.get_node(^"Fiume/FiumeLento/Paratia1")
	par.call(&"gira")
	await _secondi(0.3)
	riga("morte_fiume_paratia_prima", par.call(&"save_state"))
	await _muori()
	riga("morte_fiume_ripartito_da", GameState.snapshot.get("order", -1))
	riga("morte_fiume_caricate", _caricate())
	await _secondi(1.0)
	riga("morte_fiume_paratia_dopo", _stato_di(^"Risalita/Fiume/FiumeLento/Paratia1"))
	# nell'infermeria: dopo la luce (12), un cassetto aperto e la cassaforte, poi si muore
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.0)
	await _cp(12)
	var cassetto := ris.get_node(^"Infermeria/Cassetto12")
	cassetto.call(&"load_state", {"aperto": true})
	await _secondi(0.3)
	riga("morte_infermeria_cassetto_prima", cassetto.call(&"save_state"))
	await _muori()
	riga("morte_infermeria_ripartito_da", GameState.snapshot.get("order", -1))
	await _secondi(1.0)
	riga("morte_infermeria_cassetto_dopo", _stato_di(^"Risalita/Infermeria/Cassetto12"))
	# una paratia girata, poi il checkpoint dell'approdo (11), poi si muore: resta girata
	_tp(DENTRO_FIUME)
	await _secondi(1.0)
	ris.get_node(^"Fiume/FiumeLento/Paratia2").call(&"gira")
	await _secondi(0.3)
	await _cp(11)
	await _muori()
	await _secondi(1.0)
	riga("morte_approdo_paratia2", _stato_di(^"Risalita/Fiume/FiumeLento/Paratia2"))


## Rischio 4: un checkpoint raggiunto mentre le stanze si costruiscono, subito dopo il 6, con dello stato messo da
## parte (le stanze cambiate e poi scaricate).
func _costruzione() -> void:
	await _risveglio()
	await _cp(6)
	await _fino_alle_stanze(60.0)
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.0)
	var voluto := _cambia_stanze()
	await _secondi(0.3)
	await _cp(15)
	await _cp(16)
	_tp(MAGAZZINO_LONTANO)
	await _secondi(1.0)
	riga("costruzione_scaricate", not _caricate())
	# di nuovo alla sala pompe (come ripartendo da lì): un'istantanea al 6 con lo stato da parte
	var cp6 := _checkpoint(6)
	GameState.capture_snapshot(GameState.persist_key(cp6), 6, cp6.get_spawn_transform())
	GameState.respawn()
	await _aspetta_livello()
	riga("costruzione_dopo_ripartenza_caricate", _caricate())
	# appena cominciano a costruirsi, il checkpoint 7
	var f := 0
	while ris.get(&"_fiume_nuovo") == null and not _caricate() and f < 60 * 60:
		await get_tree().process_frame
		f += 1
	riga("costruzione_in_corso_quando_7", ris.get(&"_fiume_nuovo") != null)
	await _cp(7)
	var oggetti: Dictionary = GameState.snapshot.get("objects", {})
	var chiavi := ["Risalita/Fiume/FiumeLento/Paratia1", "Risalita/Infermeria/Cassaforte", "Risalita/Infermeria/Cassetto11",
		"Risalita/Infermeria/Negatoscopio"]
	var nel_7 := {}
	for k in chiavi:
		nel_7[k] = oggetti.get(k)
	riga("costruzione_istantanea_7", nel_7)
	await _fino_alle_stanze(60.0)
	await _secondi(1.0)
	await _muori()
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.5)
	var adesso := _stato_stanze()
	riga("costruzione_stato_dopo", adesso)
	check(adesso == voluto, "il checkpoint preso mentre si costruivano non perde lo stato messo da parte")


## Punto 2 del coordinatore: ripartenze da ogni checkpoint fra 6 e 16 e da più lontano, con le stanze cambiate.
func _ripartenze() -> void:
	await _risveglio()
	await _cp(6)
	await _fino_alle_stanze(60.0)
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.0)
	var voluto := _cambia_stanze()
	await _secondi(0.3)
	# l'istantanea col mondo cambiato: presa qui (le stanze ci sono), poi la si sposta di checkpoint in checkpoint
	GameState.capture_snapshot("collaudo", 12, Transform3D(Basis(), DENTRO_INFERMERIA))
	var stato_salvato: Dictionary = GameState.snapshot.duplicate(true)
	for ordine in [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]:
		var cp := _checkpoint(ordine)
		var spawn := cp.get_spawn_transform() if cp else Transform3D()
		if cp == null:
			# (i checkpoint delle stanze ci sono solo con le stanze: la ripartenza dal punto noto)
			spawn = Transform3D(Basis(), {10: DENTRO_FIUME, 11: Vector3(-35.0, -5.4, 54.8)}.get(ordine, DENTRO_INFERMERIA))
		var s := stato_salvato.duplicate(true)
		s["checkpoint"] = "collaudo_%d" % ordine
		s["order"] = ordine
		(s["player"] as Dictionary)["position"] = [spawn.origin.x, spawn.origin.y, spawn.origin.z]
		GameState.snapshot = s
		GameState.respawn()
		await _aspetta_livello()
		await _secondi(1.0)
		var subito := _caricate()
		_tp(DENTRO_INFERMERIA)
		await _secondi(1.5)
		var adesso := _stato_stanze()
		riga("ripartenza_%d" % ordine, "caricate_subito=%s stato_uguale=%s" % [subito, adesso == voluto])
		check(adesso == voluto, "ripartendo dal %d le stanze tornano come le avevo lasciate" % ordine)


## Rischio 7: la Polaroid della pecora.
func _polaroid() -> void:
	riga("polaroid_totale_avvio", GameState.get_total(&"polaroid"))
	riga("avvio_caricate", "%s a_richiesta=%s risalita_subito=%s" % [_caricate(), ris.get(&"a_richiesta"), Engine.has_meta(&"risalita_subito")])
	await _risveglio()
	await _cp(6)
	await _fino_alle_stanze(60.0)
	riga("polaroid_totale_caricate", GameState.get_total(&"polaroid"))
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.0)
	var pol := ris.get_node_or_null(^"Infermeria/PolaroidPecora")
	riga("polaroid_c_e", pol != null)
	if pol:
		pol.call(&"_on_interact", p)
	await _chiudi_visore()
	riga("polaroid_raccolte", GameState.get_collected_count(&"polaroid"))
	await _cp(15)
	await _cp(16)
	_tp(MAGAZZINO_LONTANO)
	await _secondi(1.0)
	riga("polaroid_scaricate", not _caricate())
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.5)
	riga("polaroid_ricomparsa", level.has_node(^"Risalita/Infermeria/PolaroidPecora"))
	riga("polaroid_totale_fine", GameState.get_total(&"polaroid"))
	await _muori()
	_tp(DENTRO_INFERMERIA)
	await _secondi(1.5)
	riga("polaroid_ricomparsa_dopo_morte", level.has_node(^"Risalita/Infermeria/PolaroidPecora"))
	riga("polaroid_raccolte_dopo_morte", GameState.get_collected_count(&"polaroid"))


## Rischio 8: si esce dal gioco mentre le stanze si caricano.
func _uscita(in_costruzione := false) -> void:
	await _risveglio()
	await _cp(6)
	var f := 0
	while (ris.get(&"_fiume_nuovo") == null if in_costruzione else (ris.get(&"_in_caricamento") != true and ris.get(&"_fiume_nuovo") == null)) and f < 600:
		await get_tree().process_frame
		f += 1
	riga("uscita_quando", "in_caricamento=%s in_costruzione=%s" % [ris.get(&"_in_caricamento"), ris.get(&"_fiume_nuovo") != null])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	print("USCITA chiesta a %d ms" % Time.get_ticks_msec())
	Game.esci(0)
	await get_tree().create_timer(600.0).timeout


# --- aiuti ------------------------------------------------------------------------------------------------

## Cambia le stanze come un giocatore a metà: paratie girate, cassaforte aperta, due cassetti aperti, la
## radiografia sul negatoscopio e i due oggetti raccolti. Torna lo stato atteso.
func _cambia_stanze() -> Dictionary:
	for n in ["Fiume/FiumeLento/Paratia1", "Fiume/FiumeLento/Paratia3"]:
		ris.get_node(NodePath(n)).call(&"gira")
	var cf := ris.get_node(^"Infermeria/Cassaforte")
	var cifre: Array = cf.call(&"save_state")["cifre"]
	cf.call(&"load_state", {"cifre": cifre, "aperta": true})
	for n in ["Infermeria/Cassetto11", "Infermeria/Cassetto23"]:
		ris.get_node(NodePath(n)).call(&"load_state", {"aperto": true})
	ris.get_node(^"Infermeria/Negatoscopio").call(&"load_state", {"con_radiografia": true})
	for n in ["Infermeria/Keycard", "Infermeria/Cassetto14/Frontale/Radiografia"]:
		var k := ris.get_node_or_null(NodePath(n))
		if k:
			k.call(&"_on_interact", p)
	return _stato_stanze()


## Lo stato di tutti gli oggetti "persist" delle stanze, e quali raccoglibili ci sono ancora.
func _stato_stanze() -> Dictionary:
	var out := {}
	for k in ["Risalita/Fiume/FiumeLento/Paratia1", "Risalita/Fiume/FiumeLento/Paratia2", "Risalita/Fiume/FiumeLento/Paratia3",
			"Risalita/Infermeria/Negatoscopio", "Risalita/Infermeria/Cassaforte", "Risalita/Infermeria/Cassetto11",
			"Risalita/Infermeria/Cassetto12", "Risalita/Infermeria/Cassetto23", "Risalita/Infermeria/Interruttore"]:
		out[k] = _stato_di(NodePath(k))
	for k in ["Risalita/Infermeria/Keycard", "Risalita/Infermeria/Cassetto14/Frontale/Radiografia", "Risalita/Infermeria/PolaroidPecora"]:
		var n := level.get_node_or_null(NodePath(k))
		out[k] = "c'è" if n and not n.is_queued_for_deletion() else "no"
	return out


func _stato_di(percorso: NodePath) -> Variant:
	var n := level.get_node_or_null(percorso)
	if n == null or n.is_queued_for_deletion():
		return "manca"
	return n.call(&"save_state")


func _caricate() -> bool:
	var f: Variant = ris.get(&"fiume")
	return f != null and is_instance_valid(f) and (f as Node).is_inside_tree()


## Aspetta che le stanze ci siano (col thread), al massimo [param s] secondi.
func _fino_alle_stanze(s: float) -> void:
	var f := 0
	while not _caricate() and f < int(s * 60.0):
		await get_tree().process_frame
		f += 1
	await _secondi(0.3)


## Il checkpoint di quest'ordine: il giocatore ci va e lo prende.
func _cp(ordine: int) -> void:
	var cp := _checkpoint(ordine)
	if cp == null:
		printerr("  manca il checkpoint ", ordine)
		return
	_tp(cp.get_spawn_transform().origin)
	await _secondi(0.2)
	GameState.reach_checkpoint(cp)
	await _secondi(0.1)


func _checkpoint(ordine: int) -> Checkpoint:
	for c in level.find_children("*", "Checkpoint", true, false):
		if (c as Checkpoint).order == ordine and (c as Node).is_inside_tree():
			return c as Checkpoint
	return null


func _tp(pos: Vector3) -> void:
	p.teleport(pos, p.yaw, 0.0)


func _percorri(punti: Array, v: float) -> void:
	var pos: Vector3 = punti[0]
	_tp(pos)
	for i in range(1, punti.size()):
		var dove: Vector3 = punti[i]
		while pos.distance_to(dove) > 0.001:
			pos = pos.move_toward(dove, v / 60.0)
			var av := dove - pos
			p.teleport(pos, atan2(-av.x, -av.z) if Vector2(av.x, av.z).length() > 0.01 else p.yaw, 0.0)
			await get_tree().physics_frame


## Il visore della Polaroid si apre raccogliendola e ferma il gioco: lo si chiude con un clic, come il giocatore.
func _chiudi_visore() -> void:
	await get_tree().create_timer(0.5, true).timeout
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	Input.parse_input_event(clic)
	await get_tree().create_timer(0.2, true).timeout
	riga("visore_chiuso", not get_tree().paused)
	get_tree().paused = false


## Si muore e si riparte dall'ultimo checkpoint (senza la sequenza di morte).
func _muori() -> void:
	GameState.respawn()
	await _aspetta_livello()


## Come nel gioco: il flash del risveglio e poi il blackout.
func _risveglio() -> void:
	GameState.imposta_luci(GameState.Luci.FLASH)
	await _secondi(1.2)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _secondi(1.0)


## I tempi dei fotogrammi per [param s] secondi: peggiore, mediano, sopra 50 ms, sopra 100 ms, e quando le stanze
## sono arrivate (s, -1 se no).
func _tempi(s: float, scrivi := false) -> Array:
	var l := PackedFloat32Array()
	var prima := Time.get_ticks_usec()
	var arrivate := -1.0
	var csv: FileAccess = FileAccess.open(uscita.path_join("fermo.csv"), FileAccess.WRITE) if scrivi else null
	for i in int(s * 60.0):
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		var ms := (ora - prima) / 1000.0
		prima = ora
		l.append(ms)
		if _caricate() and arrivate < 0.0:
			arrivate = (i + 1) / 60.0
		if csv:
			csv.store_line("%d;%.1f;%s;%s;%s" % [i, ms, ris.get(&"_in_caricamento"), ris.get(&"_fiume_nuovo") != null, _caricate()])
	var ordinati := l.duplicate()
	ordinati.sort()
	var sopra50 := 0
	var sopra100 := 0
	for ms in l:
		if ms > 50.0:
			sopra50 += 1
		if ms > 100.0:
			sopra100 += 1
	return [ordinati[ordinati.size() - 1], ordinati[ordinati.size() / 2], sopra50, sopra100, arrivate]


## La porta in fondo al corridoio del capannone è in vista dalla camera: davanti, nel campo visivo, e niente in
## mezzo (senza contare le stanze stesse).
func _porta_in_vista() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var da := cam.global_position
	if cam.is_position_behind(PORTA_CAPANNONE):
		return false
	var sp := Vector2(get_viewport().get_visible_rect().size)
	var su := cam.unproject_position(PORTA_CAPANNONE)
	if su.x < 0 or su.y < 0 or su.x > sp.x or su.y > sp.y:
		return false
	var escludi: Array[RID] = [p.get_rid()]
	var f: Variant = ris.get(&"fiume")
	if f != null and is_instance_valid(f):
		for c in (f as Node).find_children("*", "CollisionObject3D", true, false):
			escludi.append((c as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(da, PORTA_CAPANNONE, Layers.WORLD | Layers.PROPS, escludi)
	return cam.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Quello che si vede delle stanze: luci, geometrie e materiali, nodo per nodo (come test_risalita_tardi, ma da
## confrontare con un altro commit).
func _impronta() -> Dictionary:
	var out := {}
	for nome in ["Fiume", "Infermeria"]:
		var radice := ris.get_node(NodePath(nome)) as Node3D
		for n in [radice] + radice.find_children("*", "Node3D", true, false):
			var parti := PackedStringArray()
			for x in String(ris.get_path_to(n)).split("/"):
				parti.append("@" if x.contains("@") else x)
			var k := "/".join(parti)
			while out.has(k):
				k += "+"
			var t := (n as Node3D).global_transform
			var v := "vis=%s pos=%s rot=%s scala=%s" % [(n as Node3D).is_visible_in_tree(), t.origin.snapped(Vector3.ONE * 0.001),
				t.basis.get_euler().snapped(Vector3.ONE * 0.001), t.basis.get_scale().snapped(Vector3.ONE * 0.001)]
			if n is Light3D:
				var l := n as Light3D
				var forza := "sfarfalla" if l.get_parent() is FlickerLight or n.get_script() else "%.3f" % l.light_energy
				v += " luce %s acc=%s col=%s ombre=%s nebbia=%.2f" % [forza, l.visible, l.light_color, l.shadow_enabled, l.light_volumetric_fog_energy]
			if n is GeometryInstance3D:
				var g := n as GeometryInstance3D
				v += " ombra=%d gi=%d" % [g.cast_shadow, g.gi_mode]
				if n is MeshInstance3D and (n as MeshInstance3D).mesh:
					var mi := n as MeshInstance3D
					v += " tri=%d" % mi.mesh.get_faces().size()
					for i in mi.mesh.get_surface_count():
						v += " s%d=%s" % [i, _mat(mi.get_active_material(i))]
			out[k] = v
	return out


func _mat(m: Material) -> String:
	if m == null:
		return "-"
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return "B(%s %s em=%s %s x%.2f tr=%d)" % [b.albedo_color, b.albedo_texture.resource_path.get_file() if b.albedo_texture else "",
			b.emission_enabled, b.emission, b.emission_energy_multiplier, b.transparency]
	if m is ShaderMaterial:
		var s := m as ShaderMaterial
		return "S(%d)" % (s.shader.code.hash() if s.shader else 0)
	return m.get_class()


func _commit() -> String:
	var out: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], out)
	return String(out[0]).strip_edges() if out.size() > 0 else "?"


func _aspetta_livello() -> void:
	for i in 1200:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and get_tree().current_scene:
			break
	await _secondi(0.3)
	level = get_tree().current_scene
	p = GameState.player
	ris = level.get_node(^"Risalita")


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func riga(chiave: String, valore: Variant) -> void:
	print("RIGA %s = %s" % [chiave, str(valore)])


func check(cond: bool, what: String) -> void:
	if cond:
		_ok += 1
		print("  ok   ", what)
	else:
		_ko += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
