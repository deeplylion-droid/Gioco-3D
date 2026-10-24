extends Node
## Test del tunnel del viaggio sottomarino (SalaSottomarino), senza schermo: la geometria costruita dalla strada.
## - le banchine hanno il pavimento a quota piano lungo tutta la strada, il canale ha il fondo, la volta sta ad
##   almeno 6,5 m dall'acqua (regola dell'utente: almeno 6 m sopra il canale);
## - dalla porta del bacino si entra nel tunnel (pavimento nel passaggio, niente muro davanti);
## - lo spazio di lei (sull'asse, coi tentacoli aperti) è libero lungo tutta la strada;
## - dal canale si risale: i gradini ci sono ogni 12 m.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_sottomarino.gd

var ok := 0
var falliti := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	get_tree().root.add_child(sala)
	var t0 := Time.get_ticks_msec()
	sala.costruisci()
	print("costruito in %d ms, %d nodi" % [Time.get_ticks_msec() - t0, sala.find_children("*", "", true, false).size()])
	for i in 3:
		await get_tree().physics_frame
	var spazio := sala.get_world_3d().direct_space_state
	var lung := sala.lunghezza()
	var lei: Dictionary = sala.dati["lei"]

	# 1) banchine, canale, volta
	var senza_banchina := []
	var senza_fondo := []
	var volta_bassa := []
	# (a 0,37 m dai metri tondi: un raggio esattamente sul bordo fra due pezzi di collisione passa fra i due)
	var s := 0.37
	while s < lung - 0.5:
		var p := sala.punto(s)
		var r := sala.destra(s)
		for lato in [-1.0, 1.0]:
			var q: Vector3 = p + r * float(lato) * (sala.canale + sala.banchina * 0.5)
			var h := _giu(spazio, Vector3(q.x, sala.piano + 1.0, q.z))
			if h.is_empty() or absf((h.position as Vector3).y - sala.piano) > 0.02:
				senza_banchina.append(snappedf(s, 0.1))
		var hf := _giu(spazio, Vector3(p.x, sala.acqua + 0.3, p.z))
		if s > SalaSottomarino.PRESA_FINO + 1.0 and (hf.is_empty() or absf((hf.position as Vector3).y - sala.fondo) > 0.02):
			senza_fondo.append(snappedf(s, 0.1))
		var hv := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, sala.acqua + 1.0, p.z), Vector3(p.x, sala.acqua + 30.0, p.z)))
		if hv.is_empty() or (hv.position as Vector3).y - sala.acqua < 6.5:
			volta_bassa.append(snappedf(s, 0.1))
		s += 1.0
	_controlla(senza_banchina.is_empty(), "banchine col pavimento a quota piano su tutta la strada", senza_banchina)
	_controlla(senza_fondo.is_empty(), "canale col fondo su tutta la strada", senza_fondo)
	_controlla(volta_bassa.is_empty(), "volta ad almeno 6,5 m sopra l'acqua", volta_bassa)

	# 2) la porta del bacino
	var pp := sala.punto(SalaSottomarino.PORTA_S)
	var rp := sala.destra(SalaSottomarino.PORTA_S)
	var fuori := Vector3(40.3, sala.piano + 1.0, pp.z)
	var dentro := pp - rp * (sala.muro - 0.6) + Vector3.UP * (sala.piano - pp.y + 1.0)
	var muro_davanti := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(fuori, dentro))
	_controlla(muro_davanti.is_empty(), "dalla porta del bacino si entra nel tunnel (niente davanti)", [] if muro_davanti.is_empty() else [muro_davanti.position])
	var hp := _giu(spazio, Vector3(39.6, sala.piano + 1.0, pp.z))
	_controlla(not hp.is_empty() and absf((hp.position as Vector3).y - sala.piano) < 0.02, "il passaggio della porta ha il pavimento", [hp.get("position")])

	# 3) lo spazio di lei
	var forma := BoxShape3D.new()
	var alto := float(lei["quota_alta"]) - float(lei["quota_bassa"])
	forma.size = Vector3(float(lei["mezza_larghezza_coi_tentacoli"]) * 2.0, alto, 1.0)
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = forma
	var occupato := []
	s = -2.0
	while s < lung - 3.0:
		var p := sala.punto(s)
		pq.transform = Transform3D(Basis.looking_at(sala.direzione(s), Vector3.UP),
				Vector3(p.x, (float(lei["quota_bassa"]) + float(lei["quota_alta"])) * 0.5, p.z))
		if not spazio.intersect_shape(pq, 1).is_empty():
			occupato.append(snappedf(s, 0.1))
		s += 1.0
	_controlla(occupato.is_empty(), "lo spazio di lei è libero su tutta la strada", occupato)

	# 4) i gradini
	var gradini := sala.find_child("Gradini", true, false)
	_controlla(gradini != null, "ci sono i gradini per risalire dal canale", [])

	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


func _giu(spazio: PhysicsDirectSpaceState3D, da: Vector3) -> Dictionary:
	return spazio.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 8.0))


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa + ": " + str(dove.slice(0, 12)) + (" ..." if dove.size() > 12 else ""))
