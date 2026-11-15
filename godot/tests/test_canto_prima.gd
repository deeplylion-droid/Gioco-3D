extends Node
## Test del canto di lei prima del tunnel (addon audio, classe CantoPrima; 0.4.0, «L'acqua è sua», scelta A del 15
## novembre). Finché l'utente non dà il sì agli esempi le frasi vere (lei_canto_prima_lontano_NN e _vicino_NN) non sono
## nel catalogo: il test usa al loro posto due coppie di file che ci sono (CantoPrima.prova). Una lei finta nel gruppo
## lei_nell_acqua (vicinanza, punto_luce, fase, dietro_vetro, i nomi concordati con mascotte):
## - senza le frasi non suona niente e non ci sono errori;
## - prima che si riaccendano le pompe (GameState.luci = PRIMA_DEL_RISVEGLIO) non canta;
## - dopo, nella fase "lontana" canta entro 2,5 s: la frase lontana piena, la vicina giù;
## - con la vicinanza a 1 la vicina sale e la lontana scende, e la vicina sta alla luce rosa (punto_luce);
## - nella fase "silenzio" tace di colpo (entro 0,15 s), e anche in "fuori" e "respinta";
## - torna a cantare in "va_via", e due frasi di fila non sono mai la stessa;
## - dietro il vetro di un oblò si sente appena: solo la lontana, almeno 12 dB sotto;
## - fra due lei si segue la più vicina; se lei sparisce (nodo liberato) il canto si spegne.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_canto_prima.gd

const Catalogo := preload("res://addons/audio/catalogo.gd")


class LeiFinta extends Node3D:
	var vicinanza := 0.0
	var punto_luce := Vector3.ZERO
	var fase: StringName = &"ferma"
	var dietro_vetro := false


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
	var lei := LeiFinta.new()
	lei.add_to_group(&"lei_nell_acqua")
	add_child(lei)
	lei.global_position = Vector3(5, 0, 0)
	lei.punto_luce = Vector3(4, -0.5, 1)

	print("Senza le frasi nel catalogo")
	classe.prova = []
	var vere: Array = Catalogo.SUONI.get(&"lei_canto_prima_lontano", [])
	check(vere.is_empty(), "le frasi vere non sono ancora nel catalogo (prima il sì dell'utente)")
	lei.fase = &"lontana"
	await _secondi(3.0)
	check(not canto.canta(), "lei nell'acqua, ma non suona niente")

	# due coppie di file che ci sono, al posto delle frasi vere
	var t: Array = Catalogo.SUONI.get(&"lei_tunnel_canto", [])
	classe.prova = [[t[0], t[1]], [t[2], t[3]]]

	print("Prima che si riaccendano le pompe")
	GameState.luci = GameState.Luci.PRIMA_DEL_RISVEGLIO
	await _secondi(3.0)
	check(not canto.canta(), "con le luci di prima del risveglio non canta")
	GameState.luci = GameState.Luci.BLACKOUT

	print("Lontana, nei tubi")
	lei.vicinanza = 0.0
	var t0 := 0.0
	while t0 < 2.6 and not canto.canta():
		await get_tree().process_frame
		t0 += get_process_delta_time()
	check(canto.canta(), "nella fase lontana canta entro 2,5 s (%.1f s)" % t0)
	await _secondi(0.5)
	var lon: Node = canto.lon
	var vic: Node = canto.vic
	check(is_instance_valid(lon) and is_instance_valid(vic), "due lettori: la frase lontana e la stessa vicina")
	if is_instance_valid(lon) and is_instance_valid(vic):
		check(float(lon.volume_db) > -1.0 and float(vic.volume_db) < -40.0,
				"lontana piena e vicina giù (%.1f e %.1f dB)" % [lon.volume_db, vic.volume_db])
		check(not (lon is AudioStreamPlayer3D) and vic is AudioStreamPlayer3D, "la lontana non posizionale, la vicina in 3D")

	print("Si avvicina")
	lei.vicinanza = 1.0
	lei.punto_luce = Vector3(2, -0.4, 0.5)
	await _secondi(0.6)
	if canto.canta():
		lon = canto.lon
		vic = canto.vic
		check(float(vic.volume_db) > -1.0 and float(lon.volume_db) < -30.0,
				"vicina piena e lontana giù (%.1f e %.1f dB)" % [vic.volume_db, lon.volume_db])
		check((vic as Node3D).global_position.distance_to(lei.punto_luce) < 0.01, "la vicina viene dalla luce rosa")
	else:
		# (la frase di prova può essere finita: aspetta la prossima)
		await _secondi(5.5)
		check(canto.canta() and float(canto.vic.volume_db) > -1.0, "vicina piena alla frase dopo")

	print("Silenzio: sta per uscire")
	await _aspetta_canto()
	lei.fase = &"silenzio"
	await _secondi(0.15)
	check(not canto.canta(), "nella fase di silenzio tace entro 0,15 s")
	await _secondi(4.0)
	check(not canto.canta(), "e resta zitto finché è in silenzio")
	for f in [&"fuori", &"respinta"]:
		lei.fase = &"lontana"
		await _aspetta_canto()
		lei.fase = f
		await _secondi(0.15)
		check(not canto.canta(), "in \"%s\" tace di colpo" % f)

	print("Se ne va: riprende, mai la stessa frase due volte di fila")
	lei.fase = &"va_via"
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
	check(frasi_sentite.size() >= 4, "nella fase va_via riprende a cantare (%d frasi in %.0f s)" % [frasi_sentite.size(), tempo])
	var ripetute := 0
	for i in range(1, frasi_sentite.size()):
		if frasi_sentite[i] == frasi_sentite[i - 1]:
			ripetute += 1
	check(ripetute == 0, "due frasi di fila non sono mai la stessa (%s)" % [frasi_sentite.map(func(p): return p.get_file())])

	print("Dietro il vetro di un oblò")
	lei.dietro_vetro = true
	lei.vicinanza = 1.0
	await _aspetta_canto()
	await _secondi(0.8)
	if canto.canta():
		check(float(canto.lon.volume_db) <= -11.5 and float(canto.vic.volume_db) < -40.0,
				"si sente appena: solo la lontana, sotto di 12 dB (%.1f e %.1f dB)" % [canto.lon.volume_db, canto.vic.volume_db])
	lei.dietro_vetro = false

	print("Due lei: si segue la più vicina")
	var altra := LeiFinta.new()
	altra.add_to_group(&"lei_nell_acqua")
	add_child(altra)
	altra.fase = &"arriva"
	altra.vicinanza = 0.9
	lei.vicinanza = 0.3
	await _secondi(0.2)
	check(canto.lei == altra, "segue la lei più vicina")
	altra.fase = &"silenzio"
	await _secondi(0.2)
	check(canto.lei == altra and not canto.canta(), "e se quella sta per uscire, tace (anche se l'altra è lontana nei tubi)")
	altra.queue_free()

	print("Lei sparisce")
	lei.fase = &"lontana"
	await _aspetta_canto()
	lei.queue_free()
	await _secondi(0.7)
	check(not canto.canta(), "il canto si spegne")

	classe.prova = []
	GameState.luci = luci_prima
	_fine()


func _aspetta_canto() -> void:
	var t := 0.0
	while t < 15.0 and not canto.canta():
		await get_tree().process_frame
		t += get_process_delta_time()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
