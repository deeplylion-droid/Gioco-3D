extends Node
## Ricontrollo di grafica-2 (lavoro/luci-0317): il riflesso viola sulla faccia dello squalo al ruggito.
## Dalla camera del giocatore, con un preset: in alcuni momenti del ruggito la scena si ferma (pausa) e si scatta lo stesso
## fotogramma col riflesso acceso e spento; la differenza è quello che il riflesso illumina (salvata schiarita x8).
## Stampa: luminanza della bocca e di tutto, quanti pixel cambia il riflesso e quanti di questi stanno sullo squalo
## (la sua sagoma: i pixel che cambiano spegnendo lo squalo); l'energia del riflesso a ogni fotogramma (deve tornare a 0
## dopo "arretra" + 0,6 s); se qualcosa del giocatore sta sullo strato dello squalo; le pipeline compilate al ruggito.
## Uso: xvfb-run ... --fixed-fps 30 --script res://tests/run.gd -- res://tests/verifica_ruggito_g2.gd <cartella> <preset>

const LEVEL := "res://scenes/interni/interni.tscn"
const LATO := 120


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var args := OS.get_cmdline_user_args()
	var cartella: String = args[1]
	var preset: String = args[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	Grafica.applica_preset(preset)
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 30:
		await get_tree().process_frame
	var level := get_tree().current_scene
	var p := GameState.player
	var s := level.get_node("Gioco/RisveglioSqualo") as RisveglioSqualo
	var atm := s.get_node_or_null("Atmosfera")
	var rif := atm.get(&"riflesso") as OmniLight3D
	# il giocatore sullo strato dello squalo? (mani, lancia, zaino)
	var sullo_strato := []
	for g in p.find_children("*", "VisualInstance3D", true, false):
		if (g as VisualInstance3D).layers & RisveglioSqualo.STRATO_SQUALO:
			sullo_strato.append(String(g.name))
	print("VERIFICA %s: del giocatore sullo strato dello squalo: %s; maschera del riflesso %d" % [preset, sullo_strato, rif.light_cull_mask])
	var m: float = s.tempi.get("minaccia", 2.4)
	var r: float = s.tempi.get("richiamo", 5.4)
	var a: float = s.tempi.get("arretra", 6.05)
	var momenti := [[m + 0.5, "ruggito_1"], [(m + r) * 0.5, "ruggito_2"], [r - 0.2, "ruggito_3"], [a + 0.3, "arretra_03"], [a + 0.9, "arretra_09"]]
	var p0 := _pipeline()
	level.call(&"fai_risveglio", p, true)
	var t := 0.0
	var k := 0
	var acceso_dopo := 0.0
	var max_e := 0.0
	while t < a + 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		max_e = maxf(max_e, rif.light_energy)
		if t > a + 0.65:
			acceso_dopo = maxf(acceso_dopo, rif.light_energy)
		if k < momenti.size() and t >= float(momenti[k][0]):
			await _confronto(cartella, "%s_%s" % [preset, momenti[k][1]], s, rif, t)
			k += 1
	var p1 := _pipeline()
	print("VERIFICA %s: energia massima del riflesso %.2f; dopo arretra+0,65 s al più %.3f; pipeline al ruggito +%d/+%d" % [
			preset, max_e, acceso_dopo, p1[0] - p0[0], p1[1] - p0[1]])
	get_tree().quit()


func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


## Lo stesso fotogramma col riflesso acceso, spento, e senza lo squalo (la sua sagoma); la scena ferma in pausa.
func _confronto(cartella: String, nome: String, s: RisveglioSqualo, rif: OmniLight3D, t: float) -> void:
	get_tree().paused = true
	var e := rif.light_energy
	var con := await _img()
	rif.light_energy = 0.0
	var senza := await _img()
	var sq := s.squalo
	var sq_vis := sq.visible if sq else false
	if sq:
		sq.visible = false
	var vuoto := await _img()
	if sq:
		sq.visible = sq_vis
	rif.light_energy = e
	get_tree().paused = false
	con.save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	var w := con.get_width()
	var h := con.get_height()
	var diff := Image.create(w, h, false, Image.FORMAT_RGB8)
	var cambiati := 0
	var fuori := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c1 := con.get_pixel(x, y)
			var c2 := senza.get_pixel(x, y)
			var d := (absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b)) / 3.0
			diff.set_pixel(x, y, Color(minf(d * 8.0, 1.0), minf(d * 8.0, 1.0), minf(d * 8.0, 1.0)))
			if d * 255.0 > 2.0:
				cambiati += 1
				var c3 := vuoto.get_pixel(x, y)
				var dsq := (absf(c2.r - c3.r) + absf(c2.g - c3.g) + absf(c2.b - c3.b)) / 3.0
				if dsq * 255.0 < 1.0:
					fuori += 1
	diff.save_jpg(cartella.path_join(nome + "_riflesso_x8.jpg"), 0.9)
	var bocca: Vector3 = s.call(&"_punto_bocca")
	var cam := get_viewport().get_camera_3d()
	var faccia := -1.0
	if cam and not cam.is_position_behind(bocca):
		var c := cam.unproject_position(bocca)
		var rr := Rect2i(Vector2i(c) - Vector2i(LATO, LATO) / 2, Vector2i(LATO, LATO)).intersection(Rect2i(Vector2i.ZERO, con.get_size()))
		if rr.has_area():
			faccia = _luma(con, rr)
	print("VERIFICA %s t %.2f energia %.2f: bocca %.1f, tutto %.1f; pixel cambiati dal riflesso %d, fuori dallo squalo %d" % [
			nome, t, e, faccia, _luma(con, Rect2i(Vector2i.ZERO, con.get_size())), cambiati, fuori])


func _img() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _luma(img: Image, r: Rect2i) -> float:
	var somma := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var c := img.get_pixel(x, y)
			somma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return somma / maxf(n, 1) * 255.0
