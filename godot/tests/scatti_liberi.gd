extends Node
## Scatti da punti scelti di una scena qualsiasi (prima/dopo delle correzioni). Serve un vero renderer.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_liberi.gd <scena.tscn> <cartella> \
##        "nome:px,py,pz:lx,ly,lz[:lancia];nome2:..." [preset] [frame di attesa] [torcia 0/1] [luci: prima/blackout] [fisse: neon e luci rosse senza sfarfallio | neon: tutti i neon accesi, rosse spente] [togli: nodi della scena da togliere, separati da virgola, per stare nella memoria]
## Le coordinate sono globali nella scena (il giocatore viene messo coi piedi in p e guarda verso l).
## lancia (facoltativa): scena LanceRig da mettere in mano, percorso senza "res://" (per esempio scenes/player/lance/x.tscn).
## Variabili d'ambiente: SCATTI_LUCE=1 (una luce sulla camera), SCATTI_ACQUARI=comparsi|risolti (lo stato
## degli acquari davanti al portone).

var scena := ""
var out_dir := "user://scatti"
var scatti := []
var preset := "alto"
var settle := 60
var torcia := false   # (la torcia non c'è più: il parametro resta per i comandi vecchi)
var blackout := false
var fisse := false
var neon := false   # luce normale: tutti i neon accesi e fermi, luci rosse d'emergenza spente
var togli := PackedStringArray()


func _ready() -> void:
	# Negli scatti la torre non si precarica (memoria: la sala da sola arriva a 12-13 GB).
	Engine.set_meta(&"precarica_torre_spento", true)
	var a := OS.get_cmdline_user_args()
	scena = a[1]
	out_dir = a[2]
	for s in a[3].split(";", false):
		var p := s.split(":")
		scatti.append([p[0], _v(p[1]), _v(p[2]), p[3] if p.size() > 3 else ""])
	if a.size() > 4:
		preset = a[4]
	if a.size() > 5:
		settle = int(a[5])
	if a.size() > 6:
		torcia = a[6] != "0"
	if a.size() > 7:
		blackout = a[7] == "blackout"
	if a.size() > 8:
		fisse = a[8] == "fisse" or a[8] == "neon"
		neon = a[8] == "neon"
	if a.size() > 9 and a[9] != "":
		togli = a[9].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _v(t: String) -> Vector3:
	var c := t.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	if togli.is_empty():
		get_tree().change_scene_to_file(scena)
	else:
		# I nodi pesanti si tolgono già dal file della scena (tests/scena_ridotta.gd): su llvmpipe le texture si
		# espandono e caricare tutto per poi toglierlo non sta nella memoria.
		var ridotta: String = load("res://tests/scena_ridotta.gd").riduci(scena, Array(togli))
		var livello := (load(ridotta) as PackedScene).instantiate()
		get_tree().root.add_child(livello)
		get_tree().current_scene = livello
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	# Si aspetta la fine del risveglio, se c'è (la camera è storta finché il giocatore si alza).
	for i in 600:
		if GameState.player.input_enabled:
			break
		await get_tree().process_frame
	if blackout:
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
	if fisse:
		# stessa luce in tutti gli scatti (prima e dopo): niente sfarfallio né pulsazioni
		for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
			if n is LuceEmergenza and int(n.get(&"modalita")) in [1, 2]:
				n.set(&"modalita", 0)   # PULSANTE, ROTANTE -> FISSA (le SPENTE restano spente)
			elif n is Neon and int(n.get(&"modalita")) in [1, 2, 3]:
				n.set(&"modalita", 0)   # SFARFALLA, GUASTO, MORENTE -> STABILE (gli SPENTI restano spenti)
			if neon and n is Neon:
				n.set(&"modalita", 0)
			elif neon and n is LuceEmergenza:
				n.set(&"modalita", 3)   # SPENTA
	# SCATTI_ACQUARI=comparsi|risolti: gli acquari davanti al portone come al rientro dal magazzino (la
	# serranda aperta: pieni e con le lampadine accese) o a enigma risolto (miscuglio verde, portone aperto
	# del tutto); senza, come al primo passaggio (vuoti e impolverati)
	var acquari := OS.get_environment("SCATTI_ACQUARI")
	if acquari in ["comparsi", "risolti"]:
		var livello := get_tree().current_scene
		var lei := livello.get_node_or_null(^"Gioco/LeiSbuca")
		if lei:
			lei.call(&"load_state", {"finita": true})
		var lettore := livello.get_node_or_null(^"Tecnici/Logica/LettoreTessera") as LettoreTessera
		if lettore:
			GameState.player.add_item(&"keycard", 1, "Keycard")
			lettore.interact(GameState.player)
		var enigma := livello.find_children("*", "EnigmaAcquari", true, false)[0] as EnigmaAcquari
		if enigma.serranda:
			enigma.serranda.call(&"apri")
		if acquari == "risolti":
			var misto := enigma.get_node(^"AcquarioMisto") as WaterTank
			enigma.stato = EnigmaAcquari.Stato.RISOLTO
			misto.set_mix(WaterMix.pura(WaterMix.VERDE))
			misto.fill = misto.max_fill
			if enigma.portone:
				enigma.portone.call(&"load_state", {"aperto": true})
		for i in 30:
			await get_tree().process_frame
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	# SCATTI_LUCE=1: una luce bianca sulla camera, per controllare la geometria nei posti bui
	if OS.get_environment("SCATTI_LUCE") != "":
		var o := OmniLight3D.new()
		o.omni_range = 30.0
		o.light_energy = 2.5
		o.omni_attenuation = 0.6
		p.camera.add_child(o)
	for s in scatti:
		if s[3] != "":
			var pack := p.get_node_or_null(^"WaterPack") as WaterPack
			if pack:
				pack.set_equipped(true, false)   # negli interni lo zaino si prende dopo: per gli scatti lo si indossa subito
				pack.set_lance(load("res://" + s[3]))
		p.teleport(s[1], 0.0, 0.0)
		p.set_physics_process(false)
		p.velocity = Vector3.ZERO
		p.look_at_point(s[2])
		var luce := p.find_child("*orcia*", true, false)
		if luce and luce is Node3D:
			(luce as Node3D).visible = torcia
		if blackout:
			# chi prepara le luci in differita (LuciSala, i tecnici) può arrivare dopo il primo avviso: lo si ripete
			GameState.luci_cambiate.emit(GameState.luci)
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(s[0] + ".jpg"), 0.9)
		print("salvato ", s[0])
	get_tree().quit()
