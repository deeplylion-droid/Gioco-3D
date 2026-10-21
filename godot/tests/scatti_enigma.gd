extends Node
## Scatti di controllo dell'enigma degli acquari nel gioco (scenes/sala/enigma_acquari.tscn con i
## modelli veri): la sala principale al buio rosso, rientrati dal magazzino (la serranda aperta: gli
## acquari ci sono e le lampade del portone sono accese), dopo la tappa 8. Come scatti_sala.gd toglie
## gli interni e, con SCATTI_TOGLI, altre parti che non si vedono (memoria).
## Uso, sotto il render.lock, un processo per scatto:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_enigma.gd <cartella> <scatto>
## Scatti: meta (la fila da metà sala), vicino, pieni (da vicino, col verde riuscito), verde (il
## miscuglio riuscito da vicino), portone (le lampadine
## accese), gorgo (a metà del gorgo che svuota il miscuglio torbido).

const LEVEL := "res://scenes/sala_principale.tscn"
const CAMERE := {
	"meta": [Vector3(4.0, 1.7, 3.5), Vector3(15.6, 1.1, -3.6)],
	"vicino": [Vector3(11.8, 1.7, -2.6), Vector3(15.6, 1.25, -3.6)],
	"pieni": [Vector3(11.8, 1.7, -2.6), Vector3(15.6, 1.25, -3.6)],   # come vicino, col verde riuscito
	"verde": [Vector3(13.4, 1.5, -2.9), Vector3(15.1, 0.95, -3.5)],
	"portone": [Vector3(8.6, 1.7, -14.2), Vector3(20.0, 3.0, -15.0)],
	"gorgo": [Vector3(13.7, 1.85, -3.0), Vector3(15.25, 0.55, -3.6)],
}

var out_dir := "user://scatti_enigma"
var scatto := "meta"
var level: Node


func _ready() -> void:
	# Negli scatti la torre non si precarica (memoria: la sala da sola arriva a 12-13 GB).
	Engine.set_meta(&"precarica_torre_spento", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		scatto = args[2]
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
	var enigma := level.find_children("*", "EnigmaAcquari", true, false)[0] as EnigmaAcquari
	var serranda = enigma.serranda
	if serranda:
		serranda.call(&"apri")
	await _frames(5)
	p.teleport(Vector3(0.0, 0.0, 19.0), 0.0, 0.0)
	var misto := enigma.get_node(^"AcquarioMisto") as WaterTank
	var settle := 40
	match scatto:
		"verde", "pieni":
			enigma.stato = EnigmaAcquari.Stato.RISOLTO
			misto.set_mix(WaterMix.pura(WaterMix.VERDE))
			misto.fill = misto.max_fill
		"gorgo":
			enigma.stato = EnigmaAcquari.Stato.TORBIDO
			misto.set_mix(WaterMix.pura(WaterMix.TORBIDA))
			misto.fill = misto.max_fill
			await _frames(5)
			# più corto che nel gioco (4 s): la memoria del renderer software cresce coi fotogrammi;
			# a metà il gorgo è lo stesso (la forza segue la frazione del tempo)
			enigma.durata_gorgo = 1.5
			enigma.durata_ricarica = 1.5
			enigma.svuota()
			settle = int(enigma.durata_gorgo * 60.0 * 0.45)
	var c: Array = CAMERE[scatto]
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	level.add_child(cam)
	cam.global_position = c[0]
	cam.look_at(c[1], Vector3.UP)
	cam.make_current()
	await _frames(settle)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join("gioco_%s.jpg" % scatto), 0.92)
	print("salvato gioco_", scatto, " (stato ", enigma.stato, ", miscuglio ", misto.fill, ")")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
