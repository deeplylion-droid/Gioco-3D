extends Node
## Sei scatti fissi della sala principale (confronto di qualità prima/dopo; li può usare anche
## grafica). Carica sala_principale.tscn ma toglie gli interni (corridoio, spogliatoi, stanzino)
## prima del primo frame: dalle camere della sala non si vedono e, con loro, la scena intera sul
## renderer software supera i 15 GB della macchina. Occhio a 1,7 m.
##
## Uso, sempre sotto il render.lock (meglio un processo per scatto: tools/scatti_sala.sh):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_sala.gd \
##        <cartella> <prefisso> [scatti separati da virgole | tutti] [preset] [frame di attesa]
## Il preset di serie è "alto_smaa" (Alto con la GI, SMAA al posto del TAA). Gli scatti si salvano
## come <cartella>/<prefisso>_<nome>.jpg. Alla fine stampa la memoria massima del processo
## (VmHWM di /proc/self/status).
## Se la memoria non basta: SCATTI_TOGLI="Sala/Dettagli,Statua/Medusa" (percorsi di nodi della scena,
## separati da virgole) toglie anche quei nodi prima del primo frame. Va usato uguale nei prima e nei dopo.
## SCATTI_PISCINA=<0..1>[,<0..1>...]: quanta acqua c'è nella piscina a onde (tappa 5; 1 = piena, 0 = vuota,
## con il pulsante della botola acceso), con le micro medusine che vuole quel livello; con più livelli
## si rifanno gli scatti per ognuno.
## SCATTI_PISCINA_ASPETTO=<A|B|C>[,...]: l'aspetto dell'acqua della piscina (PiscinaOnde.aspetto).
## SCATTI_LUCI=BLACKOUT: le luci del blackout (dopo il risveglio); SCATTI_DOPO_TAPPA8=1: lei è già
## andata via (tappa 8 finita); SCATTI_PORTONE=aperto|chiuso: il portone della sala della torre;
## SCATTI_OCCHIO_CHIUSO=1: la medusa affacciata con l'occhio chiuso (easter egg del getto in faccia);
## SCATTI_PULSANTE=attivo|premuto: il pulsante della botola acceso (lampeggiante giallo) o già colpito
## (verde), solo ai livelli con la piscina vuota (SCATTI_PISCINA=...,0).
## SCATTI_PORTONE=auto: il portone chiuso per j_portone_lontano e aperto per k_portone_vicino.
## SCATTI_TORCIA=1: nelle camere libere la torcia del giocatore accesa, in mano alla camera.

const LEVEL := "res://scenes/sala_principale.tscn"

## nome: [posizione dei piedi, punto guardato] (coordinate di Godot)
const SCATTI := {
	"a_ingresso": [Vector3(0.0, 0.0, 19.2), Vector3(0.0, 1.9, 10.0)],      # dalla porta degli spogliatoi verso la vasca sollevata
	"b_vasca_3m": [Vector3(1.6, 0.0, 15.4), Vector3(0.0, 1.0, 10.8)],      # la vasca sollevata da 3 m
	"c_piscina_spiaggia": [Vector3(2.0, -0.15, -11.0), Vector3(-1.0, -1.6, 1.5)],  # la piscina a onde dalla spiaggia
	"d_area_bimbi": [Vector3(-12.5, 0.0, -4.5), Vector3(-12.3, 3.4, -15.0)],   # davanti all'area bimbi: festone e plafoniera (camera di grafica, 03c71c4)
	"e_base_torre": [Vector3(7.6, 0.0, -8.6), Vector3(13.5, 3.2, -17.5)],  # la base della torre degli scivoli
	"f_galleria": [Vector3(18.4, 4.3, -0.5), Vector3(0.0, 0.6, 1.5)],      # dalla galleria est verso la sala
}

