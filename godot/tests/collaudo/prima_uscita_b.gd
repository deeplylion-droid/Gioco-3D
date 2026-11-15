extends Node
## Collaudo 0.4.0, terza candidata (4b82e170): la prima uscita di lei nelle pozze col renderer vero, senza la sala (che su
## llvmpipe non sta in memoria): l'ambiente della sala, il riscaldamento del gioco (RiscaldamentoShader, come alla
## schermata di caricamento), la stanza delle pozze vera costruita a pezzi, il giocatore vero sul checkpoint d'ingresso
## (dove si riparte dopo F9, Continua e una presa), poi
##   "con": il riscaldamento della stanza come lo fa la Risalita ripartendo vicino alle pozze
##          (risalita_gioco.gd riscalda_stanza_pozze, lei in posa fuori vista con la stanza);
##   "senza": niente (il controllo: le compilazioni che il riscaldamento della stanza deve togliere).
## Ogni fotogramma dall'ingresso (PB:): compilazioni e luminosità media della vista del giocatore (un lampo o qualcosa che
## sparisce durante il riscaldamento: un salto della luminosità). Poi il giocatore sulla passerella davanti alla pozza sud
## e lei si chiama: le compilazioni in ogni fotogramma dal silenzio a 1 s dopo che è su, e nel fotogramma in cui esce.
## Poi la presa, la stanza rifatta da capo e il giocatore nuovo all'ingresso (come la ripartenza), lo stesso riscaldamento
## e la stessa misura della prima uscita dopo la presa.
## Uso: xvfb-run ... --rendering-driver vulkan --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/prima_uscita_b.gd <con|senza>

const STANZA := "res://scenes/risalita/stanza_pozze.tscn"
const RG := preload("res://scripts/risalita/risalita_gioco.gd")
const R := 3.35

var modo := "con"
var poz: Node3D
var e: EnigmaPozze
var g: Player
var difetti: Array[String] = []
var _risc_finito := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


