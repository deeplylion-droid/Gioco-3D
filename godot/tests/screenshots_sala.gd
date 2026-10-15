extends Node
## Screenshot della demo della sala principale (serve un vero renderer).
## Uso (con --fixed-fps il tempo di gioco avanza di 1/60 s per frame):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1920x1080 --script res://tests/run.gd -- res://tests/screenshots_sala.gd <cartella> \
##        [inquadrature separate da virgole] [preset] [frame di attesa]
## Il preset (predefinito "ultra") è quello dell'addon grafica; "ultra" usa la GI SDFGI.
## I frame di attesa servono all'antialiasing temporale, alla GI e alla nebbia per assestarsi.

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://screenshots_sala"
var only := PackedStringArray()
var preset := "ultra"
var settle := 50
var level: Node
var p: Player


func _ready() -> void:
	# Interruttore per fermare in fretta una serie di screenshot già in coda: basta creare il
	# file user://salta_screenshot.
	if FileAccess.file_exists("user://salta_screenshot"):
		get_tree().quit()
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2 and args[2] != "" and args[2] != "tutte":
		only = args[2].split(",")
	if args.size() > 3:
		preset = args[3]
	if args.size() > 4:
		settle = int(args[4])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _want(shot: String) -> bool:
	return only.is_empty() or only.has(shot)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if preset == "ultra" or preset == "ultra_sdfgi":
		Grafica.applica_preset("ultra")
		Grafica.imposta("gi", 2)
		# Sul renderer software del sandbox l'Ultra pieno non sta in memoria: ombre "alte"
		# (atlante 4096 invece di 8192) e nebbia volumetrica normale. A 1080p non si vede la differenza.
		Grafica.imposta("ombre", 3)
		Grafica.imposta("nebbia", 1)
		Grafica.imposta("ssil", 2)
		Grafica.imposta("ssao", 3)
	elif preset == "alto_smaa":
		# Alto con la GI calcolata, ma SMAA al posto del TAA: senza i vettori di movimento il
		# renderer software compila meno pipeline e lo scatto sta in memoria (a fermo non cambia).
		Grafica.applica_preset("alto")
		Grafica.imposta("antialiasing", 2)
	elif preset == "alto_senza_gi":
		# Alto senza illuminazione globale: sta nella memoria del renderer software anche a
		# 1600x900 (la GI VoxelGI calcolata la usa il gioco vero).
		Grafica.applica_preset("alto")
		Grafica.imposta("gi", 0)
	else:
		Grafica.applica_preset(preset)
	# Acqua con SSR nello shader invece del riflesso planare (che rende di nuovo la scena).
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	# SCATTI_LIVELLO: un'altra scena della sala (per esempio la variante senza dettagli).
	var level_path := OS.get_environment("SCATTI_LIVELLO")
	get_tree().change_scene_to_file(level_path if level_path != "" else LEVEL)
	await _frames(10)
	get_tree().paused = false
	level = get_tree().current_scene
	p = GameState.player
	# Con gli interni si parte dal risveglio nel corridoio: si aspetta che finisca.
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	for we in level.find_children("*", "WorldEnvironment", true, false):
		if (we as WorldEnvironment).environment:
			(we as WorldEnvironment).environment.sdfgi_cascades = 3
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var storm: Tempesta = level.find_children("*", "Tempesta", true, false)[0]
	storm.automatica = false
	var lamp: FlickerLight = level.get_node("Vasca/Sfarfallio")
	# SCATTI_FASE=blackout: la sala dopo il risveglio (tappa 7), con la torcia accesa.
	var buio := OS.get_environment("SCATTI_FASE") == "blackout"
	if buio:
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		await _frames(5)
	else:
		# Negli scatti la lampada è già accesa e ferma (niente accensione a colpi nella nebbia).
		lamp.turn_on(true)
	# Davanti alla statua la torcia è spenta: la illuminano solo le sue luci da monumento.
	var torch := p.find_child("Torcia", true, false) as Torcia
	var statue_only := not only.is_empty()
	for o in only:
		if not String(o).begins_with("statua") and not String(o).begins_with("vasca") and not o in ["ingresso_statua", "ingresso_vasca", "telecamera_monitor"]:
			statue_only = false
	if torch and statue_only and not buio:
		torch.imposta_accesa(false)
	if _want("ingresso_vasca"):
		# Entrando nella sala: la medusa affacciata alla vasca, il viso nel cono del lampione.
		await _shot("ingresso_vasca", Vector3(0.0, 0.0, 19.2), Vector3(0.0, 1.9, 11.0))
		# SCATTI_LUCI: la stessa inquadratura con altre energie delle luci sulla medusa, per
		# sceglierle senza ricaricare la sala. Varianti separate da ";", ognuna per esempio
		# "fari=3,lampione=2.5" (i file finiscono con la variante).
		for v in OS.get_environment("SCATTI_LUCI").split(";", false):
			for kv in v.split(",", false):
				var e := float(kv.get_slice("=", 1))
				match kv.get_slice("=", 0):
					"fari":
						for f in level.find_children("luce_faro*", "SpotLight3D", true, false):
							(f as SpotLight3D).light_energy = e
					"lampione":
						lamp.base_energy = e
			await _frames(maxi(settle, 12))
			await _capture("ingresso_vasca_" + v.replace("=", "").replace(",", "_"))
	if _want("scia_vasca"):
		# Tappa 7: dal cordone, la vasca vuota e le gocce che dal bordo vanno verso il buio.
		await _shot("scia_vasca", Vector3(-8.0, 0.0, 10.9), Vector3(-4.2, 0.0, 9.3))
	if _want("scia_buio"):
		# Tappa 7: dal cordone della vasca, la scia di gocce che va verso il fondo della sala.
		await _shot("scia_buio", Vector3(-7.9, 0.0, 10.6), Vector3(-14.5, -0.6, 7.8))
	if _want("lei_sbuca") or _want("lei_sottacqua") or _want("lei_dall_alto"):
		# Tappa 8 (con SCATTI_FASE=blackout): lei che sbuca dal bordo della fossa, vista dalla scia
		# a 5 m, e la sua luce sott'acqua quando se ne va. Ferma: niente presa, niente attesa.
		var lei := level.get(&"lei_sbuca") as LeiSbuca
		if lei:
			lei.abilitata = true
			lei.attesa = 999.0
			lei.distanza_presa = 0.0
			var testa := lei._testa_prevista()
			var verso := lei.punto_sbuca.global_basis.z
			verso.y = 0.0
			verso = verso.normalized()
			p.teleport(Vector3(0.0, 0.0, 21.0), 0.0, 0.0)
			# Quando arrivi l'acqua è già quasi al pelo pieno (sale da quando ripartono le pompe).
			for v in lei.vasche:
				var t := v as WaterTank
				t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
			lei._sbuca()
			await _frames(int(lei.durata_sbuca * 60.0) + 10)
			if _want("lei_sbuca"):
				var da := testa + verso * 5.0
				await _shot("lei_sbuca", Vector3(da.x, 0.0, da.z), testa + Vector3(0.0, -0.25, 0.0))
			if _want("lei_dall_alto"):
				# Controllo: dall'alto, che campana e tentacoli restino dentro la fossa.
				await _shot_camera("lei_dall_alto", lei.punto_sbuca.global_position + Vector3(-0.4, 4.6, 1.6),
						lei.punto_sbuca.global_position + Vector3(-0.4, 0.3, 0.2), 60.0)
			if _want("lei_sottacqua"):
				lei.durata_fuga = 60.0
				lei._fuga()
				await _frames(90)
				var bordo := testa + verso * 1.6
				await _shot("lei_sottacqua", Vector3(bordo.x, 0.0, bordo.z), lei.punto_sbuca.global_position + Vector3(0.0, -0.6, 0.0))
	if _want("telecamera_monitor"):
		# La telecamera di sorveglianza della sala, per il monitor della sala pompe: in alto sopra
		# l'ingresso, verso la medusa nella vasca (si ritaglia in 4:3).
		await _shot_camera("telecamera_monitor", Vector3(-5.0, 5.3, 16.4), Vector3(0.0, 1.1, 11.0), 60.0)
	if _want("vasca_primo_piano"):
		# Dal bordo, oltre il cordone: occhio negli occhi.
		await _shot("vasca_primo_piano", Vector3(0.35, 0.0, 13.25), Vector3(0.0, 1.5, 11.9))
	if _want("ingresso_statua"):
		# Dall'uscita degli spogliatoi: la medusa intera sul piedistallo, la cupola dietro.
		await _shot("ingresso_statua", Vector3(0.0, 0.0, 19.2), Vector3(0.0, 3.4, 10.0))
	if _want("statua_lampo_ingresso"):
		await _shot("statua_lampo_ingresso", Vector3(0.0, 0.0, 19.2), Vector3(0.0, 3.4, 10.0), func(): storm.lampo_ora(1.4, 0.5, PI * 0.95), 4)
	if _want("statua_meta"):
		# A metà strada.
		await _shot("statua_meta", Vector3(-0.6, 0.0, 15.3), Vector3(0.0, 3.8, 10.0))
	if _want("statua_piedi"):
		# Ai suoi piedi, guardando in su: deve incombere.
		await _shot("statua_piedi", Vector3(-0.9, 0.0, 13.3), Vector3(0.0, 5.0, 10.0))
	if _want("statua_vicino"):
		await _shot("statua_vicino", Vector3(1.9, 0.0, 13.6), Vector3(0.0, 3.8, 10.0))
	if _want("statua_lampo"):
		await _shot("statua_lampo", Vector3(-2.4, 0.0, 14.0), Vector3(0.0, 3.6, 10.0), func(): storm.lampo_ora(1.3, 0.6, PI * 0.8), 5)
	if _want("piscina"):
		# Dal bordo della parte profonda verso la spiaggia e l'area bimbi, sotto la cupola.
		await _shot("piscina", Vector3(5.6, 0.0, 6.6), Vector3(-2.0, -1.0, -6.0))
	if _want("torcia"):
		# La torcia sul pavimento bagnato, verso la torre degli scivoli.
		await _shot("torcia", Vector3(9.0, 0.0, 9.0), Vector3(13.0, 0.8, -4.0))
	if _want("area_bimbi"):
		await _shot("area_bimbi", Vector3(-6.5, 0.0, -6.0), Vector3(-13.0, 2.5, -15.0))
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(file: String, pos: Vector3, look: Vector3, before := Callable(), after_frames := -1) -> void:
	p.teleport(pos, 0.0, 0.0)
	p.look_at_point(look)
	await _frames(settle)
	if before.is_valid():
		before.call()
		await _frames(after_frames if after_frames >= 0 else 4)
	await _capture(file)


## Uno scatto da una telecamera libera (non dagli occhi del giocatore), per esempio dall'alto.
func _shot_camera(file: String, pos: Vector3, look: Vector3, fov := 70.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	level.add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true
	# Il giocatore lontano dall'inquadratura (e con la torcia spenta).
	p.teleport(Vector3(0.0, 0.0, 21.0), 0.0, 0.0)
	await _frames(settle)
	await _capture(file)
	cam.queue_free()
	p.camera.current = true


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)
	print("memoria: statica %d MB, video %d MB (texture %d MB, buffer %d MB), pipeline %d, oggetti %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576,
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
