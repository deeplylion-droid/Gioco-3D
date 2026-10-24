extends Node
## Test del parkour sui gommoni del tunnel sottomarino (SalaSottomarino), col Player vero e gli input simulati.
## La nota dell'utente (GDD, scelte del 24 ottobre): "sei costretto a fare parkour sui galleggianti che stanno sul
## corso d'acqua per passare da un lato all'altro del canale".
## - gli attraversamenti: da 2 a 4 gommoni, salti fra 1 e 2,5 m da bordo a bordo;
## - i salti: ogni attraversamento si fa camminando e correndo, col dondolio in tre momenti diversi, senza cadere in
##   acqua;
## - l'appoggio: fermi sul tubolare non si scivola e non si viene sbalzati; dal fondo del gommone si esce;
## - le corde: partono dalla maniglia e arrivano all'anello mentre il gommone si muove, stanno sopra l'acqua e sotto
##   lo spazio di lei, e non attraversano niente;
## - niente compenetrazioni: i gommoni non toccano muri, banchine, gradini, ostacoli né altri gommoni.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_parkour_gommoni.gd

const PLAYER := "res://scenes/player/player.tscn"
## Tempo massimo per un attraversamento (s).
const TEMPO_MAX := 25.0
## Gommoni e corde stanno almeno tanto sotto le punte dei tentacoli di lei (m; con ambienti-2 e mascotte).
const SOTTO_LEI := 0.10

var sala: SalaSottomarino
var p: Player
var ok := 0
var falliti := 0
var _rg := SalaSottomarino.GOMMONE_R + SalaSottomarino.GOMMONE_T


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	get_tree().root.add_child(sala)
	sala.costruisci()
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	get_tree().root.add_child(p)
	await _frames(10)
	_disposizione()
	await _compenetrazioni()
	await _corde()
	await _appoggio()
	await _attraversamenti()
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


# --- aiuti ---------------------------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _rilascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch", &"jump"]:
		Input.action_release(a)


func _controlla(cond: bool, cosa: String) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa)


static func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


static func _piano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## I gommoni di un attraversamento (i dizionari di sala._gommoni), nell'ordine in cui si saltano.
func _gruppi() -> Array:
	var out: Array = []
	var k := 0
	for att in sala.attraversamenti:
		var n: int = (att[1] as Array).size() - 1
		out.append({"s": float(att[0]), "salti": att[1], "gommoni": sala._gommoni.slice(k, k + n)})
		k += n
	return out


## Da che lato si parte per l'attraversamento davanti all'ostacolo a [param s].
func _lato_partenza(s: float) -> float:
	for o in sala.ostacoli:
		if absf(float(o["s"]) - s) < 0.01:
			return float(o["lato"])
	return 1.0


# --- disposizione --------------------------------------------------------------------------------------------------

func _disposizione() -> void:
	print("Disposizione dei gommoni")
	var fuori: Array = []
	var righe: Array = []
	for gr in _gruppi():
		var gs: Array = gr["gommoni"]
		var da := _lato_partenza(gr["s"])
		var salti: Array = []
		var c0: Vector3 = (gs[0]["corpo"] as Node3D).global_position
		var pr0: Array = sala.proietta(c0)
		salti.append(sala.canale - absf(float(pr0[1])) - _rg)
		for i in range(1, gs.size()):
			var a: Vector3 = (gs[i - 1]["corpo"] as Node3D).global_position
			var b: Vector3 = (gs[i]["corpo"] as Node3D).global_position
			salti.append(_piano(a).distance_to(_piano(b)) - 2.0 * _rg)
		var cn: Vector3 = (gs[gs.size() - 1]["corpo"] as Node3D).global_position
		var prn: Array = sala.proietta(cn)
		salti.append(sala.canale - absf(float(prn[1])) - _rg)
		# il primo è dalla parte di partenza, l'ultimo da quella di arrivo
		var versi_ok := signf(float(pr0[1])) == da and signf(float(prn[1])) == -da
		for x in salti:
			if x < 0.95 or x > 2.55:
				fuori.append("s %.0f: %.2f m" % [gr["s"], x])
		if gs.size() < 2 or gs.size() > 4 or not versi_ok:
			fuori.append("s %.0f: %d gommoni, versi %s" % [gr["s"], gs.size(), versi_ok])
		righe.append("s %.0f: %d gommoni, salti %s" % [gr["s"], gs.size(), str(salti.map(func(x: float) -> float: return snappedf(x, 0.01)))])
	for r in righe:
		print("    " + r)
	_controlla(fuori.is_empty(), "attraversamenti di 2-4 gommoni con salti fra 1 e 2,5 m %s" % str(fuori))


