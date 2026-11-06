extends Node
## Test delle sagome del club nelle condotte dell'inseguimento (SagomeClub, scelta A dell'utente del 6 novembre; Jilly
## fra i disegni A), nella scena di prova scenes/test/inseguimento_prova.tscn:
## 1. Dodici sagome, quattro per vasca, ognuna con la sua texture a pastello; una nuova per vasca; i tre disegni di lei
##    (balena vecchia nella vasca 1, pesce palla nella 2, pesce nuovo nella 3).
## 2. Girate verso l'acqua della loro vasca, e si vedono dagli occhi del giocatore nella vasca (niente in mezzo).
## 3. Tenute su: il punto più basso tocca il bordo o il grigliato (entro 5 mm); quelle sul bordo hanno il puntello e
##    il mattone, quelle della vasca 2 due legature ai montanti; niente sospeso.
## 4. Fuori dai passaggi: lontane dalle bocche dei tubi, dalle paratie e da dove sale lei; nessuna collisione (non
##    fermano né il giocatore né il getto).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_sagome_club.gd

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"

var sala: SalaInseguimento
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
		printerr("  FALLITO tempo scaduto")
		_failed += 1
		_fine())


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


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 900:
		await get_tree().physics_frame
		var scena := get_tree().current_scene
		sala = scena.get_node_or_null(^"SalaInseguimento") as SalaInseguimento if scena else null
		if sala and sala.costruita:
			break
	if sala == null or not sala.costruita:
		check(false, "la sala dell'inseguimento si costruisce")
		_fine()
		return
	for i in 10:
		await get_tree().physics_frame
	var club := sala.get_node_or_null(^"SagomeClub") as SagomeClub
	check(club != null, "le sagome del club ci sono, nella sala dell'inseguimento")
	if club == null:
		_fine()
		return
	var sagome := club.sagome()

	print("1. Quante e quali")
	check(sagome.size() == 12, "dodici sagome (%d)" % sagome.size())
	var per_vasca := [0, 0, 0]
	var nuove := [0, 0, 0]
	var texture_ok := true
	for s in sagome:
		var v := int(s.get_meta(&"vasca")) - 1
		per_vasca[v] += 1
		if String(s.get_meta(&"eta")) == "nuova":
			nuove[v] += 1
		var m := s.get_surface_override_material(0) as StandardMaterial3D
		texture_ok = texture_ok and m != null and m.albedo_texture != null and m.emission_enabled \
				and m.emission_energy_multiplier <= 0.15
	check(per_vasca == [4, 4, 4], "quattro per vasca (%s)" % str(per_vasca))
	check(nuove == [1, 1, 1], "una nuova per vasca (%s)" % str(nuove))
	check(texture_ok, "ognuna col suo pastello e un filo di luce propria (al massimo 0,15)")
	var lei_nei_disegni := {"balena": [1, "vecchia"], "pesce_palla": [2, "media"], "pesce": [3, "nuova"]}
	var ok_lei := true
	for nome in lei_nei_disegni:
		var s := club.get_node_or_null(NodePath("Sagoma_" + nome)) as MeshInstance3D
		ok_lei = ok_lei and s != null and int(s.get_meta(&"vasca")) == lei_nei_disegni[nome][0] \
				and String(s.get_meta(&"eta")) == lei_nei_disegni[nome][1]
	check(ok_lei, "lei fra i disegni: la mascotte sulla balena vecchia (vasca 1), alta sul pesce palla (2), l'occhio sul pesce nuovo (3)")

	print("2. Girate verso l'acqua, e si vedono dagli occhi")
	var spazio := sala.get_world_3d().direct_space_state
	var girate := 0
	var viste := 0
	for s in sagome:
		var v := int(s.get_meta(&"vasca")) - 1
		var occhi := _occhi(v)
		var c := (s.global_transform * s.get_aabb()).get_center()
		var z := s.global_transform.basis.z.normalized()
		if z.dot((Vector3(occhi.x, c.y, occhi.z) - c).normalized()) > 0.5:
			girate += 1
		# dagli occhi al centro della faccia: niente di solido in mezzo (le sagome non hanno collisioni)
		var q := PhysicsRayQueryParameters3D.create(occhi, c + z * 0.02, 0xFFFFFFFF)
		if RaggioSicuro.interseca(spazio, q).is_empty():
			viste += 1
		else:
			print("    coperta: ", s.name)
	check(girate == 12, "tutte girate verso la loro vasca (%d)" % girate)
	check(viste >= 11, "si vedono dagli occhi in mezzo alla vasca (%d su 12)" % viste)

	print("3. Tenute su")
	var appoggiate := 0
	for s in sagome:
		var basso := _punto_basso(s)
		var q := PhysicsRayQueryParameters3D.create(basso + Vector3.UP * 0.05, basso + Vector3.DOWN * 0.2, 0xFFFFFFFF)
		var hit := RaggioSicuro.interseca(spazio, q)
		var dist: float = basso.y - (hit["position"] as Vector3).y if not hit.is_empty() else 1.0
		if absf(dist) <= 0.005:
			appoggiate += 1
		else:
			print("    %s: il punto più basso è a %.4f m da sotto" % [s.name, dist])
	check(appoggiate == 12, "il punto più basso di ognuna tocca il bordo o il grigliato, entro 5 mm (%d)" % appoggiate)
	var puntelli := club.get_children().filter(func(n): return String(n.name).begins_with("Puntello")).size()
	var mattoni := club.get_children().filter(func(n): return String(n.name).begins_with("Mattone")).size()
	var legature := club.get_children().filter(func(n): return String(n.name).begins_with("Legatura")).size()
	check(puntelli == 16 and mattoni == 8, "le otto sul bordo col puntello, il suo piede e il mattone (%d, %d)" % [puntelli, mattoni])
	check(legature == 8, "le quattro della vasca 2 legate a due montanti ciascuna (%d legature)" % legature)

	print("4. Fuori dai passaggi")
	check(club.find_children("*", "CollisionObject3D", true, false).is_empty(), "nessuna collisione")
	var lontane := true
	var bocche: Array[Vector3] = []
	for nome in sala.dati["tubi"]:
		var pts: Array = sala.dati["tubi"][nome]
		bocche.append(SalaInseguimento.b(pts[pts.size() - 1]))
		bocche.append(SalaInseguimento.b(pts[0]))
	var paratie: Array[Vector3] = []
	for p in sala.dati["paratie"]:
		paratie.append(SalaInseguimento.b(p["bersaglio"]))
	var lei: Array[Vector3] = []
	for v in 3:
		lei.append(sala.call(&"_posto_vasca", v) as Vector3)
	for s in sagome:
		var box := s.global_transform * s.get_aabb()
		for c in bocche:
			if _dist_xz(box, c) < 0.5:
				lontane = false
				print("    %s vicina a una bocca (%.2f m)" % [s.name, _dist_xz(box, c)])
		for c in paratie:
			if _dist_xz(box, c) < 1.2:
				lontane = false
				print("    %s vicina a una paratia (%.2f m)" % [s.name, _dist_xz(box, c)])
		for c in lei:
			if _dist_xz(box, c) < 2.5:
				lontane = false
				print("    %s vicina a dove sale lei (%.2f m)" % [s.name, _dist_xz(box, c)])
	check(lontane, "lontane dalle bocche dei tubi (50 cm), dalle paratie (1,2 m) e da dove sale lei (2,5 m)")
	_fine()


func _occhi(v: int) -> Vector3:
	var d: Dictionary = sala.dati["vasche"][v]
	var r: Array = d["rett"]
	return Vector3((r[0] + r[2]) * 0.5, float(d["fondo"]) + 1.65, -(r[1] + r[3]) * 0.5)


func _punto_basso(s: MeshInstance3D) -> Vector3:
	var v := (s.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var giu := s.global_transform * v[0]
	for p in v:
		var w := s.global_transform * p
		if w.y < giu.y:
			giu = w
	return giu


## La distanza in pianta fra la scatola [param b] e il punto [param c].
func _dist_xz(b: AABB, c: Vector3) -> float:
	var dx := maxf(0.0, maxf(b.position.x - c.x, c.x - b.end.x))
	var dz := maxf(0.0, maxf(b.position.z - c.z, c.z - b.end.z))
	return sqrt(dx * dx + dz * dz)