## Camere in più, solo se chiamate per nome (non sono nei confronti prima/dopo).
const EXTRA := {
	"g_fossa_bimbi": [Vector3(-16.2, 0.0, -5.6), Vector3(-13.6, -1.0, -7.3)],  # tappa 8: la fossa della VascaBimbi1 da dove arriva il giocatore
	"h_piscina_bordo": [Vector3(7.35, 0.0, 2.0), Vector3(2.0, -1.8, 2.6)],     # tappa 5: dal bordo est, dove si aspira l'acqua della piscina
	"i_pulsante_botola": [Vector3(-1.2, -2.0, -0.6), Vector3(2.25, -0.95, 4.6)],  # tappa 5: il pulsante A della botola sulla parete sud, dal fondo
	"j_portone_lontano": [Vector3(8.5, 0.0, -6.0), Vector3(19.8, 2.4, -15.0)],  # dopo la tappa 8: il portone della sala della torre da lontano
	"k_portone_vicino": [Vector3(14.0, 0.0, -11.0), Vector3(19.8, 2.2, -15.0)],  # il portone da vicino (aperto, col lampeggiante)
	"m_medusa_occhio": [Vector3(0.0, 0.0, 14.6), Vector3(0.0, 1.5, 11.95)],  # la medusa affacciata da davanti (easter egg dell'occhio)
	"n_scia_serranda": [Vector3(-15.0, 0.0, 19.0), Vector3(-18.0, 0.3, 9.0)],  # tappa 7: appena usciti dalla serranda, la scia lungo il muro ovest
	# tappa 5: dal bordo est con lo zaino, mentre aspira la micro medusina più vicina (due scatti di fila)
	"l_aspira_medusine": [Vector3(7.35, 0.0, 2.0), Vector3(5.6, -1.5, 2.4)],
}

var out_dir := "user://scatti_sala"
var prefisso := "scatto"
var only := PackedStringArray()
var preset := "alto_smaa"
var settle := 50
var level: Node
var p: Player

## Camere libere (non gli occhi del giocatore, campo visivo 62 gradi), solo se chiamate per nome: le
## stesse inquadrature delle proposte approvate il 16 ottobre (godot/tests/proposte_sala.gd sul branch
## lavoro/proposte-sala), per rifare gli scatti con la sala vera. [posizione della camera, punto guardato,
## campo visivo se non è 62]
const LIBERE := {
	"sala_da_terra": [Vector3(18.4, 1.7, -0.5), Vector3(0.0, 2.2, 1.5)],          # la sala senza soppalco, da terra
	"sala_dall_alto": [Vector3(18.6, 9.6, 18.6), Vector3(-5.0, 0.5, -5.5)],       # la sala d'insieme, dall'alto
	"bimbi_arrivo": [Vector3(-8.3, 1.7, -4.0), Vector3(-16.0, 2.0, -13.2)],       # l'area bimbi da dove si arriva
	# l'area bimbi HD (17 ottobre): come i confronti di docs/proposte/bimbi_hq (camere rifatte dalle immagini)
	# da vicino (1,5-2 m), per vedere il rilievo di normal e ORM con la torcia (SCATTI_TORCIA=1)
	"vicino_pavimento": [Vector3(-14.0, 1.6, 5.0), Vector3(-13.3, 0.0, 6.4)],      # piastrelle bagnate a terra
	"vicino_muro": [Vector3(-17.6, 1.6, 2.0), Vector3(-19.4, 1.1, 2.4)],          # il muro ovest piastrellato
	"bimbi_scivolo": [Vector3(-6.8, 1.7, -15.0), Vector3(-13.8, 2.4, -19.4)],     # lo scivolo nella vasca piccola
	"bimbi_scala": [Vector3(-13.0, 1.6, -10.5), Vector3(-16.6, 2.2, -17.5)],      # la scala verso chi arriva
	"bimbi_secchio": [Vector3(-11.6, 1.2, -14.0), Vector3(-15.2, 5.5, -19.5)],    # il secchio sul telaio, dal basso
	"bimbi_fungo": [Vector3(-18.6, 1.6, -6.0), Vector3(-16.0, 1.5, -14.0)],       # il fungo-fontana vicino al muro
	"pulsante_vicino": [Vector3(-0.8, -0.27, -1.2), Vector3(1.3, -1.6, 3.6)],     # il pulsante A dal fondo della piscina
	"pulsante_spiaggia": [Vector3(0.6, 1.7, -14.2), Vector3(1.2, -1.6, 3.5)],     # il pulsante A dalla spiaggia
	"portone_est": [Vector3(8.6, 1.7, -14.2), Vector3(20.0, 3.4, -15.0)],         # il portone della sala della torre
	"vasca_cordone": [Vector3(-3.6, 1.7, 17.6), Vector3(0.0, 1.0, 10.8)],         # il cordone chiuso intorno alla vasca
	# la telecamera di sorveglianza per il monitor della sala pompe (come in screenshots_sala.gd): sul muro sud
	"telecamera_monitor": [Vector3(-5.0, 5.3, 19.6), Vector3(0.0, 1.1, 11.0), 60.0],
}


