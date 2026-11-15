extends Node
## Collaudo (squadra collaudo): una partita intera del tunnel del viaggio sottomarino col giocatore vero e gli input
## simulati, senza teletrasporti dopo SB1, nella scena di prova (scenes/test/sottomarino_prova.tscn): SB1, la scaletta,
## la porta, la riemersione, la corsa lungo tutta la strada coi gommoni che dondolano, le gallerie accovacciati, il getto
## in faccia quando lei è vicina, l'approdo, il portello col volantino, lo schianto, il nero e la scritta.
## Ogni [constant OGNI] fotogrammi uno scatto dalla camera del giocatore (con l'HUD) e una riga di registro.
## Uso (sotto il lock, col renderer vero):
##   xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --fixed-fps 60 \
##       --script res://tests/run.gd -- res://tests/collaudo/partita_tunnel.gd <cartella>
## Con DA_TUNNEL=1 si salta SB1 e la scaletta (si parte nel tunnel davanti alla porta).

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"
const OGNI := 30
const SPRUZZA_SOTTO := 6.5
## sotto questa distanza non ci si gira a spruzzare (non c'è il tempo di mirare): si corre e basta. Mentre spruzza
## il giocatore guarda lei e indietreggia (non le va incontro)
const SPRUZZA_SOPRA := 5.5

var level: Node
var ins: SalaInseguimento
var sott: SalaSottomarino
var p: Player
var cart := ""
var _log: FileAccess
var fase := "inizio"
var registra := false
var _f := 0
var _n := 0
var s_g := 0.0
var lato_att := -1.0
var morsi := 0
var prese := 0
var respinte := 0
var ripartenze := 0
var cadute := 0
var getti := 0
var _ultimo_getto := -100.0
var _ultima_occhiata := 0.0
var fine := false
var _riemersa_t := 0.0
var fermata := false
var prese_virtuali := 0


func _ready() -> void:
	_run.call_deferred()


func _t() -> float:
	return Engine.get_physics_frames() / 60.0


func _physics_process(_d: float) -> void:
	if not registra or p == null or not is_instance_valid(p):
		return
	_f += 1
	# il 3D si disegna solo nei fotogrammi prima degli scatti (la fisica e la logica girano sempre): sul renderer
	# software la partita va molte volte più svelta
	if OS.get_environment("SEMPRE_3D") == "":
		get_viewport().disable_3d = (_f % OGNI) < OGNI - 3 and not _forza_3d
	if _f % OGNI == 0:
		_scatto("")
	# con SENZA_PRESA=1 lei non prende: quando arriva alla distanza della presa si segna una presa "virtuale" (dove e
	# in che fase) e lei torna a 18 m, come se si ripartisse da lì; così una partita sola trova tutti i punti
	if OS.get_environment("SENZA_PRESA") != "" and sott and sott.lei_stato == SalaSottomarino.Lei.INSEGUE:
		var gap := sott._s_bersaglio - sott.lei_s
		if gap <= 2.5:
			prese_virtuali += 1
			_evento("PRESA VIRTUALE %d a s %.1f in fase %s (lato %.0f, acqua %s, accovacciato %s)" % [prese_virtuali, s_g, fase, lato_att, p.global_position.y < sott.piano - 0.2, p.is_crouching])
			sott.lei_s = sott._s_bersaglio - 18.0


var _forza_3d := false


