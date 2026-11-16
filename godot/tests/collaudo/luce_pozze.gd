extends Node
## Collaudo 0.4.0, terza candidata (4b82e170): la luce rosa che passa fra le pozze, vista dagli occhi in piedi, col
## renderer vero, nella stanza delle pozze vera costruita a pezzi (come scatti_pozze_lei.gd). Lei sveglia (non letale,
## pause corte) gira di pozza in pozza ed esce; il giocatore in piedi sulla passerella in tre posti, che guarda le pozze
## come camminando (20° in giù), 50 s per posto. Ogni 4 fotogrammi la scena si ferma e si scatta con la luce e senza
## (LC:): nei pixel che guardano il grigliato e i bordini fra le pozze e la passerella intorno (raggio sul piano del
## grigliato, fuori dalle pozze più 3 cm), quanti diventano più chiari con la luce, e il più chiaro; con la fase del
## motore e dove sta la luce (dentro una pozza, sotto il grigliato). Gli scatti dei 6 momenti peggiori mentre la luce
## passa (fasi LONTANA e ARRIVA) e 6 nelle uscite.
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/luce_pozze.gd <cartella>

const STANZA := "res://scenes/risalita/stanza_pozze.tscn"
const R := 3.35
const POSTI := [["sud", Vector3(0, 0, R)], ["ovest", Vector3(-R, 0, -1.1)]]

var g: Player
var poz: Node3D
var e: EnigmaPozze
var lei: LeiPozze
var acqua: AcquaDiLei
var cart := ""
var peggiori: Array = []
var uscite: Array = []
var _segnati := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _img() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	poz = (load(STANZA) as PackedScene).instantiate() as Node3D
	poz.name = "StanzaPozze"
	poz.set(&"costruzione_a_pezzi", true)
	add_child(poz)
	await poz.call(&"costruisci_a_pezzi")
	e = poz.find_child("EnigmaPozze", true, false) as EnigmaPozze
	lei = e.lei
	acqua = lei.acqua
	g = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	GameState.player = g
	g.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	g.water_pack.set_equipped(true, false)
	g.input_enabled = true
	g.camera.make_current()
	Grafica.imposta("fov", 75.0)
	lei.letale = false
	acqua.letale = false
	acqua.prima_volta_dimostrativa = false
	lei.prima_attesa = 1.0
	lei.pausa_min = 1.0
	lei.pausa_max = 2.0
	acqua.pausa_dopo = 0.5
	acqua.pausa_respinta = 0.5
	var y_grigliato := e.global_position.y
	print("LC: stanza pronta, grigliato a y %.3f, pelo pieno %.3f" % [y_grigliato, acqua.pelo])
	lei.call(&"_sveglia")
	for posto in POSTI:
		if OS.get_environment("SOLO_SUD") == "1" and posto[0] != "sud":
			continue
		await _posto(posto[0], posto[1], y_grigliato)
	peggiori.sort_custom(func(x, y): return x[0] > y[0])
	print("LC: i momenti peggiori mentre passa: %s" % [peggiori.slice(0, 8).map(func(x): return "%s %.1f %% (%s)" % [x[1], x[0] * 100.0, x[2]])])
	print("LC: finito")
	get_tree().quit()


func _fuori_dalle_pozze(q: Vector3, margine: float) -> bool:
	for u in e.pozze():
		var l := u.to_local(q)
		if absf(l.x) <= u.inner_size.x * 0.5 + margine and absf(l.z) <= u.inner_size.z * 0.5 + margine:
			return false
	return true


func _dove_luce(l: Light3D) -> String:
	var q := l.global_position
	for u in e.pozze():
		var lo := u.to_local(q)
		if absf(lo.x) <= u.inner_size.x * 0.5 and absf(lo.z) <= u.inner_size.z * 0.5:
			return "in %s (%.2f dal pelo)" % [u.name, q.y - u.get_surface_global_y()]
	return "FUORI dalle pozze a %s" % q.snappedf(0.01)