func _ready() -> void:
	if FileAccess.file_exists("user://salta_screenshot"):
		get_tree().quit()
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		prefisso = args[2]
	if args.size() > 3 and args[3] != "" and args[3] != "tutti":
		only = args[3].split(",")
	if args.size() > 4:
		preset = args[4]
	if args.size() > 5:
		settle = int(args[5])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if preset == "alto_smaa":
		Grafica.applica_preset("alto")
		Grafica.imposta("antialiasing", 2)
	else:
		Grafica.applica_preset(preset)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	# La scena si istanzia a mano per togliere gli interni prima che entrino nell'albero.
	level = (load(LEVEL) as PackedScene).instantiate()
	var togli := PackedStringArray(["Interni"])
	togli.append_array(OS.get_environment("SCATTI_TOGLI").split(",", false))
	for percorso in togli:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
			print("tolto ", percorso)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	var buio := OS.get_environment("SCATTI_LUCI") == "BLACKOUT"
	if buio:
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		await _frames(5)
	if OS.get_environment("SCATTI_DOPO_TAPPA8") == "1":
		var lei := level.get_node_or_null(^"Gioco/LeiSbuca")
		if lei:
			lei.call(&"load_state", {"finita": true})
	var stato_portone := OS.get_environment("SCATTI_PORTONE")
	var portone := level.get_node_or_null(^"Gioco/PortoneTorre")
	if portone and stato_portone != "":
		portone.call(&"load_state", {"aperto": stato_portone == "aperto"})
	var lamp := level.get_node_or_null("Vasca/Sfarfallio")
	if lamp == null:
		lamp = level.get_node_or_null("Statua/Sfarfallio")
	if lamp and lamp.has_method("turn_on") and not buio:
		lamp.turn_on()
	if OS.get_environment("SCATTI_OCCHIO_CHIUSO") == "1":
		var medusa := level.get_node_or_null(^"Vasca/Medusa")
		if medusa and medusa.has_method(&"chiudi_occhio"):
			medusa.call(&"chiudi_occhio", 600.0)
	p.stand_eye_height = 1.7
	await _scatti_liberi()
	var camere := SCATTI.duplicate()
	for nome in EXTRA:
		if only.has(nome):
			camere[nome] = EXTRA[nome]
	# SCATTI_PISCINA: uno o più livelli dell'acqua della piscina a onde (per esempio "1,0.5,0"); con
	# più livelli si rifanno gli scatti per ognuno, col livello nel nome del file.
	var livelli := OS.get_environment("SCATTI_PISCINA").split(",", false)
	if livelli.is_empty():
		livelli.append("")
	var vasca := level.get_node_or_null(^"Piscina/Pozza") as WaterTank
	# SCATTI_PISCINA_ASPETTO: uno o più aspetti dell'acqua della piscina (A com'è, B leggibile,
	# C leggibile con la lampada di servizio; PiscinaOnde.aspetto), per esempio "B,C".
	var aspetti := OS.get_environment("SCATTI_PISCINA_ASPETTO").split(",", false)
	if aspetti.is_empty():
		aspetti.append("")
	var svuota := level.get_node_or_null(^"Piscina/SvuotaPiscina")
	for asp in aspetti:
		if asp != "" and svuota:
			svuota.set(&"aspetto", {"A": 0, "B": 1, "C": 2}.get(asp, 0))
		for liv in livelli:
			if liv != "" and vasca:
				vasca.fill = clampf(float(liv), 0.0, 1.0)
				# Le micro medusine: quante ne vuole quel livello d'acqua.
				var med: Node = svuota.get_node_or_null(^"Medusine") if svuota else null
				if med:
					med.call(&"ricomincia")
			var stato_pulsante := OS.get_environment("SCATTI_PULSANTE")
			if svuota and stato_pulsante in ["attivo", "premuto"] and vasca and vasca.fill <= 0.001:
				svuota.call(&"load_state", {"attivo": true})
				var pulsante: Node = svuota.get(&"pulsante")
				if pulsante and stato_pulsante == "premuto":
					pulsante.call(&"load_state", {"powered": true})
			var pref := prefisso
			if asp != "":
				pref += "_" + asp
			if livelli.size() > 1:
				pref += "_" + liv.replace(".", "")
			for nome in camere:
				if only.is_empty() or only.has(nome):
					var s: Array = camere[nome]
					if nome == "l_aspira_medusine":
						await _aspira_medusine(pref, s[0], s[1])
						continue
					if portone and stato_portone == "auto" and nome in ["j_portone_lontano", "k_portone_vicino"]:
						portone.call(&"load_state", {"aperto": nome == "k_portone_vicino"})
					p.teleport(s[0], 0.0, 0.0)
					p.look_at_point(s[1])
					await _frames(settle)
					p.look_at_point(s[1])
					await _frames(2)
					# Il lampeggiante giallo del pulsante: lo scatto subito dopo un lampo.
					if nome == "i_pulsante_botola" and svuota and bool(svuota.get(&"attivo")) and not bool(svuota.call(&"premuto")):
						await svuota.lampeggio
						await _frames(4)
					await RenderingServer.frame_post_draw
					var img := get_viewport().get_texture().get_image()
					img.save_jpg(out_dir.path_join("%s_%s.jpg" % [pref, nome]), 0.92)
					print("salvato ", pref, "_", nome)
	print("scatti salvati in ", ProjectSettings.globalize_path(out_dir))
	print("memoria massima del processo: ", _picco_memoria())
	get_tree().quit()


