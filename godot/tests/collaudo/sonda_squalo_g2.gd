extends Node
## grafica-2, collaudo della scena dello squalo della 0.3.22 (lavoro/squalo-paura): le misure che dagli scatti non si
## leggono. Si lancia come scena (con --script il gioco salta la scena dello squalo), anche senza schermo.
## Modo "misure" (gli interni come in giro_squalo.gd "interni"): a ogni fotogramma della scena
## - la camera: distanza dai muri (raggi in 26 direzioni sulle collisioni del mondo) e salti fra un fotogramma e l'altro;
## - lo squalo: per le ossa dei piedi, delle mani, del muso e della testa la distanza dalla superficie più vicina, e per
##   i piedi l'altezza sul pavimento e quanto scivolano mentre stanno a terra;
## - le lampade del corridoio (fattore, energia) e la luce della scena; la goccia sullo schermo;
## - i suoni: ogni player che parte, con la posizione rispetto alla camera (destra/sinistra) e alla fine chi suona ancora.
## Modo "interruzioni" (il gioco vero, dalla schermata di caricamento come Nuova partita): pausa nel buio, pausa durante
## la goccia, torna al titolo a metà scena, Nuova partita fino alla fine, Continua. Dopo ogni passo: le lampade del
## corridoio (mai al 3%), la goccia, i suoni accesi.
## Modo "ravvicinati" (col renderer): una camera sua, fuori da quella del giocatore, per la bocca e i denti nei morsi e
## nella pausa (di lato e di fronte) e per i piedi mentre arriva nel buio e mentre se ne va, con una luce bianca sulla
## camera; salva in <cartella> (secondo argomento).
## Uso (sotto il render.lock): godot --headless --path godot res://tests/collaudo/sonda_squalo_g2.tscn -- <misure|interruzioni>

const CARICAMENTO := "res://scenes/ui/caricamento.tscn"
const INTERNI := "res://scenes/interni/interni.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const INTERNI_NELLA_SALA := Transform3D(Basis.IDENTITY, Vector3(-9.7, 0.0, 40.9))
const DIREZIONI := 26

var registratore := false
var modo := "misure"


func _ready() -> void:
	if registratore:
		match modo:
			"misure":
				_misure.call_deferred()
			"ravvicinati":
				_ravvicinati.call_deferred()
			_:
				_interruzioni.call_deferred()
		return
	var a := OS.get_cmdline_user_args()
	var r := Node.new()
	r.set_script(get_script())
	r.name = "SondaSqualo"
	r.set(&"registratore", true)
	r.set(&"modo", a[0] if a.size() > 0 else "misure")
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
	GameState.reset_progress()
	if r.get(&"modo") != "interruzioni":
		_monta_interni.call_deferred()


func _monta_interni() -> void:
	var radice := Node3D.new()
	radice.name = "SalaSoloInterni"
	var interni := (load(INTERNI) as PackedScene).instantiate() as Node3D
	interni.name = "Interni"
	interni.set(&"giocatore_proprio", false)
	interni.transform = INTERNI_NELLA_SALA
	radice.add_child(interni)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	p.name = "Player"
	p.transform = INTERNI_NELLA_SALA * (interni.get_node(^"Gioco/Risveglio") as Node3D).transform
	radice.add_child(p)
	var vecchia := get_tree().current_scene
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	if p.water_pack:
		p.water_pack.set_tank_amount(10.0)
		p.water_pack.set_equipped(false, false)
	interni.call(&"fai_risveglio", p)
	if vecchia and vecchia != radice:
		vecchia.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scena() -> RisveglioSqualo:
	var sc := get_tree().current_scene
	return sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo if sc else null


func _aspetta_scena(secondi := 900.0) -> RisveglioSqualo:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secondi * 1000.0:
		await get_tree().process_frame
		var s := _scena()
		if s and s.in_corso():
			return s
	return null


