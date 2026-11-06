extends Node
## Collaudo delle salite di lei nelle condotte (0.3.21, scelta C dell'utente; ambienti-1, che non le ha fatte). Con la
## logica vera del gioco (SalaInseguimento._lei_sale e _lei_aggiorna a 30 fotogrammi al secondo) e il muro vero della
## vasca (collisioni più corpi dalle mesh visibili, CorpiMesh), fotogramma per fotogramma sulla pelle vera di lei (i
## vertici della mesh deformati dalle ossa):
##  - vasca 3 (vasca_2, sale_mano): quando passa sopra la cima del muro la mano destra e quando il resto (testa e
##    capelli); mentre tiene il bordo il distacco della mano dalla cima (il vertice più basso sopra il muro, misurato
##    col raggio verso il basso) e i vertici dentro il muro; per tutta la salita e da su, i vertici oltre la faccia del
##    muro dalla sua parte sotto la cima (tentacoli o corpo che passano nel muro); quanto si gira al secondo;
##  - vasca 2 (vasca_1, sale_puntata): l'angolo fra lo sguardo dell'occhio e gli occhi del giocatore sul fondo;
##  - per tutte e due: quanto dura la salita, quando è su, e la respinta col getto subito dopo (il salto all'inizio della
##    discesa e quanto dura).
## Con "scatti" (rendering) fa anche gli scatti dagli occhi del giocatore: vasca 3 da metà vasca e dall'angolo sud-ovest
## vicino al muro, ravvicinati della mano sul bordo; vasca 2 dal fondo.
## Uso (sotto il render.lock):
##   godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/collaudo_salite_lei.gd
##   xvfb-run ... --rendering-driver vulkan --resolution 1280x720 --fixed-fps 30 ... collaudo_salite_lei.gd scatti <cartella>

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const DITA := ["mano", "pollice", "indice", "medio", "anulare", "mignolo"]

var _scatti := false
var _cartella := "/tmp/collaudo_salite_lei"
var sala: SalaInseguimento
var lei: Node3D
var p: Player
var _sk: Skeleton3D
var _ossa := PackedInt32Array()
var _pesi := PackedFloat32Array()
var _bv := PackedVector3Array()
var _mano := PackedByteArray()
var _nv := 0
var _n_scatto := 0
var _spessore := 0.2
## Quanto scende (cm) sotto la cima, dalla parte della vasca, la pelle che passa oltre il muro (le dita oltre lo spigolo).
var _dita_giu := 0.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_scatti = a.has("scatti")
	if _scatti and a.size() > 2:
		_cartella = a[2]
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	if _scatti:
		DirAccess.make_dir_recursive_absolute(_cartella)
		var env := WorldEnvironment.new()
		env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
		env.environment.sdfgi_enabled = false
		env.environment.volumetric_fog_enabled = false
		env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
		add_child(env)
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	if not _scatti:
		sala.crea_luci = false
	add_child(sala)
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	GameState.player = p
	for i in 60:
		await get_tree().process_frame
	sala.set_physics_process(false)
	lei = sala.lei
	_pelle((lei as MedusaAffacciata).get_model_instance())
	print("COLLAUDO: vertici della pelle %d, della mano destra %d" % [_nv, Array(_mano).count(1)])
	for v in [1, 2]:
		var r: Array = sala.dati["vasche"][v]["rett"]
		var c := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(sala.dati["vasche"][v]["fondo"])])
		CorpiMesh.crea(sala, AABB(c, Vector3.ZERO).grow(9.0), lei)
	for i in 4:
		await get_tree().physics_frame
	# vasca 3: gli occhi a metà vasca e nell'angolo sud-ovest vicino al muro (66,7; -2,2 nella sala)
	var r3: Array = sala.dati["vasche"][2]["rett"]
	var f3 := float(sala.dati["vasche"][2]["fondo"])
	var meta3 := SalaInseguimento.b([(r3[0] + r3[2]) / 2.0, (r3[1] + r3[3]) / 2.0, f3]) + Vector3.UP * 1.6
	var angolo3 := Vector3(66.7, meta3.y, -2.2)
	print("COLLAUDO: vasca 3 rett %s fondo %.2f; occhi a metà %s, nell'angolo %s" % [r3, f3, meta3, angolo3])
	await _vasca3(meta3, "meta_vasca", true)
	await _vasca3(angolo3, "angolo_sud_ovest", false)
	var r2: Array = sala.dati["vasche"][1]["rett"]
	var f2 := float(sala.dati["vasche"][1]["fondo"])
	var fondo2 := SalaInseguimento.b([(r2[0] + r2[2]) / 2.0, (r2[1] + r2[3]) / 2.0, f2]) + Vector3.UP * 1.6
	await _vasca2(fondo2)
	print("COLLAUDO: finito")
	get_tree().quit(0)


