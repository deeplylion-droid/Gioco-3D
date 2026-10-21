extends Node
## Scatti di controllo del portone della sala della torre e dell'interno vicino all'ingresso (squadra
## ambienti-2). Scena leggera, senza la sala principale intera: architettura e interattivi della sala,
## la sala della torre e un PortoneTorre vero sull'anta. Una luce ambiente bassa per vedere le forme.
##
## Uso, sotto il render.lock:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_portone_torre.gd <cartella> [camere separate da virgole]
## Ogni camera dà <cartella>/<camera>_<apertura>.jpg (apertura 0, 50 o 100 per cento).

const SALA := "res://assets/ambiente/sala/"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const PORTONE: GDScript = preload("res://scripts/mechanisms/portone_torre.gd")

## nome: [camera, punto guardato, aperture]
const CAMERE := {
	"sala_lontano": [Vector3(11.0, 1.7, -9.0), Vector3(19.8, 2.6, -15.0), [0.0, 0.5, 1.0]],
	"sala_vicino": [Vector3(15.5, 1.7, -13.2), Vector3(19.8, 2.8, -15.6), [0.0, 1.0]],
	"sala_binario": [Vector3(17.0, 1.7, -10.0), Vector3(19.8, 5.2, -12.0), [1.0]],
	"dentro_indietro": [Vector3(23.5, 1.7, -15.0), Vector3(19.8, 2.6, -15.0), [1.0]],
	"dentro_lato_sud": [Vector3(22.4, 1.7, -15.0), Vector3(20.5, 2.6, -8.5), [1.0]],
	"dentro_lato_nord": [Vector3(22.4, 1.7, -15.0), Vector3(20.5, 2.6, -21.5), [1.0]],
	"varco_aperto": [Vector3(16.0, 1.7, -15.0), Vector3(21.5, 2.0, -15.0), [1.0]],
	"muro_est_sud": [Vector3(12.5, 1.7, 1.0), Vector3(19.8, 2.4, -6.0), [0.0, 1.0]],
	"fine_corsa": [Vector3(16.5, 1.7, -2.5), Vector3(19.8, 3.0, -7.0), [1.0]],
	"cornice_lato": [Vector3(17.2, 1.7, -8.5), Vector3(19.8, 3.0, -13.0), [0.0, 0.5, 1.0]],
	"cornice_staffe": [Vector3(17.5, 3.6, -14.0), Vector3(19.9, 5.4, -16.5), [0.0]],
}

var out_dir := "user://scatti_portone_torre"
var solo := PackedStringArray()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		solo = args[2].split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var radice := Node3D.new()
	add_child(radice)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	radice.add_child(env)
	var sala := Node3D.new()
	sala.name = "Sala"
	radice.add_child(sala)
	for nome in ["architettura", "interattivi", "oggetti", "luci"]:
		var n := (load(SALA + "sala_%s.glb" % nome) as PackedScene).instantiate()
		n.name = nome.capitalize()
		sala.add_child(n)
	var torre := (load(TORRE) as PackedScene).instantiate()
	radice.add_child(torre)
	var guscio := sala.find_child("sala_torre_guscio", true, false)
	if guscio:
		guscio.queue_free()
	# la cornice di lampadine dell'enigma degli acquari, accesa
	var enigma := (load("res://scenes/sala/enigma_acquari.tscn") as PackedScene).instantiate()
	var lampade := enigma.get_node(^"LampadePortone")
	enigma.remove_child(lampade)
	enigma.free()
	radice.add_child(lampade)
	var portone: Node3D = PORTONE.new()
	portone.set(&"anta", sala.find_child("sala_portone_torre", true, false))
	portone.set(&"vetro", sala.find_child("sala_lampeggiante_torre", true, false))
	portone.set(&"apertura", 2)
	radice.add_child(portone)
	portone.position = Vector3(19.84, 0, -15)
	var cam := Camera3D.new()
	cam.fov = 70.0
	radice.add_child(cam)
	var luce := OmniLight3D.new()
	luce.omni_range = 14.0
	luce.light_energy = 1.2
	cam.add_child(luce)
	for i in 30:
		await get_tree().process_frame
	for nome in CAMERE:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var c: Array = CAMERE[nome]
		for k in c[2]:
			portone.call(&"_metti", float(k))
			cam.look_at_from_position(c[0], c[1])
			cam.make_current()
			for i in 12:
				await get_tree().process_frame
			var f := out_dir.path_join("%s_%d.jpg" % [nome, int(round(float(k) * 100.0))])
			get_viewport().get_texture().get_image().save_jpg(f, 0.9)
			print("scatto -> ", f)
	get_tree().quit()