# --- compenetrazioni -----------------------------------------------------------------------------------------------

func _compenetrazioni() -> void:
	print("Compenetrazioni")
	var spazio := sala.get_world_3d().direct_space_state
	var lei: Dictionary = sala.dati["lei"]
	var tocchi: Array = []
	var alti: Array = []
	for t in [0.0, 1.7, 3.9, 6.2]:
		sala.ferma_gommoni(t)
		await _frames(2)
		for g in sala._gommoni:
			var corpo: AnimatableBody3D = g["corpo"]
			for cs in corpo.get_children():
				if not cs is CollisionShape3D:
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = (cs as CollisionShape3D).shape
				q.transform = (cs as CollisionShape3D).global_transform
				q.collision_mask = Layers.WORLD
				q.exclude = [corpo.get_rid()]
				q.margin = -0.005
				for h in spazio.intersect_shape(q, 4):
					tocchi.append("%s con %s (t %.1f)" % [corpo.get_parent().name, (h["collider"] as Node).name, t])
			# la cima del tubolare resta sotto lo spazio di lei
			var cima := corpo.global_position.y + SalaSottomarino.GOMMONE_T * 2.0 + 0.03
			if cima > float(lei["quota_bassa"]) - SOTTO_LEI:
				alti.append(corpo.get_parent().name)
	_controlla(tocchi.is_empty(), "i gommoni non toccano muri, banchine, gradini, ostacoli né altri gommoni %s" % str(tocchi.slice(0, 8)))
	_controlla(alti.is_empty(), "i gommoni stanno sotto lo spazio di lei %s" % str(alti))


# --- corde ---------------------------------------------------------------------------------------------------------

func _corde() -> void:
	print("Corde")
	var spazio := sala.get_world_3d().direct_space_state
	var lei: Dictionary = sala.dati["lei"]
	var staccate: Array = []
	var basse: Array = []
	var attraversano: Array = []
	var mosse := 0
	for g in sala._gommoni:
		var corpo: AnimatableBody3D = g["corpo"]
		for c in g["corde"]:
			var prima: PackedVector3Array = sala.punti_corda(corpo, c)
			for t in [0.0, 1.1, 2.6, 4.4]:
				sala.ferma_gommoni(t)
				await get_tree().physics_frame
				var pts: PackedVector3Array = sala.punti_corda(corpo, c)
				var man: Vector3 = corpo.global_transform * (c["maniglia"] as Vector3)
				if pts[0].distance_to(man) > 0.001 or pts[pts.size() - 1].distance_to(c["anello"]) > 0.001:
					staccate.append(corpo.get_parent().name)
				for q in pts:
					if q.y < sala.acqua + 0.01 or q.y > float(lei["quota_bassa"]) - SOTTO_LEI:
						basse.append("%s y %.2f" % [corpo.get_parent().name, q.y])
						break
				# dalla maniglia all'anello non si attraversa niente (tranne il proprio gommone e il muro all'anello)
				for i in range(1, pts.size()):
					var a := pts[i - 1]
					var b := pts[i]
					if i == pts.size() - 1:
						b = a.lerp(b, 0.85)
					var rq := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD, [corpo.get_rid()])
					var h := spazio.intersect_ray(rq)
					if not h.is_empty():
						attraversano.append("%s: %s" % [corpo.get_parent().name, (h["collider"] as Node).name])
						break
				if pts[0].distance_to(prima[0]) > 0.005:
					mosse += 1
	_controlla(staccate.is_empty(), "le corde partono dalla maniglia e arrivano all'anello mentre il gommone si muove %s" % str(staccate.slice(0, 6)))
	_controlla(mosse > 0, "le corde si muovono col gommone (%d volte)" % mosse)
	_controlla(basse.is_empty(), "le corde stanno sopra l'acqua e sotto lo spazio di lei %s" % str(basse.slice(0, 6)))
	_controlla(attraversano.is_empty(), "le corde non attraversano niente %s" % str(attraversano.slice(0, 6)))
	# le facce della corda guardano fuori (collaudo del 24 ottobre: il tubo era girato verso dentro). Godot: davanti
	# in senso orario, quindi la normale (b-a)x(c-a) va verso l'asse
	var rovesciate := 0
	var facce_tot := 0
	for g in sala._gommoni:
		for c in g["corde"]:
			var mi: MeshInstance3D = c["mesh"]
			var f: PackedVector3Array = mi.global_transform * mi.mesh.get_faces()
			var pts: PackedVector3Array = sala.punti_corda(g["corpo"], c)
			for i in range(0, f.size(), 3):
				var k := mini(i / 24 + 1, pts.size() - 1)
				var mezzo := (pts[k - 1] + pts[k]) * 0.5
				var asse := (pts[k] - pts[k - 1]).normalized()
				var cc := (f[i] + f[i + 1] + f[i + 2]) / 3.0
				var fuori := cc - mezzo
				fuori -= asse * fuori.dot(asse)
				facce_tot += 1
				if (f[i + 1] - f[i]).cross(f[i + 2] - f[i]).dot(fuori) > 0.0:
					rovesciate += 1
	_controlla(facce_tot > 0 and rovesciate == 0, "le facce delle corde guardano fuori (%d rovesciate su %d)" % [rovesciate, facce_tot])


