extends Node
## Test del canto di lei prima del tunnel (addon audio, classe CantoPrima; 0.4.0, «L'acqua è sua», scelta A del 15
## novembre). Le frasi vere (lei_canto_prima_lontano_NN e _vicino_NN, 10 coppie della stessa lunghezza) sono nel
## catalogo; per i tempi il test usa due coppie corte che ci sono (CantoPrima.prova). Una lei finta come AcquaDiLei di
## mascotte (gruppo lei_nell_acqua; fase_canto, fase con l'enum Fase, vicinanza, punto_luce, punti_uscita, in_giro), un
## giocatore finto (CantoPrima.giocatore_prova) e un oblò finto (come ObloLei: stato e _dentro):
## - le 10 coppie vere ci sono, e senza frasi non suona niente;
## - prima che si riaccendano le pompe (GameState.luci = PRIMA_DEL_RISVEGLIO) non canta;
## - in LONTANA canta solo col giocatore vicino a un punto d'uscita (15 m), e lontano: la frase dei tubi piena, la
##   vicina giù; la lontana non posizionale, la vicina in 3D;
## - in «arriva», con la vicinanza a 0,9, la vicina sale e la lontana scende, e la vicina sta alla luce rosa; se non
##   sta cantando parte subito;
## - in «spegne» il canto non si tronca: la nota cala di tono e muore in circa 1 s (a metà ancora si sente, più grave e
##   più piano), poi nel «silenzio» e «fuori» niente; solo alla PRESA tace subito;
## - torna a cantare in «va_via», e due frasi di fila non sono mai la stessa;
## - in «ferma» si spegne;
## - nel giro della luce (in_giro, AcquaDiLei.percorri; fase LONTANA) canta anche col giocatore lontano dai punti, e a
##   vicinanza 0,8 è tutto vicino;
## - fra due acque si segue quella dove lei è adesso, anche se l'altra è più vicina;
## - all'oblò, con lei dietro il vetro e il giocatore nella sua zona, si sente appena: solo la lontana, 12 dB sotto;
## - se lei sparisce (nodo liberato) il canto si spegne.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_canto_prima.gd

const Catalogo := preload("res://addons/audio/catalogo.gd")


class LeiFinta extends Node3D:
	enum Fase { LONTANA, ARRIVA, SPEGNE, SILENZIO, ESCE, SU, PRESA, SCENDE, CALMA }
	var fase := Fase.LONTANA
	var fase_canto: StringName = &"lontana"
	var vicinanza := 0.0
	var punto_luce := Vector3.ZERO
	var punti_uscita: Array[Node3D] = []
	var giro := false
	func in_giro() -> bool:
		return giro
	func metti(f: Fase, fc: StringName) -> void:
		fase = f
		fase_canto = fc


class ObloFinto extends Node3D:
	var stato := 0
	func _dentro(pos: Vector3) -> bool:
		return pos.distance_to(global_position) < 10.0


var canto
var classe
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  ok  ", msg)
	else:
		_failed += 1
		print("  KO  ", msg)


