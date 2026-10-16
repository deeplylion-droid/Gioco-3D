extends Node
## Test dei bambini (creature minori): le due scene si caricano, i modelli hanno lo scheletro e
## tutte le animazioni, e le modalità funzionano nella scena di prova: statua che reagisce allo
## sguardo, osserva con la testa, si rivela, scappa con la torcia o se ti avvicini, sparisce.
## Uso:
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambini.gd
## Esce con codice 0 se tutto va bene, 1 se qualche controllo fallisce.

const LEVEL := "res://scenes/test/test_level.tscn"
const CUBO := "res://scenes/creature/bambino_cubo.tscn"
const AGNELLO := "res://scenes/creature/bambino_agnello.tscn"

var level: Node
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_scene()
	await _load_level()
	await _test_statua_e_fuga()
	await _test_vicino_e_occhio()
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Aiuti ---------------------------------------------------------------------------------
func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _load_level() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(3)
	level = get_tree().current_scene
	p = GameState.player
	var manichino := level.get_node_or_null("SalaVasche/Manichino")
	if manichino:
		manichino.process_mode = Node.PROCESS_MODE_DISABLED


func _registra(b: Bambino) -> Dictionary:
	var ev := {}
	for s in [&"visto", &"si_gira", &"rivelato", &"scappa", &"sparito"]:
		b.connect(s, func() -> void: ev[s] = ev.get(s, 0) + 1)
	return ev


func _anim(b: Bambino) -> AnimationPlayer:
	var m := b.get_node("Rivelato" if b.e_rivelato else "Calmo")
	return m.find_child("AnimationPlayer", true, false) as AnimationPlayer


# --- Test ----------------------------------------------------------------------------------
func _test_scene() -> void:
	print("Le scene, i modelli e le animazioni")
	for path in [CUBO, AGNELLO]:
		var ps := load(path) as PackedScene
		check(ps != null, "si carica " + path.get_file())
		if ps == null:
			continue
		var b := ps.instantiate() as Bambino
		check(b != null, path.get_file() + ": la radice è un Bambino")
		if b == null:
			continue
		for nome in ["Calmo", "Rivelato"]:
			var m := b.get_node_or_null(nome)
			check(m != null, "%s: c'è il modello %s" % [path.get_file(), nome])
			if m == null:
				continue
			check(not m.find_children("*", "Skeleton3D", true, false).is_empty(), "%s/%s ha lo scheletro" % [path.get_file(), nome])
			var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var mancano: Array[String] = []
			for a in Bambino.ANIMAZIONI:
				if ap == null or not ap.has_animation(a):
					mancano.append(a)
			check(mancano.is_empty(), "%s/%s ha tutte le animazioni %s" % [path.get_file(), nome, mancano])
		for s in ["visto", "si_gira", "rivelato", "scappa", "sparito"]:
			check(b.has_signal(s), "%s ha il segnale %s" % [path.get_file(), s])
		b.free()
	var agn := (load(AGNELLO) as PackedScene).instantiate()
	var occhio := agn.get_node("Rivelato").find_children("occhio_bulbo*", "MeshInstance3D", true, false)
	check(not occhio.is_empty(), "l'agnellino rivelato ha l'occhio a parte (occhio_bulbo)")
	agn.free()


