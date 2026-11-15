extends Node
## Collaudo 0.4.0, zona C (il tunnel con la carica): la corsa del tunnel col giocatore vero e gli input simulati (come
## partita_tunnel.gd: banchine, gommoni, gallerie accovacciati), con la carica di lei. CT:.
## MODO=f9 (di solito, senza schermo): F9 «Tunnel sottomarino» nel gioco vero; le morti ripartono dal checkpoint del
##   gioco e la corsa continua da lì. MODO=prova (col renderer vero): la scena di prova del tunnel, con gli scatti
##   (ogni [constant OGNI] fotogrammi e nei momenti della carica: carica, scatto, presa, respinta), finché non prende.
## POLITICA: mai (non spruzza mai: la finestra, lo scatto, la presa, la ripartenza e la finestra dopo), colpisci (alla
##   carica, dopo REAZIONE s, si gira e spruzza sull'occhio finché non è respinta; con meno di RICARICA_SOTTO litri
##   ricarica dal canale quando lei è lontana), prima_mai (la prima carica non la colpisce e muore, poi colpisci).
## Ogni carica: s, distanza, se il giocatore è sulla banchina, quanto lontano dall'attraversamento e dalla galleria più
## vicini; la finestra vera (carica -> scatto o respinta); dove torna dopo la respinta (+1, +2, +3 s); lo zaino.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/carica_tunnel.gd <cartella> [secondi]

const PROVA := "res://scenes/test/sottomarino_prova.tscn"
const OGNI := 30
const RICARICA_SOTTO := 5.0

var level: Node
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
var prese := 0
var respinte := 0
var cariche := 0
var scatti := 0
var morti := 0
var cadute := 0
var getti := 0
var modo := "f9"
var politica := "mai"
var reazione := 1.0
var spia: Node
var _carica_t := -1.0
var _carica_n := 0
var _in_carica := false
var _resp_t := -1.0
var _riemersa_t := 0.0
var _litri_prima := 0.0
var fermata := false
var _comp := {}
var _ultimo_s := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _t() -> float:
	return Engine.get_physics_frames() / 60.0


func _pipeline() -> int:
	var n := 0
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE,
			Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += int(Performance.get_monitor(m))
	return n


func _physics_process(_d: float) -> void:
	if not registra or p == null or not is_instance_valid(p) or sott == null or not is_instance_valid(sott):
		return
	_f += 1
	if modo == "prova":
		if OS.get_environment("SEMPRE_3D") == "":
			get_viewport().disable_3d = (_f % OGNI) < OGNI - 3 and not _forza_3d
		if _f % OGNI == 0:
			_scatto("")
	if _f % 60 == 0:
		var st: Object = null
		for x in get_node(^"/root/Audio").get(&"_attivi"):
			if x is Object and x.get(&"n") == sott.lei:
				st = x
		var ap: AnimationPlayer = sott.lei.find_child("AnimationPlayer", true, false) as AnimationPlayer if sott.lei else null
		_log.store_line("SEC t %.1f s %.1f gap %.2f lei %s/%s anim %s vis %s zitto %s statua %s canto_t %s canta %s sente %s" % [_t(), s_g,
				sott._s_bersaglio - sott.lei_s, SalaSottomarino.Lei.keys()[sott.lei_stato], LeiTunnel.Stato.keys()[sott.lei_tunnel.stato] if sott.lei_tunnel else "-",
				ap.current_animation if ap and ap.is_playing() else "-", sott.lei.is_visible_in_tree() if sott.lei else null,
				sott.lei.has_meta(&"canto_zitto") if sott.lei else null, st != null, st.get(&"canto_t") if st else null,
				st.call(&"canta") if st else null, spia.call(&"adesso")])
		var cn: Node = st.get(&"canto") if st else null
		if cn and is_instance_valid(cn):
			_log.store_line("SEC   canto: %s playing %s finto %s stream %s vol %.1f pos %.2f in riserva %s riproduzione %s" % [cn.get_class(), cn.get(&"playing"),
					cn.has_meta(&"finto_fino"), (cn.get(&"stream") as AudioStream).resource_path if cn.get(&"stream") else "-", float(cn.get(&"volume_db")),
					float(cn.call(&"get_playback_position")), (get_node(^"/root/Audio").get(&"_pool_3d") as Array).has(cn), AudioLoop.riproduzione_attiva()])
	if _resp_t >= 0.0:
		var dt := _t() - _resp_t
		for k in [1.0, 2.0, 3.0]:
			if dt >= k and not _comp.has("r%d_%d" % [respinte, int(k)]):
				_comp["r%d_%d" % [respinte, int(k)]] = true
				_evento("dopo la respinta %d, +%.0f s: distanza %.1f m, stato %s" % [respinte, k, sott._s_bersaglio - sott.lei_s, SalaSottomarino.Lei.keys()[sott.lei_stato]])