# --- appoggio ------------------------------------------------------------------------------------------------------

func _appoggio() -> void:
	print("Appoggio sui gommoni")
	sala.ferma_gommoni(0.0)
	var scivolati: Array = []
	var sbalzati: Array = []
	var incastrati: Array = []
	for g in sala._gommoni:
		var corpo: AnimatableBody3D = g["corpo"]
		# in piedi sulla cima del tubolare, dal lato verso l'asse
		var c := corpo.global_position
		var pr: Array = sala.proietta(c)
		var verso := -sala.destra(float(pr[0])) * signf(float(pr[1]))
		var su := c + verso * SalaSottomarino.GOMMONE_R + Vector3.UP * (SalaSottomarino.GOMMONE_T * 2.0 + 0.05)
		p.teleport(su, _yaw(verso))
		await _frames(20)
		var locale := corpo.global_transform.affine_inverse() * p.global_position
		var vy := 0.0
		for i in 180:
			await get_tree().physics_frame
			vy = maxf(vy, absf(p.velocity.y))
		var dopo := corpo.global_transform.affine_inverse() * p.global_position
		if not p.is_on_floor() or Vector2(dopo.x - locale.x, dopo.z - locale.z).length() > 0.15 or p.global_position.y < sala.acqua:
			scivolati.append("%s: %.2f m" % [corpo.get_parent().name, Vector2(dopo.x - locale.x, dopo.z - locale.z).length()])
		if vy > 1.0:
			sbalzati.append("%s: %.2f m/s" % [corpo.get_parent().name, vy])
		# dal fondo del gommone si esce verso la banchina più vicina (avanti e salto quando si è fermi)
		p.teleport(c + Vector3.UP * 0.1, _yaw(sala.destra(float(pr[0])) * signf(float(pr[1]))))
		await _frames(10)
		Input.action_press(&"move_forward")
		var fuori := false
		var fermo := 0
		for i in 360:
			await get_tree().physics_frame
			if p.is_on_floor() and Vector2(p.velocity.x, p.velocity.z).length() < 0.4:
				fermo += 1
			else:
				fermo = 0
			if fermo == 6:
				Input.action_press(&"jump")
			elif fermo == 0:
				Input.action_release(&"jump")
			if _piano(p.global_position).distance_to(_piano(c)) > _rg + 0.1:
				fuori = true
				break
		_rilascia()
		await _frames(5)
		if not fuori:
			incastrati.append(corpo.get_parent().name)
	_controlla(scivolati.is_empty(), "fermi sul tubolare non si scivola via (3 s) %s" % str(scivolati.slice(0, 6)))
	_controlla(sbalzati.is_empty(), "il dondolio non sbalza chi sta sopra %s" % str(sbalzati.slice(0, 6)))
	_controlla(incastrati.is_empty(), "dal fondo del gommone si esce in meno di 6 s %s" % str(incastrati.slice(0, 6)))


# --- attraversamenti -----------------------------------------------------------------------------------------------

