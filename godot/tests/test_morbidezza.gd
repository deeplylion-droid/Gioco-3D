extends Node
## Test del movimento secondario di lei nel tuffo (MorbidezzaLei), senza schermo:
## - "quanto" a 0: la posa resta identica a quella che arriva dal tuffo (statua ferma);
## - partenza piano: al primo fotogramma la posa è quella del tuffo, poi si stacca a poco a poco (niente scatti),
##   anche ripartendo (affacciata di nuovo, come al caricamento del checkpoint) e tuffandosi una seconda volta;
## - collisioni, già con lei affacciata (un secondo prima della spruzzata: la morbidezza è accesa da quando compare)
##   e in tutto il tuffo: nessun punto dei tentacoli (teste, punte, quarti e metà dei tratti) dentro pavimento, pareti,
##   fondo, bordo o griglia e nessun tratto che attraversa il mondo (raggi sulla collisione vera), con 1 cm di
##   tolleranza sull'asse (il tentacolo è spesso 3,5-7 cm). Non si contano i tentacoli la cui radice (che segue la
##   posa) è dentro il mondo o già nel condotto, in fondo: lì il primo tratto non può evitarlo. I punti che fra due
##   fotogrammi passano una superficie (nello strappo del salto) si stampano: ogni fotogramma disegnato è pulito;
## - i tratti restano vicini alla lunghezza di riposo; quando sparisce, anche le punte morbide sono sotto;
## - il costo in millisecondi (stampato; quello vero è sul renderer software, nel video).
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_morbidezza.gd

const LEVEL := "res://scenes/sala_principale.tscn"

const Misura := preload("res://tests/misura_morbidezza.gd")

var _ok := 0
var _ko := 0
var lei: LeiSbuca
var sk: Skeleton3D
var catene: Array[PackedInt32Array] = []
var _entrata: Array = []        # per fotogramma: le pose globali che arrivano (prima della morbidezza)
var _uscita: Array = []
var _registra := false
var _sim: Array = []
var _dt: Array = []
var _pesi: Array = []
var _guarda: Array = []
var _costi_guarda: Array = []


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


