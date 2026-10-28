extends Node
## Il video dell'enigma dei giocattoli (docs/proposte/enigma_giocattoli/): dagli occhi del giocatore che lo risolve
## nell'ordine A (prima i giocattoli sull'acqua, poi lo svuotamento), camminando e spruzzando col getto vero. Nella sala
## ridotta (tests/scena_ridotta.gd: su llvmpipe la sala intera non ci sta in memoria), col preset medio. Con
## --write-movie Godot scrive ogni fotogramma (e l'audio). Fa anche gli scatti per il LEGGIMI nei momenti giusti e
## stampa le pipeline compilate in ogni fase (dopo il riscaldamento a metà enigma non se ne devono compilare).
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --write-movie <file.avi> --script res://tests/run.gd -- res://tests/video_enigma_giocattoli.gd <cartella>

const SCENA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca",
		"Gioco/EnigmaAcquari"]
const MONITOR := {"surface": Performance.PIPELINE_COMPILATIONS_SURFACE, "draw": Performance.PIPELINE_COMPILATIONS_DRAW,
		"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION}

var out := ""
var level: Node
var p: Player
var enigma: EnigmaGiocattoli
var vasca: WaterTank
var piscina: PiscinaOnde
var pulsante: WaterButton
var portello: Node
var _pipeline := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[1] if a.size() > 1 else "user://video_giocattoli"
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.applica_preset("medio")
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(SCENA, TOGLI))
	while get_tree().current_scene == null or get_tree().current_scene == self:
		await get_tree().process_frame
	level = get_tree().current_scene
	p = level.get_node_or_null(^"Player") as Player
	# (il giocatore della sala parte dove c'erano gli interni, tolti: fermo finché non è sul bordo della piscina)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.teleport(Vector3(8.4, 0.05, -0.4), _yaw_verso(Vector3(8.4, 0, -0.4), Vector3(-6.0, 0, 0.2)), -0.35)
	enigma = level.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	vasca = level.get_node(^"Piscina/Pozza") as WaterTank
	piscina = level.get_node(^"Piscina/SvuotaPiscina") as PiscinaOnde
	pulsante = level.get_node(^"Piscina/PulsantePortello") as WaterButton
	portello = level.get_node(^"Piscina/Portello")
	for i in 90:
		await get_tree().process_frame
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true)
	p.water_pack.set_tank_amount(20.0)
	await _attendi(2.0)
	_conta_pipeline("inizio")

	print("FASE il disegno")
	# giù in acqua dal bordo est e verso il muro ovest, a guardare il disegno dei bambini
	await _cammina([Vector3(6.2, 0, -0.4), Vector3(0.5, 0, -1.6), Vector3(-2.9, 0, -0.9)])
	await _guarda(Vector3(-6.97, -0.85, -0.2), 0.8)
	await _attendi(2.5)
	_scatto("giocattoli_disegno")
	_conta_pipeline("disegno")

	print("FASE i giocattoli")
	for i in [1, 0, 2]:
		await _spingi(i)
		_conta_pipeline("giocattolo %d" % i)
	# i tre bordi accesi appena, coi giocattoli che galleggiano sopra
	await _cammina([Vector3(0.4, 0, -1.2)])
	await _guarda(Vector3(-0.5, -1.8, 2.4), 0.8)
	await _attendi(1.5)
	_scatto("giocattoli_sui_cerchi")

	print("FASE lo svuotamento")
	await _svuota()
	_conta_pipeline("svuotata")
	await _guarda(Vector3(-3.9, -2.0, 3.3), 0.9)
	for k in 240:
		if enigma.risolto_ok:
			break
		await get_tree().physics_frame
	await _attendi(1.0)
	_scatto("giocattoli_piatti_scesi")
	_conta_pipeline("piatti scesi")

	print("FASE la botola")
	await _cammina([Vector3(0.6, 0, 0.9)])
	await _guarda(pulsante.global_position + Vector3(0, 0.25, 0), 0.8)
	for k in 200:
		if pulsante.enabled:
			break
		await get_tree().physics_frame
	await _attendi(1.2)
	_scatto("giocattoli_luce_verde")
	_conta_pipeline("luce verde")
	await _spruzza_verso(pulsante.global_position + Vector3(0, 0.45, 0), 1.0)
	for k in 240:
		if bool(portello.get(&"is_open")):
			break
		await get_tree().physics_frame
	await _guarda(Vector3(0.0, -2.2, 2.1), 1.0)
	await _attendi(2.5)
	_scatto("giocattoli_botola_aperta")
	_conta_pipeline("botola aperta")
	print("FINE risolto %s, botola aperta %s" % [enigma.risolto_ok, portello.get(&"is_open")])
	get_tree().quit()


# --- Il giocatore ----------------------------------------------------------------------------------------------------

func _yaw_verso(da: Vector3, a: Vector3) -> float:
	return atan2(-(a.x - da.x), -(a.z - da.z))


## Cammina per i punti (in pianta) come il giocatore: guarda dove va (girandosi piano) e tiene premuto avanti.
func _cammina(punti: Array) -> void:
	for t in punti:
		var bersaglio: Vector3 = t
		Input.action_press(&"move_forward")
		for k in 30 * 20:
			var d := bersaglio - p.global_position
			if Vector2(d.x, d.z).length() < 0.3:
				break
			var yaw := _yaw_verso(p.global_position, bersaglio)
			p.set_look(lerp_angle(p.yaw, yaw, 0.18), lerpf(p.pitch, -0.25, 0.1))
			await get_tree().physics_frame
		Input.action_release(&"move_forward")
	for k in 6:
		await get_tree().physics_frame


