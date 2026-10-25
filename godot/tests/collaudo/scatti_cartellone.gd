extends Node
## Collaudo del cartellone dell'arcobaleno rovinato nel corridoio degli interni (texture
## cartellone_medusa_rovinato.png, alpha MASK): scatti dagli occhi del giocatore (il Player vero, senza zaino) da dove
## passa, avvicinandosi dalle due parti del corridoio, ravvicinato, i due bordi e di taglio lungo il muro (si vede se
## è staccato). Gli interni stanno dove li mette la sala, con l'ambiente e gli attributi della camera della sala
## (LookSala); due luci: com'è all'inizio del gioco e al buio dopo la sala pompe (BLACKOUT).
## Il cartellone si trova dal materiale: la superficie che usa la texture, il suo centro, le misure e la normale.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/scatti_cartellone.gd <cartella> [inizio,buio]

const INTERNI := "res://scenes/interni/interni.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const TEXTURE := "cartellone_medusa_rovinato"
const INTERNI_NELLA_SALA := Transform3D(Basis.IDENTITY, Vector3(-9.7, 0.0, 40.9))

var cartella := "user://scatti_cartellone"
var luci := PackedStringArray(["inizio", "buio"])


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		luci = a[2].split(",", false)
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var radice := Node3D.new()
	radice.name = "SalaSoloInterni"
	var look := LookSala.new()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	radice.add_child(we)
	var interni := (load(INTERNI) as PackedScene).instantiate() as Node3D
	interni.name = "Interni"
	interni.set(&"giocatore_proprio", false)
	interni.transform = INTERNI_NELLA_SALA
	radice.add_child(interni)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	p.name = "Player"
	p.transform = INTERNI_NELLA_SALA * (interni.get_node(^"Gioco/Risveglio") as Node3D).transform
	radice.add_child(p)
	add_child(radice)
	if p.water_pack:
		p.water_pack.set_equipped(false, false)
	await _fotogrammi(30)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var trovati := _cartelloni(interni)
	print("CARTELLONE: %d superfici con la texture" % trovati.size())
	for c in trovati:
		print("  %s superficie %d: centro %s, normale %s, largo %.2f, alto %.2f" % [c["nodo"], c["sup"], c["centro"], c["normale"], c["largo"], c["alto"]])
	for luce in luci:
		if luce == "buio":
			GameState.luci = GameState.Luci.BLACKOUT
			await _fotogrammi(20)
		var k := 0
		for c in trovati:
			await _giro(p, c, "%s_%d" % [luce, k])
			k += 1
	print("CARTELLONE FINITO")
	get_tree().quit()


## Le superfici che usano la texture del cartellone: nodo, indice, centro, normale verso il corridoio, misure.
func _cartelloni(radice: Node) -> Array:
	var out := []
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si) as BaseMaterial3D
			if m == null or m.albedo_texture == null or not m.albedo_texture.resource_path.contains(TEXTURE):
				continue
			var arr := mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var centro := Vector3.ZERO
			var normale := Vector3.ZERO
			for i in v.size():
				centro += mi.global_transform * v[i]
				normale += mi.global_basis * nr[i]
			centro /= maxf(v.size(), 1)
			normale.y = 0.0
			normale = normale.normalized()
			# verso il corridoio: dalla parte dove c'è il pavimento a 0,8 m dal muro (dietro il muro c'è il vuoto, che
			# sembra "libero"); se c'è da tutte e due le parti, dalla parte più libera
			var pav_piu := _pavimento(centro + normale * 0.8)
			var pav_meno := _pavimento(centro - normale * 0.8)
			if (pav_meno and not pav_piu) or (pav_meno == pav_piu and _libero(centro, -normale) > _libero(centro, normale)):
				normale = -normale
			var lungo := normale.cross(Vector3.UP).normalized()
			var u0 := INF
			var u1 := -INF
			var y0 := INF
			var y1 := -INF
			for i in v.size():
				var q := mi.global_transform * v[i] - centro
				u0 = minf(u0, q.dot(lungo))
				u1 = maxf(u1, q.dot(lungo))
				y0 = minf(y0, q.y)
				y1 = maxf(y1, q.y)
			centro += lungo * (u0 + u1) * 0.5 + Vector3.UP * (y0 + y1) * 0.5
			out.append({"nodo": String(mi.get_path()).get_file(), "sup": si, "materiale": m.resource_name,
				"centro": centro, "normale": normale, "lungo": lungo, "largo": u1 - u0, "alto": y1 - y0,
				"trasparenza": m.transparency, "cutoff": m.alpha_scissor_threshold, "cull": m.cull_mode})
			print("  materiale %s: trasparenza %d, soglia %.2f, cull %d" % [m.resource_name, m.transparency, m.alpha_scissor_threshold, m.cull_mode])
	return out