## Lo zaino in mano dal bordo est della piscina: si mira alla micro medusina più vicina che si può
## raggiungere e si aspira; due scatti mentre la corrente la tira su col filo d'acqua.
func _aspira_medusine(pref: String, dove: Vector3, mira: Vector3) -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(4.0)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.teleport(dove, 0.0, 0.0)
	await _frames(10)
	var med := level.get_node_or_null(^"Piscina/SvuotaPiscina/Medusine") as Medusine
	if med:
		# La medusina più vicina al bordo (le altre restano dove sono) si porta a portata dello zaino
		# (0,9 m dal bordo) e la si mira: la corrente la prende subito.
		var st := med.stati()
		var pos := med.posizioni()
		var scelta := -1
		for i in pos.size():
			if st[i] == Medusine.Stato.NUOTA and (scelta < 0 or pos[i].x > pos[scelta].x):
				scelta = i
		if scelta >= 0:
			mira = Vector3(dove.x - 0.9, -1.6, dove.z + 0.2)
			med.sposta(scelta, mira)
	p.look_at_point(mira)
	await _frames(settle)
	p.look_at_point(mira)
	Input.action_press(&"suck")
	var attese := [14, 10, 10]
	for k in attese.size():
		await _frames(attese[k])
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(out_dir.path_join("%s_l_aspira_medusine_%d.jpg" % [pref, k + 1]), 0.92)
		print("salvato ", pref, "_l_aspira_medusine_", k + 1)
	Input.action_release(&"suck")
	p.water_pack.set_equipped(false, false)


## Memoria residente massima del processo (Linux), per esempio "9876 MB".
func _picco_memoria() -> String:
	# i file di /proc hanno lunghezza 0: si leggono riga per riga
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return "?"
	while not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with("VmHWM:"):
			return "%d MB" % int(int(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024)
	return "?"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Gli scatti delle camere libere (LIBERE) chiamati per nome. SCATTI_LUCE="x,y,z,r,g,b,energia,raggio"
## aggiunge una OmniLight3D con le ombre (per esempio la luce del lampeggiante del pulsante A, che nel gioco
## mette lo script della sala).
func _scatti_liberi() -> void:
	var luce := OS.get_environment("SCATTI_LUCE").split(",", false)
	if luce.size() == 8:
		var o := OmniLight3D.new()
		o.position = Vector3(float(luce[0]), float(luce[1]), float(luce[2]))
		o.light_color = Color(float(luce[3]), float(luce[4]), float(luce[5]))
		o.light_energy = float(luce[6])
		o.omni_range = float(luce[7])
		o.omni_attenuation = 1.3
		o.shadow_enabled = true
		o.light_volumetric_fog_energy = 2.0
		level.add_child(o)
	for nome in LIBERE:
		if not only.has(nome):
			continue
		var c: Array = LIBERE[nome]
		var cam := Camera3D.new()
		cam.fov = float(c[2]) if c.size() > 2 else 62.0
		cam.near = 0.05
		cam.far = 200.0
		level.add_child(cam)
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		cam.make_current()
		if OS.get_environment("SCATTI_TORCIA") == "1":
			# la torcia del giocatore, in mano alla camera dello scatto
			cam.add_child(load("res://addons/grafica/torcia.tscn").instantiate())
		p.teleport(Vector3(0.0, 0.0, 19.0), 0.0, 0.0)   # il giocatore resta nella scena, lontano
		await _frames(settle)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(out_dir.path_join("%s_%s.jpg" % [prefisso, nome]), 0.92)
		print("salvato ", prefisso, "_", nome)
		cam.queue_free()
		p.camera.make_current()