## Prima di uno scatto fuori ritmo: il 3D acceso per qualche fotogramma.
func _accendi() -> void:
	_forza_3d = true
	get_viewport().disable_3d = false
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _scatto(extra: String) -> void:
	if extra != "" and get_viewport().disable_3d:
		await _accendi()
		_forza_3d = false
	_n += 1
	var nome := "%04d_%s%s" % [_n, fase, ("_" + extra) if extra != "" else ""]
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_jpg(cart.path_join(nome + ".jpg"), 0.8)
	var pr: Array = sott.proietta_vicino(p.global_position, s_g) if sott else [0.0, 0.0]
	var gap := sott._s_bersaglio - sott.lei_s if sott else 0.0
	var acqua := p.global_position.y < sott.piano - 0.2 if sott else false
	_log.store_line("%s t %.2f s %.1f lato %.2f y %.2f suolo %s acqua %s acc %s lei %s gap %.1f morsi %d prese %d respinte %d getti %d cadute %d serb %.1f" % [
			nome, _t(), float(pr[0]), float(pr[1]), p.global_position.y, p.is_on_floor(), acqua, p.is_crouching,
			SalaSottomarino.Lei.keys()[sott.lei_stato] if sott else "-", gap, morsi, prese, respinte, getti, cadute,
			p.water_pack.tank_amount if p.water_pack else -1.0])
	_log.flush()


func _evento(cosa: String) -> void:
	_log.store_line("EVENTO t %.2f %s: %s" % [_t(), fase, cosa])
	_log.flush()
	print("PARTITA: t %.1f %s: %s" % [_t(), fase, cosa])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _lascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"spray", &"sprint", &"jump", &"crouch", &"interact"]:
		if InputMap.has_action(a):
			Input.action_release(a)


static func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


static func _piano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _guarda_verso(q: Vector3, pitch := 0.0) -> void:
	var d := q - p.global_position
	if Vector2(d.x, d.z).length() > 0.05:
		p.set_look(_yaw(Vector3(d.x, 0.0, d.z)), pitch)


func _run() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	_log = FileAccess.open(cart.path_join("registro.txt"), FileAccess.WRITE)
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	level = get_tree().current_scene
	p = GameState.player
	ins = level.get_node("SalaInseguimento") as SalaInseguimento
	sott = level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	if OS.get_environment("SENZA_PRESA") != "":
		sott.distanza_presa = -100.0
	ins.sb1_finito.connect(sott.attiva_tunnel)
	sott.lei_morde.connect(func(): morsi += 1)
	sott.lei_respinta.connect(func():
		respinte += 1
		_evento("lei respinta dal getto (gap %.1f)" % (sott._s_bersaglio - sott.lei_s)))
	sott.giocatore_preso.connect(func():
		prese += 1
		_evento("PRESO da lei a s %.1f" % s_g))
	sott.lei_riemersa.connect(func(): _evento("lei riemerge dalla presa"))
	sott.prima_curva_passata.connect(func():
		_evento("prima curva passata: le condotte si liberano, come nel gioco")
		if is_instance_valid(ins):
			ins.queue_free())
	sott.fine_demo.connect(func():
		fine = true
		_evento("fine_demo"))
	GameState.player_respawned.connect(func():
		ripartenze += 1
		_evento("ripartenza dal checkpoint (%s)" % str(GameState.player.global_position if GameState.player else Vector3.ZERO)))
	p.water_pack.set_equipped(true, false)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	registra = true
	if OS.get_environment("DA_TUNNEL") == "":
		await _sb1_e_scaletta()
	else:
		var porta := SalaInseguimento.b(ins.dati["porta"]["uscita"])
		p.teleport(porta + Vector3.UP * 0.05)
		ins.sb1_finito.emit()
		await _frames(5)
	await _entra_e_riemersione()
	await _corsa()
	if fermata:
		return
	await _approdo()
	await _finale()
	_evento("FINE PARTITA: morsi %d prese %d (virtuali %d) respinte %d getti %d cadute %d ripartenze %d" % [morsi, prese, prese_virtuali, respinte, getti, cadute, ripartenze])
	_log.close()
	get_tree().quit()


# --- SB1 e la scaletta -------------------------------------------------------------------------------------------