## Gira lo sguardo verso [param punto] in [param secondi].
func _guarda(punto: Vector3, secondi: float) -> void:
	var y0 := p.yaw
	var p0 := p.pitch
	var occhio := p.get_eye_position()
	var d := punto - occhio
	var y1 := atan2(-d.x, -d.z)
	var p1 := atan2(d.y, Vector2(d.x, d.z).length())
	var n := maxi(1, int(secondi * Engine.physics_ticks_per_second))
	for k in n:
		var t := smoothstep(0.0, 1.0, float(k + 1) / n)
		p.set_look(lerp_angle(y0, y1, t), lerpf(p0, p1, t))
		await get_tree().physics_frame


func _attendi(secondi: float) -> void:
	for k in int(secondi * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## Spruzza mirando a [param punto] per [param secondi] (seguendolo se si muove).
func _spruzza_verso(punto: Vector3, secondi: float) -> void:
	await _guarda(punto, 0.35)
	Input.action_press(&"spray")
	await _attendi(secondi)
	Input.action_release(&"spray")


## Se lo zaino è quasi vuoto lo riempie dall'acqua davanti (nella pozza).
func _riempi() -> void:
	if p.water_pack.tank_amount > 7.0 or vasca.fill <= 0.01:
		return
	var davanti := p.global_position + Vector3(-sin(p.yaw), 0, -cos(p.yaw)) * 1.4
	await _guarda(Vector3(davanti.x, vasca.get_surface_global_y(), davanti.z), 0.4)
	Input.action_press(&"suck")
	for k in 30 * 4:
		if p.water_pack.tank_amount >= p.water_pack.tank_capacity - 0.5:
			break
		await get_tree().physics_frame
	Input.action_release(&"suck")


## Come nel test: dietro al giocattolo (rispetto al suo cerchio), mira un po' sopra e spruzza finché va alla velocità
## giusta per arrivarci scivolando; poi lo guarda arrivare.
func _spingi(i: int) -> void:
	var g := enigma.giocattolo(i)
	var c := enigma.cerchio(i).global_position
	for colpo in 12:
		var gp := g.global_position
		var d := Vector2(c.x - gp.x, c.z - gp.z)
		if enigma.piatto_giu(i) or (d.length() < 0.1 and enigma.velocita(i) < 0.05):
			break
		var dir := d.normalized()
		var dietro := clampf(1.6 + d.length() * 0.3, 1.8, 3.0)
		var stand := Vector3(gp.x - dir.x * dietro, 0.0, gp.z - dir.y * dietro)
		stand.x = clampf(stand.x, -6.4, 6.4)
		stand.z = clampf(stand.z, -4.0, 3.9)
		await _cammina([stand])
		await _riempi()
		var mira := func() -> Vector3:
			var q := g.global_position
			return q + Vector3(0, EnigmaGiocattoli.ALTEZZE[i] * 0.75 + 0.1 * Vector2(q.x - p.global_position.x, q.z - p.global_position.z).length(), 0)
		await _guarda(mira.call(), 0.45)
		var v_obiettivo := clampf(d.length() * 0.8, 0.3, 1.8)
		Input.action_press(&"spray")
		for f in 70:
			p.look_at_point(mira.call())
			await get_tree().physics_frame
			if f > 8 and enigma.velocita(i) >= v_obiettivo:
				break
		Input.action_release(&"spray")
		for f in 75:
			await get_tree().physics_frame
			if enigma.velocita(i) < 0.05:
				break
		if colpo == 0 and i == 0:
			_scatto("giocattoli_spinta")
	print("  giocattolo %d a %.2f m dal suo cerchio" % [i, Vector2(c.x - g.global_position.x, c.z - g.global_position.z).length()])


## Svuota la piscina da dentro, vicino al muro est: aspira davanti e spara fuori, oltre il muro.
func _svuota() -> void:
	await _cammina([Vector3(5.3, 0, 1.2)])
	var pieni := 0
	while vasca.fill > 0.001 and pieni < 12:
		if vasca.fill > 0.0:
			await _guarda(Vector3(4.2, vasca.get_surface_global_y(), 1.3), 0.5)
			Input.action_press(&"suck")
			for k in 30 * 6:
				if p.water_pack.tank_amount >= p.water_pack.tank_capacity - 0.01 or vasca.fill <= 0.001 \
						or bool(piscina.get(&"scola")):
					break
				await get_tree().physics_frame
			Input.action_release(&"suck")
		pieni += 1
		await _guarda(Vector3(12.0, 2.2, 1.2), 0.6)
		Input.action_press(&"spray")
		for k in 30 * 5:
			if p.water_pack.tank_amount <= 0.05:
				break
			await get_tree().physics_frame
		Input.action_release(&"spray")
	for k in 120:
		if vasca.fill <= 0.0:
			break
		await get_tree().physics_frame
	print("  svuotata in %d pieni" % pieni)


# --- Scatti e pipeline -----------------------------------------------------------------------------------------------

func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))
	print("SCATTO ", nome)


func _conta_pipeline(fase: String) -> void:
	var ora := {}
	var nuove := []
	for k in MONITOR:
		ora[k] = int(Performance.get_monitor(MONITOR[k]))
		if not _pipeline.is_empty():
			nuove.append("%s %d" % [k, ora[k] - int(_pipeline[k])])
	print("PIPELINE %s (%.1f s di gioco): %s" % [fase, Engine.get_physics_frames() / float(Engine.physics_ticks_per_second),
		", ".join(nuove) if not nuove.is_empty() else str(ora)])
	_pipeline = ora
