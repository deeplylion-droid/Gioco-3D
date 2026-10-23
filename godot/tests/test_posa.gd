extends Node
## Test di Posa (scripts/posizionamento/posa.gd, lo strumento comune per mettere gli oggetti): su un pavimento, un
## muro e un soffitto finti, appoggia_a_terra, fissa_al_muro, fissa_al_soffitto e appendi_a mettono l'oggetto a
## contatto e, con lega, lo fanno figlio del sostegno (se il sostegno si sposta, l'oggetto lo segue); senza sostegno
## lasciano l'oggetto dov'è e restituiscono false.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_posa.gd

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _corpo(nome: String, dove: Vector3, misure: Vector3) -> StaticBody3D:
	var c := StaticBody3D.new()
	c.name = nome
	c.collision_layer = Layers.WORLD
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = misure
	f.shape = b
	c.add_child(f)
	add_child(c)
	c.global_position = dove
	return c


func _run() -> void:
	var pavimento := _corpo("Pavimento", Vector3(0, -0.5, 0), Vector3(20, 1, 20))     # cima a y 0
	var muro := _corpo("Muro", Vector3(5.5, 2, 0), Vector3(1, 4, 20))                  # faccia a x 5
	_corpo("Soffitto", Vector3(0, 4.5, 0), Vector3(20, 1, 20))                         # sotto a y 4
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("appoggia_a_terra")
	var vaso := Node3D.new()
	add_child(vaso)
	vaso.global_position = Vector3(1, 1.3, 1)
	check(Posa.appoggia_a_terra(vaso, 0.0, true) and is_equal_approx(vaso.global_position.y, 0.0),
		"il vaso scende sul pavimento (y %.3f)" % vaso.global_position.y)
	check(vaso.get_parent() == pavimento, "con lega diventa figlio del pavimento")
	pavimento.global_position += Vector3(0, 0.2, 0)
	check(is_equal_approx(vaso.global_position.y, 0.2), "il pavimento si alza di 20 cm e il vaso lo segue")
	pavimento.global_position -= Vector3(0, 0.2, 0)
	var cassa := Node3D.new()
	add_child(cassa)
	cassa.global_position = Vector3(2, 2.0, 2)
	Posa.appoggia_a_terra(cassa, 0.25)
	check(is_equal_approx(cassa.global_position.y, 0.25) and cassa.get_parent() == self,
		"con fondo 0,25 l'origine resta 25 cm sopra il pavimento; senza lega il genitore non cambia")

	print("fissa_al_muro")
	var quadro := Node3D.new()
	add_child(quadro)
	quadro.global_position = Vector3(4.6, 1.6, 0)
	check(Posa.fissa_al_muro(quadro, Vector3.LEFT, 0.02, true) and is_equal_approx(quadro.global_position.x, 4.98),
		"il quadro va contro il muro, col retro 2 cm dietro l'origine (x %.3f)" % quadro.global_position.x)
	check(quadro.get_parent() == muro, "con lega diventa figlio del muro")
	var dentro := Node3D.new()
	add_child(dentro)
	dentro.global_position = Vector3(5.1, 1.0, 3)
	Posa.fissa_al_muro(dentro, Vector3.LEFT, 0.0)
	check(is_equal_approx(dentro.global_position.x, 5.0), "un oggetto già un po' dentro il muro torna a filo (x %.3f)" % dentro.global_position.x)

	print("la superficie che si vede, non la collisione")
	# come il muro della vasca centrale (mascotte, 22 ottobre): la collisione sporge 3 cm oltre le piastrelle
	_corpo("MuroVasca", Vector3(-5.5, 2, 0), Vector3(1, 4, 20))                        # collisione: faccia a x -5
	var piastrelle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 4, 20)
	piastrelle.mesh = bm
	add_child(piastrelle)
	piastrelle.global_position = Vector3(-5.53, 2, 0)                                  # si vede: faccia a x -5,03
	var targa := Node3D.new()
	add_child(targa)
	targa.global_position = Vector3(-4.6, 1.6, 0)
	check(Posa.fissa_al_muro(targa, Vector3.RIGHT, 0.02, true) and is_equal_approx(snappedf(targa.global_position.x, 0.0001), -5.01),
		"la targa va sulle piastrelle, non sulla collisione 3 cm più avanti (x %.3f)" % targa.global_position.x)
	check(targa.get_parent() == piastrelle, "con lega diventa figlia della mesh che la regge")
	var tappeto := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(2, 0.02, 2)
	tappeto.mesh = tm
	add_child(tappeto)
	tappeto.global_position = Vector3(-3, 0.01, 4)                                     # un tappeto senza collisione sul pavimento
	var vaso2 := Node3D.new()
	add_child(vaso2)
	vaso2.global_position = Vector3(-3, 1.0, 4)
	check(Posa.appoggia_a_terra(vaso2) and is_equal_approx(snappedf(vaso2.global_position.y, 0.0001), 0.02),
		"un vaso va sul tappeto che si vede, anche se il tappeto non ha collisione (y %.3f)" % vaso2.global_position.y)

	print("fissa_al_soffitto e appendi_a")
	var plafoniera := Node3D.new()
	add_child(plafoniera)
	plafoniera.global_position = Vector3(-2, 3.0, 0)
	check(Posa.fissa_al_soffitto(plafoniera, 0.1) and is_equal_approx(plafoniera.global_position.y, 3.9),
		"la plafoniera sale al soffitto, la cima 10 cm sopra l'origine (y %.3f)" % plafoniera.global_position.y)
	var gancio := Node3D.new()
	add_child(gancio)
	gancio.global_position = Vector3(-3, 3.5, 1)
	var lampada := Node3D.new()
	add_child(lampada)
	Posa.appendi_a(lampada, gancio, 0.3)
	check(lampada.get_parent() == gancio and lampada.global_position.is_equal_approx(Vector3(-3, 3.2, 1)),
		"la lampada è appesa al gancio, l'attacco 30 cm sopra l'origine")
	gancio.global_position += Vector3(1, 0, 0)
	check(lampada.global_position.is_equal_approx(Vector3(-2, 3.2, 1)), "il gancio si sposta e la lampada lo segue")

	print("senza sostegno")
	var nel_vuoto := Node3D.new()
	add_child(nel_vuoto)
	nel_vuoto.global_position = Vector3(30, 1, 30)
	check(not Posa.appoggia_a_terra(nel_vuoto) and nel_vuoto.global_position.is_equal_approx(Vector3(30, 1, 30)),
		"fuori dal pavimento: false e l'oggetto resta dov'è")
	_fine()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)