## La distanza dalla superficie del mondo più vicina (raggi in tutte le direzioni, fino a [param fino] m), escludendo
## [param esclusi].
func _distanza(punto: Vector3, fino: float, esclusi: Array[RID] = []) -> float:
	var spazio := get_viewport().find_world_3d().direct_space_state
	var minima := INF
	for i in DIREZIONI:
		# direzioni sulla sfera (spirale di Fibonacci)
		var y := 1.0 - 2.0 * (i + 0.5) / DIREZIONI
		var r := sqrt(1.0 - y * y)
		var a := i * 2.399963
		var d := Vector3(cos(a) * r, y, sin(a) * r)
		var q := PhysicsRayQueryParameters3D.create(punto, punto + d * fino, Layers.WORLD)
		q.exclude = esclusi
		var h := spazio.intersect_ray(q)
		if not h.is_empty():
			minima = minf(minima, punto.distance_to(h.position))
	return minima


func _sopra(punto: Vector3) -> float:
	var spazio := get_viewport().find_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 0.5, punto + Vector3.DOWN * 2.0, Layers.WORLD)
	var h := spazio.intersect_ray(q)
	if h.is_empty() or (h.normal as Vector3).y < 0.7:
		return INF
	return punto.y - (h.position as Vector3).y


func _misure() -> void:
	var s := await _aspetta_scena()
	if s == null:
		print("SONDA: la scena non è partita")
		get_tree().quit(1)
		return
	var p := GameState.player
	var esclusi: Array[RID] = [p.get_rid()]
	var sk := s.get(&"_scheletro") as Skeleton3D
	var ossa := {}
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		var l := n.to_lower()
		for chiave in ["piede", "foot", "dita", "toe", "tallone", "mano", "muso", "bocca", "mento_punta", "testa", "coda"]:
			if l.contains(chiave):
				ossa[n] = i
	print("SONDA: ossa misurate ", ossa.keys())
	var piedi := ossa.keys().filter(func(n): return String(n).to_lower().contains("piede") or String(n).to_lower().contains("foot") or String(n).to_lower().contains("dita") or String(n).to_lower().contains("tallone"))
	var cam_prima := p.camera.global_position
	var rot_prima := p.camera.global_rotation
	var min_muro := INF
	var t_min_muro := 0.0
	var max_salto := 0.0
	var t_max_salto := 0.0
	var max_giro := 0.0
	var t_max_giro := 0.0
	var ossa_min := {}
	var piede_prima := {}
	var scivola := {}
	var sospeso := {}
	var lampade_ts := []
	var goccia := []
	var suoni := []
	var visti := {}
	var a := get_node_or_null(^"/root/Audio")
	var f := 0
	while s and is_instance_valid(s) and s.in_corso():
		await get_tree().process_frame
		f += 1
		var t := float(s.get(&"_t"))
		var cam := p.camera
		var c := cam.global_position
		var dm := _distanza(c, 0.6, esclusi)
		if dm < min_muro:
			min_muro = dm
			t_min_muro = t
		var salto := c.distance_to(cam_prima)
		if (t > 1.9 and t < 2.8) or (t > float(s.tempi.get("richiamo", 8.4)) - 0.3 and t < float(s.tempi.get("richiamo", 8.4)) + 0.9):
			print("SALTO %.3f %.4f m" % [t, salto])
		if f > 2 and salto > max_salto:
			max_salto = salto
			t_max_salto = t
		var giro := rad_to_deg((cam.global_basis.get_rotation_quaternion().angle_to(Basis.from_euler(rot_prima).get_rotation_quaternion())))
		if f > 2 and giro > max_giro:
			max_giro = giro
			t_max_giro = t
		cam_prima = c
		rot_prima = cam.global_rotation
		if s.squalo and is_instance_valid(s.squalo) and s.squalo.visible:
			for n in ossa:
				var pos := sk.global_transform * sk.get_bone_global_pose(ossa[n]).origin
				var d := _distanza(pos, 0.5, esclusi)
				if not ossa_min.has(n) or d < ossa_min[n][0]:
					ossa_min[n] = [d, t]
			for n in piedi:
				var pos := sk.global_transform * sk.get_bone_global_pose(ossa[n]).origin
				var h := _sopra(pos)
				if h != INF:
					if h < 0.06 and piede_prima.has(n) and float(piede_prima[n][1]) < 0.06:
						var sc := Vector2(pos.x, pos.z).distance_to(Vector2(piede_prima[n][0].x, piede_prima[n][0].z))
						if not scivola.has(n) or sc > scivola[n][0]:
							scivola[n] = [sc, t]
					if not sospeso.has(n):
						sospeso[n] = [INF, -INF]
					sospeso[n][0] = minf(sospeso[n][0], h)
					sospeso[n][1] = maxf(sospeso[n][1], h)
				piede_prima[n] = [pos, h]
		# la luce rossa dei lampi (solo su di lui)
		var llv: Variant = s.get(&"_luce_lampo") if &"_luce_lampo" in s else null
		var ll: Light3D = llv if is_instance_valid(llv) else null
		if ll and is_instance_valid(ll) and ll.light_energy > 0.0 and f % 2 == 0:
			print("LUCE_LAMPO %.2f energia %.2f maschera %d" % [t, ll.light_energy, ll.light_cull_mask])
		if f == 5 and ll and is_instance_valid(ll):
			var altri := []
			for g in get_tree().current_scene.find_children("*", "GeometryInstance3D", true, false):
				var gi := g as GeometryInstance3D
				if (gi.layers & ll.light_cull_mask) != 0 and not s.squalo.is_ancestor_of(gi):
					altri.append(String(get_tree().current_scene.get_path_to(gi)))
			print("SONDA: mesh fuori dallo squalo che la luce dei lampi può illuminare: %d %s" % [altri.size(), altri.slice(0, 8)])
		# le lampade e la goccia, ogni 0,1 s circa
		if f % 3 == 0:
			var fattori := []
			for le in s.get(&"_lampade"):
				fattori.append(snappedf(float(le.get(&"fattore")), 0.01))
			lampade_ts.append([snappedf(t, 0.01), snappedf(float(s.get(&"_luce")), 0.01), fattori.slice(0, 2)])
			goccia.append([snappedf(t, 0.01), s.goccia_visibile()])
			if s.squalo and is_instance_valid(s.squalo) and s.squalo.visible:
				var riga := "PIEDI %.2f" % t
				for n in piedi:
					var pos := sk.global_transform * sk.get_bone_global_pose(ossa[n]).origin
					riga += "  %s h %.3f (%.2f, %.2f)" % [n, _sopra(pos), pos.x, pos.z]
				print(riga)
		# i suoni che la scena fa partire (RisveglioSqualo._suoni), e la bocca rispetto alla camera mentre annusa
		for k in (s.get(&"_suoni") as Dictionary):
			if not visti.has("scena_" + String(k)):
				visti["scena_" + String(k)] = true
				suoni.append("%.2f s parte %s" % [t, k])
		if t >= 2.4 and t <= 5.4 and f % 3 == 0:
			var b: Vector3 = s.call(&"_punto_bocca")
			var loc := cam.global_transform.affine_inverse() * b
			var lp := p.global_transform.affine_inverse() * b
			print("FIUTO %.2f bocca dalla camera: destra %.2f avanti %.2f su %.2f; dal giocatore (corpo): destra %.2f avanti %.2f" % [t, loc.x, -loc.z, loc.y, lp.x, -lp.z])
		# i suoni che partono, dove stanno rispetto alla camera
		if a:
			for pl in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false) + get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
				var ap := pl as Node
				var suona: bool = ap.get(&"playing")
				var chiave := ap.get_instance_id()
				if suona and not visti.has(chiave):
					visti[chiave] = true
					var nome := String((ap.get(&"stream") as Resource).resource_path.get_file()) if ap.get(&"stream") else "?"
					var lato := ""
					if ap is AudioStreamPlayer3D:
						var loc := cam.global_transform.affine_inverse() * (ap as Node3D).global_position
						lato = "destra %.2f, avanti %.2f, su %.2f" % [loc.x, -loc.z, loc.y]
					suoni.append("%.2f s %s %s" % [t, nome, lato])
				elif not suona and visti.has(chiave):
					visti.erase(chiave)
	print("SONDA: camera dai muri al minimo %.3f m a %.2f s" % [min_muro, t_min_muro])
	print("SONDA: salto più grande della camera in un fotogramma %.3f m a %.2f s, giro più grande %.1f gradi a %.2f s" % [max_salto, t_max_salto, max_giro, t_max_giro])
	for n in ossa_min:
		print("SONDA: osso %s dalla superficie più vicina al minimo %.3f m a %.2f s" % [n, ossa_min[n][0], ossa_min[n][1]])
	for n in sospeso:
		print("SONDA: piede %s sul pavimento fra %.3f e %.3f m; scivolata più lunga a terra in un fotogramma %s" % [n, sospeso[n][0], sospeso[n][1],
				("%.3f m a %.2f s" % scivola[n]) if scivola.has(n) else "-"])
	for r in lampade_ts:
		print("LAMPADE ", r)
	var fin := []
	var acc := false
	for g in goccia:
		if g[1] != acc:
			fin.append("%s a %.2f s" % ["compare" if g[1] else "sparisce", g[0]])
			acc = g[1]
	print("SONDA: goccia ", fin)
	for x in suoni:
		print("SUONO ", x)
	await _frames(60)
	var accesi := []
	if a:
		for pl in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false) + get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
			if pl.get(&"playing") and pl.get(&"stream"):
				accesi.append((pl.get(&"stream") as Resource).resource_path.get_file())
	print("SONDA: 2 s dopo la fine suonano ancora ", accesi)
	var fattori := []
	for le in get_tree().current_scene.find_children("*", "LuceEmergenza", true, false):
		fattori.append(float(le.get(&"fattore")))
	print("SONDA: dopo la fine le lampade hanno fattore min %.2f max %.2f (%d)" % [fattori.min(), fattori.max(), fattori.size()])
	print("SONDA FINE")
	get_tree().quit()