func _metti_occhi(occhi: Vector3) -> void:
	p.global_position = occhi - Vector3.UP * (p.get_eye_position().y - p.global_position.y)


func _da_capo(dove: String, k: int) -> void:
	sala.lei_stato = SalaInseguimento.Lei.VIA
	lei.visible = false
	await get_tree().process_frame
	sala._lei_sale(dove, sala._posto_vasca(k))


func _ap() -> AnimationPlayer:
	return (lei as MedusaAffacciata).get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer


## Vasca 3, sale_mano, guardata da [param occhi]: le misure, e gli scatti se richiesti.
func _vasca3(occhi: Vector3, nome: String, misure: bool) -> void:
	_metti_occhi(occhi)
	await _da_capo("vasca_2", 2)
	var ap := _ap()
	var muro := sala._muro_della_vasca()
	var verso_muro := Vector3(muro.x - lei.global_position.x, 0, muro.z - lei.global_position.z).normalized()
	var cima := _cima_muro(lei.global_position, verso_muro)
	_spessore = cima.z
	_dita_giu = 0.0
	print("COLLAUDO: vasca 3 (%s): lei in %s, durata della salita %.2f s, cima del muro a y %.3f (faccia a %.3f m da lei, spessore %.3f)" % [nome,
			lei.global_position.snapped(Vector3.ONE * 0.01), float(sala.get_meta(&"durata_salita")), cima.y, cima.x, cima.z])
	var mano_su := -1.0
	var resto_su := -1.0
	var distacco_min := INF
	var distacco_max := -INF
	var dentro_max := 0
	var oltre_max := 0
	var oltre_quando := ""
	var giro_max := 0.0
	var prima_rot := lei.rotation.y
	var istanti := [0.5, 0.62, 0.72, 0.82, 0.92, 1.0, 1.1, 1.3, 1.6, 2.2]
	var k := 0
	var su_da := -1
	for f in 150:
		sala._lei_aggiorna(1.0 / 30.0, p)
		await get_tree().process_frame
		var tc := ap.current_animation_position if String(ap.current_animation).begins_with("inseguimento/sale") else 99.0
		var giro := absf(angle_difference(prima_rot, lei.rotation.y)) * 30.0
		prima_rot = lei.rotation.y
		if f > 0 and tc > MANO_LASCIA_MIN:
			giro_max = maxf(giro_max, rad_to_deg(giro))
		if sala.lei_stato == SalaInseguimento.Lei.SU and su_da < 0:
			su_da = f
		if misure:
			var m := _misura(cima.y, verso_muro, cima.x)
			if mano_su < 0 and m["mano_alto"] > cima.y:
				mano_su = tc
			if resto_su < 0 and m["resto_alto"] > cima.y:
				resto_su = tc
			if tc >= 0.82 and tc <= 1.03:
				distacco_min = minf(distacco_min, m["distacco"])
				distacco_max = maxf(distacco_max, m["distacco"])
				dentro_max = maxi(dentro_max, m["dentro"])
			if m["oltre"] > oltre_max:
				oltre_max = m["oltre"]
				oltre_quando = "%.2f s (%s, %d vertici, il più oltre %.1f cm)" % [tc if tc < 90 else f / 30.0,
						SalaInseguimento.Lei.keys()[sala.lei_stato], m["oltre"], m["oltre_cm"]]
			if OS.has_environment("OGNI_FOTOGRAMMA") and tc < 2.0:
				print("FOTOGRAMMA: %.2f s mano alta %.3f resto alto %.3f (cima %.3f) distacco %+.1f mm dentro %d oltre %d" % [tc,
						m["mano_alto"], m["resto_alto"], cima.y, m["distacco"] * 1000.0, m["dentro"], m["oltre"]])
		if _scatti:
			p.look_at_point((lei as MedusaAffacciata).get_eye_position())
			p.camera.global_transform = p.get_aim_transform()
			p.camera.make_current()
			if k < istanti.size() and tc >= float(istanti[k]) - 0.001:
				await _salva("vasca3_%s_%.2fs" % [nome, float(istanti[k])])
				k += 1
		if su_da >= 0 and f - su_da > 45:
			break
	if misure:
		print("VASCA3: la mano sopra la cima a %.2f s, il resto (testa e capelli) a %.2f s: %s" % [mano_su, resto_su,
				"la mano esce prima" if mano_su >= 0 and (resto_su < 0 or mano_su < resto_su) else "NON esce prima la mano"])
		print("VASCA3: tenendosi (0,82-1,03 s): distacco della mano dalla cima da %+.1f a %+.1f mm, vertici dentro il muro al più %d" % [
				distacco_min * 1000.0, distacco_max * 1000.0, dentro_max])
		print("VASCA3: vertici dentro il muro (fra le due facce, sotto la cima): al più %d %s" % [oltre_max, oltre_quando])
		print("VASCA3: dalla parte della vasca la pelle scende sotto la cima al più di %.1f cm" % _dita_giu)
		print("VASCA3: su dopo %.2f s" % (su_da / 30.0))
	print("VASCA3: (%s) dopo aver lasciato il bordo si gira al più di %.0f gradi al secondo" % [nome, giro_max])
	if _scatti and misure:
		await _ravvicinati(cima.y)
	await _respinta("vasca 3 (%s)" % nome)


