extends Node
## Test della strada nuova della risalita (scenes/risalita/risalita.tscn) nella scena di prova
## tests/scene/risalita_prova.tscn: le stanze stanno al loro posto nello scafo e si percorrono a piedi e
## sulla ciambella, dall'ingresso del capannone del fiume fino alla porta nel corridoio C3.
## 1. Dall'ingresso del capannone si arriva all'imbarco; il fiume funziona anche girato.
## 2. Il giro giusto (paratie girate come servono) porta all'approdo.
## 3. Dall'approdo, per la porta di servizio e la zona del personale, si entra nell'infermeria; dalla porta
##    nord la stanza delle pozze, e dalla sua porta stagna la scala di servizio sale fino alla quota della sala e arriva
##    alla porta di C3.
## 4. Le stanze non si disegnano col giocatore lontano.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_risalita.gd

const SCENA := "res://tests/scene/risalita_prova.tscn"
const POLAROID_LIBERE := preload("res://tests/polaroid_libere.gd")

var level: Node
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	var ris := level.get_node(^"Risalita")
	var fiume := ris.get_node(^"Fiume/FiumeLento") as FiumeLento
	check(fiume != null, "c'è il fiume nella risalita")
	if fiume == null:
		_fine()
		return
	GameState.imposta_luci(GameState.Luci.BLACKOUT)

	print("1. Dall'ingresso all'imbarco")
	var ingresso := ris.get_node(^"Fiume/Marker/Ingresso") as Node3D
	var imbarco := ris.get_node(^"Fiume/Marker/Imbarco") as Node3D
	p.teleport(ingresso.global_position, 0.0, 0.0)
	await _secondi(0.3)
	check(await _cammina([(ris.get_node(^"Fiume/Marker/FineFila") as Node3D).global_position, imbarco.global_position], 30.0), "dall'ingresso si arriva all'imbarco (%s)" % str(p.global_position))
	fiume.sali(p)
	check(fiume.a_bordo(), "si sale sulla ciambella")

	print("2. Il giro giusto")
	(fiume.get_node(^"Paratia1") as ParatiaFiume).a_destra = false
	(fiume.get_node(^"Paratia3") as ParatiaFiume).a_destra = false
	var ev := {"fuori": false}
	fiume.uscito.connect(func(): ev.fuori = true, CONNECT_ONE_SHOT)
	for i in 60 * 90:
		await get_tree().physics_frame
		if ev.fuori:
			break
	check(ev.fuori and not fiume.a_bordo(), "si arriva all'approdo e si scende")
	await _secondi(0.5)
	check(p.is_on_floor() and absf(p.global_position.y - (-5.4)) < 0.1, "sulla banchina dell'approdo (%s)" % str(p.global_position))
	# le Polaroid nuove della proposta del 25 ottobre notte: nel corridoio verso il fiume, nella zona del personale e
	# all'approdo, appoggiate (Posa) da 0 a 1 cm sopra quello che hanno sotto
	for n in ["Polaroid13", "Polaroid15", "Polaroid16"]:
		var f := ris.find_child(n, true, false) as Node3D
		var h: float = POLAROID_LIBERE.appoggio(level, f) if f else INF
		check(f != null and h > -0.002 and h < 0.012, "%s c'è ed è appoggiata (%.1f cm sopra quello che ha sotto)" % [n, h * 100.0])

	print("3. Zona del personale, infermeria, scala di servizio")
	var porta := ris.get_node(^"Fiume/Marker/PortaPersonale") as Node3D
	var inf := ris.get_node(^"Infermeria") as Node3D
	var tappe: Array[Vector3] = [porta.global_position + porta.global_basis.z * 0.8, porta.global_position - porta.global_basis.z * 1.5,
		inf.to_global(Vector3(1.6, 0, 3.6)), inf.to_global(Vector3(1.8, 0, 1.6)), inf.to_global(Vector3(0.0, 0, 0.0)),
		inf.to_global(Vector3(-2.2, 0, -2.4))]
	check(await _cammina(tappe, 40.0), "dall'approdo si entra nell'infermeria (%s)" % str(p.global_position))
	# la porta nord resta chiusa finché non colpisci il pulsantone (richiesta dell'utente del 25 ottobre)
	var fuori: Array[Vector3] = [inf.to_global(Vector3(-2.2, 0, -3.8))]
	var uscito := await _cammina(fuori, 3.0)
	check(not uscito and inf.to_local(p.global_position).z > -3.25, "la porta nord è chiusa: non si esce (%s)" % str(inf.to_local(p.global_position)))
	print("  (scorciatoia: il pulsantone colpito col getto, lo prova test_infermeria_gioco)")
	# (l'anta si apre verso dentro: prima un passo indietro, fuori da dove gira, e si aspetta che sia contro il muro; se no
	# spinge il giocatore oltre la porta, e dal 31 ottobre lì dietro ci sono le pozze)
	var indietro: Array[Vector3] = [inf.to_global(Vector3(-2.2, 0, -1.6))]
	await _cammina(indietro, 5.0)
	inf.get_node(^"Interruttore").set(&"powered", true)
	for i in 200:
		await get_tree().physics_frame
	check(await _cammina(fuori, 20.0), "col pulsantone colpito la porta nord è aperta e se ne esce (%s)" % str(p.global_position))
	# la stanza delle pozze (31 ottobre): sulla passerella fino alla porta stagna, chiusa finché l'enigma non è risolto
	var pozze := ris.get_node(^"StanzaPozze") as Node3D
	var porta_x: float = (pozze.get_script() as Script).get_script_constant_map().get("PORTA_X", -1.7)
	var giro: Array[Vector3] = [pozze.to_global(Vector3(0, 0, 3.4)), pozze.to_global(Vector3(-3.4, 0, 3.4)),
		pozze.to_global(Vector3(-3.4, 0, -3.4)), pozze.to_global(Vector3(porta_x, 0, -3.4))]
	check(await _cammina(giro, 30.0), "sulla passerella intorno alle pozze fino alla porta stagna (%s)" % str(p.global_position))
	var oltre: Array[Vector3] = [pozze.to_global(Vector3(porta_x, 0, -5.4))]
	check(not await _cammina(oltre, 3.0) and pozze.to_local(p.global_position).z > -4.0,
		"la porta stagna è chiusa: non si esce (%s)" % str(pozze.to_local(p.global_position)))
	print("  (scorciatoia: l'enigma risolto, con le pozze dei colori giusti vuote e la porta stagna aperta; lo prova test_pozze)")
	_risolvi_pozze(pozze)
	await get_tree().physics_frame
	check(await _cammina(oltre, 10.0), "con la porta stagna aperta si esce sul piede della scala (%s)" % str(p.global_position))
	var cima := ris.get_node(^"Marker/CimaScala") as Node3D
	var c3 := ris.get_node(^"Marker/PortaC3") as Node3D
	var scala: Array[Vector3] = [Vector3(cima.global_position.x, 0, p.global_position.z), cima.global_position, c3.global_position]
	check(await _cammina(scala, 40.0), "la scala di servizio porta alla porta di C3 (%s)" % str(p.global_position))
	check(absf(p.global_position.y) < 0.15, "alla quota della sala (%.2f)" % p.global_position.y)

	print("4. Lontano non si disegna")
	p.teleport(Vector3(0, 0, 0), 0.0, 0.0)
	await _secondi(0.2)
	check(not (ris.get_node(^"Fiume") as Node3D).visible and not (ris.get_node(^"Infermeria") as Node3D).visible, "dalla sala il capannone e l'infermeria sono nascosti")
	p.teleport(ingresso.global_position, 0.0, 0.0)
	await _secondi(0.2)
	check((ris.get_node(^"Fiume") as Node3D).visible, "dentro si vedono")
	_fine()


## Cammina (tasto avanti) per i punti in fila, al massimo [param secondi] in tutto; vero se arriva
## all'ultimo (entro 0,6 m in pianta).
func _cammina(punti: Array, secondi: float) -> bool:
	var n := int(secondi * 60.0)
	var k := 0
	for i in n:
		var d: Vector3 = punti[k] - p.global_position
		d.y = 0.0
		if d.length() < 0.6:
			k += 1
			if k >= punti.size():
				Input.action_release(&"move_forward")
				return true
			continue
		p.look_at_point(p.get_eye_position() + d.normalized())
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	print("    fermo a ", p.global_position, " verso il punto ", k, " ", punti[k])
	return false


func _aspetta_livello() -> void:
	# (a tempo: la ripartenza aspetta i caricamenti nel thread, anche qualche secondo)
	var t_attesa := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_attesa < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## L'enigma delle pozze risolto come lo fanno le partenze dopo le pozze (enigmi): così i checkpoint più avanti salvano le
## pozze risolte e la porta stagna resta aperta ripartendo da lì.
func _risolvi_pozze(pozze: Node3D) -> void:
	var enigma := pozze.get_node_or_null(^"EnigmaPozze")
	if enigma and enigma.has_method(&"load_state"):
		enigma.call(&"load_state", {"stato": EnigmaPozze.Stato.RISOLTO, "tolti": EnigmaPozze.GIUSTI})
	else:
		(pozze.get_node(^"PortaStagna") as PortaStagna).apri(true)