func _ravvicinati() -> void:
	var cartella: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	var s := await _aspetta_scena()
	if s == null:
		get_tree().quit(1)
		return
	var p := GameState.player
	var sk := s.get(&"_scheletro") as Skeleton3D
	var piedi := []
	for i in sk.get_bone_count():
		var l := sk.get_bone_name(i).to_lower()
		if l.contains("piede") or l.contains("foot") or l.contains("dita") or l.contains("toe"):
			piedi.append(i)
	print("SONDA: piedi ", piedi.map(func(i): return sk.get_bone_name(i)))
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.01
	get_tree().current_scene.add_child(cam)
	var luce := OmniLight3D.new()
	luce.omni_range = 6.0
	luce.light_energy = 1.2
	cam.add_child(luce)
	luce.visible = false
	var morsi: Array = s.tempi.get("morsi", [])
	var pausa: Array = s.tempi.get("pausa", [6.65, 7.45])
	var bocca := []
	for m in morsi:
		bocca.append(["morso_%.2f" % (float(m[0]) + 0.1), float(m[0]) + 0.1])
	bocca.append(["pausa_%.2f" % lerpf(float(pausa[0]), float(pausa[1]), 0.5), lerpf(float(pausa[0]), float(pausa[1]), 0.5)])
	bocca.append(["apre_5.20", 5.2])
	var momenti_piedi := [0.3, 0.9, 1.6, 2.3, 3.5, 9.5, 10.3, 11.2, 12.2, 13.0]
	var lista := []
	if OS.get_environment("RAVV_MANI") != "":
		bocca.clear()
		momenti_piedi.clear()
		piedi = [sk.find_bone("mano.R"), sk.find_bone("mano.L")]
		var tempi_mani := [2.9, 3.1, 3.2, 3.3, 3.5]
		if OS.get_environment("RAVV_MANI") == "tutta":
			tempi_mani = []
			for k in 29:
				tempi_mani.append(0.3 + 0.5 * k)
		for t in tempi_mani:
			lista.append(["piedi", "mani_%05.2f" % t, t])
	# RAVV_PORTA=1 (ricontrollo di lavoro/torre-robusta): la porta tagliafuoco sul suo perno, chiusa, mentre si apre e
	# aperta: il cardine in basso, a metà e in alto dai due lati, e la porta intera
	if OS.get_environment("RAVV_PORTA") != "":
		bocca.clear()
		momenti_piedi.clear()
		for t in [0.5, 13.5, 14.37, 14.43, 16.0]:
			lista.append(["porta", "porta_%05.2f" % t, t])
	for b in bocca:
		lista.append(["bocca", b[0], b[1]])
	for t in momenti_piedi:
		lista.append(["piedi", "piedi_%05.2f" % t, t])
	lista.sort_custom(func(a, b): return a[2] < b[2])
	for x in lista:
		await _fino_a(s, float(x[2]))
		if not s.in_corso():
			continue
		if x[0] != "porta" and (s.squalo == null or not is_instance_valid(s.squalo) or not s.squalo.visible):
			continue
		var punti := []
		if x[0] == "porta":
			# (il verso dalla porta vera: dal perno al centro delle sue mesh, e la normale orizzontale)
			var perno := s.get(&"_perno") as Node3D
			var h := perno.global_position
			var box := AABB()
			var primo := true
			for vi in s.porta.find_children("*", "MeshInstance3D", true, false):
				var mi := vi as MeshInstance3D
				var bb := mi.global_transform * mi.get_aabb()
				box = bb if primo else box.merge(bb)
				primo = false
			var centro := box.get_center()
			var verso := Vector3(centro.x - h.x, 0.0, centro.z - h.z).normalized()
			var normale := verso.cross(Vector3.UP).normalized()
			print("SONDA: porta a %.2f s: cardine %s, centro %s, larga %.2f m" % [float(s.get(&"_t")), h, centro,
				Vector2(centro.x - h.x, centro.z - h.z).length() * 2.0])
			for q in [["basso", 0.15], ["meta", 1.0], ["alto", 1.95]]:
				var c: Vector3 = Vector3(h.x, box.position.y + float(q[1]), h.z) + verso * 0.03
				punti.append(["cardine_%s_davanti" % q[0], c + normale * 0.5 + verso * 0.2, c])
				punti.append(["cardine_%s_dietro" % q[0], c - normale * 0.5 + verso * 0.2, c])
			punti.append(["intera_davanti", centro + normale * 2.4, centro])
			punti.append(["intera_dietro", centro - normale * 2.4, centro])
		elif x[0] == "bocca":
			var c: Vector3 = s.call(&"_punto_bocca")
			var avanti := (p.camera.global_position - c)
			avanti.y = 0.0
			avanti = avanti.normalized()
			var lato := avanti.cross(Vector3.UP)
			punti = [["fronte", c + avanti * 0.55 + Vector3.UP * 0.05, c], ["lato", c + lato * 0.6 + Vector3.UP * 0.05, c],
					["altro_lato", c - lato * 0.6 + Vector3.UP * 0.05, c]]
		else:
			for k in piedi.size():
				var pos := sk.global_transform * sk.get_bone_global_pose(piedi[k]).origin
				var dir := (p.global_position - pos)
				dir.y = 0.0
				dir = dir.normalized()
				punti.append(["%s_%d" % [sk.get_bone_name(piedi[k]), k], pos + dir.rotated(Vector3.UP, 0.8) * 0.7 + Vector3.UP * 0.12, pos + Vector3.UP * 0.03])
		var prima_luce := luce.visible
		var squalo_visibile: bool = s.squalo.visible if s.squalo and is_instance_valid(s.squalo) else false
		if x[0] == "porta" and squalo_visibile:
			s.squalo.visible = false
		get_tree().paused = true
		s.process_mode = Node.PROCESS_MODE_PAUSABLE
		for q in punti:
			cam.global_position = q[1]
			cam.look_at(q[2])
			cam.make_current()
			luce.visible = true
			for i in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [x[1], q[0]]), 0.9)
		luce.visible = prima_luce
		if x[0] == "porta" and squalo_visibile:
			s.squalo.visible = true
		p.camera.make_current()
		get_tree().paused = false
	print("SONDA FINE")
	get_tree().quit()