func _sb1_e_scaletta() -> void:
	fase = "sb1"
	var finito := [false]
	ins.sb1_finito.connect(func(): finito[0] = true)
	ins.capitolo_finito.connect(func(): _evento("NERO del capitolo (non dovrebbe esserci)"))
	ins.cala_grata()
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	var piede := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z0"])])
	var cima := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z1"])])
	p.teleport(SalaInseguimento.b([float(sc["x"]) + 3.0, float(sc["y"]), float(sc["z0"]) + 0.3]))
	await _frames(3)
	var t0 := _t()
	ins.inizia_sb1()
	while not finito[0] and _t() - t0 < 25.0:
		await _frames(1)
	_evento("SB1 finito dopo %.1f s, comandi %s" % [_t() - t0, p.input_enabled])
	# il giocatore guarda intorno: la scaletta col faro e la porta in cima
	fase = "dopo_sb1"
	_guarda_verso((piede + cima) * 0.5, 0.15)
	await _frames(40)
	await _scatto("guarda_scaletta")
	fase = "scaletta"
	Input.action_press(&"move_forward")
	t0 = _t()
	while _piano(p.global_position).distance_to(_piano(piede)) > 0.7 and _t() - t0 < 10.0:
		_guarda_verso(piede)
		await _frames(1)
	# su per la scaletta: guardando in alto verso la cima e avanti
	t0 = _t()
	var y0 := p.global_position.y
	# (salendo si guarda la porta: guardando la scaletta in cima ci si incastra, difetto T1 del collaudo)
	var uscita0 := SalaInseguimento.b(ins.dati["porta"]["uscita"])
	while _t() - t0 < 15.0 and not (p.ladder == null and p.global_position.y > cima.y - 0.2 and _t() - t0 > 1.0):
		_guarda_verso(uscita0, 0.0)
		await _frames(1)
	_lascia()
	_evento("scaletta: da y %.2f a %.2f (cima %.2f) in %.1f s, sulla scala %s" % [y0, p.global_position.y, cima.y, _t() - t0, p.ladder != null])
	await _frames(10)
	fase = "porta"
	var porta := SalaInseguimento.b(ins.dati["porta"]["pos"])
	var uscita := SalaInseguimento.b(ins.dati["porta"]["uscita"])
	Input.action_press(&"move_forward")
	t0 = _t()
	for q in [porta, uscita]:
		while _piano(p.global_position).distance_to(_piano(q)) > 0.5 and _t() - t0 < 12.0:
			_guarda_verso(q)
			await _frames(1)
	_lascia()
	_evento("alla porta in cima: %s (dist dall'uscita %.2f)" % [str(p.global_position), _piano(p.global_position).distance_to(_piano(uscita))])
	if _piano(p.global_position).distance_to(_piano(uscita)) > 1.0:
		_evento("INCASTRATO in cima alla scaletta (T1): si riparte dall'uscita della porta")
		p.teleport(uscita + Vector3.UP * 0.05)
		await _frames(10)


func _entra_e_riemersione() -> void:
	fase = "entra"
	var dentro := sott.punto(SalaSottomarino.PORTA_S) - sott.destra(SalaSottomarino.PORTA_S) * (sott.canale + 1.3)
	Input.action_press(&"move_forward")
	var t0 := _t()
	while _piano(p.global_position).distance_to(_piano(dentro)) > 0.6 and _t() - t0 < 8.0:
		_guarda_verso(dentro)
		await _frames(1)
	_lascia()
	_evento("dentro il tunnel: %s y %.2f (piano %.2f)" % [str(p.global_position), p.global_position.y, sott.piano])
	fase = "riemersione"
	p.look_at_point(sott.punto(-1.0) + Vector3.UP * 2.0)
	t0 = _t()
	while sott.lei_stato == SalaSottomarino.Lei.VIA and _t() - t0 < 6.0:
		await _frames(1)
	await _frames(20)
	await _scatto("lei_dalla_porta")
	_riemersa_t = _t()
	s_g = SalaSottomarino.PORTA_S


# --- la corsa ------------------------------------------------------------------------------------------------------

func _gruppi() -> Array:
	var out: Array = []
	var k := 0
	for att in sott.attraversamenti:
		var n: int = (att[1] as Array).size() - 1
		var lato := 1.0
		for o in sott.ostacoli:
			if absf(float(o["s"]) - float(att[0])) < 0.01:
				lato = float(o["lato"])
		out.append({"s": float(att[0]), "lato": lato, "gommoni": sott._gommoni.slice(k, k + n)})
		k += n
	return out