## C'è un pavimento sotto [param punto] (entro 3 m)?
func _pavimento(punto: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 0.5, punto + Vector3.DOWN * 3.0)
	return not get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty()


## Quanto spazio libero c'è da [param da] verso [param dir] (fino a 3 m).
func _libero(da: Vector3, dir: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(da + dir * 0.05, da + dir * 3.0)
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return 3.0 if hit.is_empty() else da.distance_to(hit["position"])


func _giro(p: Player, c: Dictionary, nome: String) -> void:
	var centro: Vector3 = c["centro"]
	var n: Vector3 = c["normale"]
	var lungo: Vector3 = c["lungo"]
	var w: float = c["largo"]
	# il corridoio: a che distanza dal muro passa il giocatore (a metà dello spazio libero, al massimo 1,2 m)
	var via := clampf(_libero(centro, n) * 0.5, 0.5, 1.2)
	var piede := Vector3(centro.x, 0.0, centro.z)
	# lungo il corridoio fin dove si cammina (con mezzo metro di margine), al massimo 2,5 m oltre il cartellone
	var corsia := centro + n * via + Vector3.UP * (1.0 - centro.y)
	var meno := clampf(_libero(corsia, -lungo) - 0.5, 0.0, w * 0.5 + 2.5)
	var piu := clampf(_libero(corsia, lungo) - 0.5, 0.0, w * 0.5 + 2.5)
	var posti := [
		["1_passando_da_una_parte", piede + n * via - lungo * meno, centro],
		["2_passando_dall_altra", piede + n * via + lungo * piu, centro],
		["3_davanti", piede + n * via, centro],
		["4_ravvicinato", piede + n * 0.55, centro],
		["5_bordo_sinistro", piede + n * 0.5 - lungo * (w * 0.5 - 0.35), centro - lungo * w * 0.5],
		["6_bordo_destro", piede + n * 0.5 + lungo * (w * 0.5 - 0.35), centro + lungo * w * 0.5],
		["7_di_taglio", piede + n * 0.3 + lungo * (w * 0.5 + 1.3), centro - lungo * 0.3],
		# di taglio da lontano, dalle due parti (dove si vedrebbe lo sfarfallio col muro dietro)
		["8_lontano_di_taglio_una_parte", piede + n * via - lungo * clampf(_libero(corsia, -lungo) - 0.5, 0.0, 6.0), centro],
		["9_lontano_di_taglio_altra_parte", piede + n * via + lungo * clampf(_libero(corsia, lungo) - 0.5, 0.0, 6.0), centro],
		# gli strappi da vicino (lo strappo grande è all'altezza di 1,5 m)
		["10_strappi_sinistra", piede + n * 0.45 - lungo * w * 0.3, Vector3(centro.x, 1.5, centro.z) - lungo * w * 0.3],
		["11_strappi_destra", piede + n * 0.45 + lungo * w * 0.3, Vector3(centro.x, 1.5, centro.z) + lungo * w * 0.3],
	]
	for po in posti:
		# i piedi sul pavimento vero (se lì non c'è pavimento lo scatto si salta)
		var su: Vector3 = po[1] + Vector3.UP * 1.2
		var q := PhysicsRayQueryParameters3D.create(su, su + Vector3.DOWN * 3.0)
		var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			print("niente pavimento per %s_%s in %s: saltato" % [nome, po[0], po[1]])
			continue
		var piedi: Vector3 = hit["position"] + Vector3.UP * 0.02
		p.teleport(piedi)
		await _fotogrammi(3)
		p.look_at_point(po[2])
		await _fotogrammi(16)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [nome, po[0]]), 0.9)
		var caduto := p.global_position.y < piedi.y - 0.5
		print("scatto -> %s_%s (camera %s)%s" % [nome, po[0], p.camera.global_position, "  CADUTO" if caduto else ""])


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame
