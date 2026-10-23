extends Node
## Test del movimento secondario di lei nel tuffo (MorbidezzaLei), senza schermo:
## - "quanto" a 0: la posa resta identica a quella che arriva dal tuffo (statua ferma);
## - partenza piano: al primo fotogramma la posa è quella del tuffo, poi si stacca a poco a poco (niente scatti),
##   anche ripartendo (affacciata di nuovo, come al caricamento del checkpoint) e tuffandosi una seconda volta;
## - collisioni: i tratti dei tentacoli non attraversano il mondo (bordo, fondo, griglia di scarico divelta) più
##   di quanto già faccia la posa del tuffo; nessun punto sotto il pavimento fuori dalla fossa;
## - quando sparisce (tutta sotto), anche le punte morbide sono sotto il pelo o il pavimento;
## - il costo in millisecondi (stampato; il confronto vero è sul renderer software, nel video).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_morbidezza.gd

const LEVEL := "res://scenes/sala_principale.tscn"

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


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


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
	lei.call(&"_affaccia")
	for i in 5:
		await get_tree().process_frame
	var r2 := await _tuffo("secondo tuffo (dopo il checkpoint)", 1.0)
	# 3) quanto 0: identica alla posa del tuffo
	lei.call(&"_affaccia")
	for i in 5:
		await get_tree().process_frame
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
		# la punta: l'ultimo osso è lungo come nella posa che arriva
		var r: PackedVector3Array = rif[kc] if not rif.is_empty() else pts
		# (con la scala dell'osso lungo il suo asse: la morbidezza allunga l'ultimo osso)
		var allunga := ultimo.basis.y.length() / maxf(ultimo.basis.x.length(), 1e-6)
		pts.append(ultimo.origin + ultimo.basis.y.normalized() * r[n - 1].distance_to(r[n - 2]) * allunga)
		out.append(pts)
	return out


func _su_entrata() -> void:
	if _registra:
		_entrata.append(_punti())


func _su_uscita() -> void:
	if _registra:
		_uscita.append(_punti(_entrata.back() if not _entrata.is_empty() else []))
		var mm: MorbidezzaLei = lei.get(&"_morbidezza")
		_sim.append((mm.get(&"_x") as Array).duplicate(true))
		_dt.append(get_process_delta_time())



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


func _tuffo(nome: String, quanto: float) -> Dictionary:
	print("== ", nome)
	_entrata.clear()
	_uscita.clear()
	_sim.clear()
	_dt.clear()
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
	var nf := mini(_entrata.size(), _uscita.size())
	var max_diff := 0.0
	var primo_diff := 0.0
	var max_salto := 0.0
	var attr_in := 0
	var attr_out := 0
	var sotto := 0
	var entra := 0
	var stira_max := 0.0
	var stira_n := 0
	var stira_min := 10.0
	var entra_posa := 0
	var dove_salto := ""
	var prec_diff := []
	for f in nf:
		var e: Array = _entrata[f]
		var u: Array = _uscita[f]
		var fd := 0.0
		for k in e.size():
			var pe: PackedVector3Array = e[k]
			var pu: PackedVector3Array = u[k]
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
					if (mosso_u - mosso_e) / maxf(_dt[f], 1.0 / 60.0) > max_salto:
						max_salto = (mosso_u - mosso_e) / maxf(_dt[f], 1.0 / 60.0)
						dove_salto = "f%d k%d i%d posa %s esce %s; dt %.4f, il punto simulato si è mosso di %.3f, la posa di %.3f, l'uscita di %.3f" % [f, k, i, pe[i], pu[i], _dt[f], ((_sim[f][k] as PackedVector3Array)[i]).distance_to((_sim[f - 1][k] as PackedVector3Array)[i]) if _sim[f].size() > k and _sim[f - 1].size() > k else -1.0, pe[i].distance_to((_entrata[f - 1][k] as PackedVector3Array)[i]), pu[i].distance_to((_uscita[f - 1][k] as PackedVector3Array)[i])]
				if i > 0 and i < pe.size() - 1:
					var lp := pe[i].distance_to(pe[i - 1])
					if lp > 0.02:
						var rapporto := pu[i].distance_to(pu[i - 1]) / lp
						stira_max = maxf(stira_max, rapporto)
						if rapporto > 1.3 or rapporto < 0.7:
							stira_n += 1
							if stira_n < 4:
								print("  stira f%d k%d i%d x%.2f posa %s esce %s prima %s sott'acqua %s" % [f, k, i, rapporto, pe[i], pu[i], pu[i - 1], lei.sott_acqua(pu[i])])
						stira_min = minf(stira_min, rapporto)
				if i > 0:
					if _attraversa(pe[i - 1], pe[i]):
						attr_in += 1
					if _attraversa(pu[i - 1], pu[i]):
						attr_out += 1
				# un punto che passa una superficie da un fotogramma all'altro (la posa a volte lo fa: si conta a parte)
				if f > 0 and _attraversa((_uscita[f - 1][k] as PackedVector3Array)[i], pu[i], 0.01):
					entra += 1
				if f > 0 and _attraversa((_entrata[f - 1][k] as PackedVector3Array)[i], pe[i], 0.01):
					entra_posa += 1
					if entra < 6:
						print("  entra f%d k%d i%d posa %s esce %s" % [f, k, i, pe[i], pu[i]])
				if _fuori_dalla_fossa(pu[i]) and lei.sotto_il_pavimento(pu[i]) and not lei.sotto_il_pavimento(pe[i]):
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
	print("  fotogrammi %d, scarto massimo %.3f m, primo %.4f m, velocità massima oltre la posa %.1f m/s" % [nf, max_diff, primo_diff, max_salto])
	print("  salto peggiore ", dove_salto)
	print("  attraversamenti: posa del tuffo %d, dopo la morbidezza %d; punti sotto il pavimento in più %d; punti che passano una superficie %d (nella posa %d)" % [attr_in, attr_out, sotto, entra, entra_posa])
	if not costi.is_empty():
		print("  COSTO %s: medio %.2f ms, mediano %.2f ms, massimo %.2f ms (headless)" % [nome, medio / 1000.0, costi[costi.size() / 2] / 1000.0, costi.back() / 1000.0])
	print("  tratti dei tentacoli: da %.2f a %.2f volte la posa (%d tratti-fotogramma fuori da 0,7-1,3 su %d)" % [stira_min, stira_max, stira_n, nf * 150])
	# dove un tentacolo è appoggiato sullo spigolo del bordo il tratto contro il muro resta indietro e si allunga un po'
	_check(stira_max < 2.0 and stira_min > 0.15 and stira_n < nf * 150 / 100, "%s: i tentacoli non si allungano né accorciano troppo (%.2f-%.2f, fuori da 0,7-1,3 in %d tratti-fotogramma: meno dell'1%%)" % [nome, stira_min, stira_max, stira_n])
	_check(nf > 30, "%s: registrati %d fotogrammi" % [nome, nf])
	_check(primo_diff < 0.01, "%s: al primo fotogramma è la posa del tuffo (%.4f m)" % [nome, primo_diff])
	# (in cima al salto le punte lunghe frustano: la posa stessa lì corre fino a 60 m/s)
	_check(max_salto < 25.0, "%s: niente scatti (va al più %.1f m/s più veloce della posa)" % [nome, max_salto])
	_check(attr_out <= attr_in, "%s: non attraversa il mondo più del tuffo (%d contro %d)" % [nome, attr_out, attr_in])
	_check(entra <= entra_posa, "%s: nessun punto passa il mondo più della posa (%d contro %d)" % [nome, entra, entra_posa])
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
