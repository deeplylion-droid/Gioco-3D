extends Node
## Test automatico: i bambini (Bambino, bambino_cubo e bambino_agnello) camminano e corrono senza far scivolare i
## piedi (nota dell'utente sui bambini visti di sfuggita: "attenzione alle animazioni. falle bene"). Su un pavimento
## piatto, in camminata e in fuga (anche in curva, con la partenza da fermo), si guarda ogni fotogramma il piede che
## sta a terra (il più basso, entro 1,5 cm dal suo punto più basso e senza salire o scendere): nel mondo deve stare fermo, cioè la sua velocità
## in orizzontale deve restare sotto [constant SCIVOLA_MAX] m/s in media. E i piedi toccano il pavimento: il punto più
## basso dei piedi sta entro [constant TERRA_MAX] m dal pavimento.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambini_passi.gd

const SCENE := ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn"]
## Velocità media del piede a terra (m/s): il passo vero lo tiene fermo; prima l'agnellino scivolava a 0,15 m/s
## camminando e a 0,9 m/s correndo.
const SCIVOLA_MAX := 0.12
const SCIVOLA_MAX_CORSA := 0.35
const TERRA_MAX := 0.06

var _passed := 0
var _failed := 0
var _piede_min := 99.0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _run() -> void:
	Game.pause_on_focus_loss = false
	# un giocatore fermo lontano (i bambini lo cercano per lo sguardo e per scappare)
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(0, 0, -40)
	GameState.player = p
	for scena: String in SCENE:
		print(scena.get_file())
		await _prova(scena, "cammina")
		await _prova(scena, "corsa")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _prova(scena: String, cosa: String) -> void:
	var b := (load(scena) as PackedScene).instantiate() as Bambino
	b.modalita = Bambino.Modalita.OSSERVA
	b.distanza_fuga = 0.0
	b.libera_quando_sparisce = false
	add_child(b)
	b.visible = true
	b.global_position = Vector3.ZERO
	b.rotation.y = 0.0
	# un percorso con una curva a 60 gradi a metà, da fermo
	var punti: Array[Node3D] = []
	for q in [Vector3(0, 0, 3.0), Vector3(2.6, 0, 4.5), Vector3(5.0, 0, 6.0)]:
		var m := Marker3D.new()
		add_child(m)
		m.global_position = q
		punti.append(m)
	await get_tree().physics_frame
	var sk := b.get_node("Calmo").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var piedi := [sk.find_bone("LeftFoot"), sk.find_bone("RightFoot")]
	var punte := [sk.find_bone("LeftToeBase"), sk.find_bone("RightToeBase")]
	if cosa == "cammina":
		b.cammina(punti)
	else:
		b.punti_fuga = punti
		b.sparisce_fuori_vista = false
		b.scappa_ora()
	var prima := {}
	_piede_min = 99.0
	var somma := 0.0
	var n := 0
	var minimo := 99.0
	var t := 0.0
	var dt := 1.0 / 60.0
	while t < 30.0 and b.modalita != Bambino.Modalita.SPARITO and b.modalita != Bambino.Modalita.OSSERVA:
		await get_tree().physics_frame
		t += dt
		var pos := {}
		var basso_piede := 99.0
		for o in piedi:
			pos[o] = sk.global_transform * sk.get_bone_global_pose(o).origin
			basso_piede = minf(basso_piede, pos[o].y)
		for o in punte:
			minimo = minf(minimo, (sk.global_transform * sk.get_bone_global_pose(o).origin).y)
		# il piede più basso è quello a terra; solo dopo il primo mezzo secondo (la partenza fonde dal fermo)
		var basso: int = piedi[0] if pos[piedi[0]].y < pos[piedi[1]].y else piedi[1]
		_piede_min = minf(_piede_min, basso_piede)
		# a terra: vicino al punto più basso e senza salire o scendere (il piede in volo che passa basso non conta)
		if t > 0.5 and prima.has(basso) and pos[basso].y < _piede_min + 0.015:
			var d: Vector3 = pos[basso] - prima[basso]
			if absf(d.y) / dt < 0.25:
				somma += Vector2(d.x, d.z).length() / dt
				n += 1
		prima = pos
	var media := somma / maxf(n, 1)
	var limite := SCIVOLA_MAX if cosa == "cammina" else SCIVOLA_MAX_CORSA
	check(n > 10 and media < limite, "%s: il piede a terra scivola in media di %.2f m/s (al più %.2f; %d campioni)" % [cosa, media, limite, n])
	check(absf(minimo) < TERRA_MAX, "%s: le punte dei piedi toccano terra (la più bassa a %+.3f m dal pavimento)" % [cosa, minimo])
	b.queue_free()
	for m in punti:
		m.queue_free()
	await get_tree().physics_frame
