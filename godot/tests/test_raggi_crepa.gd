extends Node3D
## La crepa dei raggi (ricontrollo di ambienti-2 del 29 ottobre): il test raggio-triangolo di Jolt non è a tenuta, e un
## raggio a meno di qualche millesimo di millimetro da un lato condiviso fra due triangoli passa in mezzo e trova quello
## che c'è sotto. Qui un fondo di due metà che si toccano a x = 0, come quello della piscina, e un pavimento 2,4 m sotto:
## 1. il raggio solo, a x = 1e-7, passa dalla crepa (se un giorno Jolt non lo fa più, lo scrive e basta);
## 2. RaggioSicuro trova il fondo su tutta la crepa, e fuori dalla crepa dà lo stesso risultato del raggio solo: raggi a
##    caso sul fondo, sul bordo di un tavolo (1 mm fuori dallo spigolo trova il pavimento, come il raggio solo) e in
##    orizzontale contro un muro;
## 3. chi cerca un appoggio con un raggio, messo proprio sulla crepa, resta sul fondo: Posa, la Polaroid, la pozza, la
##    bava rosa, le gocce e la griglia del fondo delle medusine.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_raggi_crepa.gd

const SOTTO := -4.55
## Un raggio a questa x passa dalla crepa del fondo (fra 1e-12 e 1e-7 sì, a 1e-6 non più).
const CREPA := 1e-7

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


## Il fondo: un po' curvo come quello della piscina, due metà (x da -2 a 0 e da 0 a 2) che si toccano a x = 0.
static func fondo(x: float, z: float) -> float:
	return -2.2 + 0.01 * z * z - 0.003 * x * x


func _corpo(forma: Shape3D, dove: Vector3) -> StaticBody3D:
	var c := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = forma
	c.add_child(cs)
	c.position = dove
	add_child(c)
	return c


func _scena() -> void:
	var f := PackedVector3Array()
	for zi in 7:
		var z0 := 0.8 + zi * 0.7
		var z1 := z0 + 0.7
		for xs in [[-2.0, 0.0], [0.0, 2.0]]:
			var a := Vector3(xs[0], fondo(xs[0], z0), z0)
			var b := Vector3(xs[1], fondo(xs[1], z0), z0)
			var c := Vector3(xs[1], fondo(xs[1], z1), z1)
			var d := Vector3(xs[0], fondo(xs[0], z1), z1)
			f.append_array([a, b, c, a, c, d])
	var s := ConcavePolygonShape3D.new()
	s.set_faces(f)
	_corpo(s, Vector3.ZERO)
	var pavimento := BoxShape3D.new()
	pavimento.size = Vector3(20, 0.2, 20)
	_corpo(pavimento, Vector3(0, SOTTO - 0.1, 3))
	# un tavolo (x da 3 a 4, piano a -1,5) e un muro (x = -3)
	var tavolo := BoxShape3D.new()
	tavolo.size = Vector3(1, 0.1, 1)
	_corpo(tavolo, Vector3(3.5, -1.55, 2.5))
	var muro := BoxShape3D.new()
	muro.size = Vector3(0.2, 3, 6)
	_corpo(muro, Vector3(-3.1, -1.0, 3))


