extends Node
## Scatti delle luci degli ambienti tecnici nei tre stati di LookTecnici, dagli stessi punti di
## tests/screenshots_tecnici.gd (ambienti-1). Salva <cartella>/<stato>_<inquadratura>.jpg.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_tecnici_luci.gd <cartella> \
##        [stati: prima,flash,blackout] [inquadrature | tutte] [preset] [frame di attesa]
## Nel flash lo stato si ferma acceso (durata lunga) per lo scatto.

const LEVEL := "res://scenes/tecnici/tecnici.tscn"
const INQUADRATURE := {
	"camera": [Vector3(1.4, 0.0, 0.9), Vector3(20.0, 1.9, -0.4)],
	"pompe": [Vector3(40.5, 0.0, 3.2), Vector3(34.0, 1.0, -4.2)],
	"leva": [Vector3(41.8, 0.0, 0.2), Vector3(46.0, 2.9, -3.6)],
	"scrivania": [Vector3(40.3, 0.0, 0.4), Vector3(41.8, 0.85, 3.3)],
	"vasca": [Vector3(39.6, 0.0, 3.1), Vector3(36.0, -0.2, 0.4)],
	"raccordo": [Vector3(47.0, 0.0, 1.4), Vector3(52.0, 1.6, -0.6)],
	"rampa": [Vector3(51.7, 3.625, -7.8), Vector3(44.0, 8.3, -7.8)],
}
const STATI := {"prima": 0, "flash": 1, "blackout": 2}

var out_dir := "user://scatti_tecnici_luci"
var stati := PackedStringArray(["prima", "flash", "blackout"])
var only := PackedStringArray()
var preset := "alto"
var settle := 50


func _ready() -> void:
	# Negli scatti la torre non si precarica (memoria: la sala da sola arriva a 12-13 GB).
	Engine.set_meta(&"precarica_torre_spento", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2 and args[2] != "" and args[2] != "tutti":
		stati = args[2].split(",")
	if args.size() > 3 and args[3] != "" and args[3] != "tutte":
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
	Grafica.applica_preset(preset)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	get_tree().paused = false
	var level := get_tree().current_scene
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var look := level.find_child("LuciTecnici", true, false) as LookTecnici
	var torcia := p.find_child("Torcia", true, false)
	for s in stati:
		var st: int = STATI[s]
		if st == LookTecnici.Stato.FLASH:
			look.flash(1000.0)
		else:
			look.imposta_stato(st)
		# Torcia solo nel blackout (prima del risveglio e nel flash si vede senza).
		if torcia:
			torcia.call(&"imposta_accesa", st == LookTecnici.Stato.BLACKOUT)
		for nome in INQUADRATURE:
			if not only.is_empty() and not only.has(nome):
				continue
			var q: Array = INQUADRATURE[nome]
			p.teleport(q[0], 0.0, 0.0)
			p.look_at_point(q[1])
			await _frames(settle)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_jpg(out_dir.path_join("%s_%s.jpg" % [s, nome]), 0.92)
			print("salvato ", s, "_", nome)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
