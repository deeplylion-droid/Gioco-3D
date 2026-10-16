extends Node
## Scatti da punti scelti di una scena qualsiasi (prima/dopo delle correzioni). Serve un vero renderer.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_liberi.gd <scena.tscn> <cartella> \
##        "nome:px,py,pz:lx,ly,lz;nome2:..." [preset] [frame di attesa] [torcia 0/1] [luci: prima/blackout] [fisse: neon e luci rosse senza sfarfallio]
## Le coordinate sono globali nella scena (il giocatore viene messo coi piedi in p e guarda verso l).

var scena := ""
var out_dir := "user://scatti"
var scatti := []
var preset := "alto"
var settle := 60
var torcia := true
var blackout := false
var fisse := false


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	scena = a[1]
	out_dir = a[2]
	for s in a[3].split(";", false):
		var p := s.split(":")
		scatti.append([p[0], _v(p[1]), _v(p[2])])
	if a.size() > 4:
		preset = a[4]
	if a.size() > 5:
		settle = int(a[5])
	if a.size() > 6:
		torcia = a[6] != "0"
	if a.size() > 7:
		blackout = a[7] == "blackout"
	if a.size() > 8:
		fisse = a[8] == "fisse"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _v(t: String) -> Vector3:
	var c := t.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	get_tree().change_scene_to_file(scena)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	if blackout:
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
	if fisse:
		# stessa luce in tutti gli scatti (prima e dopo): niente sfarfallio né pulsazioni
		for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
			if n is LuceEmergenza and int(n.get(&"modalita")) in [1, 2]:
				n.set(&"modalita", 0)   # PULSANTE, ROTANTE -> FISSA (le SPENTE restano spente)
			elif n is Neon and int(n.get(&"modalita")) in [1, 2, 3]:
				n.set(&"modalita", 0)   # SFARFALLA, GUASTO, MORENTE -> STABILE (gli SPENTI restano spenti)
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for s in scatti:
		p.teleport(s[1], 0.0, 0.0)
		p.set_physics_process(false)
		p.velocity = Vector3.ZERO
		p.look_at_point(s[2])
		var luce := p.find_child("*orcia*", true, false)
		if luce and luce is Node3D:
			(luce as Node3D).visible = torcia
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(s[0] + ".jpg"), 0.9)
		print("salvato ", s[0])
	get_tree().quit()