## I controlli del costo: in CI (le macchine di GitHub sono diverse) si stampano e basta, senza contarli; le
## collisioni invece bloccano sempre.
func _check_costo(cond: bool, msg: String) -> void:
	if OS.has_environment("CI"):
		print("  (CI: solo stampato) %s  %s" % ["ok" if cond else "oltre", msg])
	else:
		_check(cond, msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var level := get_tree().current_scene
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	lei = level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	# il giocatore lontano, così non la vede né lo prende
	GameState.player.teleport(lei.punto_sbuca.global_position + lei.punto_sbuca.global_basis.z * 7.0 + Vector3(0, 0.1, 0), 0.0, 0.0)
	await get_tree().physics_frame
	lei.call(&"_affaccia")
	for i in 5:
		await get_tree().process_frame
	sk = lei.medusa.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_catene()
	print("catene ", catene.size())

	# 1) il primo tuffo, com'è nel gioco
	var r1 := await _tuffo("primo tuffo", 1.0)
	# 2) di nuovo affacciata (il checkpoint) e un secondo tuffo: riparte dalla posa, senza scatti
	var r2 := await _tuffo("secondo tuffo (dopo il checkpoint)", 1.0)
	# 3) quanto 0: identica alla posa del tuffo
	var r3 := await _tuffo("quanto 0", 0.0)
	_check(r3["max_diff"] < 1e-4, "quanto 0: la posa resta quella del tuffo (scarto massimo %.6f m)" % r3["max_diff"])
	_check(r1["max_diff"] > 0.05, "quanto 1: i tentacoli si muovono davvero (scarto massimo %.3f m)" % r1["max_diff"])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _catene() -> void:
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if not n.begins_with("tentacolo_"):
			continue
		var p := sk.get_bone_parent(b)
		if p >= 0 and sk.get_bone_name(p).begins_with("tentacolo_"):
			continue
		var c := PackedInt32Array([b])
		var x := b
		while true:
			var dopo := -1
			for f in sk.get_bone_children(x):
				if sk.get_bone_name(f).begins_with("tentacolo_"):
					dopo = f
			if dopo < 0:
				break
			c.append(dopo)
			x = dopo
		catene.append(c)


## I punti di tutte le catene (teste delle ossa e punta), nel mondo, come sono adesso nello scheletro.
func _punti(rif: Array = []) -> Array:
	var sg := sk.global_transform
	var out := []
	for kc in catene.size():
		var c := catene[kc]
		var pts := PackedVector3Array()
		for b in c:
			pts.append((sg * sk.get_bone_global_pose(b)).origin)
		var n := pts.size()
		var ultimo := sg * sk.get_bone_global_pose(c[n - 1])
		# la punta: l'ultimo osso è lungo come il tratto di riposo prima (come lo conta la morbidezza)
		var allunga := ultimo.basis.y.length() / maxf(ultimo.basis.x.length(), 1e-6)
		pts.append(ultimo.origin + ultimo.basis.y.normalized() * _lung_riposo(kc, n) * allunga)
		out.append(pts)
	return out


func _lung_riposo(k: int, i: int) -> float:
	var c := catene[k]
	var j := mini(i, c.size() - 1)
	return sk.get_bone_rest(c[j]).origin.length() * sk.global_basis.get_scale().x


## Vero se il tratto da [param a] a [param b] entra nelle forme più di 1 cm (l'asse: il tentacolo è spesso 3,5-7 cm).
func _profondo(m: MorbidezzaLei, a: Vector3, b: Vector3) -> bool:
	for k in 9:
		if _dentro(m, a.lerp(b, (k + 1) / 10.0)) > 0.01:
			return true
	return false


## Quanto [param q] è dentro le forme della morbidezza (m): 0 se è fuori.
func _dentro(m: MorbidezzaLei, q: Vector3) -> float:
	return (m.call(&"_fuori", q, 0.0, m.get(&"_forme")) as Vector3).distance_to(q)


## Vero se [param q] è dietro la parete est della fossa, nel terreno fuori dal condotto (lì la posa del tuffo, in
## fondo, a volte mette il corpo; tools/blender/ambiente_sala.py, FOSSA_BIMBI: x1 -12,3, condotto y -2,3 z -7, per le collisioni
## un canale quadrato di mezzo lato 0,43).
func _nel_terreno(q: Vector3) -> bool:
	return q.x > -12.3 and q.y < 0.0 and not _nel_condotto(q)


func _cosa(a: Vector3, b: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD)
	q.hit_back_faces = false
	if lei.coperchio:
		q.exclude = [lei.coperchio.get_rid()]
	var c := sk.get_world_3d().direct_space_state.intersect_ray(q)
	return "%s in %s normale %s" % [c.get("collider").name if c.has("collider") else "-", c.get("position"), c.get("normal")]


func _nel_condotto(q: Vector3) -> bool:
	return q.x > -12.35 and absf(q.y + 2.3) < 0.43 and absf(q.z + 7.0) < 0.43


## Il costo della morbidezza (microsecondi per fotogramma). Limiti decisi dal coordinatore il 23 ottobre (le schede
## deboli): con lei affacciata 3,5 ms in media e 7 al massimo; nel tuffo (2 s, una volta) 4,5 e 12 (i fotogrammi dello
## strappo fanno fino a 3 passi per non passare il bordo); quando compare nessun fotogramma sopra i 7,5 ms (numeri di
## questa CPU del sandbox, con la pelle vera; su un PC vero sono frazioni di ms). Il massimo
## si controlla sul 95% dei fotogrammi (si stampa anche quello vero). Da lanciare con --fixed-fps 30 (come nel gioco).
func _costo(nome: String, costi: Array, medio_max := 3.5, massimo_max := 7.0) -> void:
	if costi.is_empty():
		return
	var c := costi.duplicate()
	c.sort()
	var somma := 0.0
	for x in c:
		somma += x
	var medio: float = somma / c.size() / 1000.0
	var massimo: float = c.back() / 1000.0
	# (il 95° percentile: un fotogramma isolato più lungo è spesso la macchina, che ha 4 processori condivisi)
	var p95: float = c[mini(c.size() - 1, int(c.size() * 0.95))] / 1000.0
	var m: MorbidezzaLei = lei.get(&"_morbidezza")
	print("  COSTO %s: medio %.2f ms, mediano %.2f ms, 95%% sotto %.2f ms, massimo %.2f ms; parti (totali) %s" % [nome, medio, c[c.size() / 2] / 1000.0, p95, massimo, m.parti_usec])
	m.parti_usec = {"bersagli": 0, "passi": 0, "ossa": 0, "giri": 0, "conta_passi": 0, "conta_giri": 0}
	_check_costo(medio < medio_max and p95 < massimo_max, "%s: costo sotto %.1f ms in media e %.0f nel 95%% dei fotogrammi (%.2f e %.2f ms)" % [nome, medio_max, massimo_max, medio, p95])


func _su_guarda() -> void:
	_guarda.append(_punti())
	var mm: MorbidezzaLei = lei.get(&"_morbidezza")
	if mm.durata_usec > 0:
		_costi_guarda.append(mm.durata_usec)



func _su_entrata() -> void:
	if _registra:
		_entrata.append(_punti())


func _su_uscita() -> void:
	if _registra:
		_uscita.append(_punti(_entrata.back() if not _entrata.is_empty() else []))
		var mm: MorbidezzaLei = lei.get(&"_morbidezza")
		_sim.append((mm.get(&"_x") as Array).duplicate(true))
		_dt.append(get_process_delta_time())
		_pesi.append(float(mm.get(&"_peso")) * mm.quanto)



func _attraversa(a: Vector3, b: Vector3, tolleranza := 0.0) -> bool:
	if a.distance_to(b) < 1e-4:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD)
	q.hit_back_faces = false
	if lei.coperchio:
		q.exclude = [lei.coperchio.get_rid()]
	var spazio := sk.get_world_3d().direct_space_state
	var c := spazio.intersect_ray(q)
	return not c.is_empty() and (c["position"] as Vector3).distance_to(b) > tolleranza


