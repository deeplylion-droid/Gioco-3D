extends Node
## Scatti dagli occhi del giocatore di lei nelle pozze (0.4.0, modo MANO, col liquido opaco quando c'è), nella stanza
## vera costruita come nella Risalita (a pezzi), con l'ambiente della sala. Lei (LeiPozze) resta a dormire: le uscite
## si chiamano qui sul motore, una pozza per volta.
## - senza terzo argomento: c) la dimostrativa da lontano; b0-b3) dalla passerella nel silenzio e mentre esce e
##   incombe; d1-d2) in piedi a 1,5 e 3 m; e1-e2) la luce che gira da sola, dritto in giù e da lontano; c_colore_*) i
##   cinque colori dritto in giù; a1-a3) la scena di morte;
## - "resto": tutto tranne c), b) e d1 (per riprendere un giro interrotto);
## - "morte": solo a1-a3;
## - "viso": il controllo della scena di morte (a4-a7 a 0,5 / 0,7 / 0,95 / 1,1 s) con gli strati della scena di morte
##   nascosti (nero, lampo, glitch: restano le scosse della camera), e stampa dove sono la camera e gli occhi di lei e
##   l'estinzione del liquido della sua pozza (nella 0.4.0 resta opaco: LeiPozze.liquido_trasparente_alla_presa spento).
## Uso (scena pesante: llvmpipe, un processo per volta, flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_pozze_lei.gd <cartella> [resto|morte|viso]

var g: Player
var poz: Node3D
var e: EnigmaPozze
var lei: LeiPozze
var acqua: AcquaDiLei
var cartella := ""
var r := 3.35


func _ready() -> void:
	_run.call_deferred()


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(cartella + "/" + nome + ".png")
	print("SCATTO %s" % nome)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _aspetta_fase(f: AcquaDiLei.Fase, secondi: float) -> bool:
	for i in int(secondi * 60.0):
		if acqua.fase == f:
			return true
		await get_tree().physics_frame
	return acqua.fase == f


func _occhi_su(punto_locale: Vector3, guarda_locale: Vector3) -> void:
	g.teleport(e.to_global(punto_locale) + Vector3(0, 0.05, 0), g.yaw, 0.0)
	await _fisica(2)
	g.look_at_point(e.to_global(guarda_locale))
	await _fisica(2)


## Lei nella pozza [param t] adesso (dalla luce già lì: come quando arriva da una pozza accanto).
func _chiama(t: WaterTank) -> bool:
	lei._t = -1000.0
	if acqua.in_giro():
		acqua.lascia()
	await _fisica(2)
	lei.luce_in = t
	var m := lei.uscita_di(t)
	return acqua.chiama(m)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1] if a.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	poz = (load("res://scenes/risalita/stanza_pozze.tscn") as PackedScene).instantiate() as Node3D
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
	acqua.pausa_dopo = 0.5
	acqua.pausa_respinta = 0.5
	lei.prima_attesa = 1000.0
	lei.pausa_min = 1000.0
	lei.pausa_max = 1000.0
	# (lei, cioè LeiPozze, resta a dormire: le uscite si chiamano qui, sul motore, una pozza per volta)
	await _occhi_su(Vector3(0, 0, r), Vector3(0, -0.3, 1.8))
	for i in 30:
		await get_tree().process_frame
	print("SCATTI stanza pronta; lei %s, motore %s, modo %s" % [lei.nome_fase(), AcquaDiLei.Fase.find_key(acqua.fase), acqua.modo])

	var sud := e.find_child("Pozza_2_4", false, false) as WaterTank
	if a.size() > 2 and a[2] == "viso":
		acqua.prima_volta_dimostrativa = false
		await _morte_viso(sud)
		get_tree().quit()
		return
	var solo_morte := a.size() > 2 and a[2] == "morte"
	if solo_morte:
		acqua.prima_volta_dimostrativa = false
		await _morte(sud)
		get_tree().quit()
		return
	var resto := a.size() > 2 and a[2] == "resto"
	lei.letale = false
	if resto:
		acqua.prima_volta_dimostrativa = false
	else:
		await _prima_parte(sud)
	await _seconda_parte(sud, resto)
	await _morte(sud)
	get_tree().quit()


func _prima_parte(sud: WaterTank) -> void:
	# c) l'uscita dimostrativa da lontano: dal lato nord guardando il lato sud
	await _occhi_su(Vector3(0, 0, -r), Vector3(0, 0.2, 2.8))
	if await _chiama(sud):
		await _aspetta_fase(AcquaDiLei.Fase.ESCE, 5.0)
		await _fisica(int(1.2 * 60))
		await _scatta("c_dimostrativa_da_lontano")
	await _aspetta_fase(AcquaDiLei.Fase.LONTANA, 10.0)
	await _fisica(10)

	# b) dalla passerella guardando giù: nel silenzio (già opaco), mentre esce (la mano sbatte) e mentre incombe
	await _occhi_su(Vector3(0, 0, r), Vector3(0, -0.3, 2.6))
	if await _chiama(sud):
		await _aspetta_fase(AcquaDiLei.Fase.SILENZIO, 6.0)
		await _fisica(int(0.45 * 60))
		await _scatta("b0_silenzio_prima_che_esca")
		await _aspetta_fase(AcquaDiLei.Fase.ESCE, 5.0)
		await _fisica(int(0.75 * 60))
		await _scatta("b1_giu_mentre_esce")
		await _aspetta_fase(AcquaDiLei.Fase.SU, 4.0)
		await _fisica(30)
		await _scatta("b2_giu_mentre_incombe")
		g.look_at_point(e.to_global(Vector3(0, -0.6, 2.2)))
		await _fisica(2)
		await _scatta("b3_dritto_in_giu_nella_pozza")
	await _aspetta_fase(AcquaDiLei.Fase.LONTANA, 10.0)
	await _fisica(10)