func _test_statua_e_fuga() -> void:
	print("Testa a cubo: statua, sguardo, rivelazione, torcia, fuga")
	p.teleport(Vector3(0.5, 0, 5.2), 0.0, 0.0)
	var torcia := p.get_node("Head/Camera3D/Torcia") as Torcia
	torcia.imposta_accesa(false)
	var b := (load(CUBO) as PackedScene).instantiate() as Bambino
	b.modalita = Bambino.Modalita.STATUA
	b.reazione = Bambino.Reazione.SI_GIRA
	b.distanza_fuga = 2.0
	b.inclina_ogni = 0.0
	b.libera_quando_sparisce = false
	level.add_child(b)
	b.global_position = Vector3(0.5, 0, 1.0)     # girato verso +Z, cioè verso il giocatore
	b.add_to_group(&"test")
	var ev := _registra(b)
	check(b.is_in_group(&"bambini"), "è nel gruppo \"bambini\"")
	p.look_at_point(Vector3(6.0, 1.4, 5.2))         # guarda altrove
	await _frames(60)
	check(not ev.has(&"visto") and b.modalita == Bambino.Modalita.STATUA, "se non lo guardi resta una statua")
	check(_anim(b).assigned_animation == &"si_gira" and not _anim(b).is_playing(), "da statua è fermo, di spalle")
	p.look_at_point(b.punto_testa())
	await _frames(60)
	check(ev.has(&"visto") and ev.has(&"si_gira"), "quando lo guardi si gira (segnali visto e si_gira)")
	check(b.modalita == Bambino.Modalita.OSSERVA, "poi osserva")
	await _frames(240)
	check(_anim(b).current_animation == &"fermo", "finito di girarsi respira fermo")
	var sguardo := b.find_children("SguardoTesta", "LookAtModifier3D", true, false)
	check(not sguardo.is_empty() and (sguardo[0] as LookAtModifier3D).influence > 0.5, "segue il giocatore con la testa")
	b.rivela()
	await _frames(2)
	check(b.e_rivelato and b.get_node("Rivelato").visible and not b.get_node("Calmo").visible, "rivela(): si vede il cubo spaccato")
	check(ev.has(&"rivelato"), "segnale rivelato")
	check(_anim(b).current_animation == &"fermo", "il modello rivelato continua la stessa animazione")
	var fuga := Marker3D.new()
	level.add_child(fuga)
	fuga.global_position = Vector3(3.0, 0, -0.5)
	b.punti_fuga = [fuga]
	await _frames(20)
	check(not ev.has(&"scappa"), "a torcia spenta non scappa")
	torcia.imposta_accesa(true)
	p.look_at_point(b.global_position + Vector3(0, 0.7, 0))
	await _frames(15)
	check(not ev.has(&"scappa"), "un colpo di torcia veloce non basta")
	await _frames(55)
	check(ev.has(&"scappa"), "la torcia addosso lo fa scappare (segnale scappa)")
	check(_anim(b).current_animation == &"corsa", "scappa di corsa")
	await _frames(150)
	check(ev.has(&"sparito") and not b.visible, "arriva al punto di fuga e sparisce (segnale sparito)")
	check(b.global_position.distance_to(fuga.global_position) < 0.3, "si è mosso fino al punto di fuga (%.1f m)" % Vector3(0.5, 0, 1.0).distance_to(fuga.global_position))
	b.queue_free()
	fuga.queue_free()
	await _frames(2)


func _test_vicino_e_occhio() -> void:
	print("Agnellino: osserva con l'occhio, scappa se ti avvicini")
	p.teleport(Vector3(0.5, 0, 5.2), 0.0, 0.0)
	(p.get_node("Head/Camera3D/Torcia") as Torcia).imposta_accesa(false)
	var b := (load(AGNELLO) as PackedScene).instantiate() as Bambino
	b.modalita = Bambino.Modalita.OSSERVA
	b.rivelato_all_inizio = true
	b.distanza_fuga = 2.5
	b.inclina_ogni = 0.0
	b.gira_il_corpo = false
	b.libera_quando_sparisce = false
	b.distanza_fuga_libera = 3.0
	level.add_child(b)
	b.global_position = Vector3(0.5, 0, 1.0)
	var ev := _registra(b)
	p.look_at_point(b.punto_testa())
	await _frames(30)
	check(b.e_rivelato and _anim(b).current_animation == &"fermo", "comincia rivelato e respira fermo")
	var occhio := b.get_node("Rivelato").find_children("occhio_bulbo*", "MeshInstance3D", true, false)
	var mat: StandardMaterial3D = null
	if not occhio.is_empty():
		mat = (occhio[0] as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	check(mat != null, "il materiale dell'occhio è suo (per spostare le UV)")
	p.teleport(Vector3(3.5, 0, 4.5), 0.0, 0.0)
	await _frames(90)
	var a := mat.uv1_offset if mat else Vector3.ZERO
	p.teleport(Vector3(-2.5, 0, 4.5), 0.0, 0.0)
	await _frames(90)
	var c := mat.uv1_offset if mat else Vector3.ZERO
	check(absf(a.x - c.x) > 0.02, "l'iride segue il giocatore (UV %.3f -> %.3f)" % [a.x, c.x])
	check(not ev.has(&"scappa"), "a distanza resta a guardare")
	p.teleport(Vector3(0.5, 0, 2.6), 0.0, 0.0)
	await _frames(5)
	check(ev.has(&"scappa"), "se ti avvicini troppo scappa")
	await _frames(150)
	check(ev.has(&"sparito"), "senza punti di fuga corre via e sparisce")
	b.queue_free()
	await _frames(2)
