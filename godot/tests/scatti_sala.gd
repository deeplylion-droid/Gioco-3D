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
## andata via (tappa 8 finita); SCATTI_PORTONE=aperto|chiuso: il portone della sala della torre.

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
	"i_pulsante_botola": [Vector3(-1.2, -2.0, -0.6), Vector3(1.9, -1.35, 4.95)],  # tappa 5: il pulsante della botola sulla parete sud, dal fondo
	"j_portone_lontano": [Vector3(8.5, 0.0, -6.0), Vector3(19.8, 2.4, -15.0)],  # dopo la tappa 8: il portone della sala della torre da lontano
	"k_portone_vicino": [Vector3(14.0, 0.0, -11.0), Vector3(19.8, 2.2, -15.0)],  # il portone da vicino (aperto, col lampeggiante)
}

var out_dir := "user://scatti_sala"
var prefisso := "scatto"
var only := PackedStringArray()
var preset := "alto_smaa"
var settle := 50
var level: Node
var p: Player


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
	p.stand_eye_height = 1.7
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
			var pref := prefisso
			if asp != "":
				pref += "_" + asp
			if livelli.size() > 1:
				pref += "_" + liv.replace(".", "")
			for nome in camere:
				if only.is_empty() or only.has(nome):
					var s: Array = camere[nome]
					p.teleport(s[0], 0.0, 0.0)
					p.look_at_point(s[1])
					await _frames(settle)
					p.look_at_point(s[1])
					await _frames(2)
					await RenderingServer.frame_post_draw
					var img := get_viewport().get_texture().get_image()
					img.save_jpg(out_dir.path_join("%s_%s.jpg" % [pref, nome]), 0.92)
					print("salvato ", pref, "_", nome)
	print("scatti salvati in ", ProjectSettings.globalize_path(out_dir))
	print("memoria massima del processo: ", _picco_memoria())
	get_tree().quit()


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