var _forza_3d := false


func _accendi() -> void:
	_forza_3d = true
	get_viewport().disable_3d = false
	for i in 3:
		await get_tree().process_frame


func _scatto(extra: String) -> void:
	if modo != "prova":
		return
	if extra != "" and get_viewport().disable_3d:
		await _accendi()
		_forza_3d = false
	_n += 1
	var nome := "%04d_%s%s" % [_n, fase, ("_" + extra) if extra != "" else ""]
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_jpg(cart.path_join(nome + ".jpg"), 0.8)
	_riga(nome)


func _riga(nome: String) -> void:
	var pr: Array = sott.proietta_vicino(p.global_position, s_g) if sott else [0.0, 0.0]
	var gap := sott._s_bersaglio - sott.lei_s if sott else 0.0
	_log.store_line("%s t %.2f s %.1f lato %.2f y %.2f acqua %s acc %s lei %s/%s gap %.1f cariche %d respinte %d prese %d serb %.1f pipeline %d" % [
			nome, _t(), float(pr[0]), float(pr[1]), p.global_position.y, p.global_position.y < sott.piano - 0.2, p.is_crouching,
			SalaSottomarino.Lei.keys()[sott.lei_stato], LeiTunnel.Stato.keys()[sott.lei_tunnel.stato] if sott.lei_tunnel else "-", gap,
			cariche, respinte, prese, p.water_pack.tank_amount if p.water_pack else -1.0, _pipeline()])
	_log.flush()


func _evento(cosa: String) -> void:
	_log.store_line("EVENTO t %.2f %s: %s" % [_t(), fase, cosa])
	_log.flush()
	print("CT: t %.2f %s: %s" % [_t(), fase, cosa])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Dove sono gli attraversamenti (inizio e fine, s) e le gallerie: la distanza (in s) del giocatore dal più vicino.
func _vicino_passaggi(s: float) -> String:
	var d_att := INF
	for gr in _gruppi():
		var gs: Array = gr["gommoni"]
		if gs.is_empty():
			continue
		var s0 := float(sott.proietta((gs[0]["corpo"] as Node3D).global_position)[0])
		var s1 := float(sott.proietta((gs[-1]["corpo"] as Node3D).global_position)[0])
		d_att = minf(d_att, 0.0 if (s >= minf(s0, s1) - 1.0 and s <= maxf(s0, s1) + 1.0) else minf(absf(s - s0), absf(s - s1)))
	var d_gal := INF
	for o in sott.ostacoli:
		if o["tipo"] != "galleria":
			continue
		var a := float(o["s"]) - SalaSottomarino.GALLERIA_BOCCA * 0.5
		var b := float(o["s"]) + float(o["lungo"]) + SalaSottomarino.GALLERIA_BOCCA * 0.5
		d_gal = minf(d_gal, 0.0 if (s >= a and s <= b) else minf(absf(s - a), absf(s - b)))
	return "dai gommoni %.1f m, dalla galleria %.1f m" % [d_att, d_gal]


