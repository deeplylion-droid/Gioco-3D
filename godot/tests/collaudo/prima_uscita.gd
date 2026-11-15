extends Node
## Collaudo 0.4.0, terza candidata (4b82e170): la prima uscita di lei nelle pozze col renderer vero, nel gioco vero con
## la sala ridotta (tests/scena_ridotta.gd: via le parti pesanti della sala, la Risalita resta intera), dopo:
##   1. F9 «Stanza delle pozze» (come dal menu: l'istantanea della partenza, con la scena ridotta al posto della sala);
##   2. una presa (lei prende il giocatore, la ripartenza dal checkpoint d'ingresso);
##   3. Continua (il salvataggio scritto su disco, il titolo, Continua).
## Per ognuna (PU:): dall'arrivo a 3 s dopo lo schermo libero, ogni fotogramma la luminosità media dello schermo (un
## lampo è un salto in su e poi in giù) e le compilazioni (surface, draw, specialization), con quando il riscaldamento
## della stanza (Risalita.riscaldo_pozze) parte e finisce; poi il giocatore va sulla passerella davanti alla pozza sud
## (2_4) e lei si chiama da lì: le compilazioni in ogni fotogramma dal silenzio a 1 s dopo che è su, e quelle del
## fotogramma in cui esce (il primo di ESCE) e dei 5 dopo.
## Uso: xvfb-run ... --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 --script res://tests/run.gd --
##   res://tests/collaudo/prima_uscita.gd [f9,presa,continua]

const LEVEL := "res://scenes/sala_principale.tscn"
const TITOLO := "res://scenes/ui/menu_principale.tscn"
const CARICAMENTO := "res://scenes/ui/caricamento.tscn"
const TOGLI := ["Interni", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata", "Mascotte",
		"Sala/Dettagli", "Sala/TorreScivoli", "Gioco/EnigmaAcquari", "Atmosfera", "SalaSottomarino", "SalaTorre",
		"Sala/Piscina", "Sala/VascaCentrale", "Piscina", "Vasca", "Sala/Architettura", "Sala/Cupola", "Sala/AreaBimbi",
		"Sala/Oggetti", "Polaroid", "Vasche", "Gioco/LeiSbuca", "Gioco/LeiSalaAlBuio"]
const R := 3.35

var ridotta := ""
var e: EnigmaPozze
var difetti: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _disegnato() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _difetto(s: String) -> void:
	difetti.append(s)
	print("PU: DIFETTO " + s)


