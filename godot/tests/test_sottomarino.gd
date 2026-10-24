extends Node
## Test del tunnel del viaggio sottomarino (SalaSottomarino), senza schermo: la geometria costruita dalla strada.
## - le banchine hanno il pavimento a quota piano lungo tutta la strada, il canale ha il fondo, la volta sta ad
##   almeno 6,5 m dall'acqua (regola dell'utente: almeno 6 m sopra il canale);
## - dalla porta del bacino si entra nel tunnel (pavimento nel passaggio, niente muro davanti);
## - lo spazio di lei (sull'asse, coi tentacoli aperti) è libero lungo tutta la strada;
## - dal canale si risale da qualunque punto: c'è il gradino continuo lungo le due rive.
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
			if _ostacolo_qui(sala, s, lato):
				continue
			var q: Vector3 = p + r * float(lato) * (sala.canale + sala.banchina * 0.5)
			var h := _giu(spazio, Vector3(q.x, sala.piano + 1.0, q.z))
			if h.is_empty() or absf((h.position as Vector3).y - sala.piano) > 0.02:
				senza_banchina.append(snappedf(s, 0.1))
		var hf := _giu(spazio, Vector3(p.x, sala.acqua + 0.3, p.z))
		if s > SalaSottomarino.PRESA_FINO + 1.0 and (hf.is_empty() or absf((hf.position as Vector3).y - sala.fondo) > 0.02):
			senza_fondo.append(snappedf(s, 0.1))
		var hv := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, sala.acqua + 1.0, p.z), Vector3(p.x, sala.acqua + 30.0, p.z)))
		# (davanti al portello, sopra il canale, c'è il ballatoio: lì la volta non si vede da sotto)
		if s < lung - SalaSottomarino.BALLATOIO - 0.2 and (hv.is_empty() or (hv.position as Vector3).y - sala.acqua < 6.5):
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

	# 4) gli ostacoli chiudono davvero la banchina: dal lato da cui si arriva, a ogni larghezza e fino a 1,45 m (sopra
	# non ci si arriva saltando), qualcosa ferma chi cammina
	var aperti := []
	for o in sala.ostacoli:
		if o["tipo"] in ["crollo", "galleria"]:
			continue
		var s0: float = float(o["s"]) - 1.6
		var lato: float = o["lato"]
		for f in [0.15, 0.3, 0.5, 0.7, 0.85]:
			for h in [0.4, 0.9, 1.45]:
				var u: float = sala.canale + sala.banchina * f
				var a: Vector3 = sala.punto(s0) + sala.destra(s0) * lato * u + Vector3.UP * (sala.piano - sala.acqua + h)
				var s1: float = float(o["s"]) + float(o["lungo"]) + 1.6
				var b: Vector3 = sala.punto(s1) + sala.destra(s1) * lato * u + Vector3.UP * (sala.piano - sala.acqua + h)
				# (una sfera larga come il giocatore: fra le sbarre del cancello un raggio passa, lui no)
				var sq := PhysicsShapeQueryParameters3D.new()
				var sf := SphereShape3D.new()
				sf.radius = 0.3
				sq.shape = sf
				sq.transform = Transform3D(Basis.IDENTITY, a)
				sq.motion = b - a
				var corsa := spazio.cast_motion(sq)
				if corsa.is_empty() or corsa[0] >= 1.0:
					aperti.append("%s %d: largo %.2f alto %.2f" % [o["tipo"], int(o["s"]), f, h])
	_controlla(aperti.is_empty(), "gli ostacoli chiudono la banchina (non si passa e non si scavalcano)", aperti)

	# 4) il gradino continuo lungo il bordo del canale, su tutte e due le rive (dove la banchina non è crollata)
	var senza_gradino := []
	s = SalaSottomarino.PRESA_FINO + 0.37
	while s < lung - SalaSottomarino.BALLATOIO - 1.0:
		for lato in [-1.0, 1.0]:
			if _ostacolo_qui(sala, s, lato) and not _ostacolo_qui(sala, s, lato, ["carico", "cancello", "macerie", "vetrina"]):
				continue
			var q: Vector3 = sala.punto(s) + sala.destra(s) * float(lato) * (sala.canale - SalaSottomarino.GRADINO_LARGO * 0.5)
			var h := _giu(spazio, Vector3(q.x, sala.acqua + 0.3, q.z))
			if h.is_empty() or absf((h.position as Vector3).y - (sala.fondo + SalaSottomarino.GRADINO_SU)) > 0.02:
				senza_gradino.append("%.1f %+d" % [s, int(lato)])
		s += 1.0
	_controlla(senza_gradino.is_empty(), "il gradino continuo per risalire dal canale c'è lungo tutte e due le rive", senza_gradino)

	# 5) il finale: dalla camera stagna si chiude il portello, il volantino gira restando attaccato, poi "FINE"
	var fine := [false]
	sala.fine_demo.connect(func(): fine[0] = true)
	var vol: Node3D = sala.find_child("Volantino", true, false)
	var perno: Node3D = sala.find_child("PortelloPerno", true, false)
	var attaccato_prima: Vector3 = perno.to_local(vol.global_position)
	sala.chiudi_portello()
	var t := 0.0
	while t < 8.0 and not fine[0]:
		await get_tree().process_frame
		t += get_process_delta_time()
	var chiuso := absf(perno.global_transform.basis.z.dot(sala.direzione(lung))) > 0.98
	var attaccato_dopo: Vector3 = perno.to_local(vol.global_position)
	_controlla(fine[0] and chiuso and attaccato_prima.distance_to(attaccato_dopo) < 0.001 and vol.rotation.z > 4.0,
			"il portello si chiude, il volantino gira restando attaccato, poi la fine", ["fine %s chiuso %s giro %.2f" % [fine[0], chiuso, vol.rotation.z]])

	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## Vero se a [param s] sul lato [param lato] c'è un ostacolo (lì la banchina è chiusa apposta).
func _ostacolo_qui(sala: SalaSottomarino, s: float, lato: float, tipi: Array = []) -> bool:
	for o in sala.ostacoli:
		if not tipi.is_empty() and not o["tipo"] in tipi:
			continue
		if float(o["lato"]) == lato and s > float(o["s"]) - 1.6 and s < float(o["s"]) + float(o["lungo"]) + 1.6:
			return true
	return false


func _giu(spazio: PhysicsDirectSpaceState3D, da: Vector3) -> Dictionary:
	return spazio.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 8.0))


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa + ": " + str(dove.slice(0, 12)) + (" ..." if dove.size() > 12 else ""))