## Un attraversamento col Player vero: dalla banchina di partenza, un salto per gommone e l'ultimo sull'altra
## banchina. Per ogni tappa: si gira verso il prossimo appoggio, va avanti, e salta al bordo (o quando è fermo contro
## il tubolare, dal fondo). Il tempo, o -1 se è caduto in acqua o non è arrivato.
func _attraversa(gr: Dictionary, corsa: bool, t0: float) -> float:
	sala.ferma_gommoni(t0)
	var gs: Array = gr["gommoni"]
	var da := _lato_partenza(gr["s"])
	var c0: Vector3 = (gs[0]["corpo"] as Node3D).global_position
	var pr0: Array = sala.proietta(c0)
	var s0: float = pr0[0]
	var verso0 := sala.destra(s0) * -da
	# in piedi sulla banchina di partenza, 1 m dal bordo, davanti al primo gommone
	var start := sala.punto(s0) + sala.destra(s0) * da * (sala.canale + 1.0)
	p.teleport(Vector3(start.x, sala.piano + 0.05, start.z), _yaw(verso0))
	await _frames(10)
	var tempo := 0.0
	var tappe: Array = []
	for g in gs:
		tappe.append(g["corpo"])
	tappe.append(null)  # l'altra banchina
	var k := 0
	var fermo := 0
	Input.action_press(&"move_forward")
	if corsa:
		Input.action_press(&"sprint")
	while tempo < TEMPO_MAX:
		await get_tree().physics_frame
		tempo += 1.0 / 60.0
		var pos := p.global_position
		if pos.y < sala.acqua - 0.05:
			_rilascia()
			return -1.0
		var bersaglio: Vector3
		if tappe[k] == null:
			var pr: Array = sala.proietta(pos)
			var b := sala.punto(float(pr[0])) + sala.destra(float(pr[0])) * -da * (sala.canale + 1.2)
			bersaglio = b
		else:
			bersaglio = (tappe[k] as Node3D).global_position
		var dir := _piano(bersaglio - pos)
		if dir.length() > 0.05:
			p.set_look(_yaw(Vector3(dir.x, 0.0, dir.y)), p.pitch)
		# dove si è: sulla banchina, su un gommone (quale) o nell'acqua
		var su: Node3D = null
		for g in gs:
			if _piano(pos).distance_to(_piano((g["corpo"] as Node3D).global_position)) < _rg + 0.15 and pos.y > sala.acqua:
				su = g["corpo"]
		if tappe[k] != null and su == tappe[k] and p.is_on_floor():
			k += 1
			continue
		if tappe[k] == null and p.is_on_floor() and pos.y > sala.piano - 0.05 and signf(float(sala.proietta(pos)[1])) == -da \
				and absf(float(sala.proietta(pos)[1])) > sala.canale + 0.3:
			_rilascia()
			return tempo
		# il salto: al bordo dell'appoggio dove si è, verso il prossimo
		var al_bordo := false
		if su == null and p.is_on_floor():
			var pr2: Array = sala.proietta(pos)
			al_bordo = absf(float(pr2[1])) < sala.canale + 0.25
		elif su != null and p.is_on_floor():
			al_bordo = _piano(pos).distance_to(_piano(su.global_position)) > _rg - 0.3 and \
					(_piano(pos) - _piano(su.global_position)).dot(dir) > 0.0
		if p.is_on_floor() and Vector2(p.velocity.x, p.velocity.z).length() < 0.4:
			fermo += 1
		else:
			fermo = 0
		if (al_bordo or fermo >= 6) and p.is_on_floor():
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")
	_rilascia()
	return -1.0


func _attraversamenti() -> void:
	print("Attraversamenti col salto vero")
	for gr in _gruppi():
		var esiti: Array = []
		var tutti := true
		for corsa in [false, true]:
			for t0 in [0.0, 1.3, 2.7]:
				var t := await _attraversa(gr, corsa, t0)
				esiti.append("%s t%.1f: %s" % ["corsa" if corsa else "passo", t0, "acqua" if t < 0.0 else "%.1f s" % t])
				if t < 0.0:
					tutti = false
				await _frames(10)
		_controlla(tutti, "attraversamento a s %.0f camminando e correndo, in 3 momenti del dondolio %s" % [gr["s"], str(esiti)])
