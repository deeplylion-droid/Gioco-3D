extends Node
## Collaudo di lavoro/varchi-cielo: il controllo del cielo (controllo_cielo.gd) non copre torre, condotte e tunnel; qui
## lo stesso conto nel gioco vero, dalla partenza <id> del menu F9 (torre, inseguimento, tunnel). I posti: nella torre e
## nelle condotte i checkpoint della torre, una griglia 3x3 nel fondo di ogni vasca, i punti delle linee dei tubi (uno
## ogni 6) e il bacino; nel tunnel i checkpoint della sala sottomarina e i punti fra uno e l'altro ogni 2 m. In ogni posto
## il giocatore ci va (le zone si accendono col giocatore vicino), poi dagli occhi 240 raggi in tutte le direzioni (le
## collisioni e le mesh visibili, CorpiMesh, senza l'acqua): un raggio che non tocca niente entro 150 m è cielo.
## Stampa CIELO: i posti con raggi nel cielo (quanti, verso dove in media, quanti in su e in giù) e il totale.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/cielo_zone.gd <id>

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const RAGGI := 240
const DISTANZA := 150.0


func _ready() -> void:
	_run.call_deferred(OS.get_cmdline_user_args()[1])


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _run(id: String) -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), id)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	for i in 60 * 20:
		await get_tree().process_frame
	var sc := get_tree().current_scene as Node3D
	var p := GameState.player
	var posti := []
	if id == "tunnel":
		# lungo la banchina dove si cammina: l'asse del canale (SalaSottomarino.punto) spostato come la ripartenza del
		# primo checkpoint, ogni 3 m (fra un checkpoint e l'altro il canale gira: niente linee dritte)
		for s in sc.find_children("*", "SalaSottomarino", true, false):
			var cps: Array = s.find_children("Checkpoint_*", "Checkpoint", true, false)
			cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
			var s0: float = float((s.get(&"checkpoint_s") as PackedFloat32Array)[0])
			var sp := (cps[0] as Checkpoint).get_spawn_transform().origin
			var dx: float = (sp - s.call(&"punto", s0)).dot(s.call(&"destra", s0))
			var dy: float = sp.y - (s.call(&"punto", s0) as Vector3).y
			var L: float = s.call(&"lunghezza")
			print("CIELO: tunnel lungo %.0f m, banchina a %.2f m dall'asse e %.2f m sopra l'acqua" % [L, dx, dy])
			var q := 0.0
			while q <= L:
				var pt: Vector3 = (s.call(&"punto", q) as Vector3) + (s.call(&"destra", q) as Vector3) * dx + Vector3.UP * dy
				posti.append(["s %.0f" % q, pt])
				q += 3.0
	else:
		for t in sc.find_children("*", "SalaTorre", true, false):
			for c in t.find_children("*", "Checkpoint", true, false):
				posti.append(["torre %s" % c.name, (c as Checkpoint).get_spawn_transform().origin])
		for ins in sc.find_children("*", "SalaInseguimento", true, false):
			var d: Dictionary = ins.get(&"dati")
			for i in (d["vasche"] as Array).size():
				var v: Dictionary = d["vasche"][i]
				var r: Array = v["rett"]
				for fx in [0.2, 0.5, 0.8]:
					for fz in [0.2, 0.5, 0.8]:
						posti.append(["vasca %d" % i, SalaInseguimento.b([lerpf(r[0], r[2], fx), lerpf(r[1], r[3], fz), float(v["fondo"]) + 0.05])])
			for nome: String in d["tubi"]:
				var linea: Array = d["tubi"][nome]
				for k in range(0, linea.size(), 6):
					posti.append([nome, SalaInseguimento.b(linea[k]) + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1)])
			var bc: Dictionary = d["bacino"]
			var rb: Array = bc["rett"]
			for fx in [0.25, 0.75]:
				for fz in [0.25, 0.75]:
					posti.append(["bacino", SalaInseguimento.b([lerpf(rb[0], rb[2], fx), lerpf(rb[1], rb[3], fz), float(bc["fondo"]) + 0.05])])
	print("CIELO: %s: %d posti" % [id, posti.size()])
	var dirs: Array[Vector3] = []
	for i in RAGGI:
		var y := 1.0 - 2.0 * (i + 0.5) / RAGGI
		var r := sqrt(1.0 - y * y)
		var th := PI * (3.0 - sqrt(5.0)) * i
		dirs.append(Vector3(cos(th) * r, y, sin(th) * r))
	var con_cielo := 0
	var su_tot := 0
	var giu_tot := 0
	var morti := 0
	var scatole := []
	var scatole_di: Node = null
	var cupola := 0
	for ps in posti:
		# (se il giocatore muore la sala si ricarica: si aspetta e si riprende la scena nuova)
		if not _pronto() or not is_instance_valid(sc) or not is_instance_valid(p):
			morti += 1
			var t1 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t1 < 300000 and not _pronto():
				await get_tree().process_frame
			for i in 120:
				await get_tree().process_frame
			sc = get_tree().current_scene as Node3D
			p = GameState.player
		for ins in sc.find_children("*", "SalaInseguimento", true, false):
			ins.set(&"tempo_presa", 9999.0)
		p.teleport((ps[1] as Vector3) + Vector3.UP * 0.1)
		for i in 20:
			await get_tree().physics_frame
		if not _pronto():
			print("CIELO: %s, %s: il giocatore è morto lì (%s), salto il posto" % [id, ps[0], (ps[1] as Vector3).snapped(Vector3.ONE * 0.01)])
			continue
		CorpiMesh.crea(sc, AABB(ps[1], Vector3.ZERO).grow(80.0), p)
		for i in 2:
			await get_tree().physics_frame
		var occhio: Vector3 = p.global_position + Vector3.UP * (p.crouch_eye_height if p.accovacciato_forzato else 1.6)
		var spazio := get_viewport().find_world_3d().direct_space_state
		var fuori: Array[Vector3] = []
		for dd in dirs:
			var q := PhysicsRayQueryParameters3D.create(occhio, occhio + dd * DISTANZA, 0xFFFFFFFF, [(p as CollisionObject3D).get_rid()])
			q.hit_back_faces = true
			if spazio.intersect_ray(q).is_empty():
				fuori.append(dd)
		if fuori.is_empty():
			continue
		# come controllo_cielo.gd: il cielo della tempesta visto dalla cupola di vetro della sala è voluto
		if scatole.is_empty() or scatole_di != sc:
			scatole = _scatole(sc)
			scatole_di = sc
		var uscite := {}
		var dalla_cupola := 0
		var resto: Array[Vector3] = []
		for dd in fuori:
			var u := _uscita(scatole, occhio, dd)
			if u.contains("Cupola"):
				dalla_cupola += 1
			else:
				resto.append(dd)
				uscite[u] = int(uscite.get(u, 0)) + 1
		if resto.is_empty():
			cupola += 1
			continue
		fuori = resto
		con_cielo += 1
		var media := Vector3.ZERO
		var su := 0
		var giu := 0
		for dd in fuori:
			media += dd
			if dd.y > 0.5:
				su += 1
			elif dd.y < -0.5:
				giu += 1
		su_tot += su
		giu_tot += giu
		print("CIELO: %s, %s: occhi in %s, %d raggi su %d nel cielo (in su %d, in giù %d), verso %s, escono da %s" % [id, ps[0],
				occhio.snapped(Vector3.ONE * 0.01), fuori.size(), RAGGI, su, giu, media.normalized().snapped(Vector3.ONE * 0.01), uscite])
	print("CIELO: %s: posti %d, con il cielo %d (raggi in su %d, in giù %d), ricariche dopo una morte %d; posti che vedono il cielo solo dalla cupola di vetro (voluto) %d" % [id, posti.size(), con_cielo, su_tot, giu_tot, morti, cupola])
	print("CIELO: finito")
	get_tree().quit()


func _scatole(sc: Node) -> Array:
	var out := []
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh and m.is_visible_in_tree():
			out.append([m.global_transform * m.get_aabb(), String(sc.get_path_to(m))])
	return out


## Come controllo_cielo.gd: l'ultima scatola di mesh che il raggio attraversa prima di uscire.
func _uscita(scatole: Array, da: Vector3, d: Vector3) -> String:
	var fine := da + d * DISTANZA
	var meglio := ""
	var lontano := -1.0
	for sc in scatole:
		var b: AABB = sc[0]
		if b.size.length() > 300.0 or not b.intersects_segment(da, fine):
			continue
		var u: Variant = b.intersects_segment(fine, da)
		var t := da.distance_to(u as Vector3) if u != null else 0.0
		if t > lontano:
			lontano = t
			var pezzi := String(sc[1]).split("/")
			meglio = "/".join(pezzi.slice(0, 3)) + ("/…/" + pezzi[-1] if pezzi.size() > 3 else "")
	return meglio if meglio != "" else "niente"