func _secondi(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _acqua(pos: Vector3) -> LeiFinta:
	var l := LeiFinta.new()
	l.add_to_group(&"lei_nell_acqua")
	add_child(l)
	l.global_position = pos
	var u := Marker3D.new()
	l.add_child(u)
	l.punti_uscita = [u]
	l.punto_luce = pos + Vector3(0, -0.6, 0)
	return l


func _run() -> void:
	Game.pause_on_focus_loss = false
	classe = (Audio.get_script() as GDScript).get(&"CantoPrima")
	canto = Audio.get(&"canto_prima")
	check(canto != null, "il canto prima del tunnel c'è nell'audio")
	if canto == null:
		_fine()
		return
	var luci_prima = GameState.luci
	GameState.luci = GameState.Luci.BLACKOUT
	var gioc := Node3D.new()
	add_child(gioc)
	gioc.global_position = Vector3(40, 0, 0)
	classe.giocatore_prova = gioc
	var lei := _acqua(Vector3(5, 0, 0))
	lei.fase_canto = &"ferma"
	check(classe.nome_fase(lei) == "LONTANA", "la fase si legge per nome dall'enum (%s)" % classe.nome_fase(lei))

	print("Le frasi vere")
	var lontane: Array = Catalogo.SUONI.get(&"lei_canto_prima_lontano", [])
	var vicine: Array = Catalogo.SUONI.get(&"lei_canto_prima_vicino", [])
	check(lontane.size() == 10 and vicine.size() == 10, "10 coppie nel catalogo (%d lontane, %d vicine)" % [lontane.size(), vicine.size()])
	var stesse := true
	for i in mini(lontane.size(), vicine.size()):
		var sl := load(lontane[i]) as AudioStream
		var sv := load(vicine[i]) as AudioStream
		stesse = stesse and sl != null and sv != null and absf(sl.get_length() - sv.get_length()) < 0.05
	check(stesse, "ogni coppia: le due frasi si caricano e sono lunghe uguali")

	print("Senza frasi non suona niente")
	classe.prova = [[], []]
	lei.fase_canto = &"lontana"
	gioc.global_position = Vector3(8, 0, 0)
	await _secondi(3.0)
	check(not canto.canta(), "lei nell'acqua vicina, ma senza frasi niente")

	# due coppie corte che ci sono, per i tempi
	var t: Array = Catalogo.SUONI.get(&"lei_tunnel_canto", [])
	classe.prova = [[t[0], t[1]], [t[2], t[3]]]

	print("Prima che si riaccendano le pompe")
	GameState.luci = GameState.Luci.PRIMA_DEL_RISVEGLIO
	await _secondi(3.0)
	check(not canto.canta(), "con le luci di prima del risveglio non canta")
	GameState.luci = GameState.Luci.BLACKOUT

	print("«lontana»: nei tubi, solo con il giocatore vicino")
	gioc.global_position = Vector3(40, 0, 0)
	await _secondi(3.0)
	check(not canto.canta(), "col giocatore a 35 m dall'acqua non canta")
	gioc.global_position = Vector3(14, 0, 3)
	var t0 := 0.0
	while t0 < 2.6 and not canto.canta():
		await get_tree().process_frame
		t0 += get_process_delta_time()
	check(canto.canta(), "col giocatore a 9 m canta entro 2,5 s (%.1f s)" % t0)
	await _secondi(0.5)
	var lon: Node = canto.lon
	var vic: Node = canto.vic
	check(is_instance_valid(lon) and is_instance_valid(vic), "due lettori: la frase lontana e la stessa vicina")
	if is_instance_valid(lon) and is_instance_valid(vic):
		check(float(lon.volume_db) > -1.0 and float(vic.volume_db) < -40.0,
				"lontana piena e vicina giù (%.1f e %.1f dB)" % [lon.volume_db, vic.volume_db])
		check(not (lon is AudioStreamPlayer3D) and vic is AudioStreamPlayer3D, "la lontana non posizionale, la vicina in 3D")

	print("«arriva»: la luce rosa si avvicina")
	await _aspetta_silenzio()
	lei.metti(LeiFinta.Fase.ARRIVA, &"arriva")
	lei.vicinanza = 0.9
	lei.punto_luce = Vector3(2, -0.4, 0.5)
	await _secondi(0.1)
	check(canto.canta(), "se non stava cantando, parte subito")
	await _secondi(0.6)
	if canto.canta():
		lon = canto.lon
		vic = canto.vic
		check(float(vic.volume_db) > -1.0 and float(lon.volume_db) < -30.0,
				"a vicinanza 0,9 vicina piena e lontana giù (%.1f e %.1f dB)" % [vic.volume_db, lon.volume_db])
		check((vic as Node3D).global_position.distance_to(lei.punto_luce) < 0.01, "la vicina viene dalla luce rosa")

	print("«spegne»: il canto non si tronca, muore in un secondo")
	await _aspetta_canto()
	lei.vicinanza = 1.0
	lei.metti(LeiFinta.Fase.SPEGNE, &"spegne")
	await _secondi(0.45)
	vic = canto.vic
	check(canto.canta() and is_instance_valid(vic), "a metà dello spegnimento si sente ancora")
	if is_instance_valid(vic):
		check(float(vic.pitch_scale) < 0.97 and float(vic.volume_db) < -3.0 and float(vic.volume_db) > -30.0,
				"più grave e più piano (tono %.2f, %.1f dB)" % [vic.pitch_scale, vic.volume_db])
	await _secondi(0.75)
	check(not canto.canta(), "dopo circa 1 s è morto")
	lei.metti(LeiFinta.Fase.SILENZIO, &"silenzio")
	await _secondi(0.5)
	check(not canto.canta(), "nel silenzio niente")
	lei.metti(LeiFinta.Fase.ESCE, &"fuori")
	await _secondi(2.0)
	check(not canto.canta(), "mentre è fuori niente")

	print("Alla presa tace subito")
	lei.metti(LeiFinta.Fase.ARRIVA, &"arriva")
	await _aspetta_canto()
	lei.metti(LeiFinta.Fase.PRESA, &"fuori")
	await _secondi(0.15)
	check(not canto.canta(), "alla PRESA tace entro 0,15 s")

	print("«va_via»: torna lontano; mai la stessa frase due volte di fila")
	lei.metti(LeiFinta.Fase.SCENDE, &"va_via")
	lei.vicinanza = 0.2
	var frasi_sentite: Array = []
	var ultimo_partito := -1.0
	var tempo := 0.0
	while frasi_sentite.size() < 4 and tempo < 60.0:
		await get_tree().process_frame
		tempo += get_process_delta_time()
		if canto.canta() and float(canto.partito) != ultimo_partito:
			ultimo_partito = float(canto.partito)
			frasi_sentite.append(String((canto.lon as Node).get(&"stream").resource_path))
	check(frasi_sentite.size() >= 4, "in «va_via» canta (%d frasi in %.0f s)" % [frasi_sentite.size(), tempo])
	var ripetute := 0
	for i in range(1, frasi_sentite.size()):
		if frasi_sentite[i] == frasi_sentite[i - 1]:
			ripetute += 1
	check(ripetute == 0, "due frasi di fila non sono mai la stessa (%s)" % [frasi_sentite.map(func(p): return p.get_file())])
	if not frasi_sentite.is_empty():
		check(float(canto.lon.volume_db) > float(canto.vic.volume_db), "in «va_via» più lontana che vicina")

	print("«ferma»")
	await _aspetta_canto()
	lei.metti(LeiFinta.Fase.CALMA, &"ferma")
	await _secondi(0.7)
	check(not canto.canta(), "in «ferma» si spegne")

	print("Il giro della luce (la lezione nella sala pompe)")
	gioc.global_position = Vector3(40, 0, 0)
	lei.metti(LeiFinta.Fase.LONTANA, &"lontana")
	lei.giro = true
	lei.vicinanza = 0.0
	await _aspetta_canto()
	check(canto.canta(), "col giro canta anche col giocatore lontano dai punti")
	lei.fase_canto = &"arriva"
	lei.vicinanza = 0.8
	await _secondi(0.6)
	if canto.canta():
		check(float(canto.vic.volume_db) > -1.0, "a vicinanza 0,8 nel giro è tutto vicino (%.1f dB)" % canto.vic.volume_db)
	lei.giro = false
	lei.metti(LeiFinta.Fase.LONTANA, &"lontana")
	await _secondi(0.7)
	check(not canto.canta(), "finito il giro (giocatore lontano dai punti) si spegne")

	print("Due acque: si segue quella dove lei è adesso")
	gioc.global_position = Vector3(8, 0, 0)
	var altra := _acqua(Vector3(30, 0, 0))
	altra.metti(LeiFinta.Fase.ARRIVA, &"arriva")
	altra.vicinanza = 0.3
	await _secondi(0.2)
	check(canto.lei == altra, "segue l'acqua dove lei arriva, anche se il giocatore è più vicino all'altra")
	await _aspetta_canto()
	altra.metti(LeiFinta.Fase.SPEGNE, &"spegne")
	await _secondi(1.2)
	altra.metti(LeiFinta.Fase.SILENZIO, &"silenzio")
	await _secondi(0.3)
	check(canto.lei == altra and not canto.canta(), "e quando lì sta per uscire, non canta dall'acqua vicina")
	altra.queue_free()

	print("Oblò con lei dietro il vetro")
	lei.queue_free()
	await _secondi(0.7)
	check(not canto.canta(), "lei sparita: il canto si spegne")
	var oblo := ObloFinto.new()
	add_child(oblo)
	oblo.global_position = Vector3(16, 1, 3)
	canto.obli.append(oblo)
	await _secondi(3.0)
	check(not canto.canta(), "oblò vuoto (lei non è comparsa): niente")
	oblo.stato = 1
	await _aspetta_canto()
	await _secondi(0.5)
	check(canto.canta() and canto.fase == &"oblo", "lei dietro il vetro: canta")
	if canto.canta():
		check(float(canto.lon.volume_db) <= -11.5 and float(canto.vic.volume_db) < -40.0,
				"si sente appena: solo la lontana, sotto di 12 dB (%.1f e %.1f dB)" % [canto.lon.volume_db, canto.vic.volume_db])
	oblo.stato = 3
	await _secondi(0.7)
	check(not canto.canta(), "lei se ne va dal vetro: il canto si spegne")
	oblo.queue_free()

	classe.prova = []
	classe.giocatore_prova = null
	GameState.luci = luci_prima
	_fine()


func _aspetta_silenzio() -> void:
	var t := 0.0
	while t < 15.0 and canto.canta():
		await get_tree().process_frame
		t += get_process_delta_time()


func _aspetta_canto() -> void:
	var t := 0.0
	while t < 15.0 and not canto.canta():
		await get_tree().process_frame
		t += get_process_delta_time()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