func _fuori_dalla_fossa(q: Vector3) -> bool:
	var a := lei.superficie_fossa.global_transform * lei.superficie_fossa.mesh.get_aabb()
	return not (q.x > a.position.x and q.x < a.end.x and q.z > a.position.z and q.z < a.end.z)


## Le collisioni che non si vedono, fuori dal conto della pelle: il coperchio della fossa (per non caderci dentro) e la
## parete est di collisione, che chiude il condotto dove lei si tuffa.
func _esclusi() -> Array[RID]:
	var out: Array[RID] = []
	var co: CollisionObject3D = lei.coperchio
	if co:
		out.append(co.get_rid())
		for c in co.get_parent().find_children("fossa_parete_e*", "", true, false):
			var corpo: Node = c if c is CollisionObject3D else c.get_parent()
			if corpo is CollisionObject3D and not out.has((corpo as CollisionObject3D).get_rid()):
				out.append((corpo as CollisionObject3D).get_rid())
	return out


func _tuffo(nome: String, quanto: float) -> Dictionary:
	print("== ", nome)
	_entrata.clear()
	_uscita.clear()
	_sim.clear()
	_dt.clear()
	_pesi.clear()
	# prima del tuffo, affacciata: la morbidezza è già accesa e i tentacoli poggiano sul bordo
	var m0: MorbidezzaLei = lei.get(&"_morbidezza")
	_check(m0 != null, "%s: affacciata, la morbidezza c'è già" % nome)
	if m0:
		m0.quanto = quanto
		m0.parti_usec = {"bersagli": 0, "passi": 0, "ossa": 0, "giri": 0, "conta_passi": 0, "conta_giri": 0}
		_guarda.clear()
		_costi_guarda.clear()
		m0.modification_processed.connect(_su_guarda)
		var mis_g = Misura.new(sk, m0)
		mis_g.inizia()
		# lei compare (affacciata, come al blackout o al checkpoint): si misura già dal primo fotogramma
		lei.call(&"_affaccia")
		m0.quanto = quanto            # (_affaccia la accende a 1)
		for f in 60:
			await get_tree().process_frame
		m0.modification_processed.disconnect(_su_guarda)
		mis_g.ferma()
		var pg: Dictionary = mis_g.pelle("%s, affacciata" % nome, 0, 2, 0.01, _esclusi())
		if quanto > 0.0:
			_check(pg["pelle_dentro"] == 0, "%s: affacciata, la pelle vera dei tentacoli fuori dal mondo (%d vertici dentro, al più %.1f cm)" % [nome, pg["pelle_dentro"], pg["pelle_massimo"] * 100.0])
		var dentro_g := 0
		var attr_g := 0
		var per_f := []
		for g in range(0, _guarda.size()):
			var prima_g := dentro_g + attr_g
			for k in (_guarda[g] as Array).size():
				var pu: PackedVector3Array = _guarda[g][k]
				for i in range(1, pu.size()):
					for tq in [0.0, 0.25, 0.5, 0.75]:
						if _dentro(m0, pu[i].lerp(pu[i - 1], tq)) > 0.01:
							dentro_g += 1
							if dentro_g < 4:
								print("  affacciata dentro f%d k%d i%d t%.2f %s di %.3f; posa del punto %s" % [g, k, i, tq, pu[i].lerp(pu[i - 1], tq), _dentro(m0, pu[i].lerp(pu[i - 1], tq)), (m0.get(&"_x")[k] as PackedVector3Array)[i]])
					if _attraversa(pu[i - 1], pu[i]) and _profondo(m0, pu[i - 1], pu[i]):
						attr_g += 1
						if attr_g < 4:
							print("  affacciata attraversa f%d k%d i%d %s -> %s: %s" % [g, k, i, pu[i - 1], pu[i], _cosa(pu[i - 1], pu[i])])
			per_f.append(dentro_g + attr_g - prima_g)
		print("  affacciata, problemi per fotogramma: ", per_f)
		if quanto > 0.0:
			# quando lei compare: nessun fotogramma lungo (sarebbe uno scatto proprio quando sbuca; coordinatore, 23 ottobre)
			var primi: Array = _costi_guarda.slice(0, 3)       # (i fotogrammi della partenza)
			print("  costi dei primi fotogrammi (ms): ", primi.map(func(c): return snappedf(c / 1000.0, 0.01)))
			_check_costo(not primi.is_empty() and primi.max() < 7500, "%s: quando compare nessun fotogramma sopra i 7,5 ms (%.2f)" % [nome, primi.max() / 1000.0 if not primi.is_empty() else 0.0])
			_costo("%s, affacciata (dal fotogramma in cui compare)" % nome, _costi_guarda)
		print("  affacciata: %d fotogrammi, punti dentro il mondo %d, tratti che lo attraversano %d" % [_guarda.size(), dentro_g, attr_g])
		if quanto > 0.0:
			_check(dentro_g == 0 and attr_g == 0, "%s: affacciata, i tentacoli poggiano sul bordo senza entrarci (%d punti dentro, %d tratti)" % [nome, dentro_g, attr_g])
	lei.call(&"_on_spruzzata", 1.0, Vector3.ZERO, Vector3.ZERO)
	var m: MorbidezzaLei = lei.get(&"_morbidezza")
	_check(m != null, "%s: la morbidezza c'è" % nome)
	if m == null:
		return {"max_diff": 0.0}
	m.quanto = quanto
	# il modificatore subito prima della morbidezza: la posa che le arriva
	var prima: SkeletonModifier3D = sk.get_child(m.get_index() - 1) as SkeletonModifier3D
	_check(m.get_index() == sk.get_child_count() - 1 and prima != null, "%s: la morbidezza è l'ultima, dopo %s" % [nome, prima.name if prima else "niente"])
	if not prima.modification_processed.is_connected(_su_entrata):
		prima.modification_processed.connect(_su_entrata)
	if not m.modification_processed.is_connected(_su_uscita):
		m.modification_processed.connect(_su_uscita)
	_registra = true
	var mis_t = Misura.new(sk, m)
	mis_t.inizia()
	var costi := []
	var sparita_punti = null
	for f in 400:
		await get_tree().process_frame
		if m.durata_usec > 0:
			costi.append(m.durata_usec)
		if not lei.medusa.visible:
			break
		sparita_punti = _uscita.back() if not _uscita.is_empty() else null
	_registra = false
	mis_t.ferma()
	var pt: Dictionary = mis_t.pelle("%s, tuffo" % nome, 0, 2, 0.01, _esclusi())
	if quanto > 0.0:
		_check(pt["pelle_dentro"] == 0, "%s: tuffo, la pelle vera dei tentacoli fuori dal mondo (%d vertici dentro, al più %.1f cm)" % [nome, pt["pelle_dentro"], pt["pelle_massimo"] * 100.0])
	var nf := mini(_entrata.size(), _uscita.size())
	var max_diff := 0.0
	var primo_diff := 0.0
	var max_salto := 0.0
	var attr_in := 0
	var attr_out := 0
	var sotto := 0
	var entra := 0
	var radice_dentro := 0
	var dentro_n := 0
	var stira_max := 0.0
	var stira_n := 0
	var stira_min := 10.0
	var entra_posa := 0
	var dove_salto := ""
	var prec_diff := []
	var acceso := nf
	for f in nf:
		if float(_pesi[f]) >= 0.999:
			acceso = f
			break
	for f in nf:
		# nella dissolvenza (0,4 s) la posa, che a tratti entra nel mondo, ne esce piano: si conta dopo
		var conta := f > acceso
		var e: Array = _entrata[f]
		var u: Array = _uscita[f]
		var fd := 0.0
		for k in e.size():
			var pe: PackedVector3Array = e[k]
			var pu: PackedVector3Array = u[k]
			# la radice segue la posa: se la posa la mette dentro il mondo (in fondo, nel muro sopra il condotto), il
			# primo tratto non può evitarlo; si conta a parte
			var conta_k := true
			# (anche quando è già nel condotto, dietro la parete: il primo tratto esce dalla bocca)
			if conta and quanto > 0.0 and (_dentro(m, pe[0]) > 0.005 or _nel_terreno(pe[0]) or pe[0].x > -12.3):
				conta_k = false
				radice_dentro += 1
			for i in pe.size():
				var d := pe[i] - pu[i]
				fd = maxf(fd, d.length())
				# lo scarto dal tuffo cambia piano da un fotogramma all'altro (niente scatti)
				if f > 0:
					var dp: Vector3 = (_entrata[f - 1][k] as PackedVector3Array)[i] - (_uscita[f - 1][k] as PackedVector3Array)[i]
					var mosso_u := pu[i].distance_to((_uscita[f - 1][k] as PackedVector3Array)[i])
					# la posa si muove a scatti (a ogni passo della fisica): il più che si è mossa negli ultimi 5 fotogrammi
					var mosso_e := 0.0
					for g in range(maxi(f - 5, 1), f + 1):
						mosso_e = maxf(mosso_e, (_entrata[g][k] as PackedVector3Array)[i].distance_to((_entrata[g - 1][k] as PackedVector3Array)[i]))
					if conta and conta_k and (mosso_u - mosso_e) / maxf(_dt[f], 1.0 / 60.0) > max_salto:
						max_salto = (mosso_u - mosso_e) / maxf(_dt[f], 1.0 / 60.0)
						dove_salto = "f%d k%d i%d posa %s esce %s; dt %.4f, il punto simulato si è mosso di %.3f, la posa di %.3f, l'uscita di %.3f" % [f, k, i, pe[i], pu[i], _dt[f], ((_sim[f][k] as PackedVector3Array)[i]).distance_to((_sim[f - 1][k] as PackedVector3Array)[i]) if _sim[f].size() > k and _sim[f - 1].size() > k else -1.0, pe[i].distance_to((_entrata[f - 1][k] as PackedVector3Array)[i]), pu[i].distance_to((_uscita[f - 1][k] as PackedVector3Array)[i])]
				if i > 0 and i < pe.size() - 1:
					var lp := _lung_riposo(k, i)
					if lp > 0.02:
						var rapporto := pu[i].distance_to(pu[i - 1]) / lp
						if conta and conta_k:
							stira_max = maxf(stira_max, rapporto)
							stira_min = minf(stira_min, rapporto)
							if rapporto > 1.3 or rapporto < 0.7:
								stira_n += 1
								if stira_n < 4:
									print("  stira f%d k%d i%d x%.2f posa %s esce %s prima %s sott'acqua %s" % [f, k, i, rapporto, pe[i], pu[i], pu[i - 1], lei.sott_acqua(pu[i])])
				if i > 0 and quanto > 0.0:
					for tq in [0.0, 0.25, 0.5, 0.75]:
						var qq := pu[i].lerp(pu[i - 1], tq)
						if conta and conta_k and _dentro(m, qq) > 0.01:
							dentro_n += 1
							if dentro_n < 4:
								print("  dentro f%d k%d i%d t%.2f %s di %.3f m" % [f, k, i, tq, qq, _dentro(m, qq)])
				if i > 0:
					if conta and conta_k and _attraversa(pe[i - 1], pe[i]):
						attr_in += 1
					if conta and conta_k and _attraversa(pu[i - 1], pu[i]) and not (_nel_condotto(pu[i - 1]) or _nel_condotto(pu[i])) and _profondo(m, pu[i - 1], pu[i]):
						attr_out += 1
						if attr_out < 6:
							print("  attraversa f%d k%d i%d %s -> %s: %s" % [f, k, i, pu[i - 1], pu[i], _cosa(pu[i - 1], pu[i])])
				# un punto che passa una superficie da un fotogramma all'altro (la posa a volte lo fa: si conta a parte)
				if conta and conta_k and i > 0 and f > 0 and not _nel_condotto(pu[i]) and _attraversa((_uscita[f - 1][k] as PackedVector3Array)[i], pu[i], 0.01):
					entra += 1
					if entra < 6:
						var prima_u: Vector3 = (_uscita[f - 1][k] as PackedVector3Array)[i]
						print("  entra f%d k%d i%d %s -> %s: %s" % [f, k, i, prima_u, pu[i], _cosa(prima_u, pu[i])])
				if conta and conta_k and i > 0 and f > 0 and not _nel_condotto(pe[i]) and _attraversa((_entrata[f - 1][k] as PackedVector3Array)[i], pe[i], 0.01):
					entra_posa += 1
				if conta and conta_k and _fuori_dalla_fossa(pu[i]) and not _nel_condotto(pu[i]) and lei.sotto_il_pavimento(pu[i]) and not lei.sotto_il_pavimento(pe[i]):
					sotto += 1
					if sotto < 4:
						print("  sotto f%d k%d i%d posa %s esce %s sim %s" % [f, k, i, pe[i], pu[i], (_sim[f][k] as PackedVector3Array)[i]])
		if f == 0:
			primo_diff = fd
		max_diff = maxf(max_diff, fd)
	costi.sort()
	var medio := 0.0
	for c in costi:
		medio += c
	medio /= maxf(costi.size(), 1)
	print("  dissolvenza finita al fotogramma %d; tentacoli-fotogramma con la radice della posa dentro il mondo (non contati): %d" % [acceso, radice_dentro])
	print("  fotogrammi %d, scarto massimo %.3f m, primo %.4f m, velocità massima oltre la posa %.1f m/s" % [nf, max_diff, primo_diff, max_salto])
	print("  salto peggiore ", dove_salto)
	print("  attraversamenti: posa del tuffo %d, dopo la morbidezza %d; punti sotto il pavimento in più %d; punti che passano una superficie %d (nella posa %d)" % [attr_in, attr_out, sotto, entra, entra_posa])
	if quanto > 0.0:
		_costo("%s, tuffo" % nome, costi, 4.5, 12.0)
	print("  tratti dei tentacoli: da %.2f a %.2f volte la posa (%d tratti-fotogramma fuori da 0,7-1,3 su %d)" % [stira_min, stira_max, stira_n, nf * 150])
	# dove un tentacolo è appoggiato sullo spigolo del bordo il tratto contro il muro resta indietro e si allunga un po'
	_check(stira_max < 2.0 and stira_min > 0.15 and stira_n < nf * 150 / 100, "%s: i tentacoli non si allungano né accorciano troppo (%.2f-%.2f, fuori da 0,7-1,3 in %d tratti-fotogramma: meno dell'1%%)" % [nome, stira_min, stira_max, stira_n])
	_check(nf > 30, "%s: registrati %d fotogrammi" % [nome, nf])
	if quanto == 0.0:
		_check(primo_diff < 0.02, "%s: al primo fotogramma è la posa del tuffo (%.4f m)" % [nome, primo_diff])
	# (in cima al salto le punte lunghe frustano: la posa stessa lì corre fino a 60 m/s)
	_check(max_salto < 25.0, "%s: niente scatti (va al più %.1f m/s più veloce della posa)" % [nome, max_salto])
	_check(dentro_n == 0, "%s: nessun punto dei tentacoli dentro pavimento, pareti, fondo, bordo o griglia (%d)" % [nome, dentro_n])
	_check(attr_out == 0 or quanto == 0.0, "%s: nessun tratto dei tentacoli attraversa il mondo (%d; la posa da sola: %d)" % [nome, attr_out, attr_in])
	# (fra un fotogramma e l'altro, nello strappo del salto, una punta può passare da accanto al bordo a sopra: ogni
	# fotogramma disegnato è pulito, il passaggio non si vede; si stampa e basta)
	print("  punti che fra due fotogrammi passano una superficie (non si vede): %d; la posa da sola: %d" % [entra, entra_posa])
	_check(sotto == 0, "%s: nessun punto sotto il pavimento fuori dalla fossa (%d)" % [nome, sotto])
	if sparita_punti != null and quanto > 0.0:
		var fuori := 0
		for pts in sparita_punti:
			for q in pts:
				# (10 cm di tolleranza: i punti sono quelli dell'ultimo fotogramma prima, lei controlla al passo della fisica)
				if not lei.sott_acqua(q - Vector3(0, 0.1, 0)) and not lei.sotto_il_pavimento(q):
					fuori += 1
		_check(fuori == 0, "%s: quando sparisce è tutta sotto, anche le punte morbide (%d punti fuori)" % [nome, fuori])
	return {"max_diff": max_diff}
