extends Node
## Test automatico dei bambini visti di sfuggita (BambinoSfuggita; proposta approvata dall'utente il 25 ottobre). Per
## ogni punto, nella sua zona caricata da sola:
## 1. il bambino poggia a terra (un raggio verso il basso trova il pavimento entro [constant TERRA_MAX] m dai piedi) e
##    al suo posto non entra in niente (una capsula larga come lui, dal pavimento in su);
## 2. la strada della fuga è libera: la stessa capsula, spostata da un punto all'altro, non tocca muri né oggetti, e
##    sotto ogni punto c'è il pavimento; non passa sopra o accanto alle Polaroid e fermo non ne copre nessuna;
## 3. dove sparisce (l'ultimo punto) dalla zona del giocatore non si vede (muri in mezzo da ogni punto della zona);
## 4. con lei all'oblò dello stesso posto ancora da vedere non compare; col giocatore nella zona girato dall'altra
##    parte il bambino compare, e mai mentre il giocatore guarda il suo posto; guardato,
##    scappa, e sparisce solo quando il giocatore non lo vede più; finito, non ricompare.
## I punti: nella risalita (scena di prova, con le stanze caricate) e nel tunnel sottomarino (costruito da solo).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambini_sfuggita.gd

const SCENA := "res://tests/scene/risalita_prova.tscn"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
## Quanto corre chi gli va dietro (lo sprint del giocatore) e l'altezza degli occhi, in piedi e accucciato.
const SPRINT := 5.8
const OCCHI := 1.6
const OCCHI_GIU := 0.92
const TERRA_MAX := 0.05
## Il bambino come capsula (l'agnellino è più piccolo: la misura del più grande, il bambino a cubo).
const RAGGIO := 0.22
const ALTO := 1.15

var _passed := 0
var _failed := 0
var _p: Player


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("La risalita (nella scena di prova, coi suoi stanzoni caricati)")
	get_tree().change_scene_to_file(SCENA)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(10)
	_p = GameState.player
	_p.camera.make_current()
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var tutti := ris.find_children("*", "BambinoSfuggita", true, false)
	check(not tutti.is_empty(), "nella risalita ci sono bambini visti di sfuggita (%d)" % tutti.size())
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for b: BambinoSfuggita in tutti:
		# il giocatore nella zona del bambino: lì le stanze vicine si caricano (il capannone del fiume)
		_p.global_position = (b.get_parent() as Node3D).to_global(b.zona.get_center())
		for i in 1200:
			await get_tree().process_frame
			if not bool(ris.call(&"lavori_in_corso")):
				break
		await _frames(10)
		await _prova(b)
	print("Il tunnel sottomarino (costruito da solo)")
	var sala := SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	await _frames(10)
	var nel_tunnel := sala.find_children("*", "BambinoSfuggita", true, false)
	check(not nel_tunnel.is_empty(), "nel tunnel c'è il bambino visto di sfuggita")
	for b: BambinoSfuggita in nel_tunnel:
		await _prova(b)
		await _insegui(b, sala)
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)


func _globale(b: BambinoSfuggita, q: Vector3) -> Vector3:
	return (b.get_parent() as Node3D).to_global(q)


func _pavimento(da: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(da + Vector3.UP * 1.0, da + Vector3.DOWN * 1.0)
	q.exclude = [_p.get_rid()]
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else null


## La capsula del bambino da [param a] a [param b] (i piedi), sollevata di 5 cm: tocca qualcosa?
func _urta(a: Vector3, b: Vector3) -> Array:
	var forma := CapsuleShape3D.new()
	forma.radius = RAGGIO
	forma.height = ALTO
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * (0.05 + ALTO * 0.5))
	q.motion = b - a
	q.exclude = [_p.get_rid()]
	var spazio := get_viewport().find_world_3d().direct_space_state
	var r := spazio.cast_motion(q)
	if r.is_empty() or r[0] >= 1.0:
		return []
	q.transform.origin += (b - a) * r[1]
	q.motion = Vector3.ZERO
	var dove := spazio.get_rest_info(q)
	return [dove.get("point", Vector3.ZERO), r[1]]


