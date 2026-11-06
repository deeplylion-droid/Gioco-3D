extends Node
## Collaudo delle sagome del club nelle condotte dell'inseguimento (SagomeClub, scelta A dell'utente del 6 novembre):
## gli scatti dagli occhi del giocatore dentro ogni vasca e quelli ravvicinati di ogni appoggio e legatura (anche 1-2 cm
## di distacco sono un difetto). La sala della torre intera (con le condotte), come scatti_acque_inseguimento.gd.
## Gruppi:
## - "giro": da dentro ogni vasca, gli occhi in piedi nell'acqua (1,65 m sopra il fondo), verso ogni sagoma e tutto
##   intorno; poi gli stati: lei su in ogni vasca, le paratie aperte, la grata calata;
## - "vicino": per ogni sagoma la faccia da vicino, l'appoggio (puntello e mattone sul bordo, o le legature ai montanti
##   viste da dietro, dalla passerella), il punto più basso a contatto col bordo o col grigliato.
## SCATTI_LUCE=1 accende una luce di servizio sulla camera (per vedere la forma da vicino dove la sala è buia).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_sagome_club.gd <cartella> [giro|vicino]

var _cartella := ""
var _cam: Camera3D
var _ins: SalaInseguimento
var _luce := OS.get_environment("SCATTI_LUCE") == "1"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_sagome_club"
	var gruppo: String = a[2] if a.size() > 2 else "giro"
	DirAccess.make_dir_recursive_absolute(_cartella)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	_ins = torre.inseguimento as SalaInseguimento
	for i in 600:
		await get_tree().physics_frame
		if _ins.costruita:
			break
	for i in 30:
		await get_tree().physics_frame
	if _ins.lei:
		_ins.lei.visible = false
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()
	if _luce:
		var l := OmniLight3D.new()
		l.omni_range = 1.5
		l.light_energy = 0.6
		l.shadow_enabled = true
		_cam.add_child(l)
		l.position = Vector3(0.05, 0.08, 0)
	var club := _ins.get_node_or_null(^"SagomeClub") as SagomeClub
	if club == null:
		print("MANCANO le sagome")
		get_tree().quit(1)
		return
	var sagome := club.sagome()
	print("sagome %d" % sagome.size())
	if gruppo == "giro":
		await _giro(sagome)
	else:
		await _vicino(sagome)
	print("FINE")
	get_tree().quit()


## Gli occhi del giocatore in piedi nel mezzo della vasca [param v] (0, 1, 2).
func _occhi(v: int) -> Vector3:
	var d: Dictionary = _ins.dati["vasche"][v]
	var r: Array = d["rett"]
	return Vector3((r[0] + r[2]) * 0.5, float(d["fondo"]) + 1.65, -(r[1] + r[3]) * 0.5)


func _giro(sagome: Array[MeshInstance3D]) -> void:
	for v in 3:
		var occhi := _occhi(v)
		for s in sagome:
			if int(s.get_meta(&"vasca")) != v + 1:
				continue
			var c := (s.global_transform * s.get_aabb()).get_center()
			# un passo verso la sagoma, come chi si gira a guardarla
			var da := occhi + (Vector3(c.x, occhi.y, c.z) - occhi).normalized() * 0.8
			await _scatto("v%d_occhi_%s" % [v + 1, String(s.name).trim_prefix("Sagoma_")], da, c)
		for k in 4:
			var ang := TAU * k / 4.0
			await _scatto("v%d_intorno_%d" % [v + 1, k * 90], occhi, occhi + Vector3(sin(ang), -0.15, -cos(ang)))
	# gli stati: lei su in ogni vasca (dagli occhi, verso di lei), poi le paratie aperte e la grata calata
	for v in 3:
		var su := _ins.call(&"_posto_vasca", v) as Vector3
		_ins.call(&"_lei_sale", "vasca_%d" % v, su)
		for i in 150:
			await get_tree().physics_frame
		var occhi := _occhi(v)
		await _scatto("v%d_lei_su" % (v + 1), occhi, Vector3(su.x, occhi.y + 1.0, su.z))
		await _scatto("v%d_lei_su_intorno" % (v + 1), occhi + (occhi - Vector3(su.x, occhi.y, su.z)).normalized() * 1.2,
				Vector3(su.x, occhi.y + 0.5, su.z))
		_ins.lei.visible = false
		_ins.lei_stato = SalaInseguimento.Lei.VIA
	for k in (_ins.dati["paratie"] as Array).size():
		_ins.apri_paratia(k)
	for i in 240:
		await get_tree().physics_frame
	for v in 3:
		var occhi := _occhi(v)
		var p: Dictionary = _ins.dati["paratie"][v * 2]
		var bers := _ins.b(p["bersaglio"])
		await _scatto("v%d_paratie_aperte" % (v + 1), occhi, bers)
	_ins.cala_grata()
	for i in 200:
		await get_tree().physics_frame
	await _scatto("grata_calata_vasca1", _occhi(0), _occhi(0) + Vector3(0, -0.2, 1))