const MANO_LASCIA_MIN := 1.05


## Gli scatti ravvicinati della mano sul bordo, a 0,92 s (si tiene): di fronte, di lato e radente al bordo.
func _ravvicinati(cima_y: float) -> void:
	await _da_capo("vasca_2", 2)
	var ap := _ap()
	for f in 60:
		sala._lei_aggiorna(1.0 / 30.0, p)
		await get_tree().process_frame
		if ap.current_animation_position >= 0.92:
			break
	var mano := _mano_media()
	var muro := sala._muro_della_vasca()
	var verso := Vector3(muro.x - lei.global_position.x, 0, muro.z - lei.global_position.z).normalized()
	var lato := verso.cross(Vector3.UP)
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.02
	add_child(cam)
	sala.set_process(false)
	(lei as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var pose := [["di_fronte", mano + verso * 0.7 + Vector3.UP * 0.25], ["di_lato", mano + lato * 0.6 + Vector3.UP * 0.06],
			["altro_lato", mano - lato * 0.6 + Vector3.UP * 0.06], ["radente", mano + lato * 0.45 + verso * 0.1 + Vector3.UP * 0.015]]
	# il punto della mano più dentro la cima, di lato a filo della cima (fov stretto)
	var basso := _mano_piu_bassa(verso)
	print("RAVVICINATO: il punto della mano più basso sopra il muro in %s, %+.1f mm dalla cima" % [basso.snapped(Vector3.ONE * 0.001),
			(basso.y - cima_y) * 1000.0])
	pose.append(["sezione_lato", basso + lato * 0.35 + Vector3.UP * 0.004, basso])
	pose.append(["sezione_altro_lato", basso - lato * 0.35 + Vector3.UP * 0.004, basso])
	for v in pose:
		cam.global_position = v[1]
		cam.fov = 45.0 if v.size() < 3 else 14.0
		cam.look_at(Vector3(mano.x, cima_y + 0.02, mano.z) if v.size() < 3 else (v[2] as Vector3), Vector3.UP)
		cam.make_current()
		for i in 4:
			await get_tree().process_frame
		await _salva("vasca3_mano_%s" % v[0])
	(lei as Node).process_mode = Node.PROCESS_MODE_INHERIT
	sala.set_process(true)
	cam.queue_free()
	p.camera.make_current()


## Vasca 2, sale_puntata, dal fondo: l'angolo dell'occhio e gli scatti.
func _vasca2(occhi: Vector3) -> void:
	_metti_occhi(occhi)
	await _da_capo("vasca_1", 1)
	var ap := _ap()
	print("COLLAUDO: vasca 2: occhi in %s, lei in %s, durata della salita %.2f s" % [occhi.snapped(Vector3.ONE * 0.01),
			lei.global_position.snapped(Vector3.ONE * 0.01), float(sala.get_meta(&"durata_salita"))])
	var peggio := 0.0
	var peggio_su := 0.0
	var istanti := [0.3, 0.45, 0.6, 0.7, 0.85, 1.0, 1.3, 1.6]
	var k := 0
	var su_da := -1
	for f in 120:
		sala._lei_aggiorna(1.0 / 30.0, p)
		await get_tree().process_frame
		var tc := ap.current_animation_position if String(ap.current_animation).begins_with("inseguimento/sale") else 99.0
		var a := _angolo_occhio()
		var testa_su := (lei as MedusaAffacciata).get_eye_position().y > occhi.y + 1.0
		if sala.lei_stato == SalaInseguimento.Lei.SALE and testa_su:
			peggio = maxf(peggio, a)
		elif sala.lei_stato == SalaInseguimento.Lei.SU:
			peggio_su = maxf(peggio_su, a)
		if OS.has_environment("OGNI_FOTOGRAMMA"):
			print("FOTOGRAMMA: vasca 2 %.2f s %s occhio a %.1f gradi" % [tc, SalaInseguimento.Lei.keys()[sala.lei_stato], a])
		if sala.lei_stato == SalaInseguimento.Lei.SU and su_da < 0:
			su_da = f
		if _scatti:
			p.look_at_point((lei as MedusaAffacciata).get_eye_position())
			p.camera.global_transform = p.get_aim_transform()
			p.camera.make_current()
			if k < istanti.size() and tc >= float(istanti[k]) - 0.001:
				await _salva("vasca2_fondo_%.2fs" % float(istanti[k]))
				k += 1
		if su_da >= 0 and f - su_da > 20:
			break
	print("VASCA2: occhio sul giocatore: salendo (sopra la sua testa) al più %.1f gradi, da su al più %.1f gradi; su dopo %.2f s" % [
			peggio, peggio_su, su_da / 30.0])
	await _respinta("vasca 2")


## Subito su, il getto: la discesa da respinta (il salto all'inizio e quanto dura).
func _respinta(nome: String) -> void:
	if sala.lei_stato != SalaInseguimento.Lei.SU:
		print("RESPINTA: %s: lei non è su (%s)" % [nome, SalaInseguimento.Lei.keys()[sala.lei_stato]])
		return
	var y0 := lei.global_position.y
	sala._scendi(true)
	var salto := sala._salto_discesa(&"inseguimento/respinta")
	var dur := float(sala.get_meta(&"durata_discesa", -1.0))
	var t := 0.0
	for f in 120:
		sala._lei_aggiorna(1.0 / 30.0, p)
		await get_tree().process_frame
		t += 1.0 / 30.0
		if sala.lei_stato == SalaInseguimento.Lei.VIA or not lei.visible:
			break
	print("RESPINTA: %s: discesa prevista %.2f s, sparita dopo %.2f s, salto all'inizio %.3f m, y prima %.2f" % [nome, dur, t, salto, y0])


## Le misure sulla pelle: la quota più alta della mano destra e del resto; il distacco della mano sopra il muro (il
## vertice più basso della mano sopra la cima, dove sotto c'è il muro); i vertici della mano dentro il muro; i vertici
## (tutti) oltre la faccia del muro dalla sua parte e sotto la cima.
func _misura(cima_y: float, verso: Vector3, faccia: float) -> Dictionary:
	var ps := []
	for o in _sk.get_bone_count():
		ps.append(_sk.global_transform * _sk.get_bone_global_pose(o))
	var spazio := sala.get_world_3d().direct_space_state
	var mano_alto := -INF
	var resto_alto := -INF
	var distacco := INF
	var dentro := 0
	var oltre := 0
	var oltre_cm := 0.0
	var base := lei.global_position
	for v in _nv:
		var w := Vector3.ZERO
		for j in 4:
			var pw := _pesi[v * 4 + j]
			if pw > 0.0:
				w += ((ps[_ossa[v * 4 + j]] as Transform3D) * _bv[v * 4 + j]) * pw
		var avanti := (w - base).dot(verso)
		if _mano[v] == 1:
			mano_alto = maxf(mano_alto, w.y)
			if avanti > faccia - 0.01 and w.y < cima_y + 0.3:
				var q := PhysicsRayQueryParameters3D.create(w + Vector3.UP * 0.3, w + Vector3.DOWN * 0.5, 0xFFFFFFFF)
				q.hit_from_inside = false
				var r := spazio.intersect_ray(q)
				if not r.is_empty() and (r.normal as Vector3).y > 0.9 and absf((r.position as Vector3).y - cima_y) < 0.02:
					distacco = minf(distacco, w.y - (r.position as Vector3).y)
					if w.y < (r.position as Vector3).y - 0.002:
						dentro += 1
		else:
			resto_alto = maxf(resto_alto, w.y)
		# oltre la faccia del muro e sotto la cima: dentro o al di là del muro
		if avanti > faccia + 0.002 and w.y < cima_y - 0.002:
			if avanti < faccia + _spessore - 0.002:
				oltre += 1
				oltre_cm = maxf(oltre_cm, (avanti - faccia) * 100.0)
			else:
				_dita_giu = maxf(_dita_giu, (cima_y - w.y) * 100.0)
	return {"mano_alto": mano_alto, "resto_alto": resto_alto, "distacco": distacco, "dentro": dentro, "oltre": oltre,
			"oltre_cm": oltre_cm}


## La cima del muro davanti a lei (raggio dall'alto) e la sua faccia (raggio orizzontale da lei, 30 cm sotto la cima):
## restituisce (distanza della faccia da lei, quota della cima, 0).
func _cima_muro(da: Vector3, verso: Vector3) -> Vector3:
	var spazio := sala.get_world_3d().direct_space_state
	var faccia := 0.0
	var cima := 0.0
	var ultimo := {}
	# dall'alto in giù: il primo colpo davanti a lei è la parte alta del muro
	for h in range(0, 120):
		var y := da.y + 6.0 - h * 0.05
		var q := PhysicsRayQueryParameters3D.create(Vector3(da.x, y, da.z), Vector3(da.x, y, da.z) + verso * 3.0, 0xFFFFFFFF)
		var r := spazio.intersect_ray(q)
		if not r.is_empty():
			ultimo = r
			faccia = (r.position as Vector3 - Vector3(da.x, y, da.z)).length()
			# (la faccia un po' più in basso, lontano dallo smusso della cima)
			var q2 := PhysicsRayQueryParameters3D.create(Vector3(da.x, y - 0.3, da.z), Vector3(da.x, y - 0.3, da.z) + verso * 3.0, 0xFFFFFFFF)
			var r2 := spazio.intersect_ray(q2)
			if not r2.is_empty():
				faccia = (r2.position as Vector3 - Vector3(da.x, y - 0.3, da.z)).length()
			break
	if not ultimo.is_empty():
		var sopra := (ultimo.position as Vector3) + verso * 0.05 + Vector3.UP * 0.5
		var r2 := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(sopra, sopra + Vector3.DOWN * 1.0, 0xFFFFFFFF))
		if not r2.is_empty():
			cima = (r2.position as Vector3).y
	# lo spessore: dalla vasca verso di lei, 30 cm sotto la cima
	var dentro := Vector3(da.x, cima - 0.3, da.z) + verso * (faccia + 1.5)
	var q3 := PhysicsRayQueryParameters3D.create(dentro, dentro - verso * 1.5, 0xFFFFFFFF)
	var r3 := spazio.intersect_ray(q3)
	var spessore := (faccia + 1.5 - (r3.position as Vector3 - Vector3(da.x, cima - 0.3, da.z)).dot(verso)) if not r3.is_empty() else -1.0
	return Vector3(faccia, cima, 1.5 - spessore if spessore >= 0 else -1.0)