func _collega() -> void:
	sott.lei_carica.connect(func():
		cariche += 1
		_carica_n += 1
		_in_carica = true
		_carica_t = _t()
		var gap := sott._s_bersaglio - sott.lei_s
		_comp["pip_carica"] = _pipeline()
		_evento("CARICA %d (in questa vita %d): s %.1f, distanza %.2f m, sulla banchina %s, nel passaggio %s, %s, finestra %.2f s, prima respinta fatta %s, %.1f s dalla riemersione, canto %s" % [
				cariche, _carica_n, s_g, gap, sott.su_banchina(p.global_position), sott.in_tubo(p.global_position), _vicino_passaggi(s_g),
				float(sott.get(&"_finestra")), preload("res://scripts/game/stato_tunnel.gd").prima_respinta_fatta, _t() - _riemersa_t, spia.call(&"adesso")])
		_scatto("carica"))
	sott.lei_scatta.connect(func():
		scatti += 1
		_in_carica = false
		_evento("SCATTO dopo %.2f s di carica: s %.1f, distanza %.2f m, sulla banchina %s, %s, canto %s" % [_t() - _carica_t, s_g,
				sott._s_bersaglio - sott.lei_s, sott.su_banchina(p.global_position), _vicino_passaggi(s_g), spia.call(&"adesso")])
		_scatto("scatto"))
	sott.lei_respinta.connect(func():
		respinte += 1
		var da := _t() - _carica_t if _in_carica else -1.0
		_in_carica = false
		_resp_t = _t()
		_evento("RESPINTA %d (%s): distanza %.1f m, zaino %.1f l (spesi %.1f)" % [respinte, ("%.2f s dopo la carica" % da) if da >= 0.0 else "non in carica",
				sott._s_bersaglio - sott.lei_s, p.water_pack.tank_amount, _litri_prima - p.water_pack.tank_amount])
		_scatto("respinta"))
	sott.giocatore_preso.connect(func():
		prese += 1
		_evento("PRESO a s %.1f (%.2f s dopo la carica, in carica %s)" % [s_g, _t() - _carica_t, _in_carica])
		_scatto("presa"))
	sott.lei_riemersa.connect(func():
		_riemersa_t = _t()
		_evento("lei riemerge, distanza %.1f" % (sott._s_bersaglio - sott.lei_s)))
	sott.lei_morde.connect(func(): _evento("morso"))


func _prendi() -> bool:
	level = get_tree().current_scene
	p = GameState.player as Player
	if modo == "prova":
		sott = level.get_node("SalaSottomarino") as SalaSottomarino
	else:
		sott = level.get(&"sala_sottomarino") as SalaSottomarino if level and &"sala_sottomarino" in level else null
	return sott != null and is_instance_valid(sott) and p != null


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var durata := float(a[2]) if a.size() > 2 else 300.0
	modo = OS.get_environment("MODO") if OS.get_environment("MODO") != "" else "f9"
	politica = OS.get_environment("POLITICA") if OS.get_environment("POLITICA") != "" else "mai"
	reazione = float(OS.get_environment("REAZIONE")) if OS.get_environment("REAZIONE") != "" else 1.0
	DirAccess.make_dir_recursive_absolute(cart)
	_log = FileAccess.open(cart.path_join("registro.txt"), FileAccess.WRITE)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	spia = preload("res://tests/collaudo/spia_canto.gd").new()
	get_tree().root.add_child.call_deferred(spia)
	if modo == "prova":
		get_tree().change_scene_to_file(PROVA)
		for i in 600:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player):
				break
		await _frames(10)
		_prendi()
		sott.costruisci()
		var ins := level.get_node("SalaInseguimento") as SalaInseguimento
		ins.sb1_finito.connect(sott.attiva_tunnel)
		p.water_pack.set_equipped(true, false)
		var porta := SalaInseguimento.b(ins.dati["porta"]["uscita"])
		p.teleport(porta + Vector3.UP * 0.05)
		ins.sb1_finito.emit()
		await _frames(5)
		await _entra()
	else:
		print("CT: F9 tunnel: %s" % MenuProva.parti(get_tree(), "tunnel"))
		await _arriva(0)
		_prendi()
	_collega()
	_evento("politica %s, reazione %.1f s, finestra %.1f/%.1f, avvicinamento %.1f s, distanze %.0f-%.0f, zaino %.1f/%.1f l (aspira %.1f l/s)" % [politica, reazione,
			sott.carica_finestra_prima, sott.carica_finestra, sott.avvicinamento, sott.distanza_min, sott.distanza_max,
			p.water_pack.tank_amount, p.water_pack.tank_capacity, p.water_pack.suck_rate])
	registra = true
	var t_fine := _t() + durata
	s_g = float(sott.proietta_vicino(p.global_position, 0.0, 600.0)[0])
	while _t() < t_fine and not fermata:
		await _corsa(t_fine)
		if fermata:
			break
		if GameState.is_dying or (p and is_instance_valid(p) and not p.input_enabled) or not is_instance_valid(p):
			if modo == "prova":
				_evento("PRESO nella scena di prova: fine")
				break
			await _aspetta_ripartenza()
	_evento("FINE: cariche %d, scatti %d, respinte %d, prese %d, morti %d, cadute %d, getti %d, s %.1f" % [cariche, scatti, respinte, prese, morti, cadute, getti, s_g])
	spia.call(&"riassunto")
	_log.close()
	print("CT: finito")
	if modo == "f9":
		Game.esci(0)
	else:
		get_tree().quit()