func _corsa() -> void:
	fase = "corsa"
	var gruppi := _gruppi()
	var gallerie := sott.ostacoli.filter(func(o): return o["tipo"] == "galleria")
	var L := sott.lunghezza()
	var s_scala := L - SalaSottomarino.BALLATOIO - 12 * 0.32 - 1.5
	var t0 := _t()
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	while s_g < s_scala and _t() - t0 < 400.0:
		await _frames(1)
		if GameState.is_dying or not p.input_enabled or sott.lei_stato == SalaSottomarino.Lei.PRESA:
			_lascia()
			_evento("PRESO a s %.1f: nella scena di prova la ripartenza ricarica la scena senza tunnel, la partita si ferma qui" % s_g)
			for i in 40:
				await _frames(1)
			fermata = true
			_log.close()
			get_tree().quit()
			return
		var pr: Array = sott.proietta_vicino(p.global_position, s_g)
		s_g = float(pr[0])
		var u := float(pr[1])
		if absf(u) > sott.canale:
			lato_att = signf(u)
		# il getto in faccia quando lei è vicina
		var gap := sott._s_bersaglio - sott.lei_s
		if sott.lei_stato == SalaSottomarino.Lei.INSEGUE and sott.lei_tunnel.stato == LeiTunnel.Stato.INSEGUE and gap < SPRUZZA_SOTTO and gap > SPRUZZA_SOPRA and _t() - _ultimo_getto > 3.0 and _t() - _riemersa_t > 3.0:
			await _getto()
			continue
		# un'occhiata indietro ogni tanto (lei dietro, a bocca aperta)
		if _t() - _ultima_occhiata > 9.0:
			await _occhiata()
			continue
		# l'attraversamento davanti all'ostacolo del lato dove si è
		var fatto := false
		for gr in gruppi:
			if gr.get("fatto", false) or float(gr["lato"]) != lato_att:
				continue
			var gs: Array = gr["gommoni"]
			var s1: float = float(sott.proietta((gs[0]["corpo"] as Node3D).global_position)[0])
			if s_g > s1 - 3.5 and s_g < float(gr["s"]):
				gr["fatto"] = true
				fase = "gommoni_%d" % int(gr["s"])
				await _attraversa(gr)
				fase = "corsa"
				fatto = true
				break
		if fatto:
			Input.action_press(&"move_forward")
			Input.action_press(&"sprint")
			continue
		for g in gallerie:
			if g.get("fatto", false):
				continue
			var bocca0: float = float(g["s"]) - SalaSottomarino.GALLERIA_BOCCA * 0.5
			if s_g > bocca0 - 6.0 and s_g < float(g["s"]):
				g["fatto"] = true
				fase = "galleria_%d" % int(g["s"])
				await _galleria(g)
				fase = "corsa"
				fatto = true
				break
		if fatto:
			Input.action_press(&"move_forward")
			Input.action_press(&"sprint")
			continue
		# avanti lungo la banchina
		var q := sott.punto(s_g + 5.0) + sott.destra(s_g + 5.0) * lato_att * (sott.canale + 1.3)
		if p.global_position.y < sott.piano - 0.2:
			# nell'acqua: verso la riva del lato dove si va, saltando dal gradino
			q = sott.punto(s_g + 2.0) + sott.destra(s_g + 2.0) * lato_att * (sott.canale + 1.0)
			if Engine.get_physics_frames() % 20 == 0:
				Input.action_press(&"jump")
			elif Engine.get_physics_frames() % 20 == 4:
				Input.action_release(&"jump")
		_guarda_verso(q)
	_lascia()
	_evento("fine corsa a s %.1f (scala a %.1f), lato %.0f, in %.0f s" % [s_g, s_scala, lato_att, _t() - t0])