func _run() -> void:
	_scena()
	for i in 3:
		await get_tree().physics_frame
	var spazio := get_world_3d().direct_space_state

	print("1. Il raggio solo sulla crepa")
	var giu := func(x: float, z: float) -> PhysicsRayQueryParameters3D:
		return PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, z), Vector3(x, -7.0, z))
	var solo := spazio.intersect_ray(giu.call(CREPA, 3.6))
	if not solo.is_empty() and (solo.position as Vector3).y < -4.0:
		print("  il raggio solo a x = 1e-7 passa dalla crepa e trova il pavimento sotto (%.3f)" % (solo.position as Vector3).y)
	else:
		print("  (il raggio solo a x = 1e-7 non passa più dalla crepa: %s)" % solo)

	print("2. RaggioSicuro")
	var peggio := 0.0
	for z in [1.35, 2.1, 3.6, 4.0, 5.1]:
		for x in [0.0, 1e-12, 1e-9, 1e-7, 1e-6, -1e-7]:
			var h := RaggioSicuro.interseca(spazio, giu.call(x, z))
			var y: float = (h.position as Vector3).y if not h.is_empty() else -99.0
			peggio = maxf(peggio, absf(y - _vero(z)))
	check(peggio < 0.001, "sulla crepa (x da -1e-7 a 1e-6) trova sempre il fondo (al più %.4f m di scarto)" % peggio)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var diversi := 0
	var provati := 0
	for k in 400:
		var x := rng.randf_range(-1.9, 1.9)
		if absf(x) < 0.0001:
			continue
		provati += 1
		var q: PhysicsRayQueryParameters3D = giu.call(x, rng.randf_range(0.9, 5.5))
		if not _uguali(spazio.intersect_ray(q), RaggioSicuro.interseca(spazio, q)):
			diversi += 1
	check(diversi == 0, "fuori dalla crepa, su %d raggi a caso, dà lo stesso del raggio solo (diversi: %d)" % [provati, diversi])
	diversi = 0
	for x in [3.999, 4.001, 3.0005, 2.9995, 4.002, 3.998]:
		for z in [2.2, 2.5, 2.999, 3.001]:
			var q: PhysicsRayQueryParameters3D = giu.call(x, z)
			if not _uguali(spazio.intersect_ray(q), RaggioSicuro.interseca(spazio, q)):
				diversi += 1
	var fuori := RaggioSicuro.interseca(spazio, giu.call(4.001, 2.5))
	check(diversi == 0 and not fuori.is_empty() and (fuori.position as Vector3).y < -4.0,
		"sul bordo di un tavolo dà lo stesso del raggio solo (1 mm fuori dallo spigolo il pavimento, %.3f; diversi: %d)" % [
		(fuori.position as Vector3).y if not fuori.is_empty() else 0.0, diversi])
	diversi = 0
	for k in 20:
		var da := Vector3(-2.5, rng.randf_range(-2.0, 0.0), rng.randf_range(1.0, 5.0))
		var q := PhysicsRayQueryParameters3D.create(da, da + Vector3(-2.0, rng.randf_range(-0.3, 0.3), 0.0))
		if not _uguali(spazio.intersect_ray(q), RaggioSicuro.interseca(spazio, q)):
			diversi += 1
	check(diversi == 0, "in orizzontale contro un muro dà lo stesso del raggio solo (diversi: %d)" % diversi)

	print("3. Chi cerca un appoggio, messo proprio sulla crepa")
	var cosa := Node3D.new()
	add_child(cosa)
	cosa.global_position = Vector3(CREPA, -1.9, 3.6)
	Posa.appoggia_a_terra(cosa)
	check(absf(cosa.global_position.y - _vero(3.6)) < 0.001, "Posa la appoggia sul fondo (y %.3f, fondo %.3f)" % [cosa.global_position.y, _vero(3.6)])
	var foto := (load(PolaroidPhoto.SCENA) as PackedScene).instantiate() as PolaroidPhoto
	foto.photo = 1
	foto.snap_to_surface = true
	foto.position = Vector3(CREPA, -1.8, 2.1)
	add_child(foto)
	var pozza := WaterPuddle.new()
	pozza.position = Vector3(CREPA, -1.8, 4.0)
	pozza.size = Vector2(0.3, 0.3)
	add_child(pozza)
	var gocce := Gocce.new()
	gocce.position = Vector3(CREPA, -1.0, 5.1)
	add_child(gocce)
	var bava := BavaRosa.new()
	add_child(bava)
	for i in 6:
		await get_tree().physics_frame
	# (la Polaroid 4 mm sopra, come lo snap di sempre, e alzata se un angolo entra)
	check(foto.global_position.y - _vero(2.1) > 0.0 and foto.global_position.y - _vero(2.1) < 0.008, "la Polaroid si appoggia sul fondo (y %.3f, fondo %.3f)" % [foto.global_position.y, _vero(2.1)])
	check(absf(pozza.global_position.y - _vero(4.0)) < 0.001, "la pozza si appoggia sul fondo (y %.3f, fondo %.3f)" % [pozza.global_position.y, _vero(4.0)])
	check(absf(gocce.altezza - (-1.0 - _vero(5.1))) < 0.001, "le gocce cadono fino al fondo (%.3f m)" % gocce.altezza)
	var punto: Vector3 = bava.call(&"_a_terra", Vector3(CREPA, _vero(1.35) + 0.1, 1.35))
	check(absf(punto.y - _vero(1.35) - bava.sollevamento) < 0.001, "la bava rosa si appoggia sul fondo (y %.3f, fondo %.3f)" % [punto.y, _vero(1.35)])
	# la griglia del fondo delle medusine: una vasca stretta (3 colonne) centrata appena a destra di x = 0, così la colonna
	# di mezzo cade sulla crepa; si cerca il centro con cui il raggio solo lì passa davvero dalla crepa
	var vasca := WaterTank.new()
	vasca.build_walls = false
	vasca.inner_size = Vector3(0.5, 0.5, 4.2)
	add_child(vasca)
	var med := Medusine.new()
	med.vasca = vasca
	add_child(med)
	var trovata := false
	var scarto := 0.0
	for centro in [1.5e-8, 3e-8, 6e-8, 1e-7, 2e-7]:
		vasca.position = Vector3(centro, -2.4, 3.0)
		await get_tree().physics_frame
		med.call(&"_costruisci_griglia")
		var g: PackedFloat32Array = med.get(&"_griglia")
		var g_min: Vector2 = med.get(&"_g_min")
		var g_n: Vector2i = med.get(&"_g_n")
		var xc := Vector3(g_min.x + Medusine.PASSO, 0.0, 0.0).x
		var passa := false
		scarto = 0.0
		for j in g_n.y:
			var z := Vector3(0.0, 0.0, minf(g_min.y + j * Medusine.PASSO, g_min.y + vasca.inner_size.z)).z
			var h := spazio.intersect_ray(giu.call(xc, z))
			passa = passa or h.is_empty() or (h.position as Vector3).y < -4.0
			scarto = maxf(scarto, absf(g[j * g_n.x + 1] - _vero(z)))
		if passa:
			print("  vasca centrata a x = %s: la colonna di mezzo è a x = %s, e lì il raggio solo passa dalla crepa" % [centro, xc])
			trovata = true
			break
	if not trovata:
		print("  (nessuna delle vasche prova la crepa: il raggio solo non ci passa)")
	check(scarto < 0.001, "la griglia delle medusine sulla crepa segue il fondo (al più %.4f m di scarto)" % scarto)
	_fine()


## Il fondo vero (i triangoli, non la curva da cui vengono) alla [param z], accanto alla crepa: il raggio solo a x = -1e-5.
func _vero(z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(-1e-5, 1.0, z), Vector3(-1e-5, -7.0, z))
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3).y if not h.is_empty() else -99.0


func _uguali(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return a.is_empty() == b.is_empty()
	return (a.position as Vector3).distance_to(b.position as Vector3) < 0.000001 and a.collider == b.collider


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _fine() -> void:
	print("\nRISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