func _arriva(vecchio: int) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var g := GameState.player
		if s and String(s.name) != "Caricamento" and g and is_instance_valid(g) and g.get_instance_id() != vecchio \
				and g.is_inside_tree() and not GameState.is_dying and not GameState.is_restoring() and g.input_enabled:
			var tn: Node = s.get(&"sala_sottomarino") if &"sala_sottomarino" in s else null
			if tn and is_instance_valid(tn) and bool(tn.get(&"costruita")):
				return true
	return false


func _entra() -> void:
	fase = "entra"
	var dentro := sott.punto(SalaSottomarino.PORTA_S) - sott.destra(SalaSottomarino.PORTA_S) * (sott.canale + 1.3)
	Input.action_press(&"move_forward")
	var t0 := _t()
	while _piano(p.global_position).distance_to(_piano(dentro)) > 0.6 and _t() - t0 < 8.0:
		_guarda_verso(dentro)
		await _frames(1)
	_lascia()
	s_g = SalaSottomarino.PORTA_S


func _aspetta_ripartenza() -> void:
	_lascia()
	morti += 1
	var vecchio := p.get_instance_id() if p and is_instance_valid(p) else 0
	var t0 := Time.get_ticks_msec()
	registra = false
	await _arriva(vecchio)
	_prendi()
	_collega()
	_carica_n = 0
	_in_carica = false
	await _frames(20)
	var pr: Array = sott.proietta_vicino(p.global_position, 0.0, 600.0)
	s_g = float(pr[0])
	lato_att = signf(float(pr[1])) if absf(float(pr[1])) > 0.1 else lato_att
	registra = true
	_evento("RIPARTITO (morte %d) dopo %.1f s: checkpoint %s, s %.1f lato %.0f, lei %s, prima respinta fatta %s, zaino %.1f/%.1f" % [morti,
			(Time.get_ticks_msec() - t0) / 1000.0, GameState.snapshot.get("checkpoint", ""), s_g, lato_att, SalaSottomarino.Lei.keys()[sott.lei_stato],
			preload("res://scripts/game/stato_tunnel.gd").prima_respinta_fatta, p.water_pack.tank_amount, p.water_pack.tank_capacity])


func _deve_colpire() -> bool:
	if politica == "mai":
		return false
	if politica == "prima_mai" and morti == 0:
		return false
	return true


