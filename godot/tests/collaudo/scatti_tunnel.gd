extends Node
## Collaudo (squadra collaudo): scatti col renderer vero e le luci del tunnel (senza torcia né luce sulla camera) nel
## solo tunnel del viaggio sottomarino (SalaSottomarino, costruito tutto, con un ambiente come quello della scena di
## prova): leggero, senza la sala delle condotte.
## - ravvicinati: ogni gommone in 3 momenti del dondolio (dalla banchina agli occhi e da vicino), ogni corda (anello e
##   maniglia), il gradino continuo, le gallerie, gli ostacoli, il portello (aperto, chiuso, il volantino);
## - gli stati di lei: nella presa (ferma), che sale, che insegue a varie distanze, ritratta dal getto, che prende.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --script res://tests/run.gd -- \
##        res://tests/collaudo/scatti_tunnel.gd <cartella> [gruppi separati da virgole: gommoni,corde,gradini,gallerie,ostacoli,portello,lei]

const SCENA := "res://scenes/sala/sottomarino/sala_sottomarino.tscn"

var sott: SalaSottomarino
var cam: Camera3D
var cart := ""
var _riga := []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	DirAccess.make_dir_recursive_absolute(cart)
	var gruppi := (a[2] if a.size() > 2 else "gommoni,corde,gradini,gallerie,ostacoli,lei,portello").split(",")
	Game.pause_on_focus_loss = false
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.34)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	get_tree().root.add_child(amb)
	sott = (load(SCENA) as PackedScene).instantiate() as SalaSottomarino
	get_tree().root.add_child(sott)
	sott.costruisci()
	var finto := Node3D.new()
	finto.name = "Bersaglio"
	get_tree().root.add_child(finto)
	sott.bersaglio = finto
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.03
	cam.far = 200.0
	get_tree().root.add_child(cam)
	cam.make_current()
	for i in 20:
		await get_tree().process_frame
	for g in gruppi:
		print("SCATTI: gruppo ", g)
		await call("_" + g)
	var f := FileAccess.open(cart.path_join("scatti.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_riga))
	f.close()
	print("SCATTI: finito, %d" % _riga.size())
	get_tree().quit()


func _foto(nome: String, da: Vector3, verso: Vector3, fov := 75.0, attesa := 4) -> void:
	cam.global_position = da
	cam.fov = fov
	if da.distance_to(verso) > 0.01:
		var su := Vector3.UP if absf((verso - da).normalized().y) < 0.98 else Vector3.FORWARD
		cam.look_at(verso, su)
	for i in attesa:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.85)
	_riga.append("%s da %s verso %s" % [nome, str(da), str(verso)])


func _occhi(s: float, lato: float, su := 1.6) -> Vector3:
	return sott.punto(s) + sott.destra(s) * lato * (sott.canale + 0.8) + Vector3.UP * (sott.piano - sott.acqua + su)


# --- gommoni e corde ------------------------------------------------------------------------------------------------

func _gommoni() -> void:
	for t in [0.0, 1.3, 2.7]:
		sott.ferma_gommoni(t)
		for i in sott._gommoni.size():
			var g: Dictionary = sott._gommoni[i]
			var c: Vector3 = (g["corpo"] as Node3D).global_position
			var pr: Array = sott.proietta(c)
			var s: float = pr[0]
			var lato := -signf(float(pr[1])) if absf(float(pr[1])) > 0.2 else 1.0
			var tt := "t%02d" % int(t * 10)
			await _foto("gom%02d_%s_banchina" % [i, tt], _occhi(s - 2.0, lato), c)
			# da vicino, di lato e un po' dall'alto: il fondo nell'acqua, il tubolare e le maniglie
			var lato2 := sott.destra(s) * lato
			await _foto("gom%02d_%s_vicino" % [i, tt], c + lato2 * 1.9 + sott.direzione(s) * 1.2 + Vector3.UP * 1.1, c, 60.0)
			if t == 0.0:
				await _foto("gom%02d_%s_pelo" % [i, tt], c - sott.direzione(s) * 2.4 + Vector3.UP * 0.25, c, 60.0)


func _corde() -> void:
	sott.ferma_gommoni(0.0)
	for i in sott._gommoni.size():
		var g: Dictionary = sott._gommoni[i]
		var corpo: Node3D = g["corpo"]
		for j in (g["corde"] as Array).size():
			var c: Dictionary = g["corde"][j]
			var anello: Vector3 = c["anello"]
			var man: Vector3 = corpo.global_transform * (c["maniglia"] as Vector3)
			var via := (man - anello)
			var lato := Vector3(via.x, 0.0, via.z).normalized()
			await _foto("corda%02d_%d_anello" % [i, j], anello + lato * 0.7 + Vector3.UP * 0.25 + Vector3(lato.z, 0, -lato.x) * 0.3, anello, 55.0)
			await _foto("corda%02d_%d_maniglia" % [i, j], man + Vector3.UP * 0.6 - lato * 0.5 + Vector3(lato.z, 0, -lato.x) * 0.4, man, 55.0)
			await _foto("corda%02d_%d_intera" % [i, j], (man + anello) * 0.5 + Vector3(lato.z, 0, -lato.x) * 1.8 + Vector3.UP * 0.6, (man + anello) * 0.5, 70.0)


# --- gradini, gallerie, ostacoli --------------------------------------------------------------------------------

func _gradini() -> void:
	var s := 10.0
	while s < sott.lunghezza() - 5.0:
		for lato in [-1.0, 1.0]:
			# dal canale, nell'acqua, con la testa del giocatore (1,6 m sopra il fondo), guardando il gradino
			var da: Vector3 = sott.punto(s) + sott.destra(s) * -lato * 0.5 + Vector3.UP * (sott.fondo - sott.acqua + 1.6)
			var gr: Vector3 = sott.punto(s + 1.5) + sott.destra(s + 1.5) * lato * (sott.canale - 0.2) + Vector3.UP * (sott.fondo - sott.acqua + 0.45)
			await _foto("gradino_%03d_%s" % [int(s), "sx" if lato < 0 else "dx"], da, gr, 70.0)
		s += 45.0


func _gallerie() -> void:
	for o in sott.ostacoli:
		if o["tipo"] != "galleria":
			continue
		var s0: float = float(o["s"])
		var lato: float = float(o["lato"])
		var u_gal := sott.muro + sott.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
		var bocca := sott.punto(s0 - SalaSottomarino.GALLERIA_BOCCA * 0.5) + sott.destra(s0) * lato * u_gal + Vector3.UP * (sott.piano - sott.acqua + 0.8)
		await _foto("gal%03d_avvicinando" % int(s0), _occhi(s0 - 10.0, lato), bocca)
		await _foto("gal%03d_davanti" % int(s0), _occhi(s0 - 4.0, lato, 1.0), bocca)
		for k in 4:
			var sk := s0 + float(o["lungo"]) * float(k) / 3.0
			var dentro := sott.punto(sk) + sott.destra(sk) * lato * u_gal + Vector3.UP * (sott.piano - sott.acqua + 0.95)
			var avanti := sott.punto(sk + 3.0) + sott.destra(sk + 3.0) * lato * u_gal + Vector3.UP * (sott.piano - sott.acqua + 0.9)
			await _foto("gal%03d_dentro_%d" % [int(s0), k], dentro, avanti)
		var fine := s0 + float(o["lungo"]) + SalaSottomarino.GALLERIA_BOCCA
		await _foto("gal%03d_uscita" % int(s0), _occhi(fine + 3.0, lato), _occhi(fine - 2.0, lato, 0.8))


func _ostacoli() -> void:
	for o in sott.ostacoli:
		if o["tipo"] == "galleria":
			continue
		var s0: float = float(o["s"])
		var lato: float = float(o["lato"])
		var dove := sott.punto(s0) + sott.destra(s0) * lato * (sott.canale + 1.3) + Vector3.UP * (sott.piano - sott.acqua + 1.0)
		await _foto("ost%03d_%s_lontano" % [int(s0), o["tipo"]], _occhi(s0 - 14.0, lato), dove)
		await _foto("ost%03d_%s_vicino" % [int(s0), o["tipo"]], _occhi(s0 - 4.0, lato), dove)
		await _foto("ost%03d_%s_altra" % [int(s0), o["tipo"]], _occhi(s0 - 3.0, -lato), dove)
		await _foto("ost%03d_%s_dopo" % [int(s0), o["tipo"]], _occhi(s0 + float(o["lungo"]) + 4.0, lato), dove)


# --- lei ------------------------------------------------------------------------------------------------------------

func _passa(secondi: float) -> void:
	for i in int(secondi * 60.0):
		await get_tree().process_frame


func _lei() -> void:
	var finto: Node3D = sott.bersaglio
	# ferma nella presa (prima che riemerga): dalla porta del bacino
	var porta := sott.punto(SalaSottomarino.PORTA_S) - sott.destra(SalaSottomarino.PORTA_S) * (sott.canale + 1.3) + Vector3.UP * (sott.piano - sott.acqua + 1.6)
	var presa := sott.punto(-1.0) + Vector3.UP * 1.0
	await _foto("lei_0_presa_ferma", porta, presa)
	sott.attivo = true
	finto.global_position = sott.punto(4.0) - sott.destra(4.0) * (sott.canale + 1.3) + Vector3.UP * (sott.piano - sott.acqua)
	sott.riemergi()
	for k in 5:
		await _passa(0.6)
		await _foto("lei_1_sale_%d" % k, porta, presa + Vector3.UP * 1.5)
	# insegue: il bersaglio sulla banchina sinistra, lei dietro a 18, 12, 8, 5 m
	var s_b := 120.0
	for gap in [18.0, 12.0, 8.0, 5.0]:
		finto.global_position = sott.punto(s_b) - sott.destra(s_b) * (sott.canale + 1.3) + Vector3.UP * (sott.piano - sott.acqua)
		sott._s_bersaglio = s_b
		sott.insegui_da(s_b - gap)
		sott.lei_s = s_b - gap
		await _passa(1.2)
		var occhi := _occhi(s_b, -1.0)
		await _foto("lei_2_insegue_%02d_m" % int(gap), occhi, sott.punto(s_b - gap) + Vector3.UP * 2.0)
		await _foto("lei_2_insegue_%02d_m_lato" % int(gap), _occhi(s_b - gap * 0.5, 1.0), sott.punto(s_b - gap) + Vector3.UP * 2.0)
	# ritratta dal getto
	sott.respingi()
	for k in 4:
		await _passa(0.4)
		await _foto("lei_3_ritratta_%d" % k, _occhi(s_b, -1.0), sott.punto(sott.lei_s) + Vector3.UP * 2.0)
	# che prende: il bersaglio fermo, lei arriva
	await _passa(1.5)
	for k in 8:
		await _passa(0.5)
		var nome := "lei_4_%s_%d" % [SalaSottomarino.Lei.keys()[sott.lei_stato].to_lower(), k]
		await _foto(nome, _occhi(s_b, -1.0), sott.punto(sott.lei_s) + Vector3.UP * 2.0)
	sott.lei_stato = SalaSottomarino.Lei.VIA
	sott.lei_tunnel.via()


# --- il portello ----------------------------------------------------------------------------------------------------

func _portello() -> void:
	var L := sott.lunghezza()
	var pL := sott.punto(L)
	var rL := sott.destra(L)
	var dL := sott.direzione(L)
	var sg := sott.piano - sott.acqua + SalaSottomarino.SOGLIA
	var centro := pL + rL * (SalaSottomarino.PORTA_SX + SalaSottomarino.PORTELLO_LARGO * 0.5) + Vector3.UP * (sg + 1.0)
	await _foto("port_dalla_banchina_sx", _occhi(L - 12.0, -1.0), centro)
	await _foto("port_dalla_banchina_dx", _occhi(L - 12.0, 1.0), centro)
	await _foto("port_dal_canale", sott.punto(L - 8.0) + Vector3.UP * (sott.fondo - sott.acqua + 1.6), centro)
	await _foto("port_scala", pL - dL * 4.0 - rL * (sott.muro - 0.6) + Vector3.UP * (sott.piano - sott.acqua + 1.6), pL - dL * 0.5 - rL * (sott.muro - 0.5) + Vector3.UP * sg)
	await _foto("port_pontile", pL - dL * 0.5 - rL * (sott.muro - 0.6) + Vector3.UP * (sg + 1.6), centro)
	await _foto("port_soglia_aperto", pL - dL * 0.4 + rL * (SalaSottomarino.PONTILE_FINO - 0.3) + Vector3.UP * (sg + 1.6), centro + dL * 1.5)
	var dentro := pL + dL * 1.6 + rL * (SalaSottomarino.PORTA_SX + 0.6) + Vector3.UP * (sg + 1.6)
	await _foto("port_dalla_camera_aperto", dentro, centro)
	var vol := pL + rL * (SalaSottomarino.PORTA_SX + (SalaSottomarino.PORTELLO_LARGO * 0.5)) + Vector3.UP * (sg + SalaSottomarino.VOLANTINO_Y)
	await _foto("port_volantino_aperto", vol + dL * 1.0 + Vector3.UP * 0.4 + rL * 0.3, vol, 50.0)
	sott.chiudi_portello()
	await _passa(1.5)
	await _foto("port_dalla_camera_chiuso", dentro, centro)
	await _foto("port_volantino_chiuso", pL + dL * 0.9 + rL * (SalaSottomarino.PORTA_SX + (SalaSottomarino.PORTELLO_LARGO * 0.5) + 0.25) + Vector3.UP * (sg + SalaSottomarino.VOLANTINO_Y + 0.4), pL + rL * (SalaSottomarino.PORTA_SX + (SalaSottomarino.PORTELLO_LARGO * 0.5)) + Vector3.UP * (sg + SalaSottomarino.VOLANTINO_Y), 50.0)
	await _foto("port_chiuso_dal_tunnel", _occhi(L - 10.0, -1.0), centro)
	for k in 6:
		await _passa(0.5)
		await _foto("port_schianto_%d" % k, pL + dL * 1.0 + rL * (SalaSottomarino.PORTA_SX + (SalaSottomarino.PORTELLO_LARGO * 0.5)) + Vector3.UP * (sg + SalaSottomarino.OBLO_Y), pL - dL * 2.0 + rL * (SalaSottomarino.PORTA_SX + (SalaSottomarino.PORTELLO_LARGO * 0.5)) + Vector3.UP * (sg + SalaSottomarino.OBLO_Y))
