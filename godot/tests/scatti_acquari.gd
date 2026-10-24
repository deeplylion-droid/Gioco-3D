extends Node
## Scatti della proposta dell'enigma degli acquari (18 ottobre, squadra enigma-ambiente): la sala
## principale vera, al buio rosso del ritorno (tappa 7), dopo la tappa 8, col portone della torre chiuso,
## e dentro la proposta montata da godot/proposte/acquari/proposta_acquari.gd. Non tocca il gioco.
## Come scatti_sala.gd toglie gli interni prima del primo frame (memoria).
##
## Uso, sotto il render.lock e con almeno 13,5 GB liberi:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_acquari.gd <cartella> <giri>
## <giri>: elenco separato da ";" di giri "stile,posizione,lampade,accese,miscuglio,camere[,bassi]" con le camere
## separate da "+", per esempio "A,1,lampadine,0,vuoto,uscita+meta+vicino;A,1,lampadine,1,verde,portone".
## Un settimo campo "bassi" nel giro fa anche il giallo e il blu bassi (opzione 3).
## Le immagini: <cartella>/<stile><posizione>_<camera>[_<miscuglio>][_<lampade>_<accese|spente>].jpg

const LEVEL := "res://scenes/sala_principale.tscn"
const PROPOSTA: GDScript = preload("res://proposte/acquari/proposta_acquari.gd")

## Camere libere (campo visivo 62 gradi) per posizione: [camera, punto guardato]. "portone" e
## "dettaglio" sono uguali o quasi per le due posizioni.
const CAMERE := {
	"1": {
		"uscita": [Vector3(-15.0, 1.7, 18.6), Vector3(-11.3, 1.3, 9.7)],     # appena fuori dalla serranda
		"meta": [Vector3(-4.0, 1.7, 15.8), Vector3(-11.3, 1.2, 9.7)],
		"vicino": [Vector3(-10.6, 1.7, 13.6), Vector3(-11.3, 1.25, 9.7)],
		"dettaglio": [Vector3(-10.4, 1.5, 12.3), Vector3(-11.1, 0.95, 10.2)],
		# il disegno sul vetro del giallo, con la torcia puntata (A e B hanno il giallo in punti diversi)
		"disegno_A": [Vector3(-13.6, 1.55, 11.7), Vector3(-14.4, 1.35, 10.04)],
		"disegno_B": [Vector3(-13.0, 1.55, 11.8), Vector3(-14.13, 1.4, 10.21)],
	},
	"2": {
		"uscita": [Vector3(-15.0, 1.7, 18.6), Vector3(15.6, 1.4, -3.6)],
		"meta": [Vector3(4.0, 1.7, 3.5), Vector3(15.6, 1.1, -3.6)],
		"vicino": [Vector3(11.8, 1.7, -2.6), Vector3(15.6, 1.25, -3.6)],
		"dettaglio": [Vector3(13.4, 1.5, -2.9), Vector3(15.1, 0.95, -3.5)],
	},
	"*": {
		"portone": [Vector3(8.6, 1.7, -14.2), Vector3(20.0, 3.0, -15.0)],
		"portone_lontano": [Vector3(-15.0, 1.7, 18.6), Vector3(19.8, 2.6, -15.0)],
	},
}

var out_dir := "user://scatti_acquari"
var giri := PackedStringArray()
var settle := 40
var level: Node
var proposta: Node3D


func _ready() -> void:
	# Negli scatti la torre non si precarica (memoria: la sala da sola arriva a 12-13 GB).
	Engine.set_meta(&"precarica_torre_spento", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		giri = args[2].split(";", false)
	if args.size() > 3:
		settle = int(args[3])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
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
	var p: Player = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lei := level.get_node_or_null(^"Gioco/LeiSbuca")
	if lei:
		lei.call(&"load_state", {"finita": true})
	var portone := level.get_node_or_null(^"Gioco/PortoneTorre")
	if portone:
		portone.call(&"load_state", {"aperto": false})
	await _frames(5)
	p.teleport(Vector3(0.0, 0.0, 19.0), 0.0, 0.0)
	for giro in giri:
		var c := giro.split(",")
		var stile := c[0]
		var pos := c[1]
		if proposta:
			proposta.queue_free()
			await _frames(2)
		proposta = PROPOSTA.new()
		proposta.name = "PropostaAcquari"
		proposta.set(&"stile", stile)
		proposta.set(&"posizione", pos)
		proposta.set(&"lampade", c[2])
		proposta.set(&"lampade_accese", c[3] == "1")
		proposta.set(&"miscuglio", c[4])
		var bassi := c.size() > 6 and c[6] == "bassi"
		proposta.set(&"tutti_bassi", bassi)
		level.add_child(proposta)
		for nome in c[5].split("+"):
			var cam_def: Array = CAMERE.get(pos, {}).get(nome, CAMERE["*"].get(nome, []))
			if cam_def.is_empty():
				push_warning("camera sconosciuta " + nome)
				continue
			var cam := Camera3D.new()
			cam.fov = 62.0
			cam.near = 0.05
			cam.far = 200.0
			level.add_child(cam)
			cam.global_position = cam_def[0]
			cam.look_at(cam_def[1], Vector3.UP)
			cam.make_current()
			await _frames(settle)
			await RenderingServer.frame_post_draw
			var nomefile := "%s%s_%s" % [stile, pos, nome]
			if nome.begins_with("portone"):
				nomefile = "%s_%s_%s" % [nome, c[2], "accese" if c[3] == "1" else "spente"]
			elif c[4] != "vuoto":
				nomefile += "_" + c[4]
			if bassi:
				nomefile += "_tuttibassi"
			get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(nomefile + ".jpg"), 0.92)
			print("salvato ", nomefile)
			cam.queue_free()
	print("memoria massima del processo: ", _picco_memoria())
	get_tree().quit()


func _picco_memoria() -> String:
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
