extends Node
## Collaudo 0.3.24 (goccia pronta dall'inizio, 617888f5): la goccia di bava nella scena dello squalo arrivando dalle
## strade vere, dal titolo con la schermata di caricamento: "nuova" (Nuova partita, lo spot saltato), "inizio" (F9
## Inizio) o "continua" (Continua, col salvataggio della partita prima). Trovata la scena (RisveglioSqualo), a ogni
## fotogramma: il tempo della scena, i contatori delle pipeline (canvas, mesh, surface, draw, specialization) e il tempo
## del fotogramma. Stampa (GS:) le pipeline nuove da 0,1 s prima della goccia a 2 s dopo e i fotogrammi sopra 33 ms in
## quella finestra; con Vulkan due scatti negli istanti del collaudo della 0.3.23 (goccia +0,263 s e +0,763 s: gli scatti
## 013 e 014 di giro_squalo a PASSO 0,5).
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/goccia_strade.gd <nuova|inizio|continua> <cartella>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
var cart := ""
var scatti := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _pipe() -> Array:
	return [int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))]


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var strada := a[1] if a.size() > 1 else "nuova"
	cart = a[2] if a.size() > 2 else "user://goccia"
	DirAccess.make_dir_recursive_absolute(cart)
	scatti = DisplayServer.get_name() != "headless"
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(60)
	print("GS: strada %s, salvataggio %s, preset %s, qualita_provata %s" % [strada, GameState.has_save(), Grafica.valore("preset"), Grafica.valore("qualita_provata")])
	match strada:
		"nuova":
			get_tree().current_scene.call(&"nuova_partita")
			await _frames(120)
			for n in get_tree().root.get_children():
				if n is LettoreSpot:
					n.call(&"_fine")
		"inizio":
			get_tree().current_scene.call(&"_avvia_nuova_partita")
			await _frames(60)
			for n in get_tree().root.get_children():
				if n is LettoreSpot:
					n.call(&"_fine")
		"continua":
			get_tree().current_scene.call(&"continua")
	var s: RisveglioSqualo = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc and sc.scene_file_path.ends_with("sala_principale.tscn"):
			s = sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo
			if s and s.in_corso():
				break
	if s == null or not s.in_corso():
		print("GS: la scena dello squalo non è partita (%s)" % s)
		get_tree().quit(1)
		return
	var G := float(s.tempi.get("goccia", 4.4))
	print("GS: scena in corso dopo %.1f s, goccia a %.2f s di scena; pipeline adesso %s" % [(Time.get_ticks_msec() - t0) / 1000.0, G, _pipe()])
	var prima := _pipe()
	var ult := Time.get_ticks_usec()
	var nuove: Array = []
	var lunghi: Array = []
	var nfin := 0
	var fatti := [false, false]
	var maxms := 0.0
	while s and is_instance_valid(s) and s.in_corso():
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		var ms := (ora - ult) / 1000.0
		ult = ora
		var ts: float = s.get(&"_t")
		var p := _pipe()
		if ts >= G - 0.1 and ts <= G + 2.0:
			nfin += 1
			maxms = maxf(maxms, ms)
			if p != prima:
				var d: Array = []
				for i in p.size():
					d.append(p[i] - prima[i])
				nuove.append("a %.3f s di scena (goccia %+.3f): %s" % [ts, ts - G, d])
			if ms > 33.0:
				lunghi.append("%.1f ms a %+.3f" % [ms, ts - G])
		elif p != prima and ts > G - 1.0 and ts < G + 3.0:
			var d2: Array = []
			for i in p.size():
				d2.append(p[i] - prima[i])
			print("GS:   pipeline nuove fuori finestra a %.3f s di scena: %s" % [ts, d2])
		prima = p
		if scatti and not fatti[0] and ts >= G + 0.263:
			fatti[0] = true
			await _scatto("%s_goccia_+0.26s" % strada)
		elif scatti and not fatti[1] and ts >= G + 0.763:
			fatti[1] = true
			await _scatto("%s_goccia_+0.76s" % strada)
		if ts > G + 3.0:
			break
	print("GS: %s: nella finestra goccia -0,1 s .. +2 s: fotogrammi %d, il più lungo %.1f ms, sopra 33 ms %d %s" % [strada, nfin, maxms, lunghi.size(), lunghi])
	print("GS: %s: pipeline nuove nella finestra (canvas, mesh, surface, draw, specialization): %d volte %s" % [strada, nuove.size(), nuove])
	print("GS: finito")
	get_tree().quit()
