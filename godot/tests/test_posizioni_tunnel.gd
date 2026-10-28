extends Node
## Test: le scorciatoie dei blocchi al primo avvio (25 ottobre) non spostano niente nel tunnel sottomarino. Si costruisce
## il tunnel due volte, come nel gioco (a pezzi): prima senza scorciatoie (SalaSottomarino.senza_scorciatoie: sporgenze e
## appoggi su tutte le facce, forme convesse calcolate sul momento, com'era prima), poi con le scorciatoie (involucro
## convesso, forme salvate e caricate col thread). Ogni nodo deve stare nello stesso posto: scarto massimo sotto
## [constant SCARTO] (richiesta del coordinatore), stesse forme di collisione.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_posizioni_tunnel.gd

const SCARTO := 0.001
## Quello che si muove da solo mentre si costruisce (galleggia o è animato): non conta.
const MOBILI := ["Gommoni", "LeiTunnel"]

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


func _costruisci(senza: bool) -> Array:
	SalaSottomarino.senza_scorciatoie = senza
	SalaSottomarino._forme_convesse.clear()
	SottomarinoArrediA2._involucri.clear()
	var scena := load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene
	var s := scena.instantiate() as Node3D
	add_child(s)
	await s.call(&"costruisci_a_pezzi")
	# (i nomi automatici, "@Node3D@123", cambiano fra una costruzione e l'altra: si confronta nell'ordine dell'albero)
	var out: Array = []
	for n in s.find_children("*", "Node3D", true, false):
		var x := n as Node3D
		var forma := ""
		if x is CollisionShape3D and (x as CollisionShape3D).shape is ConvexPolygonShape3D:
			forma = str(((x as CollisionShape3D).shape as ConvexPolygonShape3D).points)
		out.append([x.get_class(), String(s.get_path_to(x)), x.global_transform, forma])
	s.free()
	return out


func _run() -> void:
	Game.pause_on_focus_loss = false
	var tenuti: Array = []
	for r in SalaSottomarino.risorse():
		tenuti.append(load(r))
	var prima: Array = await _costruisci(true)
	var dopo: Array = await _costruisci(false)
	SalaSottomarino.senza_scorciatoie = false
	check(prima.size() == dopo.size(), "stessi nodi (%d e %d)" % [prima.size(), dopo.size()])
	var peggio := 0.0
	var dove := ""
	var giri := 0.0
	var forme_diverse := 0
	var classi_diverse := 0
	for i in mini(prima.size(), dopo.size()):
		if prima[i][0] != dopo[i][0]:
			classi_diverse += 1
			continue
		if MOBILI.any(func(m: String) -> bool: return String(dopo[i][1]).begins_with(m)):
			continue
		var a: Transform3D = prima[i][2]
		var b: Transform3D = dopo[i][2]
		var d := a.origin.distance_to(b.origin)
		if d > peggio:
			peggio = d
			dove = dopo[i][1]
		for k in 3:
			giri = maxf(giri, (a.basis[k] - b.basis[k]).length())
		if prima[i][3] != dopo[i][3]:
			forme_diverse += 1
	check(classi_diverse == 0, "stessi tipi nello stesso ordine (%d diversi)" % classi_diverse)
	check(peggio <= SCARTO and giri <= SCARTO, "ogni nodo fermo nello stesso posto: scarto massimo %.4f mm (%s), rotazione %.6f" % [peggio * 1000.0, dove, giri])
	check(forme_diverse == 0, "stesse forme di collisione (%d diverse)" % forme_diverse)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
