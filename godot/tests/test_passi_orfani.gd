extends Node
## Test: la costruzione a pezzi interrotta a metà non lascia nodi orfani (richiesta del coordinatore, 6 novembre).
## Le liste dei passi si fanno tutte prima di cominciare (SalaTorre.costruisci_a_pezzi, SalaInseguimento._passi): se un
## passi() crea il suo nodo subito e la costruzione si ferma prima del suo primo passo (la torre esce dall'albero a
## metà, una morte che ricarica la sala), il nodo non entra mai nell'albero e resta orfano fino alla chiusura.
## 1. fare la lista dei passi e buttarla senza eseguirla non lascia orfani;
## 2. eseguire solo il primo passo e poi togliere la sala non lascia orfani, e i passi dopo non fanno niente;
## 3. eseguiti tutti, gli stendardi sono nella sala.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_passi_orfani.gd

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _orfani() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _run() -> void:
	# 1. la lista fatta e buttata
	var sala := Node3D.new()
	add_child(sala)
	var prima := _orfani()
	var passi := StendardiInseguimento.passi(sala)
	passi.clear()
	passi = []
	await get_tree().process_frame
	check(_orfani() == prima, "stendardi: la lista dei passi buttata senza eseguirla non lascia orfani (%d prima, %d dopo)" % [prima, _orfani()])
	# (le sagome del club hanno lo stesso schema: lo diciamo, senza far fallire il test, è di un'altra squadra)
	prima = _orfani()
	var sagome := SagomeClub.passi(sala)
	sagome.clear()
	await get_tree().process_frame
	print("  info  sagome del club: %d orfani in più con la lista buttata" % (_orfani() - prima))
	# 2. solo il primo passo, poi la sala esce e viene liberata
	prima = _orfani()
	passi = StendardiInseguimento.passi(sala)
	passi[0].call()
	check(sala.get_node_or_null("Stendardi") != null, "stendardi: il primo passo mette il nodo nella sala")
	remove_child(sala)
	sala.free()
	for k in range(1, passi.size()):
		passi[k].call()
	passi.clear()
	await get_tree().process_frame
	check(_orfani() == prima, "stendardi: interrotta dopo il primo passo e liberata la sala, niente orfani (%d prima, %d dopo)" % [prima, _orfani()])
	# 3. tutti i passi
	sala = Node3D.new()
	add_child(sala)
	for p: Callable in StendardiInseguimento.passi(sala):
		p.call()
	var st := sala.get_node_or_null("Stendardi")
	var lenzuoli := st.find_children("stendardo_?", "MeshInstance3D", true, false) if st else []
	check(lenzuoli.size() == 4, "stendardi: eseguiti tutti i passi, 4 lenzuoli nella sala (%d)" % lenzuoli.size())
	check(lenzuoli.all(func(m): return (m as MeshInstance3D).visible and (m as MeshInstance3D).material_override != null),
		"stendardi: i lenzuoli sono visibili e hanno il loro materiale")
	sala.queue_free()
	await get_tree().process_frame
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
