extends Node
## Collaudo dei tentacoli di lei (23 ottobre): registra lo scheletro di lei fotogramma per fotogramma in una scena (come
## sonda_squalo_scena.gd: pose delle ossa nel mondo e, una volta sola, la pelle a riposo), per misurare fuori da Godot
## la pelle deformata contro la geometria vera della scena.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_lei.gd <modo> <cartella>
##   modo: sbuca (lei che sbuca dalla fossa, come test_morbidezza_sbuca) | inseguimento (i posti di test_morbidezza_inseguimento)

const PASSO := 2

var cartella := ""
var modo := ""
var _bin: FileAccess
var _fot := []
var _info := {}
var _t := 0.0
var _tag := ""


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var a := OS.get_cmdline_user_args()
	modo = a[1]
	cartella = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	_bin = FileAccess.open(cartella + "/pelle.bin", FileAccess.WRITE)
	if modo == "sbuca":
		await _sbuca()
	elif modo == "tuffo":
		await _sbuca(true)
	elif modo.begins_with("v2_"):
		await _vasca2(modo)
	else:
		await _inseguimento()
	_bin.close()
	var out := FileAccess.open(cartella + "/scena.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"info": _info, "fotogrammi": _fot}))
	out.close()
	print("SONDA LEI: %d fotogrammi" % _fot.size())
	get_tree().quit()


var _ultima := PackedFloat32Array()
var _sk_mod: Skeleton3D


## Le pose come escono dall'ultimo modificatore dello scheletro (tuffo, morbidezza): fuori dal segnale le loro modifiche
## non si leggono.
func _su_mod() -> void:
	var sk := _sk_mod
	var buf := PackedFloat32Array()
	for bi in sk.get_bone_count():
		var gp := sk.global_transform * sk.get_bone_global_pose(bi)
		for c in [gp.basis.x, gp.basis.y, gp.basis.z, gp.origin]:
			buf.append(c.x); buf.append(c.y); buf.append(c.z)
	_ultima = buf


func _aggancia(sk: Skeleton3D) -> void:
	_sk_mod = sk
	var ultimo: SkeletonModifier3D = null
	for c in sk.get_children():
		if c is SkeletonModifier3D and (c as SkeletonModifier3D).active:
			ultimo = c
	for c in sk.get_children():
		if c is SkeletonModifier3D and c.modification_processed.is_connected(_su_mod) and c != ultimo:
			c.modification_processed.disconnect(_su_mod)
	if ultimo and not ultimo.modification_processed.is_connected(_su_mod):
		ultimo.modification_processed.connect(_su_mod)


func _registra(lei: Node3D, sk: Skeleton3D, durata: float) -> void:
	var t := 0.0
	var n := 0
	while t < durata:
		_aggancia(sk)
		await get_tree().process_frame
		t += get_process_delta_time()
		_t += get_process_delta_time()
		n += 1
		if n % PASSO != 0:
			continue
		if _info.is_empty():
			_scrivi_riposo(lei, sk, _info)
		if _ultima.is_empty():
			_su_mod()
		_bin.store_buffer(_ultima.to_byte_array())
		var cam := get_viewport().get_camera_3d()
		_fot.append({"t": snappedf(_t, 0.001), "tag": _tag, "tl": snappedf(t, 0.001), "camera": _v(cam.global_position) if cam else []})


## COLLAUDO_SCATTI_LEI=<cartella>, COLLAUDO_MIRE="tag:x,y,z;tag:x,y,z": alla fine di ogni registrazione, uno scatto dalla
## camera del giocatore e, per ogni mira di quel tag, uno da vicino (1 m di lato e 0,5 m sopra, con una luce).
func _scatti(tag: String, lei: Node3D) -> void:
	var dir := OS.get_environment("COLLAUDO_SCATTI_LEI")
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(dir.path_join(tag + "_giocatore.jpg"), 0.88)
	var vecchia := get_viewport().get_camera_3d()
	var k := 0
	for m in OS.get_environment("COLLAUDO_MIRE").split(";", false):
		if m.get_slice(":", 0) != tag:
			continue
		var c := m.get_slice(":", 1).split(",")
		var q := Vector3(float(c[0]), float(c[1]), float(c[2]))
		var via := q - lei.global_position
		via.y = 0
		via = via.normalized() if via.length() > 0.01 else Vector3.FORWARD
		var cam := Camera3D.new()
		cam.fov = 60
		cam.near = 0.02
		get_tree().current_scene.add_child(cam)
		for lato in [0.0, 0.9]:
			cam.global_position = q + via.rotated(Vector3.UP, lato) * 1.0 + Vector3.UP * 0.5
			cam.look_at(q, Vector3.UP)
			cam.make_current()
			var luce := OmniLight3D.new()
			luce.omni_range = 6.0
			luce.light_energy = 1.2
			cam.add_child(luce)
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(dir.path_join("%s_vicino_%d_%s.jpg" % [tag, k, "a" if lato == 0.0 else "b"]), 0.88)
			luce.queue_free()
		cam.queue_free()
		k += 1
	if vecchia:
		vecchia.make_current()


func _sbuca(tuffo := false) -> void:
	# COLLAUDO_TOGLI="nodo,nodo": per gli scatti, la sala senza le zone che non servono (e senza GI e particelle), se no
	# il renderer del sandbox va fuori memoria
	if OS.get_environment("COLLAUDO_TOGLI") != "":
		var liv := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
		for nn in OS.get_environment("COLLAUDO_TOGLI").split(",", false):
			var x := liv.get_node_or_null(NodePath(nn))
			if x:
				x.get_parent().remove_child(x)
				x.free()
		for classe in ["VoxelGI", "LightmapGI", "ReflectionProbe", "GPUParticles3D", "CPUParticles3D", "FogVolume"]:
			for x in liv.find_children("*", classe, true, false):
				var dentro_giocatore := false
				var y: Node = x
				while y:
					if y is CharacterBody3D:
						dentro_giocatore = true
					y = y.get_parent()
				if not dentro_giocatore:
					x.get_parent().remove_child(x)
					x.free()
		get_tree().root.add_child(liv)
		get_tree().current_scene = liv
	else:
		get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var level := get_tree().current_scene
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lei := level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	GameState.player.teleport(lei.punto_sbuca.global_position + lei.punto_sbuca.global_basis.z * 7.0 + Vector3(0, 0.1, 0), 0.0, 0.0)
	await get_tree().physics_frame
	lei.call(&"_ricomincia")
	for i in 3:
		await get_tree().process_frame
	if tuffo:
		# come test_morbidezza: affacciata (la morbidezza accesa), poi la spruzzata e il tuffo fino a quando sparisce
		lei.call(&"_affaccia")
		for i in 5:
			await get_tree().process_frame
		var skt := lei.medusa.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		_tag = "affacciata"
		await _registra(lei.medusa, skt, 2.0)
		await _scatti("affacciata", lei.medusa)
		lei.set(&"abilitata", true)
		print("TUFFO: fase ", lei.fase, " abilitata ", lei.get(&"abilitata"))
		lei.call(&"_on_spruzzata", 1.0, Vector3.ZERO, Vector3.ZERO)
		_tag = "tuffo"
		var t := 0.0
		while t < 12.0 and lei.medusa.visible:
			await _registra(lei.medusa, skt, 0.1)
			t += 0.1
		return
	var m := MorbidezzaLei.su(lei.medusa)
	var sk := m.get_parent() as Skeleton3D
	_tag = "sbuca"
	lei.call(&"_sbuca")
	await _registra(lei.medusa, sk, lei.durata_sbuca + 4.0)
	await _scatti("sbuca", lei.medusa)


## Vasca 2 dell'inseguimento in tre modi: v2_giro (vasca 0, 1 e 2 di seguito, come il test), v2_solo (solo la vasca 2,
## dalla scena appena caricata), v2_checkpoint (il giocatore nel punto di ripartenza del checkpoint della vasca 2, come
## dopo una morte: lei sale da sola con la logica del gioco; con COLLAUDO_SCATTI_LEI gli scatti dagli occhi del
## giocatore ogni 15 fotogrammi).
func _vasca2(modo: String) -> void:
	# dal checkpoint serve il giocatore: la scena di prova dei test (la sala dell'inseguimento vera, nello stesso posto,
	# con il giocatore)
	get_tree().change_scene_to_file("res://scenes/test/inseguimento_prova.tscn" if modo == "v2_checkpoint" else "res://scenes/sala/torre/sala_torre.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var sala := get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	sala.tempo_presa = 1e6
	for i in 5:
		await get_tree().process_frame
	var m := MorbidezzaLei.su(sala.lei)
	var sk := m.get_parent() as Skeleton3D
	if modo == "v2_giro":
		for v in [0, 1]:
			_tag = "prima_vasca_%d" % v
			sala.call(&"_lei_sale", "vasca_%d" % v, sala.call(&"_posto_vasca", v), 1.6)
			await _registra(sala.lei, sk, float(sala.get_meta(&"durata_salita", 1.6)) + 2.5)
			if sala.lei_stato != SalaInseguimento.Lei.VIA:
				sala.call(&"_scendi")
			for i in 120:
				await get_tree().process_frame
				if sala.lei_stato == SalaInseguimento.Lei.VIA:
					break
	if modo == "v2_checkpoint":
		var su: Vector3 = sala.call(&"_posto_vasca", 2)
		var cp: Checkpoint = null
		# il checkpoint della vasca 2: quello col punto di ripartenza dentro la vasca 2 (come la vede il gioco)
		for c in sala.checkpoint:
			if c.spawn_point and int(sala.call(&"_vasca_di", c.spawn_point.global_position)) == 2:
				cp = c
		if cp == null:
			var dmin := 1e9
			for c in sala.checkpoint:
				if c.spawn_point and c.spawn_point.global_position.distance_to(su) < dmin:
					dmin = c.spawn_point.global_position.distance_to(su)
					cp = c
		if cp == null:
			print("SONDA LEI: nessun checkpoint per la vasca 2")
			return
		var rip := cp.spawn_point
		print("SONDA LEI: ripartenza ", cp.name, " ", rip.global_position)
		GameState.player.teleport(rip.global_position, rip.global_rotation.y, 0.0)
		_tag = "vasca_2"
		var dir := OS.get_environment("COLLAUDO_SCATTI_LEI")
		var k := 0
		var t := 0.0
		var sale := false
		while t < 25.0:
			_aggancia(sk)
			await get_tree().process_frame
			t += get_process_delta_time()
			if int(t * 2.0) != int((t - get_process_delta_time()) * 2.0):
				print("SONDA LEI: t %.1f vasca %s giocatore %s stato %s" % [t, sala.get(&"_vasca"), GameState.player.global_position.snapped(Vector3.ONE * 0.01), sala.lei_stato])
			if sala.lei_stato != SalaInseguimento.Lei.VIA and not sale:
				sale = true
				print("SONDA LEI: lei sale a %.2f s" % t)
				break
		var durata := float(sala.get_meta(&"durata_salita", 1.6)) + 2.5
		var tt := 0.0
		var n := 0
		while tt < durata:
			await _registra(sala.lei, sk, 0.25)
			tt += 0.25
			if dir != "":
				DirAccess.make_dir_recursive_absolute(dir)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg(dir.path_join("v2_checkpoint_%02d.jpg" % n), 0.88)
				n += 1
		return
	_tag = "vasca_2"
	sala.call(&"_lei_sale", "vasca_2", sala.call(&"_posto_vasca", 2), 1.6)
	await _registra(sala.lei, sk, float(sala.get_meta(&"durata_salita", 1.6)) + 2.5)
	await _scatti("vasca_2", sala.lei)


func _inseguimento() -> void:
	get_tree().change_scene_to_file("res://scenes/sala/torre/sala_torre.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var sala := get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	sala.tempo_presa = 1e6
	for i in 5:
		await get_tree().process_frame
	var m := MorbidezzaLei.su(sala.lei)
	var sk := m.get_parent() as Skeleton3D
	for dove in ["vasca_0", "vasca_1", "vasca_2", "scolo_0", "scolo_1", "scolo_2", "grata", "sb1"]:
		_tag = dove
		match dove:
			"grata":
				sala.call(&"_lei_alla_grata")
			"sb1":
				sala.call(&"_lei_sale", "sb1", sala.call(&"_posto_sb1"), 1.3)
			_:
				var su: Vector3 = sala.call(&"_posto_vasca", int(dove[-1])) if dove.begins_with("vasca") else sala.call(&"_posto_scolo", int(dove[-1]))
				sala.call(&"_lei_sale", dove, su, 1.2 if dove.begins_with("scolo") else 1.6)
		await _registra(sala.lei, sk, float(sala.get_meta(&"durata_salita", 1.6)) + 2.5)
		await _scatti(dove, sala.lei)
		if sala.lei_stato != SalaInseguimento.Lei.VIA:
			sala.call(&"_scendi")
		for i in 120:
			await get_tree().process_frame
			if sala.lei_stato == SalaInseguimento.Lei.VIA:
				break


## La pelle a riposo: per ogni mesh con la skin, i bind (osso e matrice) e per ogni superficie vertici, ossa, pesi e
## indici (file .bin), più il materiale.
func _scrivi_riposo(sq: Node, sk: Skeleton3D, info: Dictionary) -> void:
	info["ossa"] = sk.get_bone_count()
	var nomi := []
	for bi in sk.get_bone_count():
		nomi.append(sk.get_bone_name(bi))
	info["nomi_ossa"] = nomi
	info["mesh"] = []
	for mi in sq.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		var binds := []
		for i in m.skin.get_bind_count():
			var o := m.skin.get_bind_bone(i)
			if o < 0:
				o = sk.find_bone(m.skin.get_bind_name(i))
			var bp := m.skin.get_bind_pose(i)
			binds.append([o, [bp.basis.x.x, bp.basis.x.y, bp.basis.x.z, bp.basis.y.x, bp.basis.y.y, bp.basis.y.z,
					bp.basis.z.x, bp.basis.z.y, bp.basis.z.z, bp.origin.x, bp.origin.y, bp.origin.z]])
		var sup := []
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var base := cartella + "/%s_%d_%d" % [m.name, info["mesh"].size(), si]
			for coppia in [["v", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)], ["i", arr[Mesh.ARRAY_INDEX]],
					["b", arr[Mesh.ARRAY_BONES]], ["w", arr[Mesh.ARRAY_WEIGHTS]]]:
				var fi := FileAccess.open(base + "_" + coppia[0] + ".bin", FileAccess.WRITE)
				var dato = coppia[1]
				if dato is PackedVector3Array:
					var pf := PackedFloat32Array()
					for v in dato:
						pf.append(v.x); pf.append(v.y); pf.append(v.z)
					fi.store_buffer(pf.to_byte_array())
				elif dato != null:
					fi.store_buffer(dato.to_byte_array())
				fi.close()
			var mat := m.mesh.surface_get_material(si)
			sup.append({"file": base.get_file(), "materiale": mat.resource_name if mat else "",
					"vertici": (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
					"ossa_per_vertice": (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(1, (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())})
		info["mesh"].append({"nome": String(m.name), "binds": binds, "superfici": sup})


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