func _vista_libera(da: Vector3, a: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(da, a)
	q.exclude = [_p.get_rid()]
	return get_viewport().find_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _prova(b: BambinoSfuggita) -> void:
	print("- ", b.name)
	# 1. a terra e libero
	var piedi := b.global_position
	var terra = _pavimento(piedi)
	check(terra != null and absf((terra as Vector3).y - piedi.y) < TERRA_MAX,
			"poggia a terra (pavimento a %s m dai piedi)" % (("%+.3f" % ((terra as Vector3).y - piedi.y)) if terra != null else "-"))
	var u := _urta(piedi, piedi + Vector3(0.001, 0, 0))
	check(u.is_empty(), "al suo posto non entra in niente%s" % ((" (tocca a %s)" % str(u[0])) if not u.is_empty() else ""))
	# 2. la strada della fuga
	var prima := piedi
	var i := 0
	for q in b.via:
		var g := _globale(b, q)
		var t2 = _pavimento(g)
		check(t2 != null and absf((t2 as Vector3).y - g.y) < TERRA_MAX, "fuga, punto %d: c'è il pavimento" % i)
		var urto := _urta(prima, g)
		check(urto.is_empty(), "fuga, tratto %d: la strada è libera%s" % [i, ((" (tocca a %s)" % str(urto[0])) if not urto.is_empty() else "")])
		prima = g
		i += 1
	# 2b. le Polaroid lì vicino: non ci passa sopra né accanto, e fermo non ne copre nessuna a chi guarda dalla zona
	var occhio_zona := _globale(b, b.da_dove)
	var polaroid := 0
	for f in get_tree().root.find_children("*", "PolaroidPhoto", true, false):
		var pf := (f as Node3D).global_position
		if pf.distance_to(piedi) > 25.0:
			continue
		polaroid += 1
		var minima := Vector2(pf.x - piedi.x, pf.z - piedi.z).length()
		var da := piedi
		for q in b.via:
			var g := _globale(b, q)
			minima = minf(minima, _dist_segmento(pf, da, g))
			da = g
		check(minima > 0.7, "%s: la fuga ci passa lontano (%.2f m)" % [f.name, minima])
		var testa := piedi + Vector3.UP * 0.6
		var su_linea := Geometry3D.get_closest_point_to_segment(testa, occhio_zona, pf).distance_to(testa)
		check(su_linea > 0.5, "%s: il bambino fermo non la copre a chi guarda dalla zona (%.2f m dalla linea)" % [f.name, su_linea])
	print("    (Polaroid entro 25 m: %d)" % polaroid)
	# 3. dove sparisce non si vede dalla zona
	var fine := _globale(b, b.via[b.via.size() - 1]) + Vector3.UP * 0.6
	var visti := 0
	var campioni := 0
	var z := b.zona
	for ix in 5:
		for iz in 9:
			var dove := _globale(b, z.position + Vector3(z.size.x * (ix + 0.5) / 5.0, 0.2, z.size.z * (iz + 0.5) / 9.0))
			var t3 = _pavimento(dove)
			if t3 == null:
				continue
			campioni += 1
			if _vista_libera((t3 as Vector3) + Vector3.UP * 1.6, fine):
				visti += 1
	check(campioni > 5 and visti == 0, "dove sparisce, dalla zona non si vede (%d punti su %d)" % [visti, campioni])
	# 4. comparsa, fuga, sparizione
	# (dal punto da cui lo si vede di solito, nella zona)
	var dentro := _globale(b, b.da_dove) - Vector3.UP * 1.6
	var t4 = _pavimento(dentro)
	if t4 != null:
		dentro = t4
	var oblo := b.aspetta as ObloLei
	if oblo:
		# lei all'oblò dello stesso posto: finché non ha finito il bambino non compare (mai insieme a lei)
		_metti(dentro, b.global_position, true)
		await _frames(90)
		check(b.stato == BambinoSfuggita.Stato.ATTESA and oblo.stato != ObloLei.Stato.FINITA,
				"con lei all'oblò ancora da vedere (%s) non compare" % ObloLei.Stato.keys()[oblo.stato])
		oblo.load_state({"finito": true})
	_metti(dentro, b.global_position, true)
	var t := 0.0
	while t < 3.0 and b.stato == BambinoSfuggita.Stato.ATTESA:
		await _frames(1)
		t += 1.0 / 60.0
	check(b.stato == BambinoSfuggita.Stato.GUARDA, "col giocatore nella zona girato dall'altra parte, compare")
	# lo si guarda
	_metti(dentro, b.global_position, false)
	t = 0.0
	while t < 8.0 and b.stato == BambinoSfuggita.Stato.GUARDA:
		await _frames(1)
		t += 1.0 / 60.0
	check(b.stato == BambinoSfuggita.Stato.SCAPPA, "guardato, scappa (dopo %.1f s)" % t)
	t = 0.0
	while t < 15.0 and b.stato == BambinoSfuggita.Stato.SCAPPA:
		await _frames(1)
		t += 1.0 / 60.0
		_guarda(b.bambino.punto_testa())   # lo segue con lo sguardo
		if OS.has_environment("DEBUG_FUGA"):
			print("    fuga %.2f %s vis %s cam %s" % [t, str(b.bambino.global_position.snapped(Vector3.ONE * 0.01)), b.bambino.visibile_da(_p), get_viewport().get_camera_3d() == _p.camera])
	check(b.stato == BambinoSfuggita.Stato.FINITO, "sparisce alla fine della fuga (%.1f s)" % t)
	# quando sparisce non se ne vede niente: nessun osso del corpo nell'inquadratura senza un muro in mezzo
	var in_vista := []
	var cam := get_viewport().get_camera_3d()
	for m in ["Calmo", "Rivelato"]:
		var mod := b.bambino.get_node_or_null(m) as Node3D
		if mod == null or not mod.visible:
			continue
		var sk := mod.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for o in sk.get_bone_count():
			var w: Vector3 = sk.global_transform * sk.get_bone_global_pose(o).origin
			if cam.is_position_in_frustum(w) and _vista_libera(_p.get_eye_position(), w):
				in_vista.append(sk.get_bone_name(o))
	check(in_vista.is_empty(), "quando sparisce nessun osso è in vista%s" % ((" (%s)" % ", ".join(in_vista)) if not in_vista.is_empty() else ""))
	var corsa := b.bambino.global_position.distance_to(b.global_position)
	check(corsa > 1.0, "è sparito dopo essere scappato (%.1f m), quando non si vedeva più" % corsa)
	# finito: non ricompare
	_metti(dentro, b.global_position, true)
	await _frames(60)
	check(b.stato == BambinoSfuggita.Stato.FINITO and not b.bambino.visible, "finito, non ricompare")
	var s := b.save_state()
	check(bool(s.get("finito", false)), "lo stato si salva (finito)")


## Distanza in pianta di [param p] dal tratto da [param a] a [param b].
func _dist_segmento(p: Vector3, a: Vector3, b: Vector3) -> float:
	var piano := Vector3(1, 0, 1)
	var c := Geometry3D.get_closest_point_to_segment(p * piano, a * piano, b * piano)
	return c.distance_to(p * piano)


## Il giocatore gli corre dietro (riscontro dell'utente sulla 0.3.16: "il bambino pecorella si vede che sparisce perché
## gli corri dietro"), con la camera vera che lo guarda sempre: a tutta velocità lungo la banchina, poi dentro la galleria
## accucciato (alla velocità da accucciato) fin fuori dalla bocca d'uscita; oppure fermo
## alla bocca d'entrata a guardare dentro la galleria. Quando sparisce, nessun osso del corpo dev'essere
## nell'inquadratura senza qualcosa che si vede in mezzo (raggi dalla camera sulle mesh, CorpiMesh, senza tolleranza),
## e dev'essere già fuori dalla bocca d'uscita: in mezzo alla galleria, dritta e illuminata, si vedrebbe che non c'è più.
func _insegui(b: BambinoSfuggita, sala: SalaSottomarino) -> void:
	var g: Dictionary = {}
	for o in sala.ostacoli:
		if o["tipo"] == "galleria":
			g = o
			break
	var s0: float = float(g["s"]) - SalaSottomarino.GALLERIA_BOCCA
	var s1: float = float(g["s"]) + float(g["lungo"]) + SalaSottomarino.GALLERIA_BOCCA
	var lato: float = g["lato"]
	var dentro := sala.muro + sala.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
	var al := func(s: float, u: float) -> Vector3: return sala._al(sala.punto(s), sala.destra(s) * lato, Vector2(u, sala.piano))
	var n := CorpiMesh.crea(sala, AABB(al.call(s0 - 40.0, 0.0), Vector3.ZERO).expand(al.call(s1 + 25.0, dentro + 3.0)).grow(4.0), b.bambino)
	print("    (corpi dalle mesh: %d)" % n)
	await _frames(2)
	var banchina: Array[Vector3] = [al.call(s0 - 30.0, sala.muro - 1.2), al.call(s0 - 0.6, sala.muro - 1.2),
			al.call(s0 + 0.6, sala.muro - 0.3)]
	var tutta := banchina.duplicate()
	tutta.append_array([al.call(s0 + 1.4, dentro), al.call(s1 - 1.4, dentro), al.call(s1 - 0.6, sala.muro - 0.3),
			al.call(s1 + 1.0, sala.muro - 1.1), al.call(s1 + 20.0, sala.muro - 1.2)])
	var ferma := banchina.duplicate()
	ferma.append(al.call(s0 + 0.9, sala.muro + sala.spessore))
	for caso in [["fin fuori dalla galleria", tutta], ["fermo alla bocca a guardare dentro", ferma]]:
		print("- %s, col giocatore che gli corre dietro %s" % [b.name, caso[0]])
		await _insegui_su(b, sala, caso[1], al, s0, s1, lato)


func _insegui_su(b: BambinoSfuggita, sala: SalaSottomarino, strada: Array, al: Callable, s0: float, s1: float, lato: float) -> void:
	b.load_state({"finito": false})
	var qui: Vector3 = strada[0]
	var k := 1
	var cam := _p.camera
	var t := 0.0
	var visto := false
	var fine := -1.0
	var in_vista := []
	var dove_sparito := -INF
	var fuori := false
	var dt := 1.0 / 60.0
	var r := sala.destra(s0) * lato
	while t < 25.0 and b.stato != BambinoSfuggita.Stato.FINITO:
		# accucciato nelle bocche e nella galleria (è alta 1,25 m): lì si va al più a crouch_speed (1,7 m/s; allo
		# sprint il giocatore lo raggiungeva e gli passava attraverso, ricontrollo del 30 ottobre)
		var giu: bool = (qui - al.call(s0, sala.muro)).dot(r) > -0.15 and k >= 3
		var vel := _p.crouch_speed if giu else SPRINT
		if k < strada.size():
			var verso: Vector3 = strada[k] - qui
			if verso.length() <= vel * dt:
				qui = strada[k]
				k += 1
			else:
				qui += verso.normalized() * vel * dt
		_p.global_position = qui
		# (gli occhi con cui il bambino decide se è visto alla stessa altezza della camera)
		_p.set(&"_eye_height", OCCHI_GIU if giu else OCCHI)
		var occhio := qui + Vector3.UP * (OCCHI_GIU if giu else OCCHI)
		var mira: Vector3 = strada[mini(k, strada.size() - 1)] + Vector3.UP * (OCCHI_GIU if giu else OCCHI)
		if b.stato == BambinoSfuggita.Stato.GUARDA or b.stato == BambinoSfuggita.Stato.SCAPPA:
			mira = b.bambino.punto_testa()
			visto = true
		if (mira - occhio).length() > 0.05:
			cam.global_transform = Transform3D(Basis.looking_at(mira - occhio, Vector3.UP), occhio)
		var dov := b.bambino.global_position
		await _frames(1)
		t += dt
		if b.stato == BambinoSfuggita.Stato.FINITO:
			fine = t
			# (com'era l'ultimo fotogramma in cui si vedeva: rimesso visibile solo per contare le ossa)
			b.bambino.visible = true
			in_vista = _ossa_in_vista(b, cam)
			b.bambino.visible = false
			dove_sparito = _ascissa(sala, dov, s0 - 5.0, s1 + 30.0)
			fuori = (dov - sala.punto(dove_sparito)).dot(sala.destra(dove_sparito) * lato) < sala.muro
			print("    sparito a %.2f s, a s=%.1f (bocca d'uscita fino a %.1f), il giocatore a %.1f m" % [t, dove_sparito, s1, qui.distance_to(dov)])
	check(visto, "correndogli dietro lo si vede e scappa")
	if fine < 0.0:
		print("    (non è sparito in %.0f s: lo si guardava sempre)" % t)
	check(in_vista.is_empty(), "quando sparisce, dalla camera di chi gli corre dietro nessun osso si vede%s" % ((" (%s)" % ", ".join(in_vista)) if not in_vista.is_empty() else ""))
	check(fine < 0.0 or (dove_sparito > s1 - SalaSottomarino.GALLERIA_BOCCA and fuori),
			"sparisce solo uscito dalla galleria dalla bocca in fondo, sul lato del tunnel (s=%.1f, la bocca da %.1f)" % [dove_sparito, s1 - SalaSottomarino.GALLERIA_BOCCA])


## A che punto della strada del tunnel è [param p] (il centro più vicino, a passi di 5 cm).
func _ascissa(sala: SalaSottomarino, p: Vector3, da: float, a: float) -> float:
	var migliore := da
	var d_min := INF
	var x := da
	while x <= a:
		var d := (sala.punto(x) - p).length_squared()
		if d < d_min:
			d_min = d
			migliore = x
		x += 0.05
	return migliore


## Le ossa del bambino (il modello che si vedeva) nell'inquadratura di [param cam] senza niente in mezzo.
func _ossa_in_vista(b: BambinoSfuggita, cam: Camera3D) -> Array:
	var out := []
	var spazio := get_viewport().find_world_3d().direct_space_state
	for m in ["Calmo", "Rivelato"]:
		var mod := b.bambino.get_node_or_null(m) as Node3D
		if mod == null or not mod.visible:
			continue
		var sk := mod.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for o in sk.get_bone_count():
			var w: Vector3 = sk.global_transform * sk.get_bone_global_pose(o).origin
			if not cam.is_position_in_frustum(w):
				continue
			# (solo quello che si vede: la collisione può coprire dove a occhio non c'è niente)
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, w, CorpiMesh.STRATO)
			q.exclude = [_p.get_rid()]
			if spazio.intersect_ray(q).is_empty():
				out.append(sk.get_bone_name(o))
	return out


## Il giocatore in [param dove], che guarda verso [param punto] o (con [param via]) dalla parte opposta.
func _metti(dove: Vector3, punto: Vector3, via: bool) -> void:
	_p.global_position = dove
	var occhio := _p.get_eye_position()
	var mira := punto + Vector3.UP * 0.8
	if via:
		mira = occhio - (mira - occhio)
	_guarda(mira)


## Lo sguardo e la camera insieme (il giocatore è fermo: la camera non la gira lui).
func _guarda(punto: Vector3) -> void:
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()