static func _comp() -> Vector3:
	return Vector3(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


func _luminosita() -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
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


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var quali := (a[1] if a.size() > 1 else "f9,presa,continua").split(",")
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = true
	for f in [GameState.SAVE_PATH, GameState.SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# (senza schermo la sala intera: lì serve solo vedere se il riscaldamento della stanza parte)
	ridotta = LEVEL if DisplayServer.get_name() == "headless" else load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI)
	print("PU: scena ridotta %s" % ridotta)
	# 1. F9
	var d := MenuProva.istantanea("pozze")
	d["scene"] = ridotta
	GameState.prepara_ripresa(d)
	get_tree().change_scene_to_file(CARICAMENTO)
	await _apertura("f9")
	if quali.has("f9"):
		await _uscita("f9", false)
	if quali.has("presa"):
		if not quali.has("f9"):
			await _uscita("f9 (dimostrativa, non misurata)", false, true)
		var vecchia := get_tree().current_scene
		await _uscita("presa (quella che prende)", true, true)
		await _apertura("dopo la presa", vecchia)
		await _uscita("dopo la presa", false)
	if quali.has("continua"):
		GameState._write_disk()
		print("PU: salvataggio su disco: %s" % GameState.salvataggio().get("checkpoint", "-"))
		GameState.reset_progress()
		get_tree().change_scene_to_file(TITOLO)
		await _frames(90)
		var t := get_tree().current_scene
		var voci: Array = t.call(&"voci") if t and t.has_method(&"voci") else []
		if voci.is_empty() or not String((voci[0] as Button).text).to_lower().contains("contin"):
			_difetto("nel titolo non c'è Continua (%s)" % [voci.map(func(b): return (b as Button).text)])
		else:
			(voci[0] as Button).pressed.emit()
			await _apertura("continua")
			await _uscita("continua", false)
	print("PU: difetti %d" % difetti.size())
	for x in difetti:
		print("PU:   " + x)
	print("PU: finito")
	Game.esci(0)


## Dall'arrivo (la scena del gioco, il giocatore vero) a 3 s dopo lo schermo libero: luminosità e compilazioni.
func _apertura(nome: String, da: Node = null) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s != da and s.scene_file_path != CARICAMENTO and s.scene_file_path != TITOLO and GameState.player \
				and is_instance_valid(GameState.player) and GameState.player.is_inside_tree():
			break
	var level := get_tree().current_scene
	var ris := level.get_node_or_null(^"Risalita")
	print("PU: %s: arrivo dopo %.1f s, scena %s, checkpoint %s" % [nome, (Time.get_ticks_msec() - t0) / 1000.0,
			level.scene_file_path.get_file(), GameState.snapshot.get("checkpoint", "-")])
	var prima := _comp()
	var lum: Array[String] = []
	var lums: Array[float] = []
	var libero_a := -1
	var risc := false
	var i := 0
	var comp_righe: Array[String] = []
	while i < 60 * 40:
		await _disegnato()
		var c := _comp()
		var dc := c - prima
		prima = c
		var l := _luminosita()
		lums.append(l)
		var lib := Dissolvenza.schermo_libero(get_tree())
		if lib and libero_a < 0:
			libero_a = i
			print("PU: %s: schermo libero al fotogramma %d" % [nome, i])
		var rp := ris != null and is_instance_valid(ris) and bool(ris.get(&"riscaldo_pozze"))
		if rp != risc:
			risc = rp
			print("PU: %s: riscaldamento della stanza %s al fotogramma %d (schermo libero %s, luminosità %.3f)" % [nome,
					"parte" if rp else "finito", i, lib, l])
		lum.append("%.3f" % l)
		if dc != Vector3.ZERO:
			comp_righe.append("%d%s: %d/%d/%d" % [i, "" if lib else " (nero)", dc.x, dc.y, dc.z])
		i += 1
		if libero_a >= 0 and i - libero_a > 180:
			break
		await get_tree().process_frame
	print("PU: %s: compilazioni nell'apertura (fotogramma: surface/draw/spec) %s" % [nome, comp_righe])
	print("PU: %s: luminosità per fotogramma %s" % [nome, " ".join(lum)])
	# un lampo: un fotogramma più chiaro di 0,05 di quelli prima e dopo (dopo lo schermo libero e prima)
	for k in range(1, lums.size() - 1):
		var sopra := lums[k] - maxf(lums[k - 1], lums[mini(k + 2, lums.size() - 1)])
		if sopra > 0.05:
			_difetto("%s: lampo al fotogramma %d dell'apertura (luminosità %.3f, prima %.3f, dopo %.3f)" % [nome, k, lums[k],
					lums[k - 1], lums[k + 1]])
	await _frames(30)


## Il giocatore sulla passerella davanti alla pozza sud, e lei si chiama da lì. Con [param prendi] resta fermo e lei
## prende (poi si aspetta la ripartenza in [method _apertura]).
func _uscita(nome: String, prendi: bool, zitto := false) -> void:
	var level := get_tree().current_scene
	e = level.find_child("EnigmaPozze", true, false) as EnigmaPozze
	if e == null:
		_difetto("%s: l'enigma delle pozze non c'è" % nome)
		return
	var lei := e.lei
	var acqua := lei.acqua
	var p := GameState.player
	var t := e.find_child("Pozza_2_4", false, false) as WaterTank
	p.teleport(e.to_global(Vector3(0, 0.05, R)), p.yaw, 0.0)
	await _fisica(3)
	p.look_at_point(t.global_position + Vector3(0, 0.5, 0))
	# (lei, LeiPozze, non viene da sola: la si chiama qui)
	lei.prima_attesa = 1000.0
	lei._t = -1000.0
	await _frames(20)
	var aspetta := 0
	while acqua.fase != AcquaDiLei.Fase.LONTANA and aspetta < 60 * 30:
		await get_tree().process_frame
		aspetta += 1
	if acqua.in_giro():
		acqua.lascia()
	await _fisica(2)
	lei.luce_in = t
	var dim := acqua.prossima_dimostrativa()
	var ok := acqua.chiama(lei.uscita_di(t))
	if not zitto:
		print("PU: %s: chiamata %s, dimostrativa %s, letale %s" % [nome, ok, dim, acqua.letale])
	if not ok:
		_difetto("%s: lei non si chiama (fase %s, può venire %s)" % [nome, AcquaDiLei.Fase.find_key(acqua.fase), acqua.puo_venire()])
		return
	var prima := _comp()
	var righe: Array[String] = []
	var tot := Vector3.ZERO
	var esce_da := -1
	var su_da := -1
	var fase_prima := acqua.fase
	var i := 0
	var vecchia := get_tree().current_scene
	while i < 60 * 25:
		await _disegnato()
		if not is_instance_valid(acqua) or get_tree().current_scene != vecchia:
			break
		var c := _comp()
		var dc := c - prima
		prima = c
		var f := acqua.fase
		if f != fase_prima:
			if not zitto:
				print("PU: %s: fase %s al fotogramma %d" % [nome, AcquaDiLei.Fase.find_key(f), i])
			fase_prima = f
			if f == AcquaDiLei.Fase.ESCE and esce_da < 0:
				esce_da = i
			if f == AcquaDiLei.Fase.SU and su_da < 0:
				su_da = i
		if f in [AcquaDiLei.Fase.SILENZIO, AcquaDiLei.Fase.ESCE, AcquaDiLei.Fase.SU, AcquaDiLei.Fase.PRESA]:
			tot += dc
			if dc != Vector3.ZERO:
				righe.append("%d %s: %d/%d/%d" % [i, AcquaDiLei.Fase.find_key(f), dc.x, dc.y, dc.z])
			if esce_da >= 0 and i - esce_da <= 5 and not zitto:
				print("PU: %s: fotogramma %d dall'uscita: surface %d, draw %d, specialization %d" % [nome, i - esce_da, dc.x, dc.y, dc.z])
				if i - esce_da == 0 and (dc.y > 0 or dc.z > 0):
					_difetto("%s: nel fotogramma in cui esce draw %d, specialization %d" % [nome, dc.y, dc.z])
		if prendi:
			if GameState.is_dying:
				break
		elif su_da >= 0 and i - su_da > 60:
			break
		if f == AcquaDiLei.Fase.SCENDE or f == AcquaDiLei.Fase.CALMA:
			if not prendi:
				break
		i += 1
		await get_tree().process_frame
	if not zitto:
		print("PU: %s: dal silenzio a 1 s dopo su: surface %d, draw %d, specialization %d; fotogrammi con compilazioni %s" % [nome,
				tot.x, tot.y, tot.z, righe])
		if tot.y > 0 or tot.z > 0:
			_difetto("%s: compilazioni draw %d, specialization %d mentre esce" % [nome, tot.y, tot.z])
	if prendi:
		print("PU: %s: preso %s" % [nome, GameState.is_dying])
		if not GameState.is_dying:
			_difetto("%s: lei non prende" % nome)
	await _frames(10)
