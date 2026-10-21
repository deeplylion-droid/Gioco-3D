extends Node
## Scatti della bava rosa (tappe 7 e 8) nella sala, al buio (GameState.luci = BLACKOUT), dal punto
## di vista del giocatore con la torcia accesa. Toglie gli interni come tests/scatti_sala.gd.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_bava.gd <cartella> [scatti] [frame]

const LEVEL := "res://scenes/sala_principale.tscn"
const SCATTI := {
	"scia": [Vector3(-1.6, 0.0, 9.4), Vector3(-11.0, 0.0, 8.3)],      # dalla vasca vuota lungo la scia
	"scia_curva": [Vector3(-14.5, 0.0, 8.0), Vector3(-18.3, 0.0, 0.0)], # la scia che gira verso l'area bimbi
	"fossa": [Vector3(-10.4, 0.0, -2.6), Vector3(-13.6, 0.2, -6.8)],    # la fossa con la bava intorno
}

var out_dir := "user://scatti_bava"
var only := PackedStringArray()
var settle := 60


func _ready() -> void:
	# Negli scatti la torre non si precarica (memoria: la sala da sola arriva a 12-13 GB).
	Engine.set_meta(&"precarica_torre_spento", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2 and args[2] != "tutti":
		only = args[2].split(",")
	if args.size() > 3:
		settle = int(args[3])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var level := (load(LEVEL) as PackedScene).instantiate()
	var interni := level.get_node_or_null(^"Interni")
	if interni:
		level.remove_child(interni)
		interni.free()
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
		t.set(&"automatica", false)
	# Lei non deve sbucare durante gli scatti.
	var lei := level.find_child("LeiSbuca", true, false)
	if lei:
		lei.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(5)
	var torcia := p.find_child("Torcia", true, false)
	if torcia:
		torcia.call(&"imposta_accesa", true)
	p.stand_eye_height = 1.7
	for nome in SCATTI:
		if not only.is_empty() and not only.has(nome):
			continue
		var s: Array = SCATTI[nome]
		p.teleport(s[0], 0.0, 0.0)
		p.look_at_point(s[1])
		await _frames(settle)
		p.look_at_point(s[1])
		await _frames(2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(nome + ".jpg"), 0.92)
		print("salvato ", nome)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
