extends Node
## PROPOSTA (non usata dal gioco): video e scatti del getto negli spogliatoi degli interni (scena
## leggera, luce approvata), davanti alla vasca lava-piedi.
## Scaletta fissa di 8 s dal momento in cui stampa "INIZIO frame N":
##   0,0-0,5 fermo; 0,5-3,0 aspira dalla vasca lava-piedi a ~2 m; 3,0-3,5 pausa a serbatoio pieno;
##   3,5-7,0 spara verso il tornello a ~7 m girando piano da sinistra a destra; 7,0-8,0 stop e gocce.
## Uso (video):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --write-movie /tmp/x.avi --script res://tests/run.gd -- res://proposte/zaino/video_zaino.gd \
##     <stile: attuale|A|B> [lancia: attuale|res://...tscn] [foto: t1,t2,... (scatti invece del video)] [cartella]

const LEVEL := "res://scenes/interni/interni.tscn"
const GETTO := preload("res://proposte/zaino/getto_potente.gd")
const POSIZIONE := Vector3(9.7, 0.0, -10.6)
const POZZA := Vector3(9.7, -0.05, -12.9)
const MIRA_DA := Vector3(6.8, 1.2, -17.6)
const MIRA_A := Vector3(12.6, 1.2, -17.6)
const RISCALDA := 90   # frame di assestamento prima della scaletta

var stile := "attuale"
var lancia := "attuale"
var foto := PackedFloat32Array()
var cartella := "/tmp/claude-0/zaino_foto"
var p: Player
var pack: Node
var _f := -RISCALDA


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		stile = args[1]
	if args.size() > 2:
		lancia = args[2]
	if args.size() > 3 and args[3] != "video":
		for t in args[3].split(","):
			foto.append(float(t))
	if args.size() > 4:
		cartella = args[4]
	DirAccess.make_dir_recursive_absolute(cartella)
	_avvia.call_deferred()


func _avvia() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(LEVEL)
	for i in 8:
		await get_tree().process_frame
	get_tree().paused = false
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	pack = p.water_pack
	# Negli interni lo zaino si trova nello stanzino: qui lo si ha già.
	pack.call(&"set_equipped", true, false)
	if lancia != "attuale":
		pack.set_lance(load(lancia))
	if stile != "attuale":
		var g: Node = GETTO.new()
		g.set(&"stile", stile)
		get_tree().current_scene.add_child(g)
		g.call(&"aggancia", pack)
	pack.set(&"tank_start_amount", 0.0)
	pack.call(&"set_tank_amount", 0.0)
	# Neon fissi accesi: lo sfarfallio a caso cambierebbe la luce fra un video e l'altro.
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n.get_script() and String(n.get_script().get_global_name()) == "Neon":
			n.set(&"modalita", 0)
	var torcia := p.find_child("Torcia", true, false)
	if torcia:
		torcia.call(&"imposta_accesa", true)
	p.teleport(POSIZIONE, 0.0, 0.0)
	p.look_at_point(POZZA)
	set_process(true)


func _process(_delta: float) -> void:
	if p == null:
		return
	_f += 1
	if _f == 0:
		print("INIZIO frame ", Engine.get_frames_drawn())
	if _f < 0:
		p.look_at_point(POZZA)
		return
	var t := _f / 30.0
	if OS.get_environment("ZAINO_DEBUG") != "" and _f % 15 == 0:
		print("DBG t=%.1f equip=%s input=%s suck=%s spray=%s tank=%.1f fonte=%s hit=%s" % [t, pack.get(&"equipped"),
			p.input_enabled, pack.get(&"is_sucking"), pack.get(&"is_spraying"), pack.get(&"tank_amount"),
			pack.call(&"find_suction_source"), pack.get(&"has_hit")])
	var aspira := t >= 0.5 and t < 3.0
	var spara := t >= 3.5 and t < 7.0
	_azione(&"suck", aspira)
	_azione(&"spray", spara)
	if t < 3.2:
		p.look_at_point(POZZA)
	else:
		# Alza lo sguardo verso le pompe e poi gira piano da sinistra a destra.
		var k := clampf((t - 3.2) / 0.4, 0.0, 1.0)
		var giro := clampf((t - 3.6) / 3.4, 0.0, 1.0)
		var mira := MIRA_DA.lerp(MIRA_A, giro * giro * (3.0 - 2.0 * giro))
		p.look_at_point(POZZA.lerp(mira, k * k * (3.0 - 2.0 * k)))
	for x in foto:
		if absf(t - x) < 0.5 / 30.0:
			_scatto.call_deferred(x)
	if t >= 8.0 or (not foto.is_empty() and t > foto[foto.size() - 1] + 0.1):
		print("FINE")
		get_tree().quit()


func _scatto(x: float) -> void:
	await RenderingServer.frame_post_draw
	var nome := "%s_%s_%04.1f.jpg" % [stile, lancia.get_file().get_basename(), x]
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome), 0.9)
	print("salvato ", nome)


func _azione(nome: StringName, on: bool) -> void:
	if on and not Input.is_action_pressed(nome):
		Input.action_press(nome)
	elif not on and Input.is_action_pressed(nome):
		Input.action_release(nome)