func _seconda_parte(sud: WaterTank, resto: bool) -> void:
	# d) in piedi a 1,5 m e a 3 m da dove esce, guardandola mentre è su
	for d in ([[3.0, "d2_in_piedi_a_3m"]] if resto else [[1.5, "d1_in_piedi_a_1m5"], [3.0, "d2_in_piedi_a_3m"]]):
		await _occhi_su(Vector3(d[0], 0, r), Vector3(0, 0.25, 2.8))
		if await _chiama(sud):
			await _aspetta_fase(AcquaDiLei.Fase.SU, 6.0)
			await _fisica(20)
			await _scatta(d[1])
		await _aspetta_fase(AcquaDiLei.Fase.LONTANA, 10.0)
		await _fisica(10)

	# e) la luce che gira, sola, ferma sotto una pozza piena: dritto in giù dal bordo, e da 6-8 m
	var ovest := e.find_child("Pozza_1_4", false, false) as WaterTank
	if ovest:
		if acqua.in_giro():
			acqua.lascia()
		await _fisica(2)
		var q := lei._sotto(ovest)
		if acqua.percorri(PackedVector3Array([q, q + Vector3(0.001, 0, 0)]), 1.5, null, 0.0):
			var x := e.to_local(ovest.global_position).x
			await _occhi_su(Vector3(x, 0, r), Vector3(x, -0.6, 2.2))
			await _fisica(90)
			await _scatta("e1_luce_che_gira_dritto_in_giu")
			await _occhi_su(Vector3(3.0, 0, -r), Vector3(x, -0.3, 2.2))
			await _fisica(30)
			print("SCATTI e2 da %.1f m" % Vector2(3.0 - x, -r - 2.2).length())
			await _scatta("e2_luce_che_gira_da_lontano")
		acqua.lascia()
		await _fisica(30)

	# c) una pozza di ogni colore (quelle del lato sud), guardando giù mentre è su
	for c in EnigmaPozze.COLORI:
		var t: WaterTank = null
		for u: WaterTank in e.pozze_del_colore(c):
			if lei._sul_bordo(u) and (t == null or u.position.z > t.position.z):
				t = u
		if t == null:
			continue
		var x := e.to_local(t.global_position).x
		await _occhi_su(Vector3(x, 0, r), Vector3(x, -0.4, 2.3))
		if await _chiama(t):
			await _aspetta_fase(AcquaDiLei.Fase.SU, 6.0)
			await _fisica(20)
			await _scatta("c_colore_%s" % c)
		await _aspetta_fase(AcquaDiLei.Fase.LONTANA, 10.0)
		await _fisica(10)


## a) la scena di morte: la presa e la camera che scende al pelo della pozza.
func _morte(sud: WaterTank) -> void:
	lei.letale = true
	acqua.letale = true
	await _occhi_su(Vector3(0, 0, r), Vector3(0, -0.3, 2.6))
	if await _chiama(sud):
		for i in 60 * 12:
			await get_tree().physics_frame
			if GameState.is_dying:
				break
		print("SCATTI presa: %s" % GameState.is_dying)
		for i in 12:
			await get_tree().process_frame
		await _scatta("a1_morte_presa")
		for i in 18:
			await get_tree().process_frame
		await _scatta("a2_morte_verso_il_pelo")
		for i in 18:
			await get_tree().process_frame
		await _scatta("a3_morte_al_pelo")
	print("SCATTI finiti")
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.free()


## Controllo (non per il gioco): la scena di morte con gli strati della scena nascosti (glitch, lampo, nero), per vedere
## dalla camera della morte che cosa si vede; quattro istanti.
func _morte_viso(sud: WaterTank) -> void:
	lei.letale = true
	acqua.letale = true
	await _occhi_su(Vector3(0, 0, r), Vector3(0, -0.3, 2.6))
	if await _chiama(sud):
		for i in 60 * 12:
			await get_tree().physics_frame
			if GameState.is_dying:
				break
		var seq: CanvasLayer = GameState.get(&"_death_sequence")
		var t0 := Time.get_ticks_msec()
		var k := 0
		for quando in [0.5, 0.7, 0.95, 1.1]:
			while true:
				if is_instance_valid(seq):
					seq.visible = false
					for c in seq.find_children("*", "CanvasLayer", true, false):
						(c as CanvasLayer).visible = false
					if float(seq.get(&"elapsed")) >= quando:
						break
				await get_tree().process_frame
			var cam := get_viewport().get_camera_3d()
			var lq := AcquaDiLei._lei
			print("SCATTI viso %.2f s: camera %s, pelo %.3f, occhi %s, estinzione %.2f" % [quando, cam.global_position,
				sud.get_surface_global_y(), lq.call(&"get_eye_position") if lq and lq.has_method(&"get_eye_position") else "?",
				_estinzione(sud)])
			k += 1
			await _scatta("a%d_controllo_viso_senza_effetto_%02d" % [k + 3, int(quando * 100)])
	var seq2: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq2):
		seq2.free()


func _estinzione(t: WaterTank) -> float:
	var b := t.get_node(^"Acqua") as WaterBody
	var ab: Vector3 = b.material.get_shader_parameter(&"absorption")
	return minf(minf(ab.x, ab.y), ab.z) + float(b.material.get_shader_parameter(&"turbidity"))