func _vicino(sagome: Array[MeshInstance3D]) -> void:
	for s in sagome:
		var nome := String(s.name).trim_prefix("Sagoma_")
		var xf := s.global_transform
		var X := xf.basis.x.normalized()
		var Z := xf.basis.z.normalized()
		var b := xf * s.get_aabb()
		var c := b.get_center()
		var piede := xf.origin
		await _scatto("%s_1_faccia" % nome, c + Z * 0.9 + Vector3.UP * 0.05, c)
		if int(s.get_meta(&"vasca")) == 2:
			# le legature, da dietro (dalla passerella) e da davanti, da vicino
			for l in _legature_vicine(s):
				await _scatto("%s_2_legatura_dietro_%d" % [nome, l[0]], l[1] - Z * 0.3 + Vector3.UP * 0.06 + X * 0.08, l[1])
				await _scatto("%s_3_legatura_davanti_%d" % [nome, l[0]], l[1] + Z * 0.3 + Vector3.UP * 0.04 - X * 0.08, l[1])
			await _scatto("%s_4_piede_sul_grigliato" % nome, piede + Z * 0.35 + X * 0.25 + Vector3.UP * 0.08, piede + Vector3.UP * 0.02)
		else:
			# il puntello e il mattone, dal lato e da dietro (fuori dalla vasca), e il punto più basso sul bordo
			await _scatto("%s_2_appoggio_di_lato" % nome, piede - Z * 0.25 + X * 0.55 + Vector3.UP * 0.2, piede - Z * 0.08 + Vector3.UP * 0.05)
			await _scatto("%s_3_appoggio_da_dietro" % nome, piede - Z * 0.75 + Vector3.UP * 0.45, piede - Z * 0.08 + Vector3.UP * 0.1)
			var basso := _punto_basso(s)
			await _scatto("%s_4_contatto_col_bordo" % nome, basso + Z * 0.22 + X * 0.12 + Vector3.UP * 0.05, basso)


## Il punto più basso della sagoma (quello che tocca il bordo o il grigliato), nel mondo.
func _punto_basso(s: MeshInstance3D) -> Vector3:
	var v := (s.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var giu := v[0]
	for p in v:
		if p.y < giu.y:
			giu = p
	return s.global_transform * giu


## Le legature vicine alla sagoma [param s]: [indice, centro] (il nodo, nel mondo).
func _legature_vicine(s: MeshInstance3D) -> Array:
	var out := []
	var b := (s.global_transform * s.get_aabb()).grow(0.05)
	var k := 0
	for l in s.get_parent().get_children():
		if l is MeshInstance3D and String(l.name).begins_with("Legatura"):
			var c: Vector3 = ((l as MeshInstance3D).global_transform * (l as MeshInstance3D).get_aabb()).get_center()
			if b.has_point(c):
				k += 1
				out.append([k, c])
	return out


func _scatto(nome: String, da: Vector3, verso: Vector3) -> void:
	_cam.global_position = da
	_cam.look_at(verso, Vector3.UP)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var suff := "_luce" if _luce else ""
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + suff + ".jpg"), 0.88)
	print("SCATTO ", nome)