## Il vertice della mano più basso fra quelli sopra il muro (fra la sua faccia e quella dentro la vasca).
func _mano_piu_bassa(verso: Vector3) -> Vector3:
	var ps := []
	for o in _sk.get_bone_count():
		ps.append(_sk.global_transform * _sk.get_bone_global_pose(o))
	var meglio := Vector3(0, INF, 0)
	var faccia := sala._muro_della_vasca()
	var base := lei.global_position
	var f0 := (Vector3(faccia.x, base.y, faccia.z) - base).dot(verso)
	for v in _nv:
		if _mano[v] != 1:
			continue
		var w := Vector3.ZERO
		for j in 4:
			if _pesi[v * 4 + j] > 0.0:
				w += ((ps[_ossa[v * 4 + j]] as Transform3D) * _bv[v * 4 + j]) * _pesi[v * 4 + j]
		var avanti := (w - base).dot(verso)
		if avanti > f0 + 0.01 and avanti < f0 + _spessore - 0.01 and w.y < meglio.y:
			meglio = w
	return meglio


func _mano_media() -> Vector3:
	var ps := []
	for o in _sk.get_bone_count():
		ps.append(_sk.global_transform * _sk.get_bone_global_pose(o))
	var c := Vector3.ZERO
	var n := 0
	for v in _nv:
		if _mano[v] != 1:
			continue
		var w := Vector3.ZERO
		for j in 4:
			if _pesi[v * 4 + j] > 0.0:
				w += ((ps[_ossa[v * 4 + j]] as Transform3D) * _bv[v * 4 + j]) * _pesi[v * 4 + j]
		c += w
		n += 1
	return c / maxi(n, 1)


