extends Node
## Collaudo finale 0.3.21 (enigmi): la pila dell'angolo a sinistra dell'ingresso del capannone del fiume, dalle pile del
## FILE (come nel gioco), con la Risalita della scena di prova e le luci del blackout.
## - raggi sulle collisioni dalla soglia e dai primi 2 m verso la nicchia (come sonda_nicchia_angolo.gd, ma dal file);
## - le istanze delle pile dentro l'angolo: ognuna appoggiata a quella sotto o al pavimento (scarto stampato);
## - scatti dagli occhi (soglia, 40 cm, 1 m, 2 m, 2 m a ovest, accovacciato) verso la pila, e ravvicinati (SCATTI_LUCE=1)
##   della base, del contatto col muro nord e della cima.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd --
##   <questo file> <cartella> [scatti]

const FIUME_SCRIPT := preload("res://scripts/risalita/fiume_gioco.gd")

var _p: Player
var _cartella := ""
var fiume: Node3D
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _salva(nome: String) -> void:
	await _frames(24)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	print("SCATTO ", nome)


func F(v: Vector3) -> Vector3:
	return fiume.to_global(v)


func _scatto(nome: String, da: Vector3, verso: Vector3, fov := 75.0) -> void:
	cam.fov = fov
	cam.global_position = F(da)
	var su := Vector3.UP if absf((F(verso) - F(da)).normalized().y) < 0.98 else Vector3.FORWARD
	cam.look_at(F(verso), su)
	await _salva(nome)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://collaudo_angolo"
	var con_scatti := "scatti" in a
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	_p = GameState.player
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	ris.call(&"carica_subito")
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and ris.get(&"fiume") != null and i > 120:
			break
	fiume = ris.get(&"fiume") as Node3D
	for i in 10:
		await get_tree().physics_frame
	var b := ris.find_child("BambinoCorridoioFiume", true, false) as Node3D
	if b:
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.visible = false
	var z0: float = FIUME_SCRIPT.Z0
	var ix: float = FIUME_SCRIPT.INGRESSO_X
	print("ANGOLO: Z0 %.3f, INGRESSO_X %.3f, pile dal file: %s" % [z0, ix, fiume.get(&"pile_salvate") != null])
	# 1. raggi verso la nicchia
	var nicchia := []
	for x in [-30.25, -30.0, -29.75, -29.58]:
		for z in [-28.5, -28.15, -27.8, -27.4]:
			for y in [0.25, 0.7, 1.1]:
				nicchia.append(Vector3(x, y, z))
	var occhi := [["soglia", Vector3(ix, 1.6, z0 - 0.15)], ["dentro_40cm", Vector3(ix, 1.6, z0 + 0.4)],
			["dentro_1m", Vector3(ix, 1.6, z0 + 1.0)], ["dentro_2m", Vector3(ix, 1.6, z0 + 2.0)],
			["dentro_2m_ovest", Vector3(ix - 0.8, 1.6, z0 + 2.0)], ["accovacciato_1m", Vector3(ix, 0.9, z0 + 1.0)]]
	var totale := 0
	for o in occhi:
		var visti := 0
		for q: Vector3 in nicchia:
			if _colpo(o[1], q).is_empty():
				visti += 1
		totale += visti
		print("NICCHIA: da %s %d punti su %d visibili" % [o[0], visti, nicchia.size()])
	print("NICCHIA: totale visibili %d" % totale)
	# 2. le istanze delle pile nell'angolo: scatole e unità, una sull'altra
	var ab_angolo := AABB(Vector3(-30.4, -0.2, -28.8), Vector3(2.0, 6.0, 1.7))
	var scatole := []
	for mmi in fiume.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		var m_ab := mm.mesh.get_aabb()
		var xf_loc := fiume.global_transform.affine_inverse() * (mmi as Node3D).global_transform
		for i in mm.instance_count:
			var ab := xf_loc * mm.get_instance_transform(i) * m_ab
			if ab_angolo.encloses(AABB(ab.get_center(), Vector3.ZERO)):
				scatole.append([String(mmi.name), i, ab, mm.get_instance_transform(i).basis.determinant()])
	print("ANGOLO: %d istanze delle pile nell'angolo" % scatole.size())
	var peggio := 0.0
	var specchiate := 0
	for s in scatole:
		var ab: AABB = s[2]
		if s[3] < 0.0:
			specchiate += 1
		var sotto := 0.0     # il pavimento del capannone (y 0 del fiume)
		for t in scatole:
			if t == s:
				continue
			var ab2: AABB = t[2]
			var sopra_xz := ab2.position.x < ab.end.x - 0.02 and ab.position.x < ab2.end.x - 0.02 and ab2.position.z < ab.end.z - 0.02 and ab.position.z < ab2.end.z - 0.02
			if sopra_xz and ab2.end.y <= ab.position.y + 0.03:
				sotto = maxf(sotto, ab2.end.y)
		var scarto := ab.position.y - sotto
		peggio = maxf(peggio, scarto)
		if absf(scarto) > 0.01:
			print("ANGOLO:   %s %d da %s a %s: %.3f m sopra quello che ha sotto" % [s[0], s[1], ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001), scarto])
	var tutto := AABB()
	for k in scatole.size():
		tutto = scatole[k][2] if k == 0 else tutto.merge(scatole[k][2])
	print("ANGOLO: pila da %s a %s; scarto massimo dal sostegno %.3f m; istanze specchiate %d" % [tutto.position.snapped(Vector3.ONE * 0.001), tutto.end.snapped(Vector3.ONE * 0.001), peggio, specchiate])
	# lo spazio fra la pila e il muro nord, a più altezze
	for x in [-29.6, -29.2, -28.8]:
		for y in [0.2, 0.8, 1.6, 2.4]:
			var da := Vector3(x, y, -27.0)
			var r := _colpo(da, da + Vector3(0, 0, -2.5))
			var r2 := {}
			if not r.is_empty():
				var dentro: Vector3 = fiume.to_local(r.position) + Vector3(0, 0, -0.002)
				r2 = _colpo(dentro, dentro + Vector3(0, 0, -1.5))
			print("MURO: x %.1f y %.1f: pila a z %s, muro a z %s" % [x, y, ("%.3f" % fiume.to_local(r.position).z) if not r.is_empty() else "-",
					("%.3f" % fiume.to_local(r2.position).z) if not r2.is_empty() else "-"])
	if not con_scatti:
		print("ANGOLO: FINE")
		get_tree().quit()
		return
	# 3. scatti dagli occhi e ravvicinati
	cam = Camera3D.new()
	cam.near = 0.02
	get_tree().current_scene.add_child(cam)
	cam.make_current()
	if OS.get_environment("SCATTI_LUCE") == "1":
		var l := OmniLight3D.new()
		l.omni_range = 2.5
		l.light_energy = 0.8
		l.shadow_enabled = true
		cam.add_child(l)
	var c := tutto.get_center()
	for o in occhi:
		await _scatto("occhi_%s_verso_pila" % o[0], o[1], Vector3(c.x, 1.0, c.z))
		await _scatto("occhi_%s_avanti" % o[0], o[1], o[1] + Vector3(0, -0.3, 5))
	# ravvicinati: la base ai quattro angoli, il contatto col muro nord dai due lati, la cima
	var lo := tutto.position
	var hi := tutto.end
	for k in [[lo.x, hi.z, "sud_ovest"], [hi.x, hi.z, "sud_est"], [hi.x, lo.z, "nord_est"]]:
		var p := Vector3(k[0], 0.05, k[1])
		var fuori := (p - Vector3(c.x, 0.05, c.z)).normalized()
		await _scatto("base_%s" % k[2], p + fuori * 0.5 + Vector3.UP * 0.3, p, 55.0)
	for y in [0.4, 1.4, 2.4]:
		await _scatto("muro_nord_da_est_%.1f" % y, Vector3(hi.x + 0.6, y + 0.1, lo.z + 0.25), Vector3(hi.x - 0.2, y, lo.z), 55.0)
		await _scatto("muro_nord_dalla_nicchia_%.1f" % y, Vector3(lo.x - 0.45, y + 0.1, lo.z + 0.5), Vector3(lo.x + 0.2, y, lo.z), 55.0)
	await _scatto("cima", Vector3(hi.x + 0.8, hi.y + 0.8, hi.z + 0.8), Vector3(c.x, hi.y, c.z), 60.0)
	await _scatto("nicchia_dall_alto", Vector3(lo.x - 0.3, hi.y + 1.0, hi.z + 0.6), Vector3(-30.0, 0.3, -28.0), 60.0)
	print("ANGOLO: FINE")
	get_tree().quit()


func _colpo(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(fiume.to_global(a), fiume.to_global(b))
	q.hit_from_inside = false
	return fiume.get_world_3d().direct_space_state.intersect_ray(q)
