extends Node
## Scatti di controllo della sala della torre (squadra ambienti-2): la sala da sola (SalaTorre con le sue
## luci) con l'ambiente della sala grande. Le camere sono in coordinate di Blender (x, y, z).
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_torre.gd <cartella> [scatti separati da virgole]

const SCENA := "res://scenes/sala/torre/sala_torre.tscn"

## nome: [camera, punto guardato, campo visivo]
const SCATTI := {
	"p0_portone": [[22.4, 15.0, 1.7], [28.0, 21.0, 0.5], 80.0],
	"p0_imbocco": [[25.5, 20.0, 1.7], [30.0, 21.8, 0.3], 80.0],
	"p1_ne3": [[35.5, 21.0, -1.3], [38.0, 15.0, -3.0], 80.0],
	"p2_se6": [[37.0, 11.0, -4.3], [32.0, 8.2, -6.0], 80.0],
	"p3_so9": [[27.0, 9.5, -7.3], [24.0, 13.5, -9.0], 80.0],
	"p4_no12": [[24.5, 20.0, -10.3], [30.0, 22.0, -12.0], 80.0],
	"p5_ne15": [[36.0, 21.5, -13.3], [38.3, 16.0, -16.0], 80.0],
	"alto_salto1": [[29.0, 18.0, 2.5], [31.0, 22.1, -3.0], 75.0],
	"vista_giu": [[22.5, 15.0, 1.7], [31.0, 15.0, -14.0], 90.0],
	# la strada (21 ottobre): l'imbocco giusto col portale verde, una bocca chiusa con la lampada rossa, una
	# vasca di raccolta con la scaletta
	"s1_imbocco_giusto": [[31.5, 19.0, 2.2], [28.2, 22.0, 1.0], 75.0],
	"s1b_imbocco_giusto": [[39.0, 14.6, -1.0], [37.8, 17.9, -1.8], 75.0],
	"s2_imbocco_chiuso": [[22.6, 13.4, -1.35], [25.6, 11.4, -2.6], 70.0],
	"s2b_imbocco_chiuso": [[30.4, 12.4, 4.65], [27.4, 9.9, 3.4], 70.0],
	"s2c_imbocco_chiuso": [[24.0, 15.2, -1.35], [25.6, 18.6, -2.6], 70.0],
	"s3_vasca_scaletta": [[36.4, 19.6, -1.3], [36.4, 15.0, -6.6], 80.0],
	"s3b_vasca_scaletta": [[31.3, 13.6, -6.0], [33.2, 10.0, -10.0], 80.0],
	"s3c_vasca_scaletta": [[24.6, 10.0, -7.4], [24.6, 15.0, -12.8], 80.0],
}

var cartella := "user://scatti_torre"
var solo := PackedStringArray()


static func b(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1])


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		solo = a[2].split(",", false)
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := (load(SCENA) as PackedScene).instantiate()
	add_child(sala)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in 40:
		await get_tree().process_frame
	# in più: da ogni checkpoint, dove si riparte, guardando la discesa ("cp_<n>") e di lato ("cpl_<n>")
	var scatti := SCATTI.duplicate()
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ambiente/torre/torre_gioco.json"))
	var k := 0
	for cp in dati["checkpoint"]:
		var sp: Array = cp.get("spawn", cp["pos"])
		var g: Array = cp["guarda"]
		var occhio := [sp[0], sp[1], sp[2] + 1.6]
		scatti["cp_%d" % k] = [occhio, [g[0], g[1], g[2] + 0.8], 85.0]
		var dx: float = g[0] - sp[0]
		var dy: float = g[1] - sp[1]
		scatti["cpl_%d" % k] = [occhio, [sp[0] - dy, sp[1] + dx, sp[2] + 0.6], 85.0]
		k += 1
	for nome in scatti:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var s: Array = scatti[nome]
		cam.fov = s[2]
		cam.look_at_from_position(b(s[0]), b(s[1]))
		for i in 25:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()