func _angolo_occhio() -> float:
	var o := _sk.find_bone("occhio")
	if o < 0:
		return -1.0
	var g := _sk.global_transform * _sk.get_bone_global_pose(o)
	return rad_to_deg(g.basis.y.normalized().angle_to((p.get_eye_position() - g.origin).normalized()))


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%02d_%s.jpg" % [_n_scatto, nome]), 0.9)
	print("SCATTO %02d_%s" % [_n_scatto, nome])
	_n_scatto += 1


## I vertici della pelle (4 ossa per vertice, come lo skinning), segnando quelli della mano destra e delle sue dita.
func _pelle(m: Node3D) -> void:
	_sk = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mano := {}
	for o in _sk.get_bone_count():
		var n := _sk.get_bone_name(o)
		if n.ends_with(".R") and DITA.any(func(d): return n.begins_with(d)):
			mano[o] = true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var skin := (mi as MeshInstance3D).skin
		if mesh == null or skin == null:
			continue
		var bind_osso := PackedInt32Array()
		for bb in skin.get_bind_count():
			var nome := skin.get_bind_name(bb)
			bind_osso.append(_sk.find_bone(nome) if nome != "" else skin.get_bind_bone(bb))
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_BONES] == null:
				continue
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var per: int = bo.size() / vs.size()
			for v in vs.size():
				var lista := []
				for j in per:
					if float(we[v * per + j]) > 0.0:
						lista.append([float(we[v * per + j]), int(bo[v * per + j])])
				if lista.is_empty():
					continue
				lista.sort_custom(func(x, y): return x[0] > y[0])
				lista = lista.slice(0, 4)
				var somma := 0.0
				for e in lista:
					somma += e[0]
				for j in 4:
					if j < lista.size():
						_ossa.append(bind_osso[lista[j][1]])
						_pesi.append(lista[j][0] / somma)
						_bv.append(skin.get_bind_pose(lista[j][1]) * vs[v])
					else:
						_ossa.append(0)
						_pesi.append(0.0)
						_bv.append(Vector3.ZERO)
				_mano.append(1 if mano.has(bind_osso[lista[0][1]]) else 0)
				_nv += 1
