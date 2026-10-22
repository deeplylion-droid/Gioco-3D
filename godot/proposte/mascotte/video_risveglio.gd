extends Node
## Fotogrammi della scena del risveglio con il mostro-squalo (scripts/interni/risveglio_squalo.gd) nel
## gioco vero: la sala principale con gli interni, preset Alto, dagli occhi del giocatore. Per il controllo
## della squadra (proposte/ è esclusa dall'export).
## Uso (sotto render.lock, con almeno 13,5 GB liberi; con --write-movie per il video intero):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 30 \
##     --resolution 1280x720 [--write-movie <cartella>/f.png] --script res://tests/run.gd -- \
##     res://proposte/mascotte/video_risveglio.gd <cartella> [tempi separati da virgole]
## Senza tempi salva solo il video (se c'è --write-movie); con i tempi salva anche quei fotogrammi. Il video ha
## l'audio del gioco, ai volumi di partenza. Con "interni" come terzo argomento: solo gli interni (più veloce, per
## misurare i suoni).

const LEVEL := "res://scenes/sala_principale.tscn"
## Dal corridoio la sala non si vede: si tolgono le parti grosse, se no con il Movie Maker non entra
## nella memoria della macchina (12,9 GB).
const TOGLI := ["Tecnici", "Sala/TorreScivoli", "Gioco/BambiniBalconata", "Gioco/EnigmaAcquari",
	"Gioco/MedusaFossa", "Gioco/LeiSbuca", "Mascotte", "Sala/Cupola", "Sala/Piscina", "Sala/AreaBimbi",
	"Sala/Oggetti", "Sala/VascaCentrale", "Sala/Dettagli", "Sala/AngoloPalloni", "Sala/AngoloScatoloni",
	"Vasca", "Vasche"]

var out_dir := "user://video_risveglio"
var tempi: Array[float] = []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[1]
	if a.size() > 2 and a[2] != "":
		for x in a[2].split(","):
			tempi.append(float(x))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	# con --write-movie il driver audio è Dummy e il gioco fingerebbe i suoni: qui suonano davvero (il movie
	# maker li registra), ai volumi di partenza del gioco
	AudioLoop.forza_riproduzione(true)
	Audio.ripristina_volumi()
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var solo_interni := OS.get_cmdline_user_args().size() > 3 and OS.get_cmdline_user_args()[3] == "interni"
	var level := (load("res://scenes/interni/interni.tscn" if solo_interni else LEVEL) as PackedScene).instantiate()
	for percorso in TOGLI:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(5)
	get_tree().paused = false
	var p := GameState.player
	for i in 300:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var interni := level if solo_interni else level.get_node("Interni")
	var marker := interni.get_node("Gioco/Risveglio") as Node3D
	p.teleport(marker.global_position, marker.global_rotation.y, 0.0)
	await _frames(30)
	var s := interni.get_node("Gioco/RisveglioSqualo") as RisveglioSqualo
	interni.call(&"fai_risveglio", p, true)
	var t := 0.0
	var k := 0
	var a := get_node(^"/root/Audio")
	if a:
		print("volumi: ", a.get(&"volumi"))
	while s.in_corso():
		await get_tree().process_frame
		t += 1.0 / 30.0
		if k < tempi.size() and t >= tempi[k]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(out_dir.path_join("t_%05.2f.jpg" % tempi[k]), 0.9)
			print("salvato ", tempi[k])
			k += 1
	if a:
		print("suoni: ", a.get(&"conteggio"))
	print("FINE ", t)
	get_tree().quit()
