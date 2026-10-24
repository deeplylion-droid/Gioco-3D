extends Node
## Test delle forme che si muovono della morbidezza (i galleggianti che ondeggiano, il portello del tunnel): una scatola
## legata a un nodo segue il nodo (spostato e girato), si trova nella zona giusta anche con tante forme ferme (la
## griglia), se ne va quando il nodo sparisce o si toglie. Veloce, senza scene.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_morbidezza_mobili.gd

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


## Vero se il punto è dentro la forma (tutti i piani verso fuori lo lasciano dietro).
func _dentro(fo: Array, p: Vector3) -> bool:
	for pl in fo[0]:
		if (pl as Plane).distance_to(p) > 0.0:
			return false
	return true


func _run() -> void:
	var m := MorbidezzaLei.new()
	add_child(m)
	# tante forme ferme lontane, così si usa la griglia
	for i in 40:
		m.aggiungi_scatola(Transform3D(Basis(), Vector3(100.0 + i * 2.0, 0, 0)), Vector3(0.5, 0.5, 0.5))
	var gommone := Node3D.new()
	add_child(gommone)
	gommone.global_position = Vector3(5, 0, 0)
	m.aggiungi_scatola_mobile(gommone, Transform3D(), Vector3(1.0, 0.25, 0.6))
	var zona := AABB(Vector3(4, -1, -1), Vector3(2, 2, 2))
	var trovate: Array = m.call(&"_forme_zona", zona)
	_check(trovate.size() == 1 and _dentro(trovate[0], Vector3(5.9, 0, 0)), "la scatola che si muove è dove è il nodo")
	# il nodo si sposta e si inclina (un'onda)
	gommone.global_position = Vector3(5, 0.4, 3)
	gommone.rotation = Vector3(0, 0, deg_to_rad(20))
	m.call(&"_aggiorna_mobili")
	trovate = m.call(&"_forme_zona", zona)
	_check(trovate.is_empty(), "spostato il nodo, al posto di prima non c'è più")
	trovate = m.call(&"_forme_zona", AABB(Vector3(4, -1, 2), Vector3(2, 2, 2)))
	var p := gommone.global_transform * Vector3(0.9, 0.2, 0.5)
	var fuori := gommone.global_transform * Vector3(0.9, 0.3, 0.5)
	_check(trovate.size() == 1 and _dentro(trovate[0], p) and not _dentro(trovate[0], fuori),
			"la scatola segue il nodo spostato e girato (dentro e fuori giusti, al cm)")
	_check((m.call(&"_forme_in", p, []) as Array).size() == 1, "la ricerca per punto (griglia) trova la forma che si muove")
	# la faccia di sopra (forma bassa): quella del nodo, anche inclinata
	_check(int(trovate[0][2]) >= 0 and (trovate[0][0][int(trovate[0][2])] as Plane).normal.dot(gommone.global_basis.y) > 0.99,
			"la faccia di sopra è quella del gommone anche inclinato")
	m.togli_mobili(gommone)
	_check((m.call(&"_forme_zona", AABB(Vector3(4, -1, 2), Vector3(2, 2, 2))) as Array).is_empty(), "tolta col nodo")
	m.aggiungi_scatola_mobile(gommone, Transform3D(), Vector3.ONE)
	gommone.free()
	m.call(&"_aggiorna_mobili")
	_check((m.get(&"_mobili") as Array).is_empty(), "il nodo sparisce, la forma se ne va")
	_check((m.get(&"_forme") as Array).size() == 40, "le forme ferme restano (40)")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
