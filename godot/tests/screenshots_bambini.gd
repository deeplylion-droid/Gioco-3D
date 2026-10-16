extends Node
## Screenshot dei bambini nella sala principale (serve un vero renderer). La sala si carica
## soltanto, non si modifica: i bambini si aggiungono a runtime.
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/screenshots_bambini.gd <cartella> \
##        [inquadrature separate da virgole] [preset]
## Per ogni inquadratura: dove sta il giocatore e dove guarda (con la torcia), quale bambino,
## dove, in che modalità e con quale animazione fermata a che istante.

const LEVEL := "res://scenes/sala_principale.tscn"
const CUBO := "res://scenes/creature/bambino_cubo.tscn"
const AGNELLO := "res://scenes/creature/bambino_agnello.tscn"

# nome: [scena, posizione, giocatore, guarda, rivelato, animazione, istante (s), torcia, giro (gradi)]
# "giro": il bambino è girato di tanti gradi rispetto al giocatore (la testa e l'occhio lo cercano).
const INQUADRATURE := {
	"cubo_si_gira": [CUBO, Vector3(10.6, 0, 5.4), Vector3(9.0, 0, 9.0), Vector3(10.6, 1.0, 5.4), false, "si_gira", 1.4, true],
	"cubo_osserva": [CUBO, Vector3(10.6, 0, 5.4), Vector3(9.0, 0, 9.0), Vector3(10.6, 1.0, 5.4), false, "fermo", 2.0, true],
	"cubo_rivelato": [CUBO, Vector3(10.6, 0, 5.4), Vector3(9.4, 0, 7.6), Vector3(10.6, 0.95, 5.4), true, "fermo", 2.0, true],
	"cubo_cammina": [CUBO, Vector3(10.2, 0, 5.0), Vector3(8.6, 0, 9.4), Vector3(10.6, 0.9, 5.4), false, "cammina", 0.6, true],
	"agnello_fermo": [AGNELLO, Vector3(-1.3, 0, 15.6), Vector3(0.0, 0, 19.2), Vector3(-0.6, 1.4, 13.0), false, "inclina_testa", 2.6, true],
	"agnello_occhio": [AGNELLO, Vector3(-1.3, 0, 15.6), Vector3(-0.8, 0, 18.3), Vector3(-1.3, 1.0, 15.6), true, "fermo", 2.0, true],
	"agnello_occhio_lato": [AGNELLO, Vector3(-1.3, 0, 15.6), Vector3(-0.6, 0, 18.0), Vector3(-1.3, 1.0, 15.6), true, "fermo", 2.0, true, 55.0],
	"agnello_corsa": [AGNELLO, Vector3(-1.0, 0, 15.2), Vector3(0.3, 0, 19.2), Vector3(-1.0, 0.9, 15.2), false, "corsa", 0.3, true],
}

var out_dir := "user://screenshots_bambini"
var only := PackedStringArray()
var preset := "alto"
var level: Node
var p: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2 and args[2] != "" and args[2] != "tutte":
		only = args[2].split(",")
	if args.size() > 3:
		preset = args[3]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	get_tree().paused = false
	level = get_tree().current_scene
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		t.set(&"automatica", false)
	var torch := p.find_child("Torcia", true, false) as Torcia
	for nome in INQUADRATURE:
		if not only.is_empty() and not only.has(nome):
			continue
		var d: Array = INQUADRATURE[nome]
		var b := (load(d[0]) as PackedScene).instantiate() as Bambino
		b.modalita = Bambino.Modalita.OSSERVA
		b.rivelato_all_inizio = d[4]
		b.distanza_fuga = 0.0
		b.scappa_con_la_torcia = false
		b.inclina_ogni = 0.0
		b.gira_il_corpo = false
		level.add_child(b)
		b.global_position = d[1]
		var verso: Vector3 = d[2] - d[1]
		b.rotation.y = atan2(verso.x, verso.z) + deg_to_rad(d[8] if d.size() > 8 else 0.0)
		if torch:
			torch.imposta_accesa(d[7])
		p.teleport(d[2], 0.0, 0.0)
		p.look_at_point(d[3])
		await _frames(40)
		# animazione fermata all'istante scelto (lo sguardo della testa resta attivo in "fermo")
		b.segue_con_la_testa = d[5] == "fermo"
		for ap in b.find_children("AnimationPlayer", "AnimationPlayer", true, false):
			(ap as AnimationPlayer).play(StringName(d[5]))
			(ap as AnimationPlayer).seek(d[6], true)
			(ap as AnimationPlayer).pause()
		await _frames(60 if b.segue_con_la_testa else 30)
		await _capture(nome)
		b.queue_free()
		await _frames(2)
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
