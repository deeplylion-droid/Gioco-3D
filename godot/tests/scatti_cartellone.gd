extends Node
## Scatti del cartellone di Jilly nel corridoio degli interni (25 ottobre: 1,2 x 1,6 m a 3 mm dal muro, sotto la
## canalina dei cavi, il listello dello zoccolo che si ferma ai lati della cornice), dagli occhi del giocatore: uno
## davanti e due radenti lungo il muro sud. COLLAUDO_LUCE=1 aggiunge una luce provvisoria sulla camera, solo negli
## scatti (per vedere com'è attaccato al buio), non nel gioco.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_cartellone.gd <cartella>

const INTERNI := "res://scenes/interni/interni.tscn"
## [occhio, guardato, fov]
const SCATTI := {
	"cartellone_davanti": [Vector3(14.6, 1.6, -2.3), Vector3(14.6, 1.15, 0.0), 70.0],
	"cartellone_radente_ovest": [Vector3(12.7, 1.6, -0.45), Vector3(14.9, 1.15, -0.01), 60.0],
	"cartellone_radente_est": [Vector3(16.5, 1.6, -0.45), Vector3(14.3, 1.15, -0.01), 60.0],
}

var cartella := "user://scatti_cartellone"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var interni := (load(INTERNI) as PackedScene).instantiate()
	add_child(interni)
	for i in 10:
		await get_tree().process_frame
	# niente giocatore davanti alla camera
	for p in interni.find_children("*", "Player", true, false):
		(p as Node3D).visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var luce: OmniLight3D = null
	if OS.get_environment("COLLAUDO_LUCE") == "1":
		luce = OmniLight3D.new()
		luce.light_energy = 1.5
		luce.omni_range = 4.0
		luce.shadow_enabled = true
		add_child(luce)
	for nome in SCATTI:
		var s: Array = SCATTI[nome]
		cam.fov = s[2]
		cam.look_at_from_position(s[0], s[1])
		if luce != null:
			luce.global_position = s[0]
		for i in 40:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ("_luce" if luce != null else "") + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.88)
		print("scatto -> ", f)
	get_tree().quit()