func _aspetta_ripartenza() -> void:
	var t0 := _t()
	while (GameState.is_dying or not p.input_enabled) and _t() - t0 < 20.0:
		await _frames(1)
		if not is_instance_valid(p):
			p = GameState.player
	p = GameState.player
	await _frames(20)
	var pr: Array = sott.proietta_vicino(p.global_position, 0.0, 600.0)
	s_g = float(pr[0])
	lato_att = signf(float(pr[1])) if absf(float(pr[1])) > 0.1 else lato_att
	_evento("ripartito a s %.1f lato %.0f dopo %.1f s" % [s_g, lato_att, _t() - t0])


func _getto() -> void:
	var prima := fase
	fase = "getto"
	getti += 1
	_ultimo_getto = _t()
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	Input.action_press(&"move_back")
	var occhio: Vector3 = sott.lei.get_eye_position() if sott.lei and sott.lei.has_method(&"get_eye_position") else sott.punto(sott.lei_s) + Vector3.UP * 2.0
	p.look_at_point(occhio)
	await _frames(6)
	await _scatto("mira")
	Input.action_press(&"spray")
	for i in 40:
		occhio = sott.lei.get_eye_position() if sott.lei and sott.lei.has_method(&"get_eye_position") else occhio
		p.look_at_point(occhio)
		await _frames(1)
	await _scatto("getto")
	Input.action_release(&"spray")
	await _frames(10)
	await _scatto("dopo_getto")
	fase = prima
	Input.action_release(&"move_back")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")


func _occhiata() -> void:
	var prima := fase
	fase = "occhiata"
	_ultima_occhiata = _t()
	var dietro := sott.punto(maxf(s_g - 10.0, -1.0)) + Vector3.UP * 2.5
	var yaw0 := p.yaw
	p.look_at_point(dietro)
	await _frames(4)
	await _scatto("indietro")
	p.set_look(yaw0, 0.0)
	fase = prima


# --- i gommoni -----------------------------------------------------------------------------------------------------

func _attraversa(gr: Dictionary) -> void:
	var gs: Array = gr["gommoni"]
	var da := lato_att
	var rg := SalaSottomarino.GOMMONE_R + SalaSottomarino.GOMMONE_T
	var tappe: Array = []
	for g in gs:
		tappe.append(g["corpo"])
	tappe.append(null)
	var k := 0
	var fermo := 0
	var t0 := _t()
	var in_acqua := false
	Input.action_press(&"move_forward")
	Input.action_release(&"sprint")
	if OS.get_environment("SALTI_DI_CORSA") != "":
		Input.action_press(&"sprint")
	await _scatto("prima")
	while _t() - t0 < 30.0:
		await get_tree().physics_frame
		if GameState.is_dying or not p.input_enabled:
			_lascia()
			_evento("preso durante l'attraversamento a %.0f" % float(gr["s"]))
			await _aspetta_ripartenza()
			return
		var pos := p.global_position
		if pos.y < sott.acqua - 0.05 and not in_acqua:
			in_acqua = true
			cadute += 1
			_evento("CADUTO in acqua all'attraversamento %.0f (tappa %d)" % [float(gr["s"]), k])
			await _scatto("caduto")
		if in_acqua:
			# dall'acqua: verso l'altra banchina, col gradino e i salti
			var pr0: Array = sott.proietta(pos)
			var b0 := sott.punto(float(pr0[0]) + 1.0) + sott.destra(float(pr0[0]) + 1.0) * -da * (sott.canale + 1.0)
			_guarda_verso(b0)
			if Engine.get_physics_frames() % 20 < 4:
				Input.action_press(&"jump")
			else:
				Input.action_release(&"jump")
			if p.is_on_floor() and pos.y > sott.piano - 0.05:
				_evento("risalito sulla banchina dopo la caduta (%.1f s)" % (_t() - t0))
				lato_att = signf(float(sott.proietta(pos)[1]))
				break
			continue
		var bersaglio: Vector3
		if tappe[k] == null:
			var pr: Array = sott.proietta(pos)
			bersaglio = sott.punto(float(pr[0])) + sott.destra(float(pr[0])) * -da * (sott.canale + 1.2)
		else:
			bersaglio = (tappe[k] as Node3D).global_position
		var dir := _piano(bersaglio - pos)
		if dir.length() > 0.05:
			p.set_look(_yaw(Vector3(dir.x, 0.0, dir.y)), -0.15)
		var su: Node3D = null
		for g in gs:
			if _piano(pos).distance_to(_piano((g["corpo"] as Node3D).global_position)) < rg + 0.15 and pos.y > sott.acqua:
				su = g["corpo"]
		if tappe[k] != null and su == tappe[k] and p.is_on_floor():
			k += 1
			await _scatto("su_gommone_%d" % k)
			continue
		if tappe[k] == null and p.is_on_floor() and pos.y > sott.piano - 0.05 and signf(float(sott.proietta(pos)[1])) == -da \
				and absf(float(sott.proietta(pos)[1])) > sott.canale + 0.3:
			lato_att = -da
			_evento("attraversamento %.0f fatto in %.1f s" % [float(gr["s"]), _t() - t0])
			await _scatto("dall_altra_parte")
			break
		var al_bordo := false
		if su == null and p.is_on_floor():
			al_bordo = absf(float(sott.proietta(pos)[1])) < sott.canale + 0.25
		elif su != null and p.is_on_floor():
			al_bordo = _piano(pos).distance_to(_piano(su.global_position)) > rg - 0.3 and \
					(_piano(pos) - _piano(su.global_position)).dot(dir) > 0.0
		if p.is_on_floor() and Vector2(p.velocity.x, p.velocity.z).length() < 0.4:
			fermo += 1
		else:
			fermo = 0
		if (al_bordo or fermo >= 6) and p.is_on_floor():
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")
	_lascia()