func _lampade(t: String) -> void:
	var fattori := []
	var sc := get_tree().current_scene
	if sc:
		for le in sc.find_children("*", "LuceEmergenza", true, false):
			fattori.append(snappedf(float(le.get(&"fattore")), 0.01))
	var ll := 0
	for l in get_tree().root.find_children("LuceLampo", "Light3D", true, false):
		if (l as Light3D).light_energy > 0.0 and (l as Light3D).is_visible_in_tree():
			ll += 1
	var gocce := 0
	for g in get_tree().root.find_children("Goccia", "ColorRect", true, false):
		if (g as CanvasItem).is_visible_in_tree():
			gocce += 1
	print("PASSO %s: scena %s, lampade fattore %s, gocce visibili %d, luci dei lampi accese %d" % [t, sc.name if sc else "-",
			("min %.2f max %.2f su %d" % [fattori.min(), fattori.max(), fattori.size()]) if not fattori.is_empty() else "nessuna", gocce, ll])


func _fino_a(s: RisveglioSqualo, t: float) -> void:
	while is_instance_valid(s) and s.in_corso() and float(s.get(&"_t")) < t:
		await get_tree().process_frame


func _interruzioni() -> void:
	# 1) Nuova partita: pausa nel buio, poi si riprende
	get_tree().change_scene_to_file(CARICAMENTO)
	var s := await _aspetta_scena()
	if s == null:
		print("SONDA: la scena non è partita")
		get_tree().quit(1)
		return
	await _fino_a(s, 1.0)
	Game.set_paused(true)
	await _frames(30)
	await _lampade("1. pausa nel buio (1 s)")
	Game.set_paused(false)
	await _fino_a(s, 4.9)
	await _lampade("1. ripresa, durante la goccia (4,9 s)")
	Game.set_paused(true)
	await _frames(60)
	await _lampade("1. pausa durante la goccia")
	Game.set_paused(false)
	await _fino_a(s, 30.0)
	await _frames(30)
	await _lampade("1. scena finita")
	# 2) torna al titolo a metà scena (nel buio), poi Nuova partita
	GameState.reset_progress()
	get_tree().change_scene_to_file(CARICAMENTO)
	s = await _aspetta_scena()
	await _fino_a(s, 1.4)
	Game.set_paused(true)
	await _frames(5)
	Game.return_to_title()
	await _frames(120)
	await _lampade("2. tornato al titolo dal buio")
	GameState.reset_progress()
	get_tree().change_scene_to_file(CARICAMENTO)
	s = await _aspetta_scena()
	await _fino_a(s, 4.6)
	await _lampade("2. Nuova partita, durante la goccia")
	Game.set_paused(true)
	await _frames(5)
	Game.return_to_title()
	await _frames(120)
	await _lampade("2. tornato al titolo durante la goccia")
	# 3) Continua (c'è un salvataggio?)
	print("PASSO 3. salvataggio su disco: %s" % GameState.has_save())
	if GameState.has_save():
		GameState.continue_from_disk()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 600000:
			await get_tree().process_frame
			var sc := get_tree().current_scene
			if sc and sc.scene_file_path.ends_with("sala_principale.tscn") and GameState.player and GameState.player.input_enabled:
				break
		await _frames(60)
		var r := _scena()
		print("PASSO 3. Continua: scena dello squalo %s" % ("in corso" if r and r.in_corso() else "ferma"))
		await _lampade("3. Continua")
	print("SONDA FINE")
	get_tree().quit()