func _corsa(t_fine: float) -> void:
	fase = "corsa"
	var gruppi := _gruppi()
	var gallerie := sott.ostacoli.filter(func(o): return o["tipo"] == "galleria")
	var L := sott.lunghezza()
	var s_scala := L - SalaSottomarino.BALLATOIO - 12 * 0.32 - 1.5
	for gr in gruppi:
		if float(gr["s"]) < s_g - 1.0:
			gr["fatto"] = true
	for g in gallerie:
		if float(g["s"]) < s_g - 1.0:
			g["fatto"] = true
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	while s_g < s_scala and _t() < t_fine:
		await _frames(1)
		if GameState.is_dying or not is_instance_valid(p) or not p.input_enabled or sott.lei_stato == SalaSottomarino.Lei.PRESA:
			_lascia()
			return
		var pr: Array = sott.proietta_vicino(p.global_position, s_g)
		s_g = float(pr[0])
		var u := float(pr[1])
		if absf(u) > sott.canale:
			lato_att = signf(u)
		# la carica: si gira e spruzza dopo la reazione
		if _in_carica and _deve_colpire() and _t() - _carica_t >= reazione:
			await _getto()
			continue
		# la ricarica dal canale, con lei lontana
		if politica != "mai" and p.water_pack.tank_amount < RICARICA_SOTTO and sott._s_bersaglio - sott.lei_s > 14.0 and sott.lei_stato == SalaSottomarino.Lei.INSEGUE:
			await _ricarica()
			continue
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
			if GameState.is_dying or not is_instance_valid(p) or not p.input_enabled:
				return
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
			if GameState.is_dying or not is_instance_valid(p) or not p.input_enabled:
				return
			Input.action_press(&"move_forward")
			Input.action_press(&"sprint")
			continue
		var q := sott.punto(s_g + 5.0) + sott.destra(s_g + 5.0) * lato_att * (sott.canale + 1.3)
		if p.global_position.y < sott.piano - 0.2:
			q = sott.punto(s_g + 2.0) + sott.destra(s_g + 2.0) * lato_att * (sott.canale + 1.0)
			if Engine.get_physics_frames() % 20 == 0:
				Input.action_press(&"jump")
			elif Engine.get_physics_frames() % 20 == 4:
				Input.action_release(&"jump")
		_guarda_verso(q)
	_lascia()
	if s_g >= s_scala:
		_evento("arrivato alla scala a s %.1f: fine della corsa" % s_g)
		fermata = true


func _getto() -> void:
	var prima := fase
	fase = "getto"
	getti += 1
	_litri_prima = p.water_pack.tank_amount
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	var occhio: Vector3 = sott.lei.get_eye_position() if sott.lei and sott.lei.has_method(&"get_eye_position") else sott.punto(sott.lei_s) + Vector3.UP * 2.0
	p.look_at_point(occhio)
	await _frames(6)
	Input.action_press(&"spray")
	var t0 := _t()
	var n0 := respinte
	while respinte == n0 and _t() - t0 < 3.5 and not GameState.is_dying and is_instance_valid(p) and p.input_enabled:
		occhio = sott.lei.get_eye_position() if sott.lei and sott.lei.has_method(&"get_eye_position") else occhio
		p.look_at_point(occhio)
		await _frames(1)
	Input.action_release(&"spray")
	if respinte == n0:
		_evento("getto di %.2f s senza respinta (zaino %.1f, morendo %s)" % [_t() - t0, p.water_pack.tank_amount if is_instance_valid(p) else -1.0, GameState.is_dying])
	await _frames(4)
	fase = prima
	if is_instance_valid(p) and p.input_enabled:
		Input.action_press(&"move_forward")
		Input.action_press(&"sprint")


## Ricarica dal canale: fermo sul bordo, la mira sull'acqua, aspira finché è pieno.
func _ricarica() -> void:
	var prima := fase
	fase = "ricarica"
	_lascia()
	var acqua := sott.punto(s_g + 1.0) + Vector3.DOWN * 0.3
	p.look_at_point(acqua)
	await _frames(4)
	var l0 := p.water_pack.tank_amount
	var t0 := _t()
	Input.action_press(&"suck")
	while p.water_pack.tank_amount < p.water_pack.tank_capacity - 0.05 and _t() - t0 < 8.0 and not GameState.is_dying:
		p.look_at_point(acqua)
		await _frames(1)
	Input.action_release(&"suck")
	_evento("RICARICA dal canale: da %.1f a %.1f l in %.2f s (distanza di lei %.1f)" % [l0, p.water_pack.tank_amount, _t() - t0, sott._s_bersaglio - sott.lei_s])
	fase = prima
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")



# --- copiati da partita_tunnel.gd ---

func _lascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"spray", &"sprint", &"jump", &"crouch", &"interact"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _guarda_verso(q: Vector3, pitch := 0.0) -> void:
	var d := q - p.global_position
	if Vector2(d.x, d.z).length() > 0.05:
		p.set_look(_yaw(Vector3(d.x, 0.0, d.z)), pitch)


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


static func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


static func _piano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