# --- le gallerie ---------------------------------------------------------------------------------------------------

func _galleria(gal: Dictionary) -> void:
	var accovacciato := false
	var t0 := _t()
	var fine_g: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA + 1.5
	var bocca0: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA * 0.5
	var bocca1: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA * 0.5
	var u_gal := sott.muro + sott.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
	Input.action_press(&"move_forward")
	Input.action_release(&"sprint")
	await _scatto("bocca")
	var fermo_da := _t()
	var ultima := p.global_position
	var sblocchi := 0
	while s_g < fine_g and _t() - t0 < 40.0:
		# incastrati più di 1 s (lo spigolo della bocca, difetto G1): un passo di lato, come farebbe una persona
		if p.global_position.distance_to(ultima) > 0.05:
			ultima = p.global_position
			fermo_da = _t()
		elif _t() - fermo_da > 1.0:
			sblocchi += 1
			_evento("galleria %.0f: INCASTRATO a s %.2f (lato %.2f) da 1 s, un passo a %s" % [float(gal["s"]), s_g, float(sott.proietta_vicino(p.global_position, s_g)[1]), "destra" if sblocchi % 2 == 1 else "sinistra"])
			var lato_passo := &"move_right" if sblocchi % 2 == 1 else &"move_left"
			Input.action_press(lato_passo)
			await _frames(30)
			Input.action_release(lato_passo)
			fermo_da = _t()
		if GameState.is_dying or not p.input_enabled:
			_lascia()
			_evento("preso nella galleria %.0f" % float(gal["s"]))
			await _aspetta_ripartenza()
			return
		s_g = float(sott.proietta_vicino(p.global_position, s_g)[0])
		var s_q := s_g + 2.0
		var u := sott.muro - 0.6
		if s_g < bocca0 - 0.3:
			s_q = bocca0
			u = u_gal
		elif s_g < bocca1 - 0.3:
			s_q = minf(s_g + 2.0, bocca1)
			u = u_gal
		var q := sott.punto(s_q) + sott.destra(s_q) * float(gal["lato"]) * u
		_guarda_verso(q)
		if sott.in_tubo(p.global_position):
			Input.action_release(&"crouch")
			if p.is_crouching:
				accovacciato = true
		elif s_g > bocca0 - 1.5 and s_g < bocca0 + 1.0:
			Input.action_press(&"crouch")
		else:
			Input.action_release(&"crouch")
		await _frames(1)
	_lascia()
	lato_att = float(gal["lato"])
	_evento("galleria %.0f: passata %s, accovacciati %s, in %.1f s" % [float(gal["s"]), s_g >= fine_g, accovacciato, _t() - t0])