static func _comp() -> Vector3:
	return Vector3(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


func _luminosita() -> float:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var s := 0.0
	var n := 0
	for y in range(h / 36, h, h / 18):
		for x in range(w / 64, w, w / 32):
			s += img.get_pixel(x, y).get_luminance()
			n += 1
	return s / maxf(n, 1)


func _difetto(s: String) -> void:
	difetti.append(s)
	print("PB: DIFETTO " + s)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	modo = a[1] if a.size() > 1 else "con"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var r := RiscaldamentoShader.new()
	add_child(r)
	while not r.concluso:
		await get_tree().process_frame
	print("PB: %s: riscaldamento del gioco concluso, compilazioni %s" % [modo, _comp()])
	cam.queue_free()
	await _stanza("F9 / Continua (ingresso)")
	await _uscita("prima uscita dall'ingresso", false)
	await _uscita("presa", true)
	await _stanza("dopo la presa (stanza e giocatore nuovi)")
	await _uscita("prima uscita dopo la presa", false)
	print("PB: %s: difetti %d" % [modo, difetti.size()])
	for d in difetti:
		print("PB:   " + d)
	print("PB: finito")
	get_tree().quit()


## La stanza costruita da capo e il giocatore nuovo all'ingresso; con "con" il riscaldamento della stanza, misurando ogni
## fotogramma (compilazioni e luminosità) dall'arrivo a 2 s dopo.
func _stanza(nome: String) -> void:
	if is_instance_valid(poz):
		poz.queue_free()
	if is_instance_valid(g):
		g.queue_free()
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.queue_free()
	await _frames(3)
	GameState.is_dying = false
	poz = (load(STANZA) as PackedScene).instantiate() as Node3D
	poz.name = "StanzaPozze"
	poz.set(&"costruzione_a_pezzi", true)
	add_child(poz)
	await poz.call(&"costruisci_a_pezzi")
	e = poz.find_child("EnigmaPozze", true, false) as EnigmaPozze
	e.lei.prima_attesa = 1000.0
	e.lei.pausa_min = 1000.0
	e.lei.pausa_max = 1000.0
	g = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	GameState.player = g
	g.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	g.water_pack.set_equipped(true, false)
	g.input_enabled = true
	g.camera.make_current()
	Grafica.imposta("fov", 75.0)
	var cp := poz.find_child("CheckpointIngresso", true, false) as Checkpoint
	var sp := cp.get_spawn_transform()
	g.teleport(sp.origin, atan2(-sp.basis.z.x, -sp.basis.z.z), 0.0)
	await _fisica(2)
	var prima := _comp()
	var righe: Array[String] = []
	var lums: Array[float] = []
	var fine_risc := -1
	_risc_finito = modo != "con"
	if modo == "con":
		_riscalda()
	var i := 0
	while i < 150 or not _risc_finito:
		await RenderingServer.frame_post_draw
		var c := _comp()
		var dc := c - prima
		prima = c
		lums.append(_luminosita())
		if _risc_finito and fine_risc < 0:
			fine_risc = i
		if dc != Vector3.ZERO:
			righe.append("%d%s: %d/%d/%d" % [i, "" if _risc_finito else " (riscaldando)", dc.x, dc.y, dc.z])
		i += 1
		if i > 600:
			break
		await get_tree().process_frame
	print("PB: %s: %s: riscaldamento della stanza finito al fotogramma %d; compilazioni (fotogramma: surface/draw/spec) %s" % [modo,
			nome, fine_risc, righe])
	print("PB: %s: %s: luminosità %s" % [modo, nome, " ".join(lums.slice(0, 40).map(func(x): return "%.3f" % x))])
	var base := lums[lums.size() - 1]
	for k in lums.size():
		if absf(lums[k] - base) > 0.03:
			_difetto("%s: %s: al fotogramma %d la vista cambia (luminosità %.3f, a riposo %.3f)" % [modo, nome, k, lums[k], base])
			break


func _riscalda() -> void:
	await RG.riscalda_stanza_pozze(poz, get_viewport())
	_risc_finito = true


func _uscita(nome: String, prendi: bool) -> void:
	var lei := e.lei
	var acqua := lei.acqua
	var t := e.find_child("Pozza_2_4", false, false) as WaterTank
	g.teleport(e.to_global(Vector3(0, 0.05, R)), g.yaw, 0.0)
	await _fisica(3)
	g.look_at_point(t.global_position + Vector3(0, 0.5, 0))
	await _frames(20)
	var n := 0
	while acqua.fase != AcquaDiLei.Fase.LONTANA and n < 60 * 30:
		await get_tree().process_frame
		n += 1
	if acqua.in_giro():
		acqua.lascia()
	await _fisica(2)
	lei.letale = prendi
	acqua.letale = prendi
	if prendi:
		acqua.prima_volta_dimostrativa = false
	lei.luce_in = t
	var dim := acqua.prossima_dimostrativa()
	var ok := acqua.chiama(lei.uscita_di(t))
	print("PB: %s: %s: chiamata %s, dimostrativa %s, letale %s" % [modo, nome, ok, dim, acqua.letale])
	if not ok:
		_difetto("%s: %s: lei non si chiama" % [modo, nome])
		return
	var prima := _comp()
	var righe: Array[String] = []
	var tot := Vector3.ZERO
	var esce_da := -1
	var su_da := -1
	var i := 0
	while i < 60 * 25:
		await RenderingServer.frame_post_draw
		var c := _comp()
		var dc := c - prima
		prima = c
		var f := acqua.fase
		if f == AcquaDiLei.Fase.ESCE and esce_da < 0:
			esce_da = i
		if f == AcquaDiLei.Fase.SU and su_da < 0:
			su_da = i
		if f in [AcquaDiLei.Fase.SILENZIO, AcquaDiLei.Fase.ESCE, AcquaDiLei.Fase.SU, AcquaDiLei.Fase.PRESA]:
			tot += dc
			if dc != Vector3.ZERO:
				righe.append("%d %s: %d/%d/%d" % [i, AcquaDiLei.Fase.find_key(f), dc.x, dc.y, dc.z])
			if esce_da >= 0 and i == esce_da:
				print("PB: %s: %s: nel fotogramma in cui esce: surface %d, draw %d, specialization %d" % [modo, nome, dc.x, dc.y, dc.z])
				if not prendi and (dc.y > 0 or dc.z > 0):
					_difetto("%s: %s: nel fotogramma in cui esce draw %d, specialization %d" % [modo, nome, dc.y, dc.z])
		if prendi and GameState.is_dying:
			for k in 60:
				await RenderingServer.frame_post_draw
				var c2 := _comp()
				tot += c2 - prima
				if c2 != prima:
					righe.append("morte +%d: %s" % [k, c2 - prima])
				prima = c2
			break
		if not prendi and su_da >= 0 and i - su_da > 60:
			break
		i += 1
		await get_tree().process_frame
	print("PB: %s: %s: dal silenzio a 1 s dopo su%s: surface %d, draw %d, specialization %d; fotogrammi %s" % [modo, nome,
			" (e 1 s di scena di morte)" if prendi else "", tot.x, tot.y, tot.z, righe])
	if not prendi and (tot.y > 0 or tot.z > 0):
		_difetto("%s: %s: draw %d, specialization %d mentre esce" % [modo, nome, tot.y, tot.z])
	if prendi:
		var seq: CanvasLayer = GameState.get(&"_death_sequence")
		if is_instance_valid(seq) and seq.is_connected(&"finished", GameState._on_death_sequence_finished):
			seq.disconnect(&"finished", GameState._on_death_sequence_finished)
		print("PB: %s: %s: preso %s" % [modo, nome, GameState.is_dying])