func _posto(nome: String, dove: Vector3, yg: float) -> void:
	g.teleport(e.to_global(dove) + Vector3(0, 0.05, 0), g.yaw, 0.0)
	await _fisica(3)
	var verso := e.global_position - g.global_position
	verso.y = 0.0
	g.look_at_point(g.camera.global_position + verso.normalized() * 2.0 + Vector3.DOWN * 0.73)
	await _frames(10)
	var cam := g.camera
	var vp := get_viewport()
	var vis := vp.get_visible_rect().size
	var sz := Vector2(vp.get_texture().get_size())
	var scala := vis / sz
	print("LC: vista %s, immagine %s" % [vis, sz])
	# i pixel che guardano il grigliato fuori dalle pozze (campione ogni 8 pixel dell'immagine)
	var campioni: Array[Vector2i] = []
	for y in range(4, int(sz.y), 8):
		for x in range(4, int(sz.x), 8):
			var o := cam.project_ray_origin(Vector2(x, y) * scala)
			var d := cam.project_ray_normal(Vector2(x, y) * scala)
			if d.y >= -0.01:
				continue
			var q := o + d * ((yg - o.y) / d.y)
			var lq := e.to_local(q)
			if absf(lq.x) > 3.7 or absf(lq.z) > 3.7:
				continue
			if _fuori_dalle_pozze(q, 0.03):
				campioni.append(Vector2i(x, y))
	print("LC: %s: giocatore a %s, occhi a %.2f m sopra il grigliato, pixel del grigliato campionati %d" % [nome,
			g.global_position.snappedf(0.01), cam.global_position.y - yg, campioni.size()])
	var t0 := Time.get_ticks_msec()
	var n := 0
	var max_passa := 0.0
	var luce_fuori := 0
	while n < 60 * 35:
		await get_tree().process_frame
		n += 1
		if n % 10 != 0:
			continue
		var l := acqua.get(&"_luce") as OmniLight3D
		if l == null or not l.is_visible_in_tree() or l.light_energy < 0.01:
			continue
		var fase := String(AcquaDiLei.Fase.find_key(acqua.fase))
		var dl := _dove_luce(l)
		if dl.begins_with("FUORI"):
			luce_fuori += 1
		get_tree().paused = true
		var con := await _img()
		var en := l.light_energy
		l.visible = false
		var senza := await _img()
		l.visible = true
		get_tree().paused = false
		var chiari := 0
		var piu := 0.0
		for c in campioni:
			var dlum := con.get_pixel(c.x, c.y).get_luminance() - senza.get_pixel(c.x, c.y).get_luminance()
			if dlum > 0.04:
				chiari += 1
			piu = maxf(piu, dlum)
		var quota := float(chiari) / maxf(campioni.size(), 1)
		# (con SEGNA=1: lo scatto con i pixel del grigliato e della passerella che schiariscono segnati in verde)
		if OS.get_environment("SEGNA") == "1" and quota > 0.02 and _segnati < 12:
			_segnati += 1
			var m := con.duplicate() as Image
			for c in campioni:
				var dl2 := con.get_pixel(c.x, c.y).get_luminance() - senza.get_pixel(c.x, c.y).get_luminance()
				var col := Color(0, 1, 0) if dl2 > 0.04 else Color(0, 0, 1)
				for yy in range(-2, 3):
					for xx in range(-2, 3):
						m.set_pixel(clampi(c.x + xx, 0, m.get_width() - 1), clampi(c.y + yy, 0, m.get_height() - 1), col if absi(xx) + absi(yy) <= 2 else m.get_pixel(clampi(c.x + xx, 0, m.get_width() - 1), clampi(c.y + yy, 0, m.get_height() - 1)))
			m.save_jpg(cart.path_join("segna_%s_%s.jpg" % [nome, "%05.1fs_%s" % [n / 60.0, String(AcquaDiLei.Fase.find_key(acqua.fase))]]), 0.9)
			senza.save_jpg(cart.path_join("senza_%s_%s.jpg" % [nome, "%05.1fs" % (n / 60.0)]), 0.9)
		var etichetta := "%s_%05.1fs_%s" % [nome, n / 60.0, fase]
		if quota > 0.0 or n % 120 == 0:
			print("LC: %s: luce %s, energia %.2f, raggio %.2f; grigliato più chiaro in %.1f %% dei pixel, il più chiaro +%.3f" % [etichetta,
					dl, en, l.omni_range, quota * 100.0, piu])
		if fase in ["LONTANA", "ARRIVA", "SPEGNE"]:
			max_passa = maxf(max_passa, quota)
			# (gli scatti subito: la luce fuori dalle pozze sempre, gli altri se il grigliato schiarisce)
			if dl.begins_with("FUORI") or quota > 0.02:
				con.save_jpg(cart.path_join("passa_%s.jpg" % etichetta), 0.85)
			peggiori.append([quota, etichetta, dl, null])
			peggiori.sort_custom(func(x, y): return x[0] > y[0])
			peggiori.resize(mini(peggiori.size(), 8))
		elif uscite.size() < 6 and fase in ["ESCE", "SU"] and n % 60 == 0:
			con.save_jpg(cart.path_join("esce_%s.jpg" % etichetta), 0.85)
			uscite.append([quota, etichetta, dl, null])
	print("LC: %s: mentre passa il grigliato più chiaro al più in %.1f %% dei pixel; luce fuori dalle pozze in %d campioni" % [nome,
			max_passa * 100.0, luce_fuori])