# --- l'approdo e il finale -----------------------------------------------------------------------------------------

func _approdo() -> void:
	fase = "approdo"
	var L := sott.lunghezza()
	var pL := sott.punto(L)
	var rL := sott.destra(L)
	var dL := sott.direzione(L)
	var sg := sott.piano + SalaSottomarino.SOGLIA
	var s_scala := L - SalaSottomarino.BALLATOIO - 12 * 0.32 - 1.5
	var t0 := _t()
	if lato_att > 0.0:
		# dalla banchina destra alla sinistra: nel canale, a guado, e su dal gradino
		_evento("all'approdo sulla banchina DESTRA: la scala è a sinistra, si passa nel canale")
		var q0 := sott.punto(s_scala) - sott.destra(s_scala) * (sott.canale + 1.0)
		Input.action_press(&"move_forward")
		while _t() - t0 < 25.0:
			var pos := p.global_position
			if p.is_on_floor() and pos.y > sott.piano - 0.05 and float(sott.proietta(pos)[1]) < -sott.canale - 0.3:
				break
			_guarda_verso(q0)
			if Engine.get_physics_frames() % 20 < 4:
				Input.action_press(&"jump")
			else:
				Input.action_release(&"jump")
			await _frames(1)
		_lascia()
		_evento("passato a sinistra in %.1f s (y %.2f)" % [_t() - t0, p.global_position.y])
	var via := [
		sott.punto(s_scala) - sott.destra(s_scala) * (sott.muro - 0.5) + Vector3.UP * (sott.piano - sott.acqua),
		pL - dL * 0.5 - rL * (sott.muro - 0.5) + Vector3.UP * (sg - sott.acqua),
		pL - dL * 0.5 + rL * (SalaSottomarino.PONTILE_FINO - 0.3) + Vector3.UP * (sg - sott.acqua),
		pL - dL * 0.36 + rL * (SalaSottomarino.PORTA_SX + 0.35) + Vector3.UP * (sg - sott.acqua),
		pL + dL * 1.2 + rL * (SalaSottomarino.PORTA_SX + 0.45) + Vector3.UP * (sg - sott.acqua),
	]
	Input.action_press(&"move_forward")
	var tappa := 0
	t0 = _t()
	while tappa < via.size() and _t() - t0 < 40.0:
		if GameState.is_dying or not p.input_enabled:
			_lascia()
			_evento("preso all'approdo")
			await _aspetta_ripartenza()
			return
		var q: Vector3 = via[tappa]
		if _piano(p.global_position).distance_to(_piano(q)) < 0.3:
			tappa += 1
			await _scatto("tappa_%d" % tappa)
			continue
		_guarda_verso(q)
		await _frames(1)
	_lascia()
	_evento("approdo: tappe %d di %d, in %.1f s, y %.2f (soglia %.2f)" % [tappa, via.size(), _t() - t0, p.global_position.y, sg])


func _finale() -> void:
	fase = "portello"
	var L := sott.lunghezza()
	var verso := sott.punto(L) + Vector3.UP * (sott.piano - sott.acqua + SalaSottomarino.SOGLIA + 1.0)
	p.look_at_point(verso)
	await _frames(10)
	await _scatto("davanti_al_volantino")
	Input.action_press(&"interact")
	await _frames(3)
	Input.action_release(&"interact")
	var t0 := _t()
	fase = "schianto"
	while not fine and _t() - t0 < 15.0:
		await _frames(1)
	_evento("fine_demo dopo %.1f s: %s" % [_t() - t0, fine])
	fase = "nero"
	t0 = _t()
	while _t() - t0 < 14.0:
		await _frames(1)
	var sc := get_tree().current_scene
	_evento("14 s dopo la fine: scena %s" % (sc.scene_file_path if sc else "niente"))
